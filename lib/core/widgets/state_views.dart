import 'package:flutter/material.dart';

import '../l10n/app_localizations_fixed.dart';

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key, this.message = 'Cargando...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(_resolveUiMessage(context, message)),
        ],
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 44),
            const SizedBox(height: 12),
            Text(
              _resolveUiMessage(context, message),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.t('reintentar')),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 44),
            const SizedBox(height: 12),
            Text(
              _resolveUiMessage(context, message),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child: Text(_resolveUiMessage(context, actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _resolveUiMessage(BuildContext context, String raw) {
  final normalized = raw.trim();
  final noDataKey = context.l10n.t('state_view_no_data');
  if (normalized == 'Cargando...') {
    return context.l10n.t('loading');
  }
  if (normalized == 'Reintentar') {
    return context.l10n.t('reintentar');
  }
  if (normalized == noDataKey) {
    return context.l10n.t('empty');
  }
  return raw;
}
