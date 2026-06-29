import { Router, Request, Response, NextFunction } from 'express';
import { userService } from '../services/user.service';
import { authenticate, authorize } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { createUserSchema, updateUserSchema, userQuerySchema } from '../validators/user.validator';

const router = Router();

router.use(authenticate, authorize('ADMIN'));

/**
 * @swagger
 * /api/users:
 *   get:
 *     tags: [Users]
 *     summary: List all users (admin only)
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
 *         description: Search by username, email, or full name
 *     responses:
 *       200:
 *         description: List of users (without password hashes)
 *       403:
 *         description: Not authorized
 */
router.get('/', validate(userQuerySchema, 'query'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await userService.list(req.query as any);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/users/{id}:
 *   get:
 *     tags: [Users]
 *     summary: Get user by ID
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: User details
 *       404:
 *         description: User not found
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await userService.getById(req.params.id);
    res.json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/users:
 *   post:
 *     tags: [Users]
 *     summary: Create a new user
 *     security:
 *       - cookieAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [username, email, password, fullName, role]
 *             properties:
 *               username: { type: string, minLength: 3, pattern: '^[a-zA-Z0-9_]+$' }
 *               email: { type: string, format: email }
 *               password: { type: string, format: password, minLength: 8 }
 *               fullName: { type: string }
 *               phone: { type: string }
 *               role: { type: string, enum: [ADMIN, OPERATOR, VIEWER] }
 *     responses:
 *       201:
 *         description: User created
 *       409:
 *         description: Username or email already exists
 */
router.post('/', validate(createUserSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await userService.create(req.body);
    res.status(201).json({ success: true, message: 'User created successfully', data: user });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/users/{id}:
 *   put:
 *     tags: [Users]
 *     summary: Update a user
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
 *             properties:
 *               email: { type: string }
 *               fullName: { type: string }
 *               phone: { type: string }
 *               role: { type: string, enum: [ADMIN, OPERATOR, VIEWER] }
 *               isActive: { type: boolean }
 *               password: { type: string, minLength: 8 }
 *     responses:
 *       200:
 *         description: User updated
 *       404:
 *         description: User not found
 */
router.put('/:id', validate(updateUserSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await userService.update(req.params.id, req.body);
    res.json({ success: true, message: 'User updated successfully', data: user });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/users/{id}:
 *   delete:
 *     tags: [Users]
 *     summary: Delete a user
 *     description: Cannot delete the last admin user.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: User deleted
 *       400:
 *         description: Cannot delete the last admin
 *       404:
 *         description: User not found
 */
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    await userService.delete(req.params.id);
    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    next(error);
  }
});

export default router;