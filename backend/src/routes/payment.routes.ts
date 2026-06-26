import { Router, Request, Response, NextFunction } from 'express';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { paymentService } from '../services/payment.service';
import { authenticate, authorize } from '../middleware/auth';
import { config } from '../config';

const router = Router();

// Multer setup for Excel uploads
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, config.uploadDir);
  },
  filename: (_req, file, cb) => {
    cb(null, `${uuidv4()}${path.extname(file.originalname)}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: config.maxFileSizeMb * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = ['.xlsx', '.xls', '.csv'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (!allowed.includes(ext)) {
      cb(new Error('Only Excel files (.xlsx, .xls) and CSV files are allowed'));
      return;
    }
    cb(null, true);
  },
});

router.use(authenticate);

/**
 * @swagger
 * /api/payments/sample-excel:
 *   get:
 *     tags: [Payments]
 *     summary: Download sample Excel template
 *     responses:
 *       200:
 *         description: Excel file
 *         content:
 *           application/vnd.openxmlformats-officedocument.spreadsheetml.sheet:
 *             schema:
 *               type: string
 *               format: binary
 */
router.get('/sample-excel', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const buffer = paymentService.generateSampleExcel();
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=sample_payments.xlsx');
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/payments/upload:
 *   post:
 *     tags: [Payments]
 *     summary: Upload Excel file for payment processing
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *               financialYearId:
 *                 type: string
 *     responses:
 *       200:
 *         description: File uploaded and parsed
 */
router.post('/upload', authorize('ADMIN', 'OPERATOR'), upload.single('file'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.file) {
      res.status(400).json({ success: false, message: 'No file uploaded' });
      return;
    }

    const { financialYearId } = req.body;
    if (!financialYearId) {
      res.status(400).json({ success: false, message: 'financialYearId is required' });
      return;
    }

    const parsed = await paymentService.parseExcel(req.file.path);
    const preview = await paymentService.previewPayments(parsed.validRows, financialYearId);

    res.json({
      success: true,
      data: {
        parsed: { ...parsed, filePath: undefined },
        preview,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/payments/preview:
 *   post:
 *     tags: [Payments]
 *     summary: Preview payment data before confirming
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               rows: { type: array }
 *               financialYearId: { type: string }
 *     responses:
 *       200:
 *         description: Preview results
 */
router.post('/preview', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (req.body.validRows) {
      const preview = await paymentService.previewPayments(req.body.validRows, req.body.financialYearId);
      res.json({ success: true, data: preview });
    } else {
      res.json({ success: true, data: req.body });
    }
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/payments/confirm:
 *   post:
 *     tags: [Payments]
 *     summary: Confirm and save uploaded payments
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: Payments confirmed
 */
router.post('/confirm', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { previewResults, financialYearId } = req.body;
    const saved = await paymentService.confirmPayments(previewResults, financialYearId, req.user!.id);
    res.json({
      success: true,
      message: `${saved.length} payments saved successfully`,
      data: { count: saved.length },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/payments/tds-decision/{farmerId}:
 *   post:
 *     tags: [Payments]
 *     summary: Make TDS decision for a farmer
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: farmerId
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               financialYearId: { type: string }
 *               decision: { type: string, enum: [YES, NO] }
 *               notes: { type: string }
 *     responses:
 *       200:
 *         description: TDS decision recorded
 */
router.post('/tds-decision/:farmerId', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await paymentService.handleTdsDecision(
      req.params.farmerId,
      req.body.financialYearId,
      req.body.decision,
      req.user!.id,
      req.body.notes,
    );
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

export default router;