import prisma from '../utils/prisma';
import { NotFoundError, ConflictError } from '../utils/errors';

export class FinancialYearService {
  async list() {
    return prisma.financialYear.findMany({
      orderBy: { startDate: 'desc' },
      include: {
        createdByUser: { select: { id: true, fullName: true } },
        updatedByUser: { select: { id: true, fullName: true } },
      },
    });
  }

  async getById(id: string) {
    const fy = await prisma.financialYear.findUnique({
      where: { id },
      include: {
        createdByUser: { select: { id: true, fullName: true } },
        updatedByUser: { select: { id: true, fullName: true } },
        _count: { select: { paymentBatches: true } },
      },
    });
    if (!fy) throw new NotFoundError('Financial year');
    return fy;
  }

  async getActive() {
    const fy = await prisma.financialYear.findFirst({
      where: { isActive: true, isClosed: false },
    });
    if (!fy) throw new NotFoundError('Active financial year');
    return fy;
  }

  async create(data: {
    yearLabel: string;
    startDate: Date | string;
    endDate: Date | string;
    createdBy: string;
  }) {
    const existing = await prisma.financialYear.findUnique({
      where: { yearLabel: data.yearLabel },
    });
    if (existing) throw new ConflictError(`Financial year ${data.yearLabel} already exists`);

    return prisma.financialYear.create({
      data: {
        ...data,
        startDate: new Date(data.startDate),
        endDate: new Date(data.endDate),
        createdBy: data.createdBy,
        updatedBy: data.createdBy,
      },
    });
  }

  async update(id: string, data: Partial<{
    yearLabel: string;
    startDate: Date | string;
    endDate: Date | string;
    isActive: boolean;
    isClosed: boolean;
    updatedBy: string;
  }>) {
    const fy = await prisma.financialYear.findUnique({ where: { id } });
    if (!fy) throw new NotFoundError('Financial year');

    const updateData: any = { ...data };
    if (data.startDate) updateData.startDate = new Date(data.startDate);
    if (data.endDate) updateData.endDate = new Date(data.endDate);
    updateData.updatedBy = data.updatedBy || fy.updatedBy;

    return prisma.financialYear.update({ where: { id }, data: updateData });
  }

  async close(id: string, updatedBy: string) {
    const fy = await prisma.financialYear.findUnique({ where: { id } });
    if (!fy) throw new NotFoundError('Financial year');

    return prisma.financialYear.update({
      where: { id },
      data: { isClosed: true, isActive: false, updatedBy },
    });
  }
}

export const financialYearService = new FinancialYearService();