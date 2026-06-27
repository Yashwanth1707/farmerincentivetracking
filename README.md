# Farmer Incentive Management System

## Run locally

1. Install dependencies:
   - Backend: npm install in the backend folder
   - Frontend: flutter pub get in the frontend folder
2. Start the full app:
   - npm run dev
3. The app will launch:
   - Backend API at http://localhost:3001
   - Frontend at http://localhost:3000

## Vercel deployment notes

- The backend API is prepared for Vercel serverless hosting through the entrypoint in [backend/api/index.js](backend/api/index.js).
- For production, configure the environment variables listed below in your Vercel project settings.
- The frontend is a Flutter web app and should be built separately for static hosting, or deployed with a Flutter-compatible host.

## Required environment variables

### Backend
Create a file named .env in the backend folder using the values from [backend/.env.example](backend/.env.example).

- PORT: API port, usually 3001
- NODE_ENV: development or production
- DATABASE_URL: PostgreSQL connection string
- SESSION_SECRET: strong random secret
- SESSION_EXPIRY_HOURS: session lifetime in hours
- REMEMBER_ME_EXPIRY_DAYS: remember-me cookie lifetime in days
- APP_URL: public URL of the frontend or backend
- CORS_ORIGIN: allowed frontend origin, for example https://your-domain.com
- SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, EMAIL_FROM: email config for password resets
- TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER: SMS config
- RATE_LIMIT_WINDOW_MS, RATE_LIMIT_MAX_REQUESTS: API throttle settings
- DEFAULT_TDS_PERCENTAGE, TDS_THRESHOLD_AMOUNT: default tax rules
- MAX_FILE_SIZE_MB, UPLOAD_DIR: upload settings

### Frontend
The Flutter app reads its API base URL from a compile-time define named FIMS_API_BASE_URL.

- For local development, the default is http://localhost:3001/api
- For production, build with:
  - flutter build web --release --dart-define=FIMS_API_BASE_URL=https://your-backend-url/api

