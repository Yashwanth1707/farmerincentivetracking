import { Router, Request, Response, NextFunction } from 'express';
import { paymentService } from '../services/payment.service';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createBatchSchema, rejectBatchSchema, batchQuerySchema } from '../validators/batch.validator';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/batches:
 *   get:
 *     tags: [Batches]
 *     summary: List payment batches
 *     description: Returns paginated list of payment batches with status filtering and financial year scoping.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [DRAFT, PENDING_APPROVAL, APPROVED, REJECTED, PAID] }
 *       - in: query
 *         name: financialYearId
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Paginated list of batches
 */
router.get('/', validate(batchQuerySchema, 'query'), async (req: Request, res: Response, next: NextFunction) => {
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
 *     description: Returns full batch details including all payments and farmer info in the batch.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Batch details with payments and farmers
 *       404:
 *         description: Batch not found
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const batch = await paymentService.getBatchById(req.params.id);
    res.json({ success: true, data: batch });
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
 *     description: Groups selected payments into a batch for processing. Generates a unique batch number.
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
 *               paymentIds:
 *                 type: array
 *                 items: { type: string, format: uuid }
 *                 description: Array of payment UUIDs to include in the batch
 *               financialYearId:
 *                 type: string
 *                 format: uuid
 *               notes:
 *                 type: string
 *                 maxLength: 500
 *     responses:
 *       201:
 *         description: Batch created in DRAFT status
 *       400:
 *         description: Invalid input or payments already in another batch
 */
router.post('/create', authorize('ADMIN', 'OPERATOR'), validate(createBatchSchema), async (req: Request, res: Response, next: NextFunction) => {
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
 *     description: Approves a batch. If TDS decisions are pending, sets status to PENDING_APPROVAL instead. Only admins can approve.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Batch approved or set to pending approval
 *       400:
 *         description: Cannot approve an already approved/paid batch
 *       404:
 *         description: Batch not found
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
 *     description: Rejects a batch with a required reason. Cannot reject already approved or paid batches.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [reason]
 *             properties:
 *               reason: { type: string, maxLength: 500 }
 *     responses:
 *       200:
 *         description: Batch rejected
 *       400:
 *         description: Cannot reject approved/paid batch
 *       404:
 *         description: Batch not found
 */
router.post('/reject/:id', authorize('ADMIN'), validate(rejectBatchSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const batch = await paymentService.rejectBatch(req.params.id, req.body.reason, req.user!.id);
    res.json({ success: true, message: 'Batch rejected', data: batch });
  } catch (error) {
    next(error);
  }
});

export default router;