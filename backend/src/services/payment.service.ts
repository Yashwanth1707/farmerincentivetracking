import prisma from '../utils/prisma';
import { config } from '../config';
import { NotFoundError, ValidationError } from '../utils/errors';
import { PaginatedResult } from '../types';
import * as XLSX from 'xlsx';
import { Decimal } from '@prisma/client/runtime/library';

export class PaymentService {
  /**
   * Parse uploaded Excel file and return preview data
   */
  async parseExcel(filePath: string) {
    const workbook = XLSX.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json<any[]>(sheet, { header: 1, defval: '' });

    if (rows.length < 2) {
      throw new ValidationError({ file: ['Excel file must include a header row and at least one data row'] });
    }

    const headers = rows[0].map((value) => String(value).trim());
    const normalizedHeaders = headers.map((header) => header.toLowerCase());
    const isSimpleTemplate = normalizedHeaders[0] === 'farmer id'
      && normalizedHeaders[1] === 'incentive amount'
      && (normalizedHeaders[2] === 'remarks' || normalizedHeaders[2] === 'remarks (optional)');

    if (!isSimpleTemplate) {
      throw new ValidationError({ file: ['Invalid Excel format. Please use the provided sample template.'] });
    }

    const fileFarmerIds = new Set<string>();
    const duplicateFarmerIds = new Set<string>();
    const errors: { row: number; field: string; message: string }[] = [];
    const validRows: any[] = [];

    for (let i = 1; i < rows.length; i += 1) {
      const rowNum = i + 1;
      const row = rows[i];
      const farmerId = String(row[0] ?? '').trim();
      const incentiveAmount = Number(String(row[1] ?? '').trim());
      const remarks = String(row[2] ?? '').trim();

      if (!farmerId) {
        errors.push({ row: rowNum, field: 'Farmer ID', message: 'Farmer ID is required' });
      }
      if (!Number.isFinite(incentiveAmount) || incentiveAmount <= 0) {
        errors.push({ row: rowNum, field: 'Incentive Amount', message: 'Incentive Amount must be greater than zero' });
      }

      if (farmerId) {
        if (fileFarmerIds.has(farmerId)) {
          duplicateFarmerIds.add(farmerId);
          errors.push({ row: rowNum, field: 'Farmer ID', message: 'Duplicate Farmer ID in uploaded file' });
        } else {
          fileFarmerIds.add(farmerId);
        }
      }

      if (errors.some((error) => error.row === rowNum)) {
        continue;
      }

      validRows.push({
        farmerId,
        incentiveAmount,
        remarks,
      });
    }

    const existingFarmerErrors = await this.validateExistingFarmerAndPhone(Array.from(fileFarmerIds), []);
    errors.push(...existingFarmerErrors);

    const summary = {
      totalRecords: rows.length - 1,
      successfullyValidated: validRows.length,
      failedRecords: new Set(errors.map((error) => error.row)).size,
      duplicateFarmerIds: duplicateFarmerIds.size,
      duplicateMobileNumbers: 0,
    };

    return { validRows, errors, summary };
  }

  /**
   * Preview uploaded payments - match farmers and calculate TDS
   */
  async previewPayments(validRows: any[], financialYearId: string) {
    const results = [];
    const notFoundFarmers: string[] = [];

    const financialYear = await prisma.financialYear.findUnique({ where: { id: financialYearId } });
    const previousFinancialYear = financialYear
      ? await prisma.financialYear.findFirst({
          where: { startDate: { lt: financialYear.startDate } },
          orderBy: { startDate: 'desc' },
        })
      : null;

    const tdsThreshold = await this.getTdsThreshold();
    const tdsPercentage = await this.getTdsPercentage();

    for (const row of validRows) {
      const farmer = await prisma.farmer.findUnique({
        where: { farmerId: row.farmerId },
      });

      if (!farmer) {
        notFoundFarmers.push(row.farmerId);
        results.push({
          ...row,
          status: 'FARMER_NOT_FOUND',
          message: 'Farmer ID not found in master data',
        });
        continue;
      }

      const previousYearResult = previousFinancialYear
        ? await prisma.payment.aggregate({
            where: {
              farmerId: farmer.id,
              financialYearId: previousFinancialYear.id,
            },
            _sum: { grossAmount: true },
          })
        : null;

      const previousYearIncentive = previousYearResult?._sum.grossAmount
        ? Number(previousYearResult._sum.grossAmount)
        : 0;

      const totalYearlyIncentive = previousYearIncentive + Number(row.incentiveAmount);
      const tdsApplicable = totalYearlyIncentive >= tdsThreshold;
      const tdsAmount = tdsApplicable
        ? Math.round(Number(row.incentiveAmount) * (tdsPercentage / 100) * 100) / 100
        : 0;

      results.push({
        farmerId: row.farmerId,
        farmerName: farmer.name,
        village: farmer.village,
        district: farmer.district,
        bankName: farmer.bankName,
        branchName: farmer.branchName,
        ifscCode: farmer.ifscCode,
        accountNumber: farmer.accountNumber,
        accountHolderName: farmer.accountHolderName ?? farmer.name,
        areaInAcres: farmer.areaInAcres ? Number(farmer.areaInAcres) : null,
        areaInHectares: farmer.areaInHectares ? Number(farmer.areaInHectares) : null,
        grossAmount: Number(row.incentiveAmount),
        previousYearIncentive,
        totalYearlyIncentive,
        tdsApplicable,
        suggestedTdsPercentage: tdsApplicable ? tdsPercentage : 0,
        tdsPercentage: tdsApplicable ? tdsPercentage : 0,
        tdsAmount,
        netAmount: Number(row.incentiveAmount) - tdsAmount,
        remarks: row.remarks,
        farmerInternalId: farmer.id,
        status: tdsApplicable ? 'TDS_REQUIRED' : 'READY',
      });
    }

    return { results, notFoundFarmers };
  }

  async processPayments(
    previewResults: any[],
    financialYearId: string,
    userId: string,
    batchName?: string,
    tdsPercentages?: Record<string, number>,
    paymentDate?: Date,
  ) {
    const validRows = previewResults.filter((row) => row.status !== 'FARMER_NOT_FOUND' && row.status !== 'INVALID');

    if (validRows.length === 0) {
      throw new ValidationError({ previewResults: ['No valid payments to process'] });
    }

    const financialYear = await prisma.financialYear.findUnique({ where: { id: financialYearId } });
    if (!financialYear) throw new NotFoundError('Financial year');

    const batchLabel = batchName?.trim() || `Kharif Batch ${new Date().getFullYear()}`;
    const batchNumber = `${batchLabel.replace(/[^a-zA-Z0-9]/g, '-').toUpperCase()}-${String(Date.now()).slice(-4)}`;

    const createdPayments = [] as any[];

    for (const row of validRows) {
      const selectedTdsPercentage = tdsPercentages?.[row.farmerId] ?? row.tdsPercentage ?? 0;
      const tdsAmount = row.tdsApplicable
        ? Math.round(Number(row.grossAmount) * (selectedTdsPercentage / 100) * 100) / 100
        : 0;
      const netAmount = Number(row.grossAmount) - tdsAmount;

      const payment = await prisma.payment.create({
        data: {
          farmerId: row.farmerInternalId,
          financialYearId,
          invoiceNumber: `TXN-${Date.now()}-${createdPayments.length + 1}`,
          grossAmount: new Decimal(row.grossAmount),
          tdsAmount: new Decimal(tdsAmount),
          netAmount: new Decimal(netAmount),
          tdsApplicable: Boolean(row.tdsApplicable || selectedTdsPercentage > 0),
          tdsPercentage: selectedTdsPercentage > 0 ? new Decimal(selectedTdsPercentage) : null,
          paymentDate: paymentDate || new Date(),
          notes: row.remarks || undefined,
        },
      });

      if (row.tdsApplicable || selectedTdsPercentage > 0) {
        await prisma.tdsRecord.create({
          data: {
            farmerId: row.farmerInternalId,
            financialYearId,
            cumulativeAmount: new Decimal(row.totalYearlyIncentive ?? row.grossAmount),
            decision: 'YES',
            decidedBy: userId,
            decidedAt: new Date(),
            notes: `Auto-applied TDS at ${selectedTdsPercentage}%`,
          },
        });
      }

      createdPayments.push(payment);
    }

    const batch = await prisma.paymentBatch.create({
      data: {
        batchNumber,
        financialYearId,
        totalFarmers: createdPayments.length,
        totalGrossAmount: new Decimal(createdPayments.reduce((sum, payment) => sum + Number(payment.grossAmount), 0)),
        totalTdsAmount: new Decimal(createdPayments.reduce((sum, payment) => sum + Number(payment.tdsAmount), 0)),
        totalNetAmount: new Decimal(createdPayments.reduce((sum, payment) => sum + Number(payment.netAmount), 0)),
        status: 'PAID',
        processedBy: userId,
        paymentDate: paymentDate || new Date(),
        notes: batchLabel,
        batchDetails: {
          create: createdPayments.map((payment) => ({
            paymentId: payment.id,
            farmerId: payment.farmerId,
          })),
        },
      },
    });

    return {
      batch,
      payments: createdPayments,
      totalFarmers: createdPayments.length,
      totalGrossAmount: createdPayments.reduce((sum, payment) => sum + Number(payment.grossAmount), 0),
      totalTdsAmount: createdPayments.reduce((sum, payment) => sum + Number(payment.tdsAmount), 0),
      totalNetAmount: createdPayments.reduce((sum, payment) => sum + Number(payment.netAmount), 0),
    };
  }

  /**
   * Confirm and save payments from preview
   */
  async confirmPayments(previewResults: any[], financialYearId: string, userId: string) {
    const savedPayments = [];

    for (const row of previewResults) {
      if (row.status === 'FARMER_NOT_FOUND') continue;

      const existingPayment = await prisma.payment.findFirst({
        where: {
          farmerId: row.farmerInternalId,
          financialYearId,
          invoiceNumber: row.invoiceNumber || undefined,
        },
      });

      // Skip duplicates (same farmer, same FY, same invoice)
      if (existingPayment) continue;

      const payment = await prisma.payment.create({
        data: {
          farmerId: row.farmerInternalId,
          financialYearId,
          invoiceNumber: row.invoiceNumber,
          grossAmount: new Decimal(row.grossAmount),
          tdsAmount: new Decimal(row.tdsAmount),
          netAmount: new Decimal(row.netAmount),
          tdsApplicable: row.tdsApplicable,
          tdsPercentage: row.tdsApplicable ? new Decimal(row.tdsPercentage) : null,
          isTdsDecisionPending: row.needsDecision || false,
        },
      });

      savedPayments.push(payment);
    }

    return savedPayments;
  }

  /**
   * Create a payment batch from selected payments
   */
  async createBatch(paymentIds: string[], financialYearId: string, userId: string, notes?: string) {
    if (paymentIds.length === 0) {
      throw new ValidationError({ paymentIds: ['At least one payment must be selected'] });
    }

    const payments = await prisma.payment.findMany({
      where: {
        id: { in: paymentIds },
        financialYearId,
      },
    });

    if (payments.length !== paymentIds.length) {
      throw new NotFoundError('One or more payments not found');
    }

    // Check no payments are already in a batch
    const existingBatchDetails = await prisma.batchDetail.findMany({
      where: { paymentId: { in: paymentIds } },
      include: { batch: true },
    });

    if (existingBatchDetails.length > 0) {
      const batchPayments = existingBatchDetails.map(bd => bd.paymentId);
      throw new ValidationError({
        paymentIds: [`Payments ${batchPayments.join(', ')} are already in a batch`],
      });
    }

    // Generate batch number
    const fy = await prisma.financialYear.findUnique({ where: { id: financialYearId } });
    if (!fy) throw new NotFoundError('Financial year');

    const batchCount = await prisma.paymentBatch.count({
      where: { financialYearId },
    });
    const shortYear = fy.yearLabel.split('-')[0];
    const batchNumber = `BATCH-${shortYear}-${String(batchCount + 1).padStart(4, '0')}`;

    // Calculate totals
    const totalGross = payments.reduce((sum, p) => sum + Number(p.grossAmount), 0);
    const totalTds = payments.reduce((sum, p) => sum + Number(p.tdsAmount), 0);
    const totalNet = payments.reduce((sum, p) => sum + Number(p.netAmount), 0);

    const batch = await prisma.paymentBatch.create({
      data: {
        batchNumber,
        financialYearId,
        totalFarmers: payments.length,
        totalGrossAmount: new Decimal(totalGross),
        totalTdsAmount: new Decimal(totalTds),
        totalNetAmount: new Decimal(totalNet),
        processedBy: userId,
        notes,
        batchDetails: {
          create: payments.map(p => ({
            paymentId: p.id,
            farmerId: p.farmerId,
          })),
        },
      },
      include: {
        batchDetails: {
          include: {
            payment: {
              include: { farmer: { select: { name: true, farmerId: true, village: true } } },
            },
          },
        },
      },
    });

    return batch;
  }

  /**
   * Approve a batch
   */
  async approveBatch(batchId: string, userId: string) {
    const batch = await prisma.paymentBatch.findUnique({
      where: { id: batchId },
      include: { batchDetails: { include: { payment: true } } },
    });

    if (!batch) throw new NotFoundError('Batch');
    if (batch.status !== 'DRAFT' && batch.status !== 'PENDING_APPROVAL') {
      throw new ValidationError({ status: ['Batch can only be approved from DRAFT or PENDING_APPROVAL status'] });
    }

    // Auto-approve any pending TDS decisions or flag them
    const pendingTdsFarmers = batch.batchDetails
      .filter(bd => bd.payment.isTdsDecisionPending)
      .map(bd => bd.payment);

    if (pendingTdsFarmers.length > 0) {
      // Set status to PENDING_APPROVAL if TDS decisions are pending
      return prisma.paymentBatch.update({
        where: { id: batchId },
        data: { status: 'PENDING_APPROVAL' },
      });
    }

    return prisma.paymentBatch.update({
      where: { id: batchId },
      data: {
        status: 'APPROVED',
        approvedBy: userId,
        approvedAt: new Date(),
        paymentDate: new Date(),
      },
    });
  }

  /**
   * Reject a batch
   */
  async rejectBatch(batchId: string, reason: string, userId: string) {
    const batch = await prisma.paymentBatch.findUnique({ where: { id: batchId } });
    if (!batch) throw new NotFoundError('Batch');
    if (batch.status === 'APPROVED' || batch.status === 'PAID') {
      throw new ValidationError({ status: ['Cannot reject an approved or paid batch'] });
    }

    return prisma.paymentBatch.update({
      where: { id: batchId },
      data: {
        status: 'REJECTED',
        rejectedReason: reason,
        approvedBy: userId,
        approvedAt: new Date(),
      },
    });
  }

  async generateBatchPaymentFile(batchId: string) {
    const batch = await prisma.paymentBatch.findUnique({
      where: { id: batchId },
      include: {
        batchDetails: {
          include: {
            farmer: true,
            payment: true,
          },
        },
      },
    });

    if (!batch) throw new NotFoundError('Batch');

    const paymentSettings = await this.getPaymentSettings();
    const remitterAccountNo = paymentSettings.payment_remitter_account_no || '';
    const remitterName = paymentSettings.payment_remitter_name || 'Eco Agripreneurs Pvt Ltd';
    const remitterIfsc = paymentSettings.payment_remitter_ifsc || '';
    const beneficiaryLeiCode = paymentSettings.payment_beneficiary_lei_code || '';

    const rows = batch.batchDetails.map((detail, index) => ({
      Transaction_Ref_No: this.buildTransactionRef(batch, index + 1),
      Remitter_Account_No: remitterAccountNo,
      Remitter_Name: remitterName,
      IFSC_Code: remitterIfsc,
      Amount: Number(detail.payment.netAmount).toFixed(2),
      Bank_Account_Number: detail.farmer.accountNumber || '',
      Beneficiary_Name: detail.farmer.accountHolderName || detail.farmer.name,
      Beneficiary_LEI_Code: beneficiaryLeiCode || '',
    }));

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(rows, {
      header: [
        'Transaction_Ref_No',
        'Remitter_Account_No',
        'Remitter_Name',
        'IFSC_Code',
        'Amount',
        'Bank_Account_Number',
        'Beneficiary_Name',
        'Beneficiary_LEI_Code',
      ]
    });
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Payments');
    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }

  async generateSampleOutputExcel() {
    const sampleRows = [];
    for (let i = 1; i <= 10; i += 1) {
      sampleRows.push({
        'Farmer ID': `FARM${String(i).padStart(4, '0')}`,
        'Farmer Name': `Farmer ${i}`,
        Village: `Village ${i}`,
        'Bank Name': 'State Bank of India',
        Branch: `Branch ${i}`,
        IFSC: 'SBIN0001234',
        'Account Number': `ACC${String(100000 + i)}`,
        'Gross Incentive': (Math.round((5000 + i * 1000) * 100) / 100).toFixed(2),
        'TDS %': '0%',
        'TDS Amount': '0.00',
        'Net Amount': (Math.round((5000 + i * 1000) * 100) / 100).toFixed(2),
        Batch: 'Kharif Batch 1',
        'Payment Date': new Date().toISOString().slice(0, 10),
        Status: 'Ready',
      });
    }

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(sampleRows, {
      header: [
        'Farmer ID',
        'Farmer Name',
        'Village',
        'Bank Name',
        'Branch',
        'IFSC',
        'Account Number',
        'Gross Incentive',
        'TDS %',
        'TDS Amount',
        'Net Amount',
        'Batch',
        'Payment Date',
        'Status',
      ],
    });
    XLSX.utils.book_append_sheet(workbook, worksheet, 'PaymentOutput');
    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }

  generateSampleExcel(): Buffer {
    const sampleData = [
      {
        'Farmer ID': 'FARM0001',
        'Incentive Amount': '5000',
        Remarks: 'Sample upload row',
      },
      {
        'Farmer ID': 'FARM0002',
        'Incentive Amount': '7500',
        Remarks: 'Sample upload row',
      },
    ];

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(sampleData, {
      header: ['Farmer ID', 'Incentive Amount', 'Remarks'],
    });
    XLSX.utils.book_append_sheet(workbook, worksheet, 'SampleInput');
    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }

  generateImportErrorReport(errors: { row: number; field: string; message: string }[]) {
    const rows = errors.map((error) => ({
      Row: error.row,
      Field: error.field,
      Message: error.message,
    }));

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(rows, {
      header: ['Row', 'Field', 'Message'],
    });
    XLSX.utils.book_append_sheet(workbook, worksheet, 'ImportErrors');
    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }

  private buildTransactionRef(batch: any, sequence: number) {
    const date = batch.paymentDate ? new Date(batch.paymentDate) : new Date(batch.createdAt);
    const datePart = date.toISOString().slice(0, 10).replace(/-/g, '');
    return `${datePart}${String(sequence).padStart(4, '0')}`;
  }

  private async getPaymentSettings() {
    const settings = await prisma.setting.findMany({
      where: {
        key: {
          in: [
            'payment_remitter_account_no',
            'payment_remitter_name',
            'payment_remitter_ifsc',
            'payment_beneficiary_lei_code',
            'tds_threshold',
            'tds_percentage',
          ],
        },
      },
    });

    const map: Record<string, any> = {};
    for (const entry of settings) {
      try {
        map[entry.key] = JSON.parse(entry.value);
      } catch {
        map[entry.key] = entry.value;
      }
    }
    return map;
  }

  private async validateExistingFarmerAndPhone(farmerIds: string[], mobileNumbers: string[]) {
    const where: any = {
      OR: [],
    };
    if (farmerIds.length > 0) {
      where.OR.push({ farmerId: { in: farmerIds } });
    }
    if (mobileNumbers.length > 0) {
      where.OR.push({ phone: { in: mobileNumbers } });
    }
    if (where.OR.length === 0) return [];

    const existing = await prisma.farmer.findMany({
      where,
      select: { farmerId: true, phone: true },
    });

    const errors: { row: number; field: string; message: string }[] = [];
    for (const farmer of existing) {
      if (farmerIds.includes(farmer.farmerId)) {
        errors.push({ row: 0, field: 'Farmer ID', message: `Farmer ID ${farmer.farmerId} already exists in the system` });
      }
      if (farmer.phone && mobileNumbers.includes(farmer.phone)) {
        errors.push({ row: 0, field: 'Registered Mobile Number', message: `Mobile number ${farmer.phone} already exists in the system` });
      }
    }
    return errors;
  }

  /**
   * List batches with pagination
   */
  async listBatches(params: {
    page?: number;
    limit?: number;
    status?: string;
    financialYearId?: string;
  }): Promise<PaginatedResult<any>> {
    const page = Number(params.page) || 1;
    const limit = Number(params.limit) || 20;

    const skip = (page - 1) * limit;
    const where: any = {};

    if (params.status) where.status = params.status;
    if (params.financialYearId) where.financialYearId = params.financialYearId;

    const [data, total] = await Promise.all([
      prisma.paymentBatch.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          financialYear: { select: { yearLabel: true } },
          processedByUser: { select: { id: true, fullName: true } },
          approvedByUser: { select: { id: true, fullName: true } },
          _count: { select: { batchDetails: true } },
        },
      }),
      prisma.paymentBatch.count({ where }),
    ]);

    return {
      data,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /**
   * Get batch by ID with full details
   */
  async getBatchById(id: string) {
    const batch = await prisma.paymentBatch.findUnique({
      where: { id },
      include: {
        financialYear: { select: { yearLabel: true } },
        processedByUser: { select: { id: true, fullName: true } },
        approvedByUser: { select: { id: true, fullName: true } },
        batchDetails: {
          include: {
            farmer: {
              select: {
                id: true,
                farmerId: true,
                name: true,
                village: true,
                district: true,
                bankName: true,
                accountNumber: true,
                ifscCode: true,
              },
            },
            payment: true,
          },
        },
      },
    });

    if (!batch) throw new NotFoundError('Batch');
    return batch;
  }

  async generatePreviewReport(previewResults: any[]) {
    const rows = previewResults.map((row) => ({
      'Farmer ID': row.farmerId,
      'Farmer Name': row.farmerName,
      Village: row.village,
      'Bank Name': row.bankName,
      Branch: row.branchName || '',
      IFSC: row.ifscCode || '',
      'Account Number': row.accountNumber || '',
      'Gross Incentive': Number(row.grossAmount).toFixed(2),
      'TDS %': `${Number(row.tdsPercentage || 0).toFixed(2)}%`,
      'TDS Amount': Number(row.tdsAmount || 0).toFixed(2),
      'Net Amount': Number(row.netAmount || 0).toFixed(2),
      Batch: row.batchName || 'Pending',
      'Payment Date': row.paymentDate || '',
      Status: row.tdsApplicable ? 'TDS Required' : 'Ready',
    }));

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(rows, {
      header: [
        'Farmer ID',
        'Farmer Name',
        'Village',
        'Bank Name',
        'Branch',
        'IFSC',
        'Account Number',
        'Gross Incentive',
        'TDS %',
        'TDS Amount',
        'Net Amount',
        'Batch',
        'Payment Date',
        'Status',
      ],
    });
    XLSX.utils.book_append_sheet(workbook, worksheet, 'PaymentPreview');
    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }

  async getBatchOptions() {
    const existingBatches = await prisma.paymentBatch.findMany({
      orderBy: { createdAt: 'desc' },
      take: 20,
      select: { id: true, batchNumber: true, status: true },
    });

    return [
      { value: 'Kharif Batch 1', label: 'Kharif Batch 1' },
      { value: 'Kharif Batch 2', label: 'Kharif Batch 2' },
      { value: 'Cotton Procurement Batch', label: 'Cotton Procurement Batch' },
      { value: 'Special Incentive Batch', label: 'Special Incentive Batch' },
      ...existingBatches.map((batch) => ({ value: batch.batchNumber, label: batch.batchNumber })),
    ];
  }

  /**
   * Get TDS threshold from settings
   */
  private async getTdsThreshold(): Promise<number> {
    const setting = await prisma.setting.findUnique({ where: { key: 'tds_threshold' } });
    return setting ? Number(setting.value) : config.tdsThresholdAmount;
  }

  /**
   * Get TDS percentage from settings
   */
  private async getTdsPercentage(): Promise<number> {
    const setting = await prisma.setting.findUnique({ where: { key: 'tds_percentage' } });
    return setting ? Number(setting.value) : config.defaultTdsPercentage;
  }

  /**
   * Handle TDS decision for a farmer
   */
  async handleTdsDecision(farmerId: string, financialYearId: string, decision: 'YES' | 'NO', decidedBy: string, notes?: string) {
    const farmer = await prisma.farmer.findUnique({ where: { id: farmerId } });
    if (!farmer) throw new NotFoundError('Farmer');

    const cumulativeResult = await prisma.payment.aggregate({
      where: { farmerId, financialYearId },
      _sum: { grossAmount: true },
    });

    const cumulativeAmount = cumulativeResult._sum.grossAmount
      ? Number(cumulativeResult._sum.grossAmount)
      : 0;

    await prisma.tdsRecord.create({
      data: {
        farmerId,
        financialYearId,
        cumulativeAmount: new Decimal(cumulativeAmount),
        decision,
        decidedBy,
        decidedAt: new Date(),
        notes,
      },
    });

    if (decision === 'YES') {
      const tdsPercentage = await this.getTdsPercentage();

      // Update all unpaid payments for this farmer in this FY that need TDS
      await prisma.payment.updateMany({
        where: {
          farmerId,
          financialYearId,
          isTdsDecisionPending: true,
        },
        data: {
          tdsApplicable: true,
          tdsPercentage: new Decimal(tdsPercentage),
          tdsAmount: new Decimal(tdsPercentage / 100),
          isTdsDecisionPending: false,
        },
      });

      // Recalculate actual TDS amounts
      const pendingPayments = await prisma.payment.findMany({
        where: {
          farmerId,
          financialYearId,
          tdsApplicable: true,
        },
      });

      for (const payment of pendingPayments) {
        const tdsAmount = Math.round(Number(payment.grossAmount) * (tdsPercentage / 100) * 100) / 100;
        await prisma.payment.update({
          where: { id: payment.id },
          data: {
            tdsAmount: new Decimal(tdsAmount),
            netAmount: new Decimal(Number(payment.grossAmount) - tdsAmount),
          },
        });
      }
    } else {
      // Mark as TDS not applicable
      await prisma.payment.updateMany({
        where: {
          farmerId,
          financialYearId,
          isTdsDecisionPending: true,
        },
        data: {
          tdsApplicable: false,
          tdsAmount: new Decimal(0),
          isTdsDecisionPending: false,
        },
      });
    }

    return { message: `TDS decision recorded: ${decision}` };
  }

}

export const paymentService = new PaymentService();