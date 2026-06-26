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
    const rawData = XLSX.utils.sheet_to_json(sheet, { defval: '' });

    if (rawData.length === 0) {
      throw new ValidationError({ file: ['Excel file is empty'] });
    }

    const requiredFields = ['farmerId', 'name', 'village', 'district', 'grossAmount'];
    const errors: { row: number; field: string; message: string }[] = [];
    const validRows: any[] = [];

    for (let i = 0; i < rawData.length; i++) {
      const row: any = rawData[i];
      const rowNum = i + 2; // +2 for header + 1-indexed

      for (const field of requiredFields) {
        if (!row[field] && row[field] !== 0) {
          errors.push({ row: rowNum, field, message: `${field} is required` });
        }
      }

      if (isNaN(Number(row.grossAmount)) || Number(row.grossAmount) <= 0) {
        errors.push({ row: rowNum, field: 'grossAmount', message: 'Gross amount must be a positive number' });
      }

      if (!errors.length) {
        validRows.push({
          farmerId: String(row.farmerId).trim(),
          name: String(row.name).trim(),
          village: String(row.village).trim(),
          district: String(row.district).trim(),
          grossAmount: Number(row.grossAmount),
          invoiceNumber: row.invoiceNumber ? String(row.invoiceNumber).trim() : undefined,
          notes: row.notes ? String(row.notes).trim() : undefined,
        });
      }
    }

    return { validRows, errors, totalRows: rawData.length };
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

      // Calculate cumulative incentives for TDS check
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

      const newCumulative = cumulativeAmount + row.grossAmount;
      const tdsThreshold = await this.getTdsThreshold();
      const tdsPercentage = await this.getTdsPercentage();

      let tdsApplicable = false;
      let tdsAmount = 0;
      let needsDecision = false;

      if (newCumulative >= tdsThreshold) {
        // Check if TDS decision was already made this FY
        const existingTdsRecord = await prisma.tdsRecord.findFirst({
          where: {
            farmerId: farmer.id,
            financialYearId,
          },
          orderBy: { createdAt: 'desc' },
        });

        if (existingTdsRecord?.decision === 'YES') {
          tdsApplicable = true;
          tdsAmount = Math.round(row.grossAmount * (tdsPercentage / 100) * 100) / 100;
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
        grossAmount: row.grossAmount,
        cumulativeAmount: cumulativeAmount,
        newCumulative,
        tdsApplicable,
        tdsPercentage: tdsApplicable ? tdsPercentage : 0,
        tdsAmount,
        netAmount: row.grossAmount - tdsAmount,
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

  /**
   * Generate sample Excel template
   */
  generateSampleExcel(): Buffer {
    const sampleData = [];
    for (let i = 1; i <= 10; i++) {
      sampleData.push({
        farmerId: `FARM${String(i).padStart(4, '0')}`,
        name: `Farmer ${i}`,
        village: `Village ${i}`,
        district: 'Warangal',
        grossAmount: Math.round(Math.random() * 50000 * 100) / 100,
        invoiceNumber: i % 3 === 0 ? `INV-2024-${String(i).padStart(4, '0')}` : '',
        notes: '',
      });
    }

    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(sampleData);
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Payments');

    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }
}

export const paymentService = new PaymentService();