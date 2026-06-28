import 'package:flutter/material.dart';
import '../../core/router/app_router.dart';

/// Helper class to show snackbar messages
class AppSnackbar {
  /// Show a success snackbar
  static void success(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _showSnackbar(context, message, SnackbarType.success, actionLabel: actionLabel, onAction: onAction);
  }

  /// Show an error snackbar
  static void error(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _showSnackbar(context, message, SnackbarType.error, actionLabel: actionLabel, onAction: onAction);
  }

  /// Show a warning snackbar
  static void warning(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _showSnackbar(context, message, SnackbarType.warning, actionLabel: actionLabel, onAction: onAction);
  }

  /// Show an info snackbar
  static void info(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
    _showSnackbar(context, message, SnackbarType.info, actionLabel: actionLabel, onAction: onAction);
  }

  /// Internal method to show snackbar
  static void _showSnackbar(
    BuildContext context,
    String message,
    SnackbarType type, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case SnackbarType.success:
        backgroundColor = const Color(0xFF43A047);
        textColor = Colors.white;
        icon = Icons.check_circle_rounded;
        break;
      case SnackbarType.error:
        backgroundColor = const Color(0xFFE53935);
        textColor = Colors.white;
        icon = Icons.error_rounded;
        break;
      case SnackbarType.warning:
        backgroundColor = const Color(0xFFFFA000);
        textColor = Colors.white;
        icon = Icons.warning_rounded;
        break;
      case SnackbarType.info:
        backgroundColor = const Color(0xFF1E88E5);
        textColor = Colors.white;
        icon = Icons.info_rounded;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 4),
      actionOverflowThreshold: 1,
    );

    // Use the root scaffold messenger key to show snackbar
    rootScaffoldMessengerKey.currentState
        ?.showSnackBar(snackBar);
  }

  /// Show a loading snackbar
  static void showLoading(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(message),
        ],
      ),
      backgroundColor: Colors.black87,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(minutes: 5), // Long duration for loading
    );

    rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }

  /// Hide current snackbar
  static void hideCurrent() {
    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  }
}

enum SnackbarType { success, error, warning, info }
