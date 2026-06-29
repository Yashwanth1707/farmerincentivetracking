import { z } from 'zod';

export const updateSettingsSchema = z.object({
  settings: z.record(z.string(), z.any(), {
    errorMap: () => ({ message: 'Settings must be a key-value object' }),
  }),
  category: z.string().max(50).optional().default('general'),
});

export type UpdateSettingsInput = z.infer<typeof updateSettingsSchema>;