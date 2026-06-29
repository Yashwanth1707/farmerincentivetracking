import { z } from 'zod';

export const createUserSchema = z.object({
  username: z.string().min(3, 'Username must be at least 3 characters').max(50)
    .regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores'),
  email: z.string().email('Valid email is required'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  fullName: z.string().min(1, 'Full name is required').max(200),
  phone: z.string().max(15).optional().nullable(),
  role: z.enum(['ADMIN', 'OPERATOR', 'VIEWER'], { errorMap: () => ({ message: 'Role must be ADMIN, OPERATOR, or VIEWER' }) }),
});

export const updateUserSchema = z.object({
  email: z.string().email().optional(),
  fullName: z.string().min(1).max(200).optional(),
  phone: z.string().max(15).optional().nullable(),
  role: z.enum(['ADMIN', 'OPERATOR', 'VIEWER']).optional(),
  isActive: z.boolean().optional(),
  password: z.string().min(8).optional(),
});

export const userQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(100).optional().default(20),
  search: z.string().optional(),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;
export type UpdateUserInput = z.infer<typeof updateUserSchema>;