import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/app_error_formatter.dart';
import '../../../shared/utils/incident_translation_service.dart';
import '../../../shared/utils/peru_time.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../data/evidence_picker.dart';
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
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _selectedImageMimeType;

  bool get _canReply =>
      widget.allowReply && widget.status.trim().toUpperCase() == 'OPEN';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      incidentMessagesProvider(widget.incidentId),
    );
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
                          context.l10n.t('incident_conversation_title'),
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
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _MessageBubble(message: message);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
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
                if (_selectedImageBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImageBytes!,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            _selectedImageBytes = null;
                            _selectedImageName = null;
                            _selectedImageMimeType = null;
                          }),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(4),
                            minimumSize: const Size(24, 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('incident_reply_label'),
                    hintText: context.l10n.t('incident_reply_hint'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: _sending ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      tooltip: context.l10n.t('incident_select_image'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendReply,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        _sending
                            ? context.l10n.t('incident_sending')
                            : context.l10n.t('incident_send_reply'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final evidence = await pickEvidenceImage();
    if (evidence != null && mounted) {
      setState(() {
        _selectedImageBytes = evidence.bytes;
        _selectedImageName = evidence.filename;
        _selectedImageMimeType = evidence.mimeType;
      });
    }
  }

  Future<void> _sendReply() async {
    final message = _controller.text.trim();
    if (message.isEmpty && _selectedImageBytes == null) {
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
      await ref
          .read(incidentsRepositoryProvider)
          .addIncidentMessage(
            incidentId: widget.incidentId,
            message: message,
            originalLanguage: sourceLanguage,
            imageBytes: _selectedImageBytes,
            imageFilename: _selectedImageName,
            imageMimeType: _selectedImageMimeType,
          );
      _controller.clear();
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedImageMimeType = null;
      ref.invalidate(incidentMessagesProvider(widget.incidentId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('incident_reply_sent_success'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorFormatter.readable(
              error,
              (String key, {Map<String, dynamic>? params}) =>
                  context.l10n.t(key),
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
        : _roleLabel(message.authorRole, context);
    final displayText = (message.textTranslated?.trim().isNotEmpty ?? false)
        ? message.textTranslated!.trim()
        : message.textOriginal.trim();
    final hasImage = message.imageUrl != null && message.imageUrl!.isNotEmpty;

    return Align(
      alignment: isCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCustomer
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  )
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
              if (hasImage || displayText.isNotEmpty) const SizedBox(height: 8),
              if (hasImage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppSmartImage(
                    source: message.imageUrl,
                    height: 180,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              if (displayText.isNotEmpty) Text(displayText),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleLabel(String rawRole, BuildContext context) {
  switch (rawRole.trim().toUpperCase()) {
    case 'ADMIN':
      return context.l10n.t('incident_role_admin');
    case 'SUPPORT':
      return context.l10n.t('incident_role_support');
    case 'OPERATOR':
    case 'CITY_SUPERVISOR':
      return context.l10n.t('incident_role_operations');
    case 'COURIER':
      return context.l10n.t('incident_role_courier');
    case 'CLIENT':
    default:
      return context.l10n.t('incident_role_client');
  }
}
