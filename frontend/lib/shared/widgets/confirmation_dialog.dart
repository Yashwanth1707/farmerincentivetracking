import 'package:flutter/material.dart';

/// Confirmation dialog with customizable content and actions
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final Color? confirmColor;
  final Color? iconColor;
  final bool isDestructive;
  final Widget? content;
  final List<Widget>? additionalActions;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.icon,
    this.confirmColor,
    this.iconColor,
    this.isDestructive = false,
    this.content,
    this.additionalActions,
  });

  /// Show the confirmation dialog and return true if confirmed
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
    Color? confirmColor,
    bool isDestructive = false,
    Widget? content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        confirmColor: confirmColor,
        isDestructive: isDestructive,
        content: content,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Column(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (iconColor ?? (isDestructive
                        ? AppColors.error
                        : colorScheme.primary))
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor ??
                    (isDestructive ? AppColors.error : colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (content != null) ...[
            const SizedBox(height: 16),
            content!,
          ],
        ],
      ),
      actions: [
        if (additionalActions != null) ...additionalActions!,
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor ??
                (isDestructive ? AppColors.error : null),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// App colors reference (used by ConfirmationDialog)
class AppColors {
  static const Color error = Color(0xFFE53935);
  static const Color primary = Color(0xFF2E7D32);
}