import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/services/app_error_report_service.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/internal_message_translator.dart';
import '../../../shared/widgets/app_smart_image.dart';
import '../../auth/data/auth_repository_impl.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = context.responsive;
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;

    return AppShellScaffold(
      title: context.l10n.t('profile'),
      currentRoute: '/profile',
      actions: user?.canSelfEditProfile == true
          ? [
              IconButton(
                onPressed: () => context.go('/profile/edit'),
                icon: const Icon(Icons.edit_outlined),
              ),
            ]
          : const [],
      child: ListView(
        padding: responsive.pageInsets(
          top: responsive.verticalPadding,
          bottom: 24,
        ),
        children: [
          Card(
            child: ListTile(
              leading: SizedBox(
                width: 52,
                height: 52,
                child: ClipOval(
                  child: AppSmartImage(
                    source: user?.profilePhotoPath,
                    width: 52,
                    height: 52,
                    fallback: Container(
                      color: const Color(0xFFE6F0F4),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person_outline),
                    ),
                  ),
                ),
              ),
              title: Text(user?.name ?? context.l10n.t('profile_no_user')),
              subtitle: Text(
                '${user?.email ?? context.l10n.t('profile_not_available')}\n'
                '${context.l10n.t('profile_role_prefix')}: '
                '${user == null ? '-' : context.l10n.t(user.role.localizationKey)}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(user?.nationality ?? '-'),
                  Text(user?.preferredLanguage.toUpperCase() ?? 'ES'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (user?.canSelfEditProfile == false) ...[
            Card(
              color: const Color(0xFFF6F1E8),
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(
                  context.l10n.t('perfil_administrado_por_travelbox'),
                ),
                subtitle: Text(
                  context.l10n.t('profile_internal_edit_admin_only'),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Column(
              children: [
                _ProfileRow(
                  context.l10n.t('profile_phone_number'),
                  user?.phone ?? '-',
                ),
                _ProfileRow(
                  context.l10n.t('address'),
                  user?.address.isNotEmpty == true ? user!.address : '-',
                ),
                _ProfileRow(
                  context.l10n.t('city'),
                  user?.city.isNotEmpty == true ? user!.city : '-',
                ),
                _ProfileRow(
                  context.l10n.t('country'),
                  user?.country.isNotEmpty == true ? user!.country : '-',
                ),
                _ProfileRow(
                  context.l10n.t('profile_document_type'),
                  user?.documentType != null && user?.documentNumber != null
                      ? '${user!.documentType} ${user.documentNumber}'
                      : '-',
                ),
                _ProfileRow(
                  context.l10n.t('profile_emergency_contact'),
                  user?.emergencyContactName != null
                      ? '${user!.emergencyContactName} (${user.emergencyContactPhone ?? '-'})'
                      : '-',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    (user?.emailVerified ?? true)
                        ? Icons.verified_outlined
                        : Icons.mark_email_unread_outlined,
                  ),
                  title: Text(context.l10n.t('estado_de_correo')),
                  subtitle: Text(
                    (user?.emailVerified ?? true)
                        ? context.l10n.t('profile_email_verified')
                        : context.l10n.t('profile_email_pending_verification'),
                  ),
                  trailing: !(user?.emailVerified ?? true)
                      ? TextButton(
                          onPressed: () => context.go('/verify-email'),
                          child: Text(context.l10n.t('verificar')),
                        )
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(context.l10n.t('idioma_de_app')),
                  subtitle: Text(user?.preferredLanguage.toUpperCase() ?? 'ES'),
                  trailing: SizedBox(
                    width: responsive.isMobile ? 116 : 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: session.locale.languageCode,
                      items: const ['es', 'en', 'de', 'fr', 'it', 'pt']
                          .map(
                            (code) => DropdownMenuItem(
                              value: code,
                              child: Text(languageLabel(code)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        ref
                            .read(sessionControllerProvider.notifier)
                            .setLocale(Locale(value));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () async {
              final refreshToken = session.refreshToken?.trim();
              
              try {
                final jsonReporte = await AppErrorReportNotifier.exportAndClearBeforeLogout();
                
                if (!context.mounted) return;
                
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => _ErrorReportDialog(jsonReporte: jsonReporte),
                );
                
                if (shouldLogout != true) return;
                
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al exportar reporte: $e')),
                );
              }
              
              await ref.read(sessionControllerProvider.notifier).signOut();
              if (!context.mounted) return;
              context.go('/login');
              if (refreshToken != null && refreshToken.isNotEmpty) {
                unawaited(
                  ref
                      .read(authRepositoryProvider)
                      .logout(refreshToken: refreshToken)
                      .catchError((_) {}),
                );
              }
            },
            child: Text(context.l10n.t('logout')),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(label), subtitle: Text(value));
  }
}

class _ErrorReportDialog extends StatelessWidget {
  const _ErrorReportDialog({required this.jsonReporte});

  final String jsonReporte;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(jsonReporte) as Map<String, dynamic>;
    } catch (_) {
      parsed = null;
    }
    
    final totalErrors = parsed?['totalErrors'] ?? 0;
    final errorsByType = parsed?['errorsByType'] as Map<String, dynamic>? ?? {};
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: totalErrors > 0 ? Colors.orange : Colors.green),
          const SizedBox(width: 8),
          const Text('Reporte de errores'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              totalErrors == 0
                  ? 'No se encontraron errores durante la sesión.'
                  : 'Se encontraron $totalErrors errores durante la sesión. '
                    'Puedes copiar el reporte antes de cerrar.',
            ),
            if (errorsByType.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Resumen por tipo:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...errorsByType.entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                  children: [
                    Icon(_getIconForType(e.key), size: 16),
                    const SizedBox(width: 4),
                    Text('${e.key}: ${e.value}'),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonReporte.length > 4000 
                      ? '${jsonReporte.substring(0, 4000)}...\n\n(Contenido truncado - descarga el archivo completo)'
                      : jsonReporte,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Saltar'),
        ),
        FilledButton.icon(
          onPressed: () {
            _copyToClipboard(context, jsonReporte);
            Navigator.of(context).pop(true);
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar reporte'),
        ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'i18n': return Icons.translate;
      case 'network': return Icons.wifi_off;
      case 'flutter': return Icons.error_outline;
      case 'validation': return Icons.warning;
      case 'operation': return Icons.play_arrow;
      case 'firebase': return Icons.cloud_off;
      default: return Icons.help_outline;
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    debugPrint('[ERROR REPORT] Reporte copiado al portapapeles');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reporte copiado. Disponible también en consola.'),
        duration: Duration(seconds: 5),
      ),
    );
  }
}
