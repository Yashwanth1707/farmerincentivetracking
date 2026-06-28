import { z } from 'zod';

export const createBatchSchema = z.object({
  paymentIds: z.array(z.string().uuid()).min(1, 'At least one payment must be selected'),
  financialYearId: z.string().uuid('Valid financial year ID is required'),
  notes: z.string().max(500).optional().nullable(),
});

export const rejectBatchSchema = z.object({
  reason: z.string().min(1, 'Rejection reason is required').max(500),
});

export const batchQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(100).optional().default(20),
  status: z.enum(['DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'PAID']).optional(),
  financialYearId: z.string().uuid().optional(),
});

export const tdsDecisionSchema = z.object({
  financialYearId: z.string().uuid('Valid financial year ID is required'),
  decision: z.enum(['YES', 'NO'], { errorMap: () => ({ message: 'Decision must be YES or NO' }) }),
  notes: z.string().max(500).optional().nullable(),
});

export type CreateBatchInput = z.infer<typeof createBatchSchema>;
export type RejectBatchInput = z.infer<typeof rejectBatchSchema>;
export type TdsDecisionInput = z.infer<typeof tdsDecisionSchema>;