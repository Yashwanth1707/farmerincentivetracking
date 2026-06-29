import { Router, Request, Response, NextFunction } from 'express';
import { farmerService } from '../services/farmer.service';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createFarmerSchema, updateFarmerSchema, farmerQuerySchema } from '../validators/farmer.validator';

const router = Router();

/**
 * @swagger
 * /api/farmers:
 *   get:
 *     tags: [Farmers]
 *     summary: List farmers with pagination, search, and filters
 *     description: Returns paginated list of farmers. Supports full-text search, village/district filtering, and sorting.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20, maximum: 100 }
 *         description: Items per page
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *         description: Search across name, farmerId, village, phone
 *       - in: query
 *         name: village
 *         schema: { type: string }
 *       - in: query
 *         name: district
 *         schema: { type: string }
 *       - in: query
 *         name: isActive
 *         schema: { type: string, enum: [true, false] }
 *       - in: query
 *         name: sortBy
 *         schema: { type: string, enum: [createdAt, updatedAt, name, farmerId, village], default: createdAt }
 *       - in: query
 *         name: sortOrder
 *         schema: { type: string, enum: [asc, desc], default: desc }
 *     responses:
 *       200:
 *         description: Paginated list of farmers
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean }
 *                 data: { type: array, items: { $ref: '#/components/schemas/Farmer' } }
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page: { type: integer }
 *                     limit: { type: integer }
 *                     total: { type: integer }
 *                     totalPages: { type: integer }
 */
router.get('/', authenticate, validate(farmerQuerySchema, 'query'), async (req: Request, res: Response, next: NextFunction) => {
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
 *     summary: Get list of unique villages
 *     description: Returns alphabetically sorted list of all villages with active farmers.
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: List of villages
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean }
 *                 data: { type: array, items: { type: string } }
 */
router.get('/villages', authenticate, async (_req: Request, res: Response, next: NextFunction) => {
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
 *     summary: Get list of unique districts
 *     description: Returns alphabetically sorted list of all districts with active farmers.
 *     security:
 *       - cookieAuth: []
 *     responses:
 *       200:
 *         description: List of districts
 */
router.get('/districts', authenticate, async (_req: Request, res: Response, next: NextFunction) => {
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
 *     summary: Get farmer by ID with payments and TDS history
 *     description: Returns complete farmer profile including payment history and TDS records.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *         description: Farmer UUID
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
 *     description: Registers a new farmer in the system. farmerId and aadharNumber must be unique.
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
 *               farmerId: { type: string, example: FARM0001, description: Unique farmer identifier }
 *               aadharNumber: { type: string, pattern: '^\d{12}$', description: 12-digit Aadhar number }
 *               name: { type: string, example: Rajesh Kumar }
 *               fatherName: { type: string }
 *               village: { type: string, example: Gopalpally }
 *               district: { type: string, example: Warangal }
 *               state: { type: string, default: Telangana }
 *               pincode: { type: string }
 *               phone: { type: string }
 *               bankName: { type: string }
 *               branchName: { type: string }
 *               accountNumber: { type: string }
 *               ifscCode: { type: string }
 *     responses:
 *       201:
 *         description: Farmer created
 *       409:
 *         description: Duplicate farmerId or aadharNumber
 */
router.post('/', authenticate, authorize('ADMIN', 'OPERATOR'), validate(createFarmerSchema), async (req: Request, res: Response, next: NextFunction) => {
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
 *     description: Updates farmer details. Only provided fields will be updated. aadharNumber uniqueness is enforced.
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
 *     responses:
 *       200:
 *         description: Farmer updated
 *       404:
 *         description: Farmer not found
 */
router.put('/:id', authenticate, authorize('ADMIN', 'OPERATOR'), validate(updateFarmerSchema), async (req: Request, res: Response, next: NextFunction) => {
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
 *     summary: Deactivate a farmer (soft delete)
 *     description: Marks a farmer as inactive instead of deleting. Only admins can deactivate.
 *     security:
 *       - cookieAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Farmer deactivated
 *       404:
 *         description: Farmer not found
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