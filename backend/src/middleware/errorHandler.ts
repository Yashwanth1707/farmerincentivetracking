import { Request, Response, NextFunction } from 'express';
import { AppError, ValidationError } from '../utils/errors';
import logger from '../utils/logger';

/**
 * Global error handler middleware
 */
export const errorHandler = (err: Error, req: Request, res: Response, _next: NextFunction): void => {
  logger.error({
    err,
    method: req.method,
    url: req.url,
    ip: req.ip,
  }, 'Error occurred');

  // Handle known application errors
  if (err instanceof AppError) {
    const response: Record<string, any> = {
      success: false,
      message: err.message,
    };

    if (err instanceof ValidationError) {
      response.errors = err.errors;
    }

    res.status(err.statusCode).json(response);
    return;
  }

  // Handle Prisma errors
  if (err.name === 'PrismaClientKnownRequestError') {
    const prismaErr = err as any;
    if (prismaErr.code === 'P2002') {
      res.status(409).json({
        success: false,
        message: 'A record with this value already exists',
        error: 'CONFLICT',
      });
      return;
    }
    if (prismaErr.code === 'P2025') {
      res.status(404).json({
        success: false,
        message: 'Record not found',
        error: 'NOT_FOUND',
      });
      return;
    }
  }

  // Handle JSON parse errors
  if (err.name === 'SyntaxError' && (err as any).status === 400) {
    res.status(400).json({
      success: false,
      message: 'Invalid JSON in request body',
      error: 'INVALID_JSON',
    });
    return;
  }

  // Default 500
  res.status(500).json({
    success: false,
    message: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
    error: 'INTERNAL_ERROR',
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
};