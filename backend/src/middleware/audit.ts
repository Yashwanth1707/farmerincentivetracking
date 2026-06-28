import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';
import prisma from '../utils/prisma';

/**
 * Middleware to log all audit actions to the database
 */
export const auditLog = (action: string, entity?: string) => {
  return async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
    try {
      // Store original end to capture response
      const originalEnd = _res.end.bind(_res);
      let responseBody: any;

      _res.end = ((chunk?: any, encoding?: any, cb?: any) => {
        responseBody = chunk;
        return originalEnd(chunk, encoding, cb);
      }) as any;

      _res.on('finish', async () => {
        try {
          if (req.user?.id) {
            // Extract entityId from params or body
            const entityId = req.params?.id || (req.body as any)?.id || null;

            await prisma.auditLog.create({
              data: {
                userId: req.user.id,
                action,
                entity: entity || req.baseUrl?.replace('/api/', '') || null,
                entityId,
                ipAddress: req.ip || req.socket.remoteAddress || null,
                userAgent: req.headers['user-agent'] || null,
              },
            });
          }
        } catch (error) {
          logger.error({ error }, 'Failed to create audit log');
        }
      });

      next();
    } catch (error) {
      next(error);
    }
  };
};
