import { Router, Request, Response, NextFunction } from 'express';
import { settingsService } from '../services/settings.service';
import { authenticate, authorize } from '../middleware/auth';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/settings:
 *   get:
 *     tags: [Settings]
 *     summary: Get all settings
 *     responses:
 *       200:
 *         description: All settings grouped by category
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
 *     parameters:
 *       - in: path
 *         name: key
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Setting value
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
 *     summary: Update settings (admin only)
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               settings:
 *                 type: object
 *                 description: Key-value pairs of settings
 *               category:
 *                 type: string
 *     responses:
 *       200:
 *         description: Settings updated
 */
router.put('/', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
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