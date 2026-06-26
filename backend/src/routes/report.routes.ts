import { Router, Request, Response, NextFunction } from 'express';
import { reportService } from '../services/report.service';
import { authenticate } from '../middleware/auth';

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /api/reports/farmer-ledger/{farmerId}:
 *   get:
 *     tags: [Reports]
 *     summary: Get farmer ledger report
 *     parameters:
 *       - in: path
 *         name: farmerId
 *         required: true
 *         schema: { type: string }
 *       - in: query
 *         name: financialYearId
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Farmer ledger
 */
router.get('/farmer-ledger/:farmerId', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await reportService.farmerLedger(req.params.farmerId, req.query.financialYearId as string);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/reports/payment-register:
 *   get:
 *     tags: [Reports]
 *     summary: Get payment register
 *     parameters:
 *       - in: query
 *         name: startDate
 *         schema: { type: string }
 *       - in: query
 *         name: endDate
 *         schema: { type: string }
 *       - in: query
 *         name: financialYearId
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Payment register
 */
router.get('/payment-register', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await reportService.paymentRegister(
      req.query.startDate as string,
      req.query.endDate as string,
      req.query.financialYearId as string,
    );
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/reports/batch/{batchId}:
 *   get:
 *     tags: [Reports]
 *     summary: Get batch report
 *     parameters:
 *       - in: path
 *         name: batchId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Batch report
 */
router.get('/batch/:batchId', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await reportService.batchReport(req.params.batchId);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/reports/fy/{financialYearId}:
 *   get:
 *     tags: [Reports]
 *     summary: Get financial year report
 *     parameters:
 *       - in: path
 *         name: financialYearId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: FY report
 */
router.get('/fy/:financialYearId', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await reportService.fyReport(req.params.financialYearId);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/reports/tds/{financialYearId}:
 *   get:
 *     tags: [Reports]
 *     summary: Get TDS report for a financial year
 *     parameters:
 *       - in: path
 *         name: financialYearId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: TDS report
 */
router.get('/tds/:financialYearId', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await reportService.tdsReport(req.params.financialYearId);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/reports/export/excel:
 *   post:
 *     tags: [Reports]
 *     summary: Export data as Excel
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               data: { type: array }
 *               sheetName: { type: string }
 *     responses:
 *       200:
 *         description: Excel file
 */
router.post('/export/excel', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { data, sheetName } = req.body;
    const buffer = reportService.exportToExcel(data, sheetName);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=report.xlsx`);
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/reports/export/pdf:
 *   post:
 *     tags: [Reports]
 *     summary: Export data as PDF
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title: { type: string }
 *               headers: { type: array, items: { type: string } }
 *               rows: { type: array }
 *     responses:
 *       200:
 *         description: PDF file
 */
router.post('/export/pdf', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { title, headers, rows } = req.body;
    const buffer = await reportService.exportToPdf(title, headers, rows);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=report.pdf`);
    res.send(buffer);
  } catch (error) {
    next(error);
  }
});

export default router;