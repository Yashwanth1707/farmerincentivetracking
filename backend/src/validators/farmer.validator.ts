import { z } from 'zod';

export const createFarmerSchema = z.object({
  farmerId: z.string().min(1, 'Farmer ID is required').max(50),
  aadharNumber: z.string().length(12, 'Aadhar must be 12 digits').regex(/^\d{12}$/, 'Invalid Aadhar format').optional().nullable(),
  name: z.string().min(1, 'Name is required').max(200),
  fatherName: z.string().max(200).optional().nullable(),
  village: z.string().min(1, 'Village is required').max(100),
  district: z.string().min(1, 'District is required').max(100),
  state: z.string().max(100).optional().default('Telangana'),
  pincode: z.string().max(10).optional().nullable(),
  phone: z.string().max(15).optional().nullable(),
  bankName: z.string().max(200).optional().nullable(),
  branchName: z.string().max(200).optional().nullable(),
  accountNumber: z.string().max(50).optional().nullable(),
  ifscCode: z.string().max(20).optional().nullable(),
});

export const updateFarmerSchema = z.object({
  aadharNumber: z.string().length(12).regex(/^\d{12}$/).optional().nullable(),
  name: z.string().min(1).max(200).optional(),
  fatherName: z.string().max(200).optional().nullable(),
  village: z.string().min(1).max(100).optional(),
  district: z.string().min(1).max(100).optional(),
  state: z.string().max(100).optional(),
  pincode: z.string().max(10).optional().nullable(),
  phone: z.string().max(15).optional().nullable(),
  bankName: z.string().max(200).optional().nullable(),
  branchName: z.string().max(200).optional().nullable(),
  accountNumber: z.string().max(50).optional().nullable(),
  ifscCode: z.string().max(20).optional().nullable(),
  isActive: z.boolean().optional(),
});

export const farmerQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(100).optional().default(20),
  search: z.string().optional(),
  village: z.string().optional(),
  district: z.string().optional(),
  isActive: z.string().optional(),
  sortBy: z.enum(['createdAt', 'updatedAt', 'name', 'farmerId', 'village']).optional().default('createdAt'),
  sortOrder: z.enum(['asc', 'desc']).optional().default('desc'),
});

export type CreateFarmerInput = z.infer<typeof createFarmerSchema>;
export type UpdateFarmerInput = z.infer<typeof updateFarmerSchema>;
export type FarmerQueryInput = z.infer<typeof farmerQuerySchema>;