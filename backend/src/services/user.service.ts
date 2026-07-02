import bcrypt from 'bcryptjs';
import prisma from '../utils/prisma';
import { NotFoundError, ConflictError, ValidationError } from '../utils/errors';
import { PaginatedResult } from '../types';

export class UserService {
  /**
   * List all users with pagination
   */
  async list(
    params: {
      page?: number;
      limit?: number;
      search?: string;
    } = {}
  ): Promise<PaginatedResult<any>> {
    const page = params.page || 1;
    const limit = params.limit || 20;
    const skip = (page - 1) * limit;
    const where: any = {};

    if (params.search) {
      where.OR = [
        { username: { contains: params.search, mode: 'insensitive' } },
        { email: { contains: params.search, mode: 'insensitive' } },
        { fullName: { contains: params.search, mode: 'insensitive' } },
      ];
    }

    const [data, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          username: true,
          email: true,
          fullName: true,
          phone: true,
          role: true,
          isActive: true,
          lastLoginAt: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
      prisma.user.count({ where }),
    ]);

    return {
      data,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /**
   * Get user by ID
   */
  async getById(id: string) {
    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true,
        phone: true,
        role: true,
        isActive: true,
        lastLoginAt: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!user) throw new NotFoundError('User');
    return user;
  }

  /**
   * Create a new user
   */
  async create(data: {
    username: string;
    email: string;
    password: string;
    fullName: string;
    phone?: string;
    role: 'ADMIN' | 'OPERATOR' | 'VIEWER';
  }) {
    // Check for existing username
    const existingUsername = await prisma.user.findUnique({ where: { username: data.username } });
    if (existingUsername) throw new ConflictError('Username already exists');

    // Check for existing email
    const existingEmail = await prisma.user.findUnique({ where: { email: data.email } });
    if (existingEmail) throw new ConflictError('Email already exists');

    if (data.role === 'ADMIN') {
      const adminCount = await prisma.user.count({ where: { role: 'ADMIN' } });
      if (adminCount > 0) {
        throw new ValidationError({ role: ['Only one admin user is allowed'] });
      }
    }

    const passwordHash = await bcrypt.hash(data.password, 12);

    return prisma.user.create({
      data: {
        ...data,
        passwordHash,
      },
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true,
        phone: true,
        role: true,
        isActive: true,
        createdAt: true,
      },
    });
  }

  /**
   * Update a user
   */
  async update(id: string, data: Partial<{
    email: string;
    fullName: string;
    phone: string;
    role: 'ADMIN' | 'OPERATOR' | 'VIEWER';
    isActive: boolean;
    password: string;
  }>) {
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundError('User');

    if (data.role === 'ADMIN' && user.role !== 'ADMIN') {
      const adminCount = await prisma.user.count({ where: { role: 'ADMIN' } });
      if (adminCount > 0) {
        throw new ValidationError({ role: ['Only one admin user is allowed'] });
      }
    }

    // Check email uniqueness if changing
    if (data.email && data.email !== user.email) {
      const existing = await prisma.user.findUnique({ where: { email: data.email } });
      if (existing) throw new ConflictError('Email already in use');
    }

    const updateData: any = { ...data };
    if (data.password) {
      updateData.passwordHash = await bcrypt.hash(data.password, 12);
      updateData.passwordChangedAt = new Date();
    }
    delete updateData.password;

    return prisma.user.update({
      where: { id },
      data: updateData,
      select: {
        id: true,
        username: true,
        email: true,
        fullName: true,
        phone: true,
        role: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  /**
   * Delete a user
   */
  async delete(id: string) {
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundError('User');

    // Cannot delete the last admin
    if (user.role === 'ADMIN') {
      const adminCount = await prisma.user.count({ where: { role: 'ADMIN' } });
      if (adminCount <= 1) {
        throw new ValidationError({ role: ['Cannot delete the last admin user'] });
      }
    }

    return prisma.user.update({ where: { id }, data: { isActive: false } });
  }

  async remove(id: string) {
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundError('User');

    if (user.role === 'ADMIN') {
      const adminCount = await prisma.user.count({ where: { role: 'ADMIN' } });
      if (adminCount <= 1) {
        throw new ValidationError({ role: ['Cannot remove the last admin user'] });
      }
    }

    await prisma.auditLog.deleteMany({ where: { userId: id } });
    await prisma.session.deleteMany({ where: { sess: { path: ['userId'], equals: id } } as any });
    await prisma.passwordReset.deleteMany({ where: { userId: id } });
    await prisma.smsLog.deleteMany({ where: { sentById: id } });
    await prisma.sentSmsRecord.deleteMany({ where: { sentById: id } });

    return prisma.user.delete({ where: { id } });
  }
}

export const userService = new UserService();
