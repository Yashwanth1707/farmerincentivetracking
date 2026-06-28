import dotenv from 'dotenv';
import path from 'path';

// Load .env from project root
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const vercelUrl = process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : undefined;

export const config = {
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  isDev: (process.env.NODE_ENV || 'development') === 'development',
  isProd: process.env.NODE_ENV === 'production',

  // Database
  databaseUrl: process.env.DATABASE_URL || '',

  // Session
  sessionSecret: process.env.SESSION_SECRET || 'dev-secret-change-in-production',
  sessionExpiryHours: parseInt(process.env.SESSION_EXPIRY_HOURS || '24', 10),
  rememberMeExpiryDays: parseInt(process.env.REMEMBER_ME_EXPIRY_DAYS || '30', 10),

  // Twilio
  twilio: {
    accountSid: process.env.TWILIO_ACCOUNT_SID || '',
    authToken: process.env.TWILIO_AUTH_TOKEN || '',
    phoneNumber: process.env.TWILIO_PHONE_NUMBER || '',
  },

  // Email
  smtp: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
  },
  emailFrom: process.env.EMAIL_FROM || 'noreply@farmerincentive.com',

  // App
  appUrl: process.env.APP_URL || vercelUrl || 'http://localhost:3000',
  corsOrigin: process.env.CORS_ORIGIN || process.env.APP_URL || vercelUrl || 'http://localhost:3000',
  isVercel: process.env.VERCEL === '1' || process.env.VERCEL === 'true',

  // Rate Limiting
  rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
  rateLimitMaxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10),

  // TDS
  defaultTdsPercentage: parseFloat(process.env.DEFAULT_TDS_PERCENTAGE || '10'),
  tdsThresholdAmount: parseFloat(process.env.TDS_THRESHOLD_AMOUNT || '100000'),

  // Upload
  maxFileSizeMb: parseInt(process.env.MAX_FILE_SIZE_MB || '10', 10),
  uploadDir: process.env.UPLOAD_DIR || './uploads',

  // Logging
  logLevel: process.env.LOG_LEVEL || 'debug',
} as const;

export default config;
