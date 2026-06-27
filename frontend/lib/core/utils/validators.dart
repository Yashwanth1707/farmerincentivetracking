import 'package:flutter/material.dart';

/// Form validators for various input fields
class FormValidators {
  /// Required field validation
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Email validation
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Password validation (min 6 chars)
  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Confirm password validation
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.trim().isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Mobile number validation (10 digits)
  static String? mobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final mobileRegex = RegExp(r'^[0-9]{10}$');
    if (!mobileRegex.hasMatch(value.trim())) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// Aadhaar number validation (12 digits)
  static String? aadhaar(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Aadhaar number is required';
    }
    final aadhaarRegex = RegExp(r'^[0-9]{12}$');
    if (!aadhaarRegex.hasMatch(value.trim())) {
      return 'Please enter a valid 12-digit Aadhaar number';
    }
    return null;
  }

  /// PAN validation
  static String? pan(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PAN is required';
    }
    // Format: ABCDE1234F
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegex.hasMatch(value.trim().toUpperCase())) {
      return 'Please enter a valid PAN (e.g., ABCDE1234F)';
    }
    return null;
  }

  /// IFSC code validation
  static String? ifsc(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'IFSC code is required';
    }
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(value.trim().toUpperCase())) {
      return 'Please enter a valid IFSC code';
    }
    return null;
  }

  /// Account number validation
  static String? accountNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Account number is required';
    }
    if (value.length < 9 || value.length > 18) {
      return 'Account number must be between 9 and 18 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
      return 'Account number must contain only digits';
    }
    return null;
  }

  /// Amount validation
  static String? amount(String? value, {double? min, double? max}) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final amount = double.tryParse(value.trim());
    if (amount == null || amount <= 0) {
      return 'Please enter a valid positive amount';
    }
    if (min != null && amount < min) {
      return 'Amount must be at least ₹$min';
    }
    if (max != null && amount > max) {
      return 'Amount must not exceed ₹$max';
    }
    return null;
  }

  /// Farmer ID validation
  static String? farmerId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Farmer ID is required';
    }
    if (value.trim().length > 20) {
      return 'Farmer ID must not exceed 20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value.trim())) {
      return 'Farmer ID can only contain letters, numbers, hyphens, and underscores';
    }
    return null;
  }

  /// URL validation
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // URL is optional
    }
    final urlRegex = RegExp(
      r'^(https?:\/\/)?([\w\-]+\.)+[\w\-]+(\/[\w\-\.~:/?#\[\]@!$&()*+,;=]*)?$',
    );
    if (!urlRegex.hasMatch(value.trim())) {
      return 'Please enter a valid URL';
    }
    return null;
  }
}

/// Form validation helper - validates all fields and returns first error
class FormValidationHelper {
  static String? validateAll(Map<String, String?> Function() validators) {
    final errors = validators();
    for (final error in errors.values) {
      if (error != null) return error;
    }
    return null;
  }
}