/// API endpoint constants for FIMS backend
class ApiEndpoints {
  static const String _base = '/api';

  // Auth
  static const String login = '$_base/auth/login';
  static const String logout = '$_base/auth/logout';
  static const String forgotPassword = '$_base/auth/forgot-password';
  static const String resetPassword = '$_base/auth/reset-password';
  static const String changePassword = '$_base/auth/change-password';
  static const String me = '$_base/auth/me';

  // Dashboard
  static const String dashboardStats = '$_base/dashboard/stats';
  static const String dashboardMonthlyPayments =
      '$_base/dashboard/monthly-payments';
  static const String dashboardRecentActivity =
      '$_base/dashboard/recent-activity';
  static const String dashboardFinancialYearSummary =
      '$_base/dashboard/fy-summary';

  // Farmers
  static const String farmers = '$_base/farmers';
  static String farmerById(String id) => '$_base/farmers/$id';
  static String farmerPaymentHistory(String id) =>
      '$_base/farmers/$id/payments';
  static const String farmerBulkUpload = '$_base/farmers/bulk-upload';
  static const String farmerDownloadSample = '$_base/farmers/download-sample';
  static const String farmerExport = '$_base/farmers/export';

  // Users
  static const String users = '$_base/users';
  static String userById(String id) => '$_base/users/$id';
  static String userDisable(String id) => '$_base/users/$id/disable';

  // Financial Years
  static const String financialYears = '$_base/financial-years';
  static String financialYearById(String id) => '$_base/financial-years/$id';
  static const String currentFinancialYear = '$_base/financial-years/active';
  static String closeFinancialYear(String id) =>
      '$_base/financial-years/$id/close';

  // Payments
  static const String payments = '$_base/payments';
  static String paymentById(String id) => '$_base/payments/$id';
  static const String paymentsUpload = '$_base/payments/upload';
  static const String paymentsSampleExcel = '$_base/payments/sample-excel';
  static const String paymentsSampleOutput = '$_base/payments/sample-output';
  static const String paymentsConfirm = '$_base/payments/confirm';
  static const String paymentsImportErrors = '$_base/payments/import-errors';
  static const String paymentsValidate = '$_base/payments/validate';
  static const String paymentsPreview = '$_base/payments/preview';
  static const String paymentsGenerateBatch = '$_base/payments/generate-batch';
  static const String paymentsExport = '$_base/payments/export';

  // Batches
  static const String batches = '$_base/batches';
  static String batchById(String id) => '$_base/batches/$id';
  static const String batchCreate = '$_base/batches/create';
  static String batchApprove(String id) => '$_base/batches/approve/$id';
  static String batchReject(String id) => '$_base/batches/reject/$id';
  static String batchPaymentFile(String id) =>
      '$_base/batches/$id/payment-file';

  // TDS
  static const String tds = '$_base/tds';
  static String tdsByFarmer(String farmerId) => '$_base/tds/farmer/$farmerId';
  static const String tdsSettings = '$_base/tds/settings';

  // SMS
  static const String smsSend = '$_base/sms/send';
  static String smsBatch(String batchId) => '$_base/sms/send-batch/$batchId';
  static const String smsPreview = '$_base/sms/preview';
  static const String smsLogs = '$_base/sms/logs';
  static const String smsTemplates = '$_base/sms/templates';
  static String smsTemplateById(String id) => '$_base/sms/templates/$id';

  // Reports
  static String reportFarmerLedger(String farmerId) =>
      '$_base/reports/farmer-ledger/$farmerId';
  static const String reportPaymentRegister = '$_base/reports/payment-register';
  static String reportBatchReport(String batchId) =>
      '$_base/reports/batch/$batchId';
  static String reportFyReport(String financialYearId) =>
      '$_base/reports/fy/$financialYearId';
  static String reportTdsReport(String financialYearId) =>
      '$_base/reports/tds/$financialYearId';
  static const String reportExportExcel = '$_base/reports/export/excel';
  static const String reportExportPdf = '$_base/reports/export/pdf';

  // Audit Logs
  static const String auditLogs = '$_base/audit-logs';
  static String auditLogById(String id) => '$_base/audit-logs/$id';

  // Settings
  static const String settings = '$_base/settings';
  static String settingsByKey(String key) => '$_base/settings/$key';

  // TDS Config
  static const String tdsConfig = '$_base/tds-config';
}
