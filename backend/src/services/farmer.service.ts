import prisma from '../utils/prisma';
import { NotFoundError, ValidationError, ConflictError } from '../utils/errors';
import { PaginatedResult, QueryParams } from '../types';

export class FarmerService {
  /**
   * List farmers with pagination, search, filter, and sort
   */
  async list(params: Partial<QueryParams>): Promise<PaginatedResult<any>> {
    const {
      page = 1,
      limit = 20,
      sortBy = 'createdAt',
      sortOrder = 'desc',
      search,
      ...filters
    } = params;

    const pageNumber = Number(page) || 1;
    const limitNumber = Number(limit) || 20;

    const skip = (pageNumber - 1) * limitNumber;
    const where: any = {};

    // Search across name, farmerId, village, phone
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { farmerId: { contains: search, mode: 'insensitive' } },
        { village: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search } },
        { aadharNumber: { contains: search } },
      ];
    }

    // Apply filters
    if (filters.village) where.village = { contains: String(filters.village), mode: 'insensitive' };
    if (filters.district) where.district = { contains: String(filters.district), mode: 'insensitive' };
    if (filters.isActive !== undefined) where.isActive = filters.isActive === 'true' || filters.isActive === true;

    const [data, total] = await Promise.all([
      prisma.farmer.findMany({
        where,
        skip,
        take: limitNumber,
        orderBy: { [sortBy]: sortOrder },
        include: {
          createdByUser: { select: { id: true, fullName: true } },
          updatedByUser: { select: { id: true, fullName: true } },
        },
      }),
      prisma.farmer.count({ where }),
    ]);

    return {
      data,
      pagination: {
        page: pageNumber,
        limit: limitNumber,
        total,
        totalPages: Math.ceil(total / limitNumber),
      }
    };
  }

  /**
   * Get farmer by ID
   */
  async getById(id: string) {
    const farmer = await prisma.farmer.findUnique({
      where: { id },
      include: {
        createdByUser: { select: { id: true, fullName: true } },
        updatedByUser: { select: { id: true, fullName: true } },
        payments: {
          include: {
            financialYear: { select: { yearLabel: true } },
          },
          orderBy: { createdAt: 'desc' },
          take: 50,
        },
        tdsRecords: {
          include: {
            financialYear: { select: { yearLabel: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!farmer) {
      throw new NotFoundError('Farmer');
    }

    return farmer;
  }

  /**
   * Create a new farmer
   */
  async create(data: {
    farmerId: string;
    aadharNumber?: string;
    name: string;
    fatherName?: string;
    village: string;
    district: string;
    state?: string;
    pincode?: string;
    phone?: string;
    bankName?: string;
    branchName?: string;
    accountNumber?: string;
    ifscCode?: string;
    createdBy: string;
  }) {
    // Check for duplicate farmerId
    const existing = await prisma.farmer.findUnique({
      where: { farmerId: data.farmerId },
    });

    if (existing) {
      throw new ConflictError(`Farmer with ID ${data.farmerId} already exists`);
    }

    // Check for duplicate aadhar
    if (data.aadharNumber) {
      const existingAadhar = await prisma.farmer.findUnique({
        where: { aadharNumber: data.aadharNumber },
      });
      if (existingAadhar) {
        throw new ConflictError('Aadhar number already registered with another farmer');
      }
    }

    return prisma.farmer.create({
      data: {
        ...data,
        createdBy: data.createdBy,
        updatedBy: data.createdBy,
      },
    });
  }

  /**
   * Update a farmer
   */
  async update(id: string, data: Partial<{
    aadharNumber: string;
    name: string;
    fatherName: string;
    village: string;
    district: string;
    state: string;
    pincode: string;
    phone: string;
    bankName: string;
    branchName: string;
    accountNumber: string;
    ifscCode: string;
    isActive: boolean;
    updatedBy: string;
  }>) {
    const farmer = await prisma.farmer.findUnique({ where: { id } });
    if (!farmer) {
      throw new NotFoundError('Farmer');
    }

    // Check aadhar uniqueness if changing
    if (data.aadharNumber && data.aadharNumber !== farmer.aadharNumber) {
      const existingAadhar = await prisma.farmer.findUnique({
        where: { aadharNumber: data.aadharNumber },
      });
      if (existingAadhar) {
        throw new ConflictError('Aadhar number already registered with another farmer');
      }
    }

    return prisma.farmer.update({
      where: { id },
      data: {
        ...data,
        updatedBy: data.updatedBy || farmer.updatedBy,
      },
    });
  }

  /**
   * Delete (deactivate) a farmer
   */
  async deactivate(id: string, updatedBy: string) {
    const farmer = await prisma.farmer.findUnique({ where: { id } });
    if (!farmer) {
      throw new NotFoundError('Farmer');
    }

    return prisma.farmer.update({
      where: { id },
      data: { isActive: false, updatedBy },
    });
  }

  async remove(id: string) {
    const farmer = await prisma.farmer.findUnique({ where: { id } });
    if (!farmer) {
      throw new NotFoundError('Farmer');
    }

    await prisma.batchDetail.deleteMany({ where: { farmerId: id } });
    await prisma.payment.deleteMany({ where: { farmerId: id } });
    await prisma.tdsRecord.deleteMany({ where: { farmerId: id } });

    return prisma.farmer.delete({ where: { id } });
  }

  /**
   * Get unique villages list
   */
  async getVillages() {
    const result = await prisma.farmer.findMany({
      where: { isActive: true },
      select: { village: true },
      distinct: ['village'],
      orderBy: { village: 'asc' },
    });
    return result.map(r => r.village);
  }

  /**
   * Get unique districts list
   */
  async getDistricts() {
    const result = await prisma.farmer.findMany({
      where: { isActive: true },
      select: { district: true },
      distinct: ['district'],
      orderBy: { district: 'asc' },
    });
    return result.map(r => r.district);
  }
}

export const farmerService = new FarmerService();