import pino from 'pino';
import config from '../config';

// Use pretty-printing only in development to avoid noisy logs in production
let logger: pino.Logger;
if (config.isDev) {
  const transport = pino.transport({
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
    },
  });

  logger = pino(
    {
      level: config.logLevel,
      name: 'fims-backend',
    },
    transport,
  );
} else {
  logger = pino({
    level: config.logLevel,
    name: 'fims-backend',
  });
}

export default logger;