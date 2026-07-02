import { Router, Request, Response, NextFunction } from 'express';
import { auditService } from '../services/audit.service';
import { authenticate, authorize } from '../middleware/auth';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/audit-logs:
 *   get:
 *     tags: [Audit Logs]
 *     summary: Get audit logs with pagination and filtering
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer }
 *       - in: query
 *         name: limit
 *         schema: { type: integer }
 *       - in: query
 *         name: userId
 *         schema: { type: string }
 *       - in: query
 *         name: action
 *         schema: { type: string }
 *       - in: query
 *         name: entity
 *         schema: { type: string }
 *       - in: query
 *         name: startDate
 *         schema: { type: string }
 *       - in: query
 *         name: endDate
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: List of audit logs
 */
router.get('/', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await auditService.list({
      page: Number(req.query.page) || 1,
      limit: Number(req.query.limit) || 50,
      userId: req.query.userId as string,
      action: req.query.action as string,
      entity: req.query.entity as string,
      startDate: req.query.startDate as string,
      endDate: req.query.endDate as string,
    });
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

export default router;