import { Router, Request, Response, NextFunction } from 'express';
import { farmerService } from '../services/farmer.service';
import { authenticate, authorize } from '../middleware/auth';
import { auditLog } from '../middleware/audit';

const router = Router();

/**
 * @swagger
 * /api/farmers:
 *   get:
 *     tags: [Farmers]
 *     summary: List farmers with pagination, search, and filters
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
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: village
 *         schema: { type: string }
 *       - in: query
 *         name: district
 *         schema: { type: string }
 *       - in: query
 *         name: sortBy
 *         schema: { type: string, default: 'createdAt' }
 *       - in: query
 *         name: sortOrder
 *         schema: { type: string, enum: [asc, desc], default: 'desc' }
 *     responses:
 *       200:
 *         description: List of farmers
 */
router.get('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await farmerService.list(req.query as any);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/farmers/villages:
 *   get:
 *     tags: [Farmers]
 *     summary: Get list of villages
 *     responses:
 *       200:
 *         description: List of villages
 */
router.get('/villages', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const villages = await farmerService.getVillages();
    res.json({ success: true, data: villages });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/farmers/districts:
 *   get:
 *     tags: [Farmers]
 *     summary: Get list of districts
 *     responses:
 *       200:
 *         description: List of districts
 */
router.get('/districts', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const districts = await farmerService.getDistricts();
    res.json({ success: true, data: districts });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/farmers/{id}:
 *   get:
 *     tags: [Farmers]
 *     summary: Get farmer by ID
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Farmer details
 *       404:
 *         description: Farmer not found
 */
router.get('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const farmer = await farmerService.getById(req.params.id);
    res.json({ success: true, data: farmer });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/farmers:
 *   post:
 *     tags: [Farmers]
 *     summary: Create a new farmer
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [farmerId, name, village, district]
 *             properties:
 *               farmerId: { type: string }
 *               aadharNumber: { type: string }
 *               name: { type: string }
 *               fatherName: { type: string }
 *               village: { type: string }
 *               district: { type: string }
 *               state: { type: string }
 *               pincode: { type: string }
 *               phone: { type: string }
 *               bankName: { type: string }
 *               branchName: { type: string }
 *               accountNumber: { type: string }
 *               ifscCode: { type: string }
 *     responses:
 *       201:
 *         description: Farmer created
 */
router.post('/', authenticate, authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const farmer = await farmerService.create({
      ...req.body,
      createdBy: req.user!.id,
    });
    res.status(201).json({ success: true, message: 'Farmer created successfully', data: farmer });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/farmers/{id}:
 *   put:
 *     tags: [Farmers]
 *     summary: Update a farmer
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
 *     responses:
 *       200:
 *         description: Farmer updated
 */
router.put('/:id', authenticate, authorize('ADMIN', 'OPERATOR'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const farmer = await farmerService.update(req.params.id, {
      ...req.body,
      updatedBy: req.user!.id,
    });
    res.json({ success: true, message: 'Farmer updated successfully', data: farmer });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/farmers/{id}:
 *   delete:
 *     tags: [Farmers]
 *     summary: Deactivate a farmer
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: Farmer deactivated
 */
router.delete('/:id', authenticate, authorize('ADMIN'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    await farmerService.deactivate(req.params.id, req.user!.id);
    res.json({ success: true, message: 'Farmer deactivated successfully' });
  } catch (error) {
    next(error);
  }
});

export default router;