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
    const expectedHeaders = [
      'Column',
      'Field Center',
      'Implementation Partner',
      'State',
      'Area',
      'Belongs To',
      'Field Officer',
      'Farmer ID',
      'Alternate Farmer ID',
      'Farmer Name',
      'Father/Husband Name',
      'Last Name',
      'Financial Year',
      'Season',
      'District',
      'Mandal / Taluk',
      'Village',
      'Registered Mobile Number',
      'Area in Acres',
      'Area in Hectares',
      'Incentive Amount',
      'Bank Linked Mobile Number',
      'Account Holder Name',
      'Account Number',
      'Account Type',
      'Bank Name',
      'IFSC Code',
      'Branch Name',
      'Branch Address',
      'Remarks',
      'Upload Date',
    ];

    if (headers.length !== expectedHeaders.length || !expectedHeaders.every((value, index) => headers[index] === value)) {
      throw new ValidationError({ file: ['Excel headers must match the required template exactly'] });
    }

    const fieldMap: Record<string, string> = {
      Column: 'column',
      'Field Center': 'fieldCenter',
      'Implementation Partner': 'implementationPartner',
      State: 'state',
      Area: 'area',
      'Belongs To': 'belongsTo',
      'Field Officer': 'fieldOfficer',
      'Farmer ID': 'farmerId',
      'Alternate Farmer ID': 'alternateFarmerId',
      'Farmer Name': 'farmerName',
      'Father/Husband Name': 'fatherName',
      'Last Name': 'lastName',
      'Financial Year': 'financialYear',
      Season: 'season',
      District: 'district',
      'Mandal / Taluk': 'mandalTaluk',
      Village: 'village',
      'Registered Mobile Number': 'registeredMobileNumber',
      'Area in Acres': 'areaInAcres',
      'Area in Hectares': 'areaInHectares',
      'Incentive Amount': 'incentiveAmount',
      'Bank Linked Mobile Number': 'bankLinkedMobileNumber',
      'Account Holder Name': 'accountHolderName',
      'Account Number': 'accountNumber',
      'Account Type': 'accountType',
      'Bank Name': 'bankName',
      'IFSC Code': 'ifscCode',
      'Branch Name': 'branchName',
      'Branch Address': 'branchAddress',
      Remarks: 'remarks',
      'Upload Date': 'uploadDate',
    };

    const fileFarmerIds = new Set<string>();
    const fileMobileNumbers = new Set<string>();
    const duplicateFarmerIds = new Set<string>();
    const duplicateMobileNumbers = new Set<string>();
    const errors: { row: number; field: string; message: string }[] = [];
    const validRows: any[] = [];

    for (let i = 1; i < rows.length; i += 1) {
      const rowNum = i + 1;
      const row = rows[i];
      const parsedRow: Record<string, any> = {};

      for (let j = 0; j < expectedHeaders.length; j += 1) {
        const header = expectedHeaders[j];
        parsedRow[fieldMap[header]] = String(row[j] ?? '').trim();
      }

      const farmerId = parsedRow.farmerId;
      const farmerName = parsedRow.farmerName;
      const village = parsedRow.village;
      const financialYear = parsedRow.financialYear;
      const ifscCode = parsedRow.ifscCode;
      const accountNumber = parsedRow.accountNumber;
      const accountHolderName = parsedRow.accountHolderName;
      const incentiveAmount = Number(parsedRow.incentiveAmount);
      const registeredMobileNumber = parsedRow.registeredMobileNumber;

      if (!farmerId) {
        errors.push({ row: rowNum, field: 'Farmer ID', message: 'Farmer ID is required' });
      }
      if (!farmerName) {
        errors.push({ row: rowNum, field: 'Farmer Name', message: 'Farmer Name is required' });
      }
      if (!village) {
        errors.push({ row: rowNum, field: 'Village', message: 'Village is required' });
      }
      if (!financialYear) {
        errors.push({ row: rowNum, field: 'Financial Year', message: 'Financial Year is required' });
      }
      if (!ifscCode) {
        errors.push({ row: rowNum, field: 'IFSC Code', message: 'IFSC Code is required' });
      }
      if (!accountNumber) {
        errors.push({ row: rowNum, field: 'Account Number', message: 'Account Number is required' });
      }
      if (!accountHolderName) {
        errors.push({ row: rowNum, field: 'Account Holder Name', message: 'Account Holder Name is required' });
      }
      if (Number.isNaN(incentiveAmount) || incentiveAmount <= 0) {
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

      if (registeredMobileNumber) {
        if (fileMobileNumbers.has(registeredMobileNumber)) {
          duplicateMobileNumbers.add(registeredMobileNumber);
          errors.push({ row: rowNum, field: 'Registered Mobile Number', message: 'Duplicate mobile number in uploaded file' });
        } else {
          fileMobileNumbers.add(registeredMobileNumber);
        }
      }

      if (errors.some((error) => error.row === rowNum)) {
        continue;
      }

      validRows.push({
        ...parsedRow,
        incentiveAmount,
        areaInAcres: parsedRow.areaInAcres ? Number(parsedRow.areaInAcres) : undefined,
        areaInHectares: parsedRow.areaInHectares ? Number(parsedRow.areaInHectares) : undefined,
        uploadDate: parsedRow.uploadDate ? new Date(parsedRow.uploadDate) : undefined,
      });
    }

    const existingFarmerErrors = await this.validateExistingFarmerAndPhone(Array.from(fileFarmerIds), Array.from(fileMobileNumbers));
    errors.push(...existingFarmerErrors);

    const summary = {
      totalRecords: rows.length - 1,
      successfullyValidated: validRows.length,
      failedRecords: errors.reduce((acc, error) => acc.add(error.row), new Set<number>()).size,
      duplicateFarmerIds: duplicateFarmerIds.size,
      duplicateMobileNumbers: duplicateMobileNumbers.size,
    };

    return { validRows, errors, summary };
  }

  /**
   * Preview uploaded payments - match farmers and calculate TDS
   */
  async previewPayments(validRows: any[], financialYearId: string) {
    const results = [];
    const notFoundFarmers: string[] = [];

    for (const row of validRows) {
      const farmer = await prisma.farmer.findUnique({
        where: { farmerId: row.farmerId },
      });

      if (!farmer) {
        notFoundFarmers.push(row.farmerId);
        results.push({ ...row, status: 'FARMER_NOT_FOUND' });
        continue;
      }

      const cumulativeResult = await prisma.payment.aggregate({
        where: {
          farmerId: farmer.id,
          financialYearId,
        },
        _sum: { grossAmount: true },
      });

      const cumulativeAmount = cumulativeResult._sum.grossAmount
        ? Number(cumulativeResult._sum.grossAmount)
        : 0;

      const newCumulative = cumulativeAmount + row.incentiveAmount;
      const tdsThreshold = await this.getTdsThreshold();
      const tdsPercentage = await this.getTdsPercentage();

      let tdsApplicable = false;
      let tdsAmount = 0;
      let needsDecision = false;

      if (newCumulative >= tdsThreshold) {
        const existingTdsRecord = await prisma.tdsRecord.findFirst({
          where: {
            farmerId: farmer.id,
            financialYearId,
          },
          orderBy: { createdAt: 'desc' },
        });

        if (existingTdsRecord?.decision === 'YES') {
          tdsApplicable = true;
          tdsAmount = Math.round(row.incentiveAmount * (tdsPercentage / 100) * 100) / 100;
        } else if (existingTdsRecord?.decision === 'NO') {
          tdsApplicable = false;
          tdsAmount = 0;
        } else {
          needsDecision = true;
        }
      }

      results.push({
        farmerId: row.farmerId,
        farmerName: farmer.name,
        village: farmer.village,
        district: farmer.district,
        bankName: farmer.bankName,
        ifscCode: farmer.ifscCode,
        accountNumber: farmer.accountNumber,
        accountHolderName: farmer.accountHolderName ?? farmer.name,
        grossAmount: row.incentiveAmount,
        cumulativeAmount,
        newCumulative,
        tdsApplicable,
        tdsPercentage: tdsApplicable ? tdsPercentage : 0,
        tdsAmount,
        netAmount: row.incentiveAmount - tdsAmount,
        needsDecision,
        invoiceNumber: row.invoiceNumber,
        notes: row.notes,
        farmerInternalId: farmer.id,
        status: 'VALID',
      });
    }

    return { results, notFoundFarmers };
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
    const worksheet = XLSX.utils.json_to_sheet(rows, { header: [
      'Transaction_Ref_No',
      'Remitter_Account_No',
      'Remitter_Name',
      'IFSC_Code',
      'Amount',
      'Bank_Account_Number',
      'Beneficiary_Name',
      'Beneficiary_LEI_Code',
    ] });
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Payments');
    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }

  async generateSampleOutputExcel() {
    const sampleRows = [];
    for (let i = 1; i <= 10; i += 1) {
      sampleRows.push({
        Transaction_Ref_No: `20240701${String(i).padStart(4, '0')}`,
        Remitter_Account_No: '123456789012',
        Remitter_Name: 'Eco Agripreneurs Pvt Ltd',
        IFSC_Code: 'SBIN0012345',
        Amount: (Math.round((5000 + Math.random() * 25000) * 100) / 100).toFixed(2),
        Bank_Account_Number: `ACC${String(100000 + i)}`,
        Beneficiary_Name: `Farmer ${i}`,
        Beneficiary_LEI_Code: '',
      });
    }

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(sampleRows, {
      header: [
        'Transaction_Ref_No',
        'Remitter_Account_No',
        'Remitter_Name',
        'IFSC_Code',
        'Amount',
        'Bank_Account_Number',
        'Beneficiary_Name',
        'Beneficiary_LEI_Code',
      ],
    });
    XLSX.utils.book_append_sheet(workbook, worksheet, 'PaymentOutput');
    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }

  generateSampleExcel(): Buffer {
    const sampleData = [];
    for (let i = 1; i <= 10; i += 1) {
      sampleData.push({
        Column: `Sample ${i}`,
        'Field Center': `Center ${i}`,
        'Implementation Partner': 'Akshaya Ginning',
        State: 'Telangana',
        Area: `Area ${i}`,
        'Belongs To': 'Group A',
        'Field Officer': `Officer ${i}`,
        'Farmer ID': `FARM${String(i).padStart(4, '0')}`,
        'Alternate Farmer ID': `ALT${String(i).padStart(4, '0')}`,
        'Farmer Name': `Farmer ${i}`,
        'Father/Husband Name': `Father ${i}`,
        'Last Name': `Surname ${i}`,
        'Financial Year': '2024-2025',
        Season: 'Kharif',
        District: 'Warangal',
        'Mandal / Taluk': `Mandal ${i}`,
        Village: `Village ${i}`,
        'Registered Mobile Number': `9876543${String(100 + i).padStart(3, '0')}`,
        'Area in Acres': (Math.random() * 5 + 1).toFixed(2),
        'Area in Hectares': (Math.random() * 2 + 0.5).toFixed(2),
        'Incentive Amount': (Math.round((5000 + i * 1000) * 100) / 100).toFixed(2),
        'Bank Linked Mobile Number': `9876500${String(100 + i).padStart(3, '0')}`,
        'Account Holder Name': `Farmer ${i}`,
        'Account Number': `ACC${String(1000000 + i)}`,
        'Account Type': 'Savings',
        'Bank Name': 'State Bank of India',
        'IFSC Code': 'SBIN0001234',
        'Branch Name': `Branch ${i}`,
        'Branch Address': `Branch Address ${i}`,
        Remarks: 'Sample upload row',
        'Upload Date': new Date().toISOString().slice(0, 10),
      });
    }

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(sampleData, {
      header: [
        'Column',
        'Field Center',
        'Implementation Partner',
        'State',
        'Area',
        'Belongs To',
        'Field Officer',
        'Farmer ID',
        'Alternate Farmer ID',
        'Farmer Name',
        'Father/Husband Name',
        'Last Name',
        'Financial Year',
        'Season',
        'District',
        'Mandal / Taluk',
        'Village',
        'Registered Mobile Number',
        'Area in Acres',
        'Area in Hectares',
        'Incentive Amount',
        'Bank Linked Mobile Number',
        'Account Holder Name',
        'Account Number',
        'Account Type',
        'Bank Name',
        'IFSC Code',
        'Branch Name',
        'Branch Address',
        'Remarks',
        'Upload Date',
      ],
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
    const page = params.page || 1;
    const limit = params.limit || 20;
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