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
  static const String dashboardMonthlyPayments = '$_base/dashboard/monthly-payments';
  static const String dashboardRecentActivity = '$_base/dashboard/recent-activity';
  static const String dashboardFinancialYearSummary = '$_base/dashboard/fy-summary';

  // Farmers
  static const String farmers = '$_base/farmers';
  static String farmerById(String id) => '$_base/farmers/$id';
  static String farmerPaymentHistory(String id) => '$_base/farmers/$id/payments';
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
  static const String currentFinancialYear = '$_base/financial-years/current';

  // Payments
  static const String payments = '$_base/payments';
  static String paymentById(String id) => '$_base/payments/$id';
  static const String paymentsUpload = '$_base/payments/upload';
  static const String paymentsValidate = '$_base/payments/validate';
  static const String paymentsPreview = '$_base/payments/preview';
  static const String paymentsGenerateBatch = '$_base/payments/generate-batch';
  static const String paymentsExport = '$_base/payments/export';

  // Batches
  static const String batches = '$_base/batches';
  static String batchById(String id) => '$_base/batches/$id';
  static String batchApprove(String id) => '$_base/batches/$id/approve';
  static String batchReject(String id) => '$_base/batches/$id/reject';
  static String batchExportExcel(String id) => '$_base/batches/$id/export/excel';
  static String batchExportPdf(String id) => '$_base/batches/$id/export/pdf';

  // TDS
  static const String tds = '$_base/tds';
  static String tdsByFarmer(String farmerId) => '$_base/tds/farmer/$farmerId';
  static const String tdsSettings = '$_base/tds/settings';

  // SMS
  static const String smsSend = '$_base/sms/send';
  static const String smsBatch = '$_base/sms/batch';
  static const String smsPreview = '$_base/sms/preview';
  static const String smsLogs = '$_base/sms/logs';
  static const String smsTemplates = '$_base/sms/templates';
  static String smsTemplateById(String id) => '$_base/sms/templates/$id';

  // Reports
  static const String reportFarmerLedger = '$_base/reports/farmer-ledger';
  static const String reportPaymentRegister = '$_base/reports/payment-register';
  static const String reportBatchReport = '$_base/reports/batch-report';
  static const String reportFyReport = '$_base/reports/fy-report';
  static const String reportTdsReport = '$_base/reports/tds-report';
  static const String reportSmsReport = '$_base/reports/sms-report';
  static const String reportPendingPayments = '$_base/reports/pending-payments';
  static const String reportVillageWise = '$_base/reports/village-wise';
  static const String reportDistrictWise = '$_base/reports/district-wise';
  static const String reportExport = '$_base/reports/export';

  // Audit Logs
  static const String auditLogs = '$_base/audit-logs';
  static String auditLogById(String id) => '$_base/audit-logs/$id';

  // Settings
  static const String settings = '$_base/settings';
  static String settingsByKey(String key) => '$_base/settings/$key';

  // TDS Config
  static const String tdsConfig = '$_base/tds-config';
}
