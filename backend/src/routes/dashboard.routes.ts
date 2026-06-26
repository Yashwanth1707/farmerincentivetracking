import { Router, Request, Response, NextFunction } from 'express';
import { dashboardService } from '../services/dashboard.service';
import { authenticate } from '../middleware/auth';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/dashboard/stats:
 *   get:
 *     tags: [Dashboard]
 *     summary: Get dashboard statistics
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: query
 *         name: financialYearId
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Dashboard stats
 */
router.get('/stats', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const stats = await dashboardService.getStats(req.query.financialYearId as string);
    res.json({ success: true, data: stats });
  } catch (error) {
    next(error);
  }
});

export default router;