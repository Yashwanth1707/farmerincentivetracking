import { Router, Request, Response, NextFunction } from 'express';
import { paymentService } from '../services/payment.service';
import { authenticate, authorize } from '../middleware/auth';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/batches:
 *   get:
 *     tags: [Batches]
 *     summary: List payment batches
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
 *         name: status
 *         schema: { type: string }
 *       - in: query
 *         name: financialYearId
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: List of batches
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await paymentService.listBatches(req.query as any);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/batches/{id}:
 *   get:
 *     tags: [Batches]
 *     summary: Get batch details by ID
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Batch details
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const batch = await paymentService.getBatchById(req.params.id);
    res.json({ success: true, data: batch });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/payment-file', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const buffer = await paymentService.generateBatchPaymentFile(req.params.id);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=batch_${req.params.id}_payment_file.xlsx`);
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/batches/create:
 *   post:
 *     tags: [Batches]
 *     summary: Create a new payment batch
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [paymentIds, financialYearId]
 *             properties:
 *               paymentIds: { type: array, items: { type: string } }
 *               financialYearId: { type: string }
 *               notes: { type: string }
 *     responses:
 *       201:
 *         description: Batch created
 */
router.post('/create', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { paymentIds, financialYearId, notes } = req.body;
    const batch = await paymentService.createBatch(paymentIds, financialYearId, req.user!.id, notes);
    res.status(201).json({ success: true, message: 'Batch created successfully', data: batch });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/batches/approve/{id}:
 *   post:
 *     tags: [Batches]
 *     summary: Approve a payment batch
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Batch approved
 */
router.post('/approve/:id', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const batch = await paymentService.approveBatch(req.params.id, req.user!.id);
    res.json({ success: true, message: 'Batch approved', data: batch });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/batches/reject/{id}:
 *   post:
 *     tags: [Batches]
 *     summary: Reject a payment batch
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               reason: { type: string }
 *     responses:
 *       200:
 *         description: Batch rejected
 */
router.post('/reject/:id', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const batch = await paymentService.rejectBatch(req.params.id, req.body.reason || 'No reason provided', req.user!.id);
    res.json({ success: true, message: 'Batch rejected', data: batch });
  } catch (error) {
    next(error);
  }
});

export default router;