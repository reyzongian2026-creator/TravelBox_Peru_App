import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations_fixed.dart';

/// Shows a dialog with the cancellation policy breakdown,
/// fee calculation, and refund amount before the user confirms.
class CancellationPreviewDialog extends StatelessWidget {
  const CancellationPreviewDialog({
    super.key,
    required this.preview,
    required this.onConfirm,
  });

  final Map<String, dynamic> preview;
  final VoidCallback onConfirm;

  /// Shows the dialog and returns `true` if the user confirmed the cancellation.
  static Future<bool?> show({
    required BuildContext context,
    required Map<String, dynamic> preview,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancellationPreviewDialog(
        preview: preview,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bookingType = preview['bookingType']?.toString() ?? 'UNKNOWN';
    final policyType = preview['policyType']?.toString() ?? 'UNKNOWN';
    final policyDescription = preview['policyDescription']?.toString() ?? '';
    final grossPaid = _parseDouble(preview['grossPaid']);
    final cancellationFee = _parseDouble(preview['cancellationFee']);
    final refundToCustomer = _parseDouble(preview['refundToCustomer']);
    final requiresRefund = preview['requiresRefund'] == true;
    final refundAllowed = preview['refundAllowed'] == true;
    final refundBlockedReason = preview['refundBlockedReason']?.toString();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            requiresRefund ? Icons.receipt_long : Icons.cancel_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(context.l10n.t('cancel_reservation')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking type badge
            _buildBadge(
              context,
              bookingType == 'IMMEDIATE'
                  ? context.l10n.t('booking_immediate')
                  : context.l10n.t('booking_advance'),
              bookingType == 'IMMEDIATE'
                  ? Colors.orange
                  : Colors.blue,
            ),
            const SizedBox(height: 12),

            // Policy description
            Text(
              policyDescription,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Financial breakdown
            if (requiresRefund) ...[
              const Divider(),
              _buildRow(context, context.l10n.t('amount_paid'), 'S/ ${grossPaid.toStringAsFixed(2)}'),
              if (cancellationFee > 0)
                _buildRow(
                  context,
                  context.l10n.t('cancellation_fee'),
                  '- S/ ${cancellationFee.toStringAsFixed(2)}',
                  valueColor: theme.colorScheme.error,
                ),
              const Divider(),
              _buildRow(
                context,
                context.l10n.t('refund_to_receive'),
                'S/ ${refundToCustomer.toStringAsFixed(2)}',
                isBold: true,
                valueColor: refundToCustomer > 0
                    ? Colors.green.shade700
                    : theme.colorScheme.error,
              ),
              const SizedBox(height: 8),
            ],

            // Policy type indicator
            _buildPolicyChip(context, policyType),

            if (refundBlockedReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: theme.colorScheme.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _friendlyBlockReason(refundBlockedReason),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.t('go_back')),
        ),
        if (refundAllowed || !requiresRefund)
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(
              requiresRefund ? context.l10n.t('confirm_refund_cancel') : context.l10n.t('confirm_cancellation'),
            ),
          ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyChip(BuildContext context, String policyType) {
    final (label, color) = switch (policyType) {
      'FULL_REFUND' => (context.l10n.t('policy_full_refund'), Colors.green),
      'PARTIAL_REFUND' => (context.l10n.t('policy_partial_refund'), Colors.orange),
      'NO_REFUND' => (context.l10n.t('policy_no_refund'), Colors.red),
      'MANUAL_REVIEW' => (context.l10n.t('policy_manual_review'), Colors.grey),
      _ => (context.l10n.t('policy_unknown'), Colors.grey),
    };
    return _buildBadge(context, label, color);
  }

  String _friendlyBlockReason(String reason) {
    return switch (reason) {
      'REFUND_ALREADY_PROCESSED' => 'Refund already processed.',
      _ => 'Cannot process refund at this time.',
    };
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
