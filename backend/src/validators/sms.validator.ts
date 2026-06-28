import { z } from 'zod';

export const createSmsTemplateSchema = z.object({
  name: z.string().min(1, 'Template name is required').max(100),
  body: z.string().min(1, 'Template body is required').max(1000),
});

export const updateSmsTemplateSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  body: z.string().min(1).max(1000).optional(),
  isActive: z.boolean().optional(),
});

export const sendSmsSchema = z.object({
  farmerId: z.string().uuid('Valid farmer ID is required'),
  templateId: z.string().uuid().optional(),
  customMessage: z.string().max(1000).optional(),
}).refine(data => data.templateId || data.customMessage, {
  message: 'Either templateId or customMessage is required',
  path: ['templateId'],
});

export const sendBatchSmsSchema = z.object({
  batchId: z.string().uuid('Valid batch ID is required'),
  templateId: z.string().uuid('Valid template ID is required'),
});

export const smsPreviewSchema = z.object({
  farmerId: z.string().uuid('Valid farmer ID is required'),
  templateId: z.string().uuid().optional(),
  customMessage: z.string().max(1000).optional(),
});

export const smsLogQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(100).optional().default(20),
  status: z.enum(['QUEUED', 'SENT', 'DELIVERED', 'FAILED']).optional(),
});