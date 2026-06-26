import { Router, Request, Response, NextFunction } from 'express';
import { smsService } from '../services/sms.service';
import { authenticate, authorize } from '../middleware/auth';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/sms/templates:
 *   get:
 *     tags: [SMS]
 *     summary: Get all SMS templates
 *     responses:
 *       200:
 *         description: List of templates
 */
router.get('/templates', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const templates = await smsService.getTemplates();
    res.json({ success: true, data: templates });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/sms/templates:
 *   post:
 *     tags: [SMS]
 *     summary: Create SMS template
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, body]
 *             properties:
 *               name: { type: string }
 *               body: { type: string }
 *     responses:
 *       201:
 *         description: Template created
 */
router.post('/templates', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const template = await smsService.createTemplate(req.body);
    res.status(201).json({ success: true, data: template });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/sms/templates/{id}:
 *   put:
 *     tags: [SMS]
 *     summary: Update SMS template
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Template updated
 */
router.put('/templates/:id', authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const template = await smsService.updateTemplate(req.params.id, req.body);
    res.json({ success: true, data: template });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/sms/preview:
 *   post:
 *     tags: [SMS]
 *     summary: Preview SMS message
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               farmerId: { type: string }
 *               templateId: { type: string }
 *               customMessage: { type: string }
 *     responses:
 *       200:
 *         description: Preview
 */
router.post('/preview', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { farmerId, templateId, customMessage } = req.body;
    const preview = await smsService.previewSms(farmerId, templateId, customMessage);
    res.json({ success: true, data: preview });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/sms/send:
 *   post:
 *     tags: [SMS]
 *     summary: Send SMS to a farmer
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               farmerId: { type: string }
 *               templateId: { type: string }
 *               customMessage: { type: string }
 *     responses:
 *       200:
 *         description: SMS sent
 */
router.post('/send', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { farmerId, templateId, customMessage } = req.body;
    const result = await smsService.sendSingleSms(farmerId, templateId, req.user!.id, customMessage);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/sms/send-batch/{batchId}:
 *   post:
 *     tags: [SMS]
 *     summary: Send SMS to all farmers in a batch
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: batchId
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               templateId: { type: string }
 *     responses:
 *       200:
 *         description: Batch SMS sent
 */
router.post('/send-batch/:batchId', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const results = await smsService.sendBatchSms(req.params.batchId, req.body.templateId, req.user!.id);
    res.json({ success: true, data: results });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/sms/logs:
 *   get:
 *     tags: [SMS]
 *     summary: Get SMS logs
 *     responses:
 *       200:
 *         description: List of SMS logs
 */
router.get('/logs', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await smsService.listLogs(req.query as any);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

export default router;