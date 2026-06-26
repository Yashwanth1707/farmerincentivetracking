import { Router, Request, Response, NextFunction } from 'express';
import { financialYearService } from '../services/financial-year.service';
import { authenticate, authorize } from '../middleware/auth';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/financial-years:
 *   get:
 *     tags: [Financial Years]
 *     summary: List all financial years
 *     responses:
 *       200:
 *         description: List of financial years
 */
router.get('/', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const years = await financialYearService.list();
    res.json({ success: true, data: years });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/financial-years/active:
 *   get:
 *     tags: [Financial Years]
 *     summary: Get the currently active financial year
 *     responses:
 *       200:
 *         description: Active financial year
 */
router.get('/active', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const fy = await financialYearService.getActive();
    res.json({ success: true, data: fy });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/financial-years/{id}:
 *   get:
 *     tags: [Financial Years]
 *     summary: Get financial year by ID
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Financial year details
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const fy = await financialYearService.getById(req.params.id);
    res.json({ success: true, data: fy });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/financial-years:
 *   post:
 *     tags: [Financial Years]
 *     summary: Create a new financial year
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [yearLabel, startDate, endDate]
 *             properties:
 *               yearLabel: { type: string }
 *               startDate: { type: string, format: date }
 *               endDate: { type: string, format: date }
 *     responses:
 *       201:
 *         description: Financial year created
 */
router.post('/', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const fy = await financialYearService.create({
      ...req.body,
      createdBy: req.user!.id,
    });
    res.status(201).json({ success: true, message: 'Financial year created', data: fy });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/financial-years/{id}:
 *   put:
 *     tags: [Financial Years]
 *     summary: Update a financial year
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Financial year updated
 */
router.put('/:id', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const fy = await financialYearService.update(req.params.id, {
      ...req.body,
      updatedBy: req.user!.id,
    });
    res.json({ success: true, message: 'Financial year updated', data: fy });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/financial-years/{id}/close:
 *   post:
 *     tags: [Financial Years]
 *     summary: Close a financial year
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Financial year closed
 */
router.post('/:id/close', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    await financialYearService.close(req.params.id, req.user!.id);
    res.json({ success: true, message: 'Financial year closed' });
  } catch (error) {
    next(error);
  }
});

export default router;