import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/utils/incident_translation_service.dart';
import '../data/incidents_repository.dart';

final incidentMessagesProvider =
    FutureProvider.family<List<IncidentMessage>, int>((ref, incidentId) async {
      final repository = ref.read(incidentsRepositoryProvider);
      return repository.getIncidentMessages(incidentId);
    });

class IncidentConversationDialog extends ConsumerStatefulWidget {
  const IncidentConversationDialog({
    super.key,
    required this.incidentId,
    required this.ticketLabel,
    required this.status,
    required this.allowReply,
  });

  final int incidentId;
  final String ticketLabel;
  final String status;
  final bool allowReply;

  @override
  ConsumerState<IncidentConversationDialog> createState() =>
      _IncidentConversationDialogState();
}

class _IncidentConversationDialogState
    extends ConsumerState<IncidentConversationDialog> {
  final _controller = TextEditingController();
  bool _sending = false;

  bool get _canReply =>
      widget.allowReply && widget.status.trim().toUpperCase() == 'OPEN';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(incidentMessagesProvider(widget.incidentId));
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.ticketLabel,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Conversacion del ticket',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          context.l10n.t('incident_empty_history_hint'),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _MessageBubble(message: message);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      AppErrorFormatter.readable(
                        error,
                        (String key, {Map<String, dynamic>? params}) =>
                            context.l10n.t(key),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              if (_canReply) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Responder incidencia',
                    hintText: 'Escribe una respuesta clara para continuar el caso.',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _sendReply,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Enviando...' : 'Enviar respuesta'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendReply() async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      final session = ref.read(sessionControllerProvider);
      final translator = ref.read(incidentTranslationServiceProvider);
      final sourceLanguage = translator.detectLikelySourceLanguage(
        message: message,
        fallbackLanguage: session.locale.languageCode,
      );
      await ref.read(incidentsRepositoryProvider).addIncidentMessage(
            incidentId: widget.incidentId,
            message: message,
            originalLanguage: sourceLanguage,
          );
      _controller.clear();
      ref.invalidate(incidentMessagesProvider(widget.incidentId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respuesta enviada correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorFormatter.readable(
              error,
              (String key, {Map<String, dynamic>? params}) => context.l10n.t(key),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final IncidentMessage message;

  @override
  Widget build(BuildContext context) {
    final isCustomer = message.authorRole.trim().toUpperCase() == 'CLIENT';
    final theme = Theme.of(context);
    final label = (message.authorName?.trim().isNotEmpty ?? false)
        ? message.authorName!.trim()
        : _roleLabel(message.authorRole);

    return Align(
      alignment: isCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCustomer
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
                : theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCustomer
                  ? theme.colorScheme.outlineVariant.withValues(alpha: 0.35)
                  : theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    PeruTime.formatDateTime(message.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                (message.textTranslated?.trim().isNotEmpty ?? false)
                    ? message.textTranslated!.trim()
                    : message.textOriginal.trim(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleLabel(String rawRole) {
  switch (rawRole.trim().toUpperCase()) {
    case 'ADMIN':
      return 'Administrador';
    case 'SUPPORT':
      return 'Soporte';
    case 'OPERATOR':
    case 'CITY_SUPERVISOR':
      return 'Operaciones';
    case 'COURIER':
      return 'Courier';
    case 'CLIENT':
    default:
      return 'Cliente';
  }
}
