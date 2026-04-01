import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations_fixed.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/brand_tokens.dart';
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.2),
                        width: 3,
                      ),
                    ),
                    child: ClipOval(
                      child: AppSmartImage(
                        source: user?.profilePhotoPath,
                        width: 80,
                        height: 80,
                        fallback: Container(
                          color: const Color(0xFFE8F0FE),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.person_outline,
                            size: 36,
                            color: TravelBoxBrand.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.name ?? context.l10n.t('profile_no_user'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? context.l10n.t('profile_not_available'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user == null
                              ? '-'
                              : context.l10n.t(user.role.localizationKey),
                          style: TextStyle(
                            color: TravelBoxBrand.primaryBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TravelBoxBrand.border,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${user?.nationality ?? '-'} / ${user?.preferredLanguage.toUpperCase() ?? 'ES'}',
                          style: TextStyle(
                            color: TravelBoxBrand.textBody,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    context.l10n.t('profile'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ProfileRow(
                  icon: Icons.phone_outlined,
                  label: context.l10n.t('profile_phone_number'),
                  value: user?.phone ?? '-',
                ),
                const Divider(height: 1, indent: 56),
                _ProfileRow(
                  icon: Icons.location_on_outlined,
                  label: context.l10n.t('address'),
                  value: user?.address.isNotEmpty == true ? user!.address : '-',
                ),
                const Divider(height: 1, indent: 56),
                _ProfileRow(
                  icon: Icons.location_city_outlined,
                  label: context.l10n.t('city'),
                  value: user?.city.isNotEmpty == true ? user!.city : '-',
                ),
                const Divider(height: 1, indent: 56),
                _ProfileRow(
                  icon: Icons.public_outlined,
                  label: context.l10n.t('country'),
                  value: user?.country.isNotEmpty == true ? user!.country : '-',
                ),
                const Divider(height: 1, indent: 56),
                _ProfileRow(
                  icon: Icons.badge_outlined,
                  label: context.l10n.t('profile_document_type'),
                  value: user?.documentType != null &&
                          user?.documentNumber != null
                      ? '${user!.documentType} ${user.documentNumber}'
                      : '-',
                ),
                const Divider(height: 1, indent: 56),
                _ProfileRow(
                  icon: Icons.contact_phone_outlined,
                  label: context.l10n.t('profile_emergency_contact'),
                  value: user?.emergencyContactName != null
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
                    width: responsive.tier == ResponsiveTier.mobileSmall
                        ? 104
                        : (responsive.isMobile ? 116 : 150),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: session.locale.languageCode,
                      items: const ['es', 'en']
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
              final refreshToken = session.refreshToken?.trim();
              final authRepository = ref.read(authRepositoryProvider);

              try {
                final jsonReporte =
                    await AppErrorReportNotifier.exportAndClearBeforeLogout();

                if (!context.mounted) return;

                final shouldLogout = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      _ErrorReportDialog(jsonReporte: jsonReporte),
                );

                if (shouldLogout != true) return;
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${context.l10n.t('error_exporting_report_prefix')}: $e',
                    ),
                  ),
                );
              }

              await ref.read(sessionControllerProvider.notifier).signOut();
              if (refreshToken != null && refreshToken.isNotEmpty) {
                unawaited(
                  authRepository
                      .logout(refreshToken: refreshToken)
                      .catchError((_) {}),
                );
              }
            },
            icon: const Icon(Icons.logout_outlined),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
              side: const BorderSide(color: Color(0xFFB42318)),
            ),
            label: Text(context.l10n.t('logout')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      subtitle: Text(value),
    );
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
          Icon(
            Icons.bug_report,
            color: totalErrors > 0 ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(context.l10n.t('report_errors')),
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
              const Text(
                'Resumen por tipo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...errorsByType.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Row(
                    children: [
                      Icon(_getIconForType(e.key), size: 16),
                      const SizedBox(width: 4),
                      Text('${e.key}: ${e.value}'),
                    ],
                  ),
                ),
              ),
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
          child: Text(context.l10n.t('omitir')),
        ),
        FilledButton.icon(
          onPressed: () {
            _copyToClipboard(context, jsonReporte);
            Navigator.of(context).pop(true);
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text(context.l10n.t('copy_report')),
        ),
      ],
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'i18n':
        return Icons.translate;
      case 'network':
        return Icons.wifi_off;
      case 'flutter':
        return Icons.error_outline;
      case 'validation':
        return Icons.warning;
      case 'operation':
        return Icons.play_arrow;
      case 'socialAuth':
        return Icons.cloud_off;
      default:
        return Icons.help_outline;
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    debugPrint('[ERROR REPORT] Reporte copiado al portapapeles');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.t('report_copied')),
        duration: Duration(seconds: 5),
      ),
    );
  }
}
