class ApiConstants {
  static const String baseUrlKey = 'FIMS_API_BASE_URL';
  static const String defaultBaseUrl = String.fromEnvironment(
    'FIMS_API_BASE_URL',
    defaultValue: 'http://localhost:3001/',
  );
}

class AppConstants {
  static const String appName = 'Farmer Incentive Management System';
  static const String appShortName = 'FIMS';
  static const String version = '1.0.0';

  // Pagination
  static const int defaultPageSize = 20;
  static const List<int> pageSizeOptions = [10, 20, 50, 100];

  // Session
  static const int sessionTimeoutMinutes = 30;

  // Financial
  static const double tdsThreshold = 100000.0; // ₹1,00,000
  static const double defaultTdsPercentage = 1.0; // 1%

  // Validation
  static const int farmerIdMaxLength = 20;
  static const int mobileLength = 10;
  static const int aadhaarLength = 12;
  static const int panLength = 10;
  static const int ifscLength = 11;

  // SMS
  static const int smsMaxLength = 160;
  static const int smsMaxTemplateLength = 320;

  // File upload
  static const int maxFileSizeMB = 5;
  static const List<String> allowedExcelFormats = ['.xlsx', '.xls', '.csv'];

  // UI
  static const double desktopBreakpoint = 900;
  static const double tabletBreakpoint = 600;
  static const Duration animationDuration = Duration(milliseconds: 300);
}

class AppStrings {
  static const String loginTitle = 'Sign In';
  static const String loginSubtitle = 'Welcome back to FIMS';
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Password';
  static const String rememberMe = 'Remember me';
  static const String forgotPassword = 'Forgot password?';
  static const String noAccount = "Don't have an account?";
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';
  static const String logout = 'Logout';
  static const String dashboard = 'Dashboard';
  static const String farmers = 'Farmers';
  static const String users = 'Users';
  static const String payments = 'Payments';
  static const String batches = 'Batches';
  static const String reports = 'Reports';
  static const String settings = 'Settings';
  static const String auditLogs = 'Audit Logs';
  static const String financialYears = 'Financial Years';
  static const String sms = 'SMS';
  static const String tds = 'TDS';
  static const String totalFarmers = 'Total Farmers';
  static const String totalIncentive = 'Total Incentive Paid';
  static const String pendingPayments = 'Pending Payments';
  static const String errorFetching = 'Error fetching data';
  static const String retry = 'Retry';
  static const String loading = 'Loading...';
  static const String noData = 'No data available';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String clear = 'Clear';
  static const String apply = 'Apply';
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String create = 'Create';
  static const String export = 'Export';
  static const String import = 'Import';
  static const String download = 'Download';
  static const String upload = 'Upload';
  static const String success = 'Success';
  static const String warning = 'Warning';
  static const String error = 'Error';
  static const String info = 'Information';
  static const String confirm = 'Confirm';
  static const String approve = 'Approve';
  static const String reject = 'Reject';
  static const String submit = 'Submit';
  static const String reset = 'Reset';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String finish = 'Finish';
  static const String required = 'Required';
  static const String invalidEmail = 'Please enter a valid email';
  static const String invalidMobile =
      'Please enter a valid 10-digit mobile number';
  static const String invalidAadhaar =
      'Please enter a valid 12-digit Aadhaar number';
  static const String invalidPan =
      'Please enter a valid PAN (e.g., ABCDE1234F)';
  static const String passwordMinLength =
      'Password must be at least 6 characters';
  static const String passwordsNotMatch = 'Passwords do not match';
}

class SvgAssets {
  static const String logo = 'assets/icons/logo.svg';
  static const String farmer = 'assets/icons/farmer.svg';
  static const String payment = 'assets/icons/payment.svg';
  static const String report = 'assets/icons/report.svg';
  static const String empty = 'assets/icons/empty.svg';
  static const String error404 = 'assets/icons/error404.svg';
  static const String successCheck = 'assets/icons/success.svg';
  static const String uploadIcon = 'assets/icons/upload.svg';
  static const String downloadIcon = 'assets/icons/download.svg';
}

class SharedPrefKeys {
  static const String userData = 'user_data';
  static const String rememberMe = 'remember_me';
  static const String savedEmail = 'saved_email';
  static const String themeMode = 'theme_mode';
  static const String selectedFinancialYear = 'selected_financial_year';
}

class RoleConstants {
  static const String admin = 'admin';
  static const String operator = 'operator';
  static const String viewer = 'viewer';
}
