import 'package:flutter/material.dart';

/// A full-screen blocking overlay displayed during critical operations
/// (payment processing, refund execution, cancellation).
///
/// Prevents user from navigating away or tapping buttons
/// while the operation is in progress.
class CriticalOperationOverlay extends StatelessWidget {
  const CriticalOperationOverlay({
    super.key,
    required this.message,
    this.submessage,
    this.showProgress = true,
  });

  final String message;
  final String? submessage;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showProgress) ...[
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (submessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      submessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'No cierres esta ventana',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show the overlay as a full-screen dialog that blocks interaction.
  static OverlayEntry show(
    BuildContext context, {
    required String message,
    String? submessage,
  }) {
    final overlay = OverlayEntry(
      builder: (_) => CriticalOperationOverlay(
        message: message,
        submessage: submessage,
      ),
    );
    Overlay.of(context).insert(overlay);
    return overlay;
  }

  /// Remove a previously shown overlay.
  static void dismiss(OverlayEntry? entry) {
    entry?.remove();
  }
}
