import express from 'express';
import session from 'express-session';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import fs from 'fs';
import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';

import { config } from './config';
import { errorHandler } from './middleware/errorHandler';
import logger from './utils/logger';

// Import routes
import authRoutes from './routes/auth.routes';
import farmerRoutes from './routes/farmer.routes';
import userRoutes from './routes/user.routes';
import financialYearRoutes from './routes/financial-year.routes';
import paymentRoutes from './routes/payment.routes';
import batchRoutes from './routes/batch.routes';
import smsRoutes from './routes/sms.routes';
import reportRoutes from './routes/report.routes';
import auditRoutes from './routes/audit.routes';
import settingsRoutes from './routes/settings.routes';
import dashboardRoutes from './routes/dashboard.routes';

// Ensure upload directory exists
if (!fs.existsSync(config.uploadDir)) {
  fs.mkdirSync(config.uploadDir, { recursive: true });
}

const app = express();

// ── Swagger Configuration ──────────────────────────────────────────────────────
const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'Farmer Incentive Management System API',
    version: '1.0.0',
    description: 'Complete REST API for managing farmer incentive payments, TDS tracking, SMS notifications, and reporting.',
    contact: {
      name: 'FIMS Team',
    },
  },
  servers: [
    {
      url: `http://localhost:${config.port}`,
      description: 'Development server',
    },
  ],
  components: {
    securitySchemes: {
      cookieAuth: {
        type: 'apiKey',
        in: 'cookie',
        name: 'connect.sid',
      },
    },
  },
  security: [{ cookieAuth: [] }],
};

const swaggerSpec = swaggerJsdoc({
  definition: swaggerDefinition,
  apis: ['./src/routes/*.ts'],
});

app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customSiteTitle: 'FIMS API Documentation',
}));

// ── Security & Middleware ──────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(cors({
  origin: config.isDev ? true : config.corsOrigin,
  credentials: true,
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Morgan HTTP logging (via pino)
app.use(morgan('combined', {
  stream: { write: (msg: string) => logger.info(msg.trim()) },
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMaxRequests,
  message: {
    success: false,
    message: 'Too many requests, please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api', limiter);

// ── Session Configuration ──────────────────────────────────────────────────────
declare module 'express-session' {
  interface SessionData {
    userId?: string;
    username?: string;
    role?: string;
    rememberMe?: boolean;
  }
}

app.use(session({
  secret: config.sessionSecret,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: config.isProd || config.isVercel,
    sameSite: 'lax',
    maxAge: config.sessionExpiryHours * 60 * 60 * 1000, // 24 hours default
  },
}));

// ── API Routes ─────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/farmers', farmerRoutes);
app.use('/api/users', userRoutes);
app.use('/api/financial-years', financialYearRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/batches', batchRoutes);
app.use('/api/sms', smsRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/audit-logs', auditRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/dashboard', dashboardRoutes);

// ── Health Check ──────────────────────────────────────────────────────────────
app.get('/api/health', (_req, res) => {
  res.json({
    success: true,
    message: 'FIMS API is running',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// ── 404 Handler ───────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
});

// ── Global Error Handler ──────────────────────────────────────────────────────
app.use(errorHandler);

// ── Start Server ──────────────────────────────────────────────────────────────
if (process.env.NODE_ENV !== 'test') {
  const port = config.port;
  const startServer = () => {
    app.listen(port, () => {
      logger.info(`FIMS Backend server running on port ${port}`);
      logger.info(`API Documentation: http://localhost:${port}/api/docs`);
      logger.info(`Environment: ${config.nodeEnv}`);
    });
  };

  if (process.env.VERCEL) {
    logger.info('Running in Vercel-compatible mode');
  } else {
    startServer();
  }
}

export default app;