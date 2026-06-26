import { Request, Response, NextFunction } from 'express';

// Augment Express Request
declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        username: string;
        email: string;
        role: string;
        fullName: string;
      };
    }
  }
}

export {};