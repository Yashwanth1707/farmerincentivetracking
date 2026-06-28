import { PrismaClient } from '@prisma/client';
import config from '../config';
import logger from './logger';

const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'query' },
    { emit: 'stdout', level: 'error' },
    { emit: 'stdout', level: 'warn' },
  ],
});

// Log queries in development via logger
if (config.isDev) {
  prisma.$on('query' as never, (e: any) => {
    logger.debug(`[Prisma] ${e.query} [${e.params}] - ${e.duration}ms`);
  });
}

export default prisma;