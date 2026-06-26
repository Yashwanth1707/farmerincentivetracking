import prisma from '../utils/prisma';
import * as XLSX from 'xlsx';
import PDFDocument from 'pdfkit';
import { NotFoundError } from '../utils/errors';

export class ReportService {
  /**
   * Generate farmer ledger report
   */
  async farmerLedger(farmerId: string, financialYearId?: string) {
    const farmer = await prisma.farmer.findUnique({ where: { id: farmerId } });
    if (!farmer) throw new NotFoundError('Farmer');

    const where: any = { farmerId };
    if (financialYearId) where.financialYearId = financialYearId;

    const payments = await prisma.payment.findMany({
      where,
      include: {
        financialYear: { select: { yearLabel: true } },
        batchDetails: {
          include: { batch: { select: { batchNumber: true, status: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const tdsRecords = await prisma.tdsRecord.findMany({
      where: { farmerId },
      include: { financialYear: { select: { yearLabel: true } } },
      orderBy: { createdAt: 'desc' },
    });

    return { farmer, payments, tdsRecords };
  }

  /**
   * Generate payment register (all payments across a period)
   */
  async paymentRegister(startDate?: string, endDate?: string, financialYearId?: string) {
    const where: any = {};

    if (startDate || endDate) {
      where.createdAt = {};
      if (startDate) where.createdAt.gte = new Date(startDate);
      if (endDate) where.createdAt.lte = new Date(endDate);
    }

    if (financialYearId) where.financialYearId = financialYearId;

    const payments = await prisma.payment.findMany({
      where,
      include: {
        farmer: { select: { farmerId: true, name: true, village: true, district: true } },
        financialYear: { select: { yearLabel: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return payments;
  }

  /**
   * Generate batch report
   */
  async batchReport(batchId: string) {
    const batch = await prisma.paymentBatch.findUnique({
      where: { id: batchId },
      include: {
        financialYear: { select: { yearLabel: true } },
        processedByUser: { select: { fullName: true } },
        approvedByUser: { select: { fullName: true } },
        batchDetails: {
          include: {
            farmer: true,
            payment: true,
          },
        },
      },
    });

    if (!batch) throw new NotFoundError('Batch');
    return batch;
  }

  /**
   * Generate FY summary report
   */
  async fyReport(financialYearId: string) {
    const fy = await prisma.financialYear.findUnique({ where: { id: financialYearId } });
    if (!fy) throw new NotFoundError('Financial year');

    const batches = await prisma.paymentBatch.findMany({
      where: { financialYearId },
      include: {
        processedByUser: { select: { fullName: true } },
        _count: { select: { batchDetails: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const totals = await prisma.payment.aggregate({
      where: { financialYearId },
      _sum: { grossAmount: true, tdsAmount: true, netAmount: true },
      _count: true,
    });

    const farmerCount = await prisma.payment.groupBy({
      by: ['farmerId'],
      where: { financialYearId },
    });

    return {
      financialYear: fy,
      batches,
      totals: {
        totalPayments: totals._count,
        totalGross: Number(totals._sum.grossAmount || 0),
        totalTds: Number(totals._sum.tdsAmount || 0),
        totalNet: Number(totals._sum.netAmount || 0),
        uniqueFarmers: farmerCount.length,
      },
    };
  }

  /**
   * Generate TDS report
   */
  async tdsReport(financialYearId: string) {
    const tdsRecords = await prisma.tdsRecord.findMany({
      where: { financialYearId },
      include: {
        farmer: { select: { farmerId: true, name: true, village: true, district: true } },
        financialYear: { select: { yearLabel: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const totals = await prisma.payment.aggregate({
      where: { financialYearId, tdsApplicable: true },
      _sum: { tdsAmount: true, grossAmount: true },
    });

    return {
      records: tdsRecords,
      totals: {
        totalTdsDeducted: Number(totals._sum.tdsAmount || 0),
        totalTdsApplicableGross: Number(totals._sum.grossAmount || 0),
      },
    };
  }

  /**
   * Export data as Excel
   */
  exportToExcel(data: any[], sheetName: string = 'Report'): Buffer {
    const workbook = XLSX.utils.book_new();
    const worksheet = XLSX.utils.json_to_sheet(data);
    XLSX.utils.book_append_sheet(workbook, worksheet, sheetName);
    return Buffer.from(XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' }));
  }

  /**
   * Export data as PDF (simple tabular format)
   */
  exportToPdf(title: string, headers: string[], rows: any[][]): Buffer {
    return new Promise((resolve, reject) => {
      try {
        const doc = new PDFDocument({ margin: 30, size: 'A4' });
        const buffers: Buffer[] = [];

        doc.on('data', (chunk: Buffer) => buffers.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(buffers)));

        // Title
        doc.fontSize(18).font('Helvetica-Bold').text(title, { align: 'center' });
        doc.moveDown();

        // Date
        doc.fontSize(10).font('Helvetica').text(`Generated: ${new Date().toLocaleString()}`, { align: 'right' });
        doc.moveDown();

        // Table
        const tableTop = doc.y;
        const colWidth = (doc.page.width - 60) / headers.length;
        const rowHeight = 20;

        // Headers
        doc.fontSize(10).font('Helvetica-Bold');
        headers.forEach((header, i) => {
          doc.text(header, 30 + i * colWidth, tableTop, {
            width: colWidth,
            align: 'left',
          });
        });

        // Draw header line
        doc.moveTo(30, tableTop + 15).lineTo(30 + headers.length * colWidth, tableTop + 15).stroke();

        // Rows
        doc.fontSize(8).font('Helvetica');
        let y = tableTop + 25;
        for (const row of rows) {
          row.forEach((cell, i) => {
            doc.text(String(cell), 30 + i * colWidth, y, {
              width: colWidth,
              align: 'left',
            });
          });
          y += rowHeight;

          if (y > doc.page.height - 50) {
            doc.addPage();
            y = 30;
          }
        }

        doc.end();
      } catch (error) {
        reject(error);
      }
    }) as unknown as Buffer;
  }
}

export const reportService = new ReportService();