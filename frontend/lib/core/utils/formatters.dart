import 'package:intl/intl.dart';

/// Utility class for formatting various data types
class Formatters {
  static final _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
    locale: 'en_IN',
  );

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _timeFormat = DateFormat('HH:mm');
  static final _monthYearFormat = DateFormat('MMM yyyy');
  static final _apiDateFormat = DateFormat('yyyy-MM-dd');
  static final _apiDateTimeFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  /// Format amount as Indian currency (e.g., ₹1,23,456.78)
  static String currency(dynamic amount) {
    if (amount == null) return '₹0.00';
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0;
    return _currencyFormat.format(value);
  }

  /// Format amount in compact form (e.g., ₹1.2L, ₹5Cr)
  static String compactCurrency(dynamic amount) {
    if (amount == null) return '₹0';
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0;
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }
    return '₹${value.toStringAsFixed(0)}';
  }

  /// Format date (e.g., 31/12/2024)
  static String date(dynamic date) {
    if (date == null) return '';
    final DateTime dateTime = _parseDate(date);
    return _dateFormat.format(dateTime);
  }

  /// Format date and time (e.g., 31/12/2024 14:30)
  static String dateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return '';
    final DateTime dateTime = _parseDate(dateTimeValue);
    return _dateTimeFormat.format(dateTime);
  }

  /// Format time only (e.g., 14:30)
  static String time(dynamic dateTimeValue) {
    if (dateTimeValue == null) return '';
    final DateTime dateTime = _parseDate(dateTimeValue);
    return _timeFormat.format(dateTime);
  }

  /// Format month and year (e.g., Jan 2024)
  static String monthYear(dynamic date) {
    if (date == null) return '';
    final DateTime dateTime = _parseDate(date);
    return _monthYearFormat.format(dateTime);
  }

  /// Format date for API (yyyy-MM-dd)
  static String apiDate(dynamic date) {
    if (date == null) return '';
    final DateTime dateTime = _parseDate(date);
    return _apiDateFormat.format(dateTime);
  }

  /// Format date time for API
  static String apiDateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return '';
    final DateTime dateTime = _parseDate(dateTimeValue);
    return _apiDateTimeFormat.format(dateTime);
  }

  /// Format mobile number (e.g., 98765 43210)
  static String mobile(String? mobile) {
    if (mobile == null || mobile.length != 10) return mobile ?? '';
    return '${mobile.substring(0, 5)} ${mobile.substring(5)}';
  }

  /// Mask Aadhaar number (e.g., XXXX XXXX 1234)
  static String maskedAadhaar(String? aadhaar) {
    if (aadhaar == null || aadhaar.length != 12) return aadhaar ?? '';
    return 'XXXX XXXX ${aadhaar.substring(8)}';
  }

  /// Mask PAN (e.g., ABCDE1234F → ABCDEXXXXF)
  static String maskedPan(String? pan) {
    if (pan == null || pan.length != 10) return pan ?? '';
    return '${pan.substring(0, 5)}XXXX${pan.substring(9)}';
  }

  /// Format bank account with mask
  static String maskedAccount(String? account) {
    if (account == null || account.length < 4) return account ?? '';
    return 'XXXX${account.substring(account.length - 4)}';
  }

  /// Format percentage (e.g., 1.5%)
  static String percentage(dynamic value) {
    if (value == null) return '0%';
    final numValue =
        value is num ? value : double.tryParse(value.toString()) ?? 0;
    return '${numValue.toStringAsFixed(1)}%';
  }

  /// Format number with commas
  static String number(dynamic value) {
    if (value == null) return '0';
    final formatter = NumberFormat('#,##0', 'en_IN');
    final numValue = value is num ? value : int.tryParse(value.toString()) ?? 0;
    return formatter.format(numValue);
  }

  /// Get relative time (e.g., "2 hours ago", "3 days ago")
  static String relativeTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return '';
    final DateTime dateTime = _parseDate(dateTimeValue);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  /// Format file size in human-readable format
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Parse date from various formats
  static DateTime _parseDate(dynamic date) {
    if (date is DateTime) return date;
    if (date is String) {
      // Try ISO format first
      try {
        return DateTime.parse(date);
      } catch (_) {
        // Try other common formats
        try {
          return DateFormat('dd/MM/yyyy').parse(date);
        } catch (_) {
          return DateTime.now();
        }
      }
    }
    return DateTime.now();
  }

  /// Get financial year string from a date
  static String getFinancialYear(DateTime? date) {
    final now = date ?? DateTime.now();
    final year = now.year;
    final month = now.month;
    if (month >= 4) {
      return '$year-${(year + 1).toString().substring(2)}';
    } else {
      return '${year - 1}-${year.toString().substring(2)}';
    }
  }

  /// Get current financial year
  static String get currentFinancialYear => getFinancialYear(DateTime.now());

  /// Capitalize first letter of each word
  static String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Get status chip color
  static int statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'completed':
      case 'success':
      case 'paid':
        return 0xFF43A047; // green
      case 'pending':
      case 'processing':
        return 0xFFFFA000; // amber
      case 'inactive':
      case 'rejected':
      case 'failed':
      case 'cancelled':
        return 0xFFE53935; // red
      case 'draft':
        return 0xFF757575; // grey
      default:
        return 0xFF1E88E5; // blue
    }
  }
}

