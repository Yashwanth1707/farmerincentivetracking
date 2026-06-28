import { z } from 'zod';

export const createFinancialYearSchema = z.object({
  yearLabel: z.string().min(1, 'Year label is required').regex(/^\d{4}-\d{4}$/, 'Format must be YYYY-YYYY (e.g., 2024-2025)'),
  startDate: z.string().min(1, 'Start date is required'),
  endDate: z.string().min(1, 'End date is required'),
}).refine(data => new Date(data.endDate) > new Date(data.startDate), {
  message: 'End date must be after start date',
  path: ['endDate'],
});

export const updateFinancialYearSchema = z.object({
  yearLabel: z.string().regex(/^\d{4}-\d{4}$/).optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  isActive: z.boolean().optional(),
  isClosed: z.boolean().optional(),
});

export type CreateFinancialYearInput = z.infer<typeof createFinancialYearSchema>;