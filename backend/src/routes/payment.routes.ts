import { Router, Request, Response, NextFunction } from 'express';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { paymentService } from '../services/payment.service';
import { smsService } from '../services/sms.service';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { tdsDecisionSchema } from '../validators/batch.validator';
import { config } from '../config';

const router = Router();

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, config.uploadDir),
  filename: (_req, file, cb) => cb(null, `${uuidv4()}${path.extname(file.originalname)}`),
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
 *     summary: Download sample Excel template for payment upload
 *     description: Returns an Excel file with 10 sample farmers and payment data. Use this as a template for bulk uploads.
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: Excel file download
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

router.get('/sample-output', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const buffer = await paymentService.generateSampleOutputExcel();
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=sample_payment_output.xlsx');
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

router.get('/batch-options', authorize('ADMIN', 'OPERATOR'), async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await paymentService.getBatchOptions();
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
});

router.post('/preview-report', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const buffer = await paymentService.generatePreviewReport(req.body.previewResults || []);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=payment_preview.xlsx');
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

router.post('/bank-file-preview', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { previewResults, remitterAccountNo, remitterName, remitterIfsc, beneficiaryLei } = req.body;
    const buffer = paymentService.generateBankFilePreview(previewResults || [], remitterAccountNo, remitterName, remitterIfsc, beneficiaryLei);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=bank_file.xlsx');
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

router.post('/tds-report-preview', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const buffer = paymentService.generateTdsReport(req.body.previewResults || []);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=tds_report.xlsx');
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

router.post('/audit-report-preview', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const buffer = paymentService.generateAuditReport(req.body);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=payment_audit_report.xlsx');
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

router.post('/import-errors', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { errors } = req.body;
    if (!Array.isArray(errors)) {
      res.status(400).json({ success: false, message: 'errors array is required' });
      return;
    }

    const buffer = paymentService.generateImportErrorReport(errors);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=import_error_report.xlsx');
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
 *     description: Upload an Excel file with payment data. Parsed and validated — returns preview with TDS calculations.
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [file, financialYearId]
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *               financialYearId:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       200:
 *         description: File parsed — preview data with validation results
 *       400:
 *         description: Invalid file or missing financialYearId
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
    const duplicateRows = parsed.errors.filter((error) =>
      error.message.toLowerCase().includes('duplicate')
    );
    const invalidRows = parsed.errors.filter((error) =>
      !error.message.toLowerCase().includes('duplicate')
    );
    const summary = {
      ...parsed.summary,
      ...(preview.summary || {}),
      duplicateRows: duplicateRows.length,
      invalidRows: invalidRows.length,
    };
    res.json({
      success: true,
      data: {
        mappedFarmers: preview.mappedFarmers,
        missingFarmers: preview.missingFarmers,
        duplicateRows,
        invalidRows,
        summary,
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
 *     description: Returns calculated amounts (gross, TDS, net) for each payment row with TDS rules applied.
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: Preview results with TDS calculations
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
 *     description: Saves validated payment data from the preview step to the database. Skips duplicates and missing farmers.
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [previewResults, financialYearId]
 *             properties:
 *               previewResults: { type: array, description: Array of preview results from /preview }
 *               financialYearId: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Payments confirmed and saved
 */
router.post('/confirm', authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { previewResults, financialYearId, batchName, tdsPercentages, paymentDate, smsTemplateId, customSms } = req.body;
    const result = await paymentService.processPayments(
      previewResults,
      financialYearId,
      req.user!.id,
      batchName,
      tdsPercentages,
      paymentDate ? new Date(paymentDate) : undefined,
    );

    // Optionally send SMS notifications to farmers in the created batch
    let smsResults: any[] | null = null;
    if (smsTemplateId || customSms) {
      try {
        smsResults = await smsService.sendBatchSms(result.batch.id, smsTemplateId || null, req.user!.id, customSms);
      } catch (smsError) {
        // Log and continue — do not fail the payment processing if SMS fails
        console.error('SMS sending failed for batch', result.batch.id, smsError);
        smsResults = [{ error: 'SMS sending failed', details: String(smsError) }];
      }
    }

    res.json({
      success: true,
      message: `${result.totalFarmers} payments saved successfully`,
      data: { ...result, smsResults },
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
 *     description: Records admin decision on TDS applicability when cumulative incentives exceed ₹1,00,000 threshold.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: farmerId
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [financialYearId, decision]
 *             properties:
 *               financialYearId: { type: string, format: uuid }
 *               decision: { type: string, enum: [YES, NO] }
 *               notes: { type: string }
 *     responses:
 *       200:
 *         description: TDS decision recorded
 *       404:
 *         description: Farmer not found
 */
router.post('/tds-decision/:farmerId', authorize('ADMIN', 'OPERATOR'), validate(tdsDecisionSchema), async (req: Request, res: Response, next: NextFunction) => {
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
