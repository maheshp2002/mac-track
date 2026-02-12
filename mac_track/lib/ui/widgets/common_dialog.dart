import 'package:flutter/material.dart';
import 'package:mac_track/ui/theme.dart';

/// CommonDialog
/// ----------------------------
/// A reusable dialog shell that provides:
/// - Title with optional close button
/// - Scroll-safe content area
/// - Optional footer actions (Cancel / Primary)
/// - Consistent sizing and theming
class CommonDialog extends StatelessWidget {
  final String title;
  final Widget body;

  /// Dialog size control
  final double? height;
  final double? width;

  /// Footer actions
  final String? primaryActionText;
  final VoidCallback? onPrimaryAction;
  final String? cancelText;

  /// UI behavior
  final bool showCloseButton;
  final bool barrierDismissible;

  const CommonDialog({
    super.key,
    required this.title,
    required this.body,
    this.height,
    this.width,
    this.primaryActionText,
    this.onPrimaryAction,
    this.cancelText = 'Cancel',
    this.showCloseButton = true,
    this.barrierDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.dialogTheme.backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),

      /// Title row with optional close button
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.displayMedium,
            ),
          ),
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),

      /// Main content
      content: SizedBox(
        height: height,
        width: width ?? double.maxFinite,
        child: body,
      ),

      /// Footer actions
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(cancelText!, style: theme.textTheme.bodyLarge),
          ),
        if (primaryActionText != null && onPrimaryAction != null)
          TextButton(
            onPressed: onPrimaryAction,
            child: Text(
              primaryActionText!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.primaryGreen,
              ),
            ),
          ),
      ],
    );
  }
}
