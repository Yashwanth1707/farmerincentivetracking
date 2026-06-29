import { Router, Request, Response, NextFunction } from 'express';
import { settingsService } from '../services/settings.service';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { updateSettingsSchema } from '../validators/settings.validator';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/settings:
 *   get:
 *     tags: [Settings]
 *     summary: Get all settings grouped by category
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: Settings grouped by category (general, tds, sms, payment)
 */
router.get('/', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const settings = await settingsService.getAll();
    res.json({ success: true, data: settings });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/settings/{key}:
 *   get:
 *     tags: [Settings]
 *     summary: Get a specific setting by key
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: key
 *         required: true
 *         schema: { type: string }
 *         description: Setting key (e.g., tds_percentage, tds_threshold)
 *     responses:
 *       200:
 *         description: Setting value with category
 *       404:
 *         description: Setting not found
 */
router.get('/:key', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const setting = await settingsService.getByKey(req.params.key);
    res.json({ success: true, data: setting });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/settings:
 *   put:
 *     tags: [Settings]
 *     summary: Update multiple settings at once
 *     description: Update settings by key-value pairs. All values are stored as JSON strings. Admin only.
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [settings]
 *             properties:
 *               settings:
 *                 type: object
 *                 description: Key-value pairs of settings
 *                 example: { tds_percentage: 10, tds_threshold: 100000 }
 *               category:
 *                 type: string
 *                 default: general
 *                 enum: [general, tds, sms, email, payment]
 *     responses:
 *       200:
 *         description: Settings updated
 */
router.put('/', authorize('ADMIN'), validate(updateSettingsSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { settings, category } = req.body;
    const updated = await settingsService.updateMany(settings, category);
    res.json({
      success: true,
      message: `${updated.length} settings updated`,
      data: updated,
    });
  } catch (error) {
    next(error);
  }
});

export default router;