import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations_fixed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/brand_tokens.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/models/reservation.dart';
import '../../../shared/state/qr_handoff_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/operation_guide.dart';
import '../../payments/presentation/cash_payments_page.dart';
import '../../reservation/presentation/reservation_providers.dart';

final opsPendingApprovalsProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(reservationRealtimeEventCursorProvider);
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get<List<dynamic>>('/ops/qr-handoff/approvals');
    final items = response.data ?? const <dynamic>[];
    var pending = 0;
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        final status = item['status']?.toString().toUpperCase() ?? '';
        if (status == 'PENDING') {
          pending += 1;
        }
      }
    }
    return pending;
  } catch (_) {
    final state = ref.read(qrHandoffControllerProvider);
    return state.approvalNotifications
        .where((item) => item.status == OpsApprovalStatus.pending)
        .length;
  }
});

class OperatorDashboardPage extends ConsumerWidget {
  const OperatorDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final responsive = context.responsive;
    final pendingCash = ref.watch(cashPendingPaymentsProvider);
    final reservations = ref.watch(adminReservationsProvider);
    final pendingApprovals =
        ref.watch(opsPendingApprovalsProvider).valueOrNull ?? 0;
    final session = ref.watch(sessionControllerProvider);

    final reservationItems = reservations.valueOrNull ?? const <Reservation>[];
    final activeReservations = reservationItems
        .where(
          (item) =>
              item.status != ReservationStatus.cancelled &&
              item.status != ReservationStatus.completed &&
              item.status != ReservationStatus.expired,
        )
        .length;
    final incidentReservations = reservationItems
        .where((item) => item.status == ReservationStatus.incident)
        .length;
    final pendingCashCount = pendingCash.valueOrNull?.items.length ?? 0;
    final operatorGuide = session.locale.languageCode.toLowerCase() == 'es'
        ? resolveOperationGuide('/operator/panel')
        : null;

    return AppShellScaffold(
      title: l10n.t('operator_dashboard_title'),
      currentRoute: '/operator/panel',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cashPendingPaymentsProvider);
          ref.invalidate(adminReservationsProvider);
          ref.invalidate(opsPendingApprovalsProvider);
        },
        child: ListView(
          padding: responsive.pageInsets(
            top: responsive.verticalPadding,
            bottom: 24,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: TravelBoxBrand.heroGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x283366FF),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.dashboard_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.t('operator_dashboard_intro'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (operatorGuide != null) ...[
              OperationGuideSummaryCard(guide: operatorGuide, compact: true),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 430) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _KpiCard(
                          title: l10n.t('operator_kpi_pending_cash'),
                          value: '$pendingCashCount',
                          icon: Icons.point_of_sale_outlined,
                          colors: const [Color(0xFF1F6E8C), Color(0xFF3F9AC1)],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _KpiCard(
                          title: l10n.t('operator_kpi_active_reservations'),
                          value: '$activeReservations',
                          icon: Icons.luggage_outlined,
                          colors: const [Color(0xFF0B8B8C), Color(0xFF2AAAC2)],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _KpiCard(
                          title: l10n.t('operator_kpi_incidents'),
                          value: '$incidentReservations',
                          icon: Icons.warning_amber_outlined,
                          colors: const [Color(0xFFC43D3D), Color(0xFFDE7060)],
                        ),
                      ),
                    ],
                  );
                }
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: l10n.t('operator_kpi_pending_cash'),
                              value: '$pendingCashCount',
                              icon: Icons.point_of_sale_outlined,
                              colors: const [
                                Color(0xFF1F6E8C),
                                Color(0xFF3F9AC1),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KpiCard(
                              title: l10n.t('operator_kpi_active_reservations'),
                              value: '$activeReservations',
                              icon: Icons.luggage_outlined,
                              colors: const [
                                Color(0xFF0B8B8C),
                                Color(0xFF2AAAC2),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _KpiCard(
                          title: l10n.t('operator_kpi_incidents'),
                          value: '$incidentReservations',
                          icon: Icons.warning_amber_outlined,
                          colors: const [Color(0xFFC43D3D), Color(0xFFDE7060)],
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: l10n.t('operator_kpi_pending_cash'),
                        value: '$pendingCashCount',
                        icon: Icons.point_of_sale_outlined,
                        colors: const [Color(0xFF1F6E8C), Color(0xFF3F9AC1)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiCard(
                        title: l10n.t('operator_kpi_active_reservations'),
                        value: '$activeReservations',
                        icon: Icons.luggage_outlined,
                        colors: const [Color(0xFF0B8B8C), Color(0xFF2AAAC2)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KpiCard(
                        title: l10n.t('operator_kpi_incidents'),
                        value: '$incidentReservations',
                        icon: Icons.warning_amber_outlined,
                        colors: const [Color(0xFFC43D3D), Color(0xFFDE7060)],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      l10n.t('operator_dashboard_title'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _NavTile(
                    icon: Icons.point_of_sale_outlined,
                    iconColor: const Color(0xFF1F6E8C),
                    title: l10n.t('cobros_en_caja'),
                    subtitle: l10n.t('aprobar_o_rechazar_pagos_pendientes'),
                    onTap: () => context.go('/operator/cash-payments'),
                  ),
                  const Divider(height: 1, indent: 68),
                  _NavTile(
                    icon: Icons.assignment_outlined,
                    iconColor: const Color(0xFF0B8B8C),
                    title: l10n.t('reservas_operativas'),
                    subtitle: l10n.t('operator_reservations_subtitle'),
                    onTap: () => context.go('/operator/reservations'),
                  ),
                  const Divider(height: 1, indent: 68),
                  _NavTile(
                    icon: Icons.warning_amber_outlined,
                    iconColor: const Color(0xFFC43D3D),
                    title: l10n.t('incidencias'),
                    subtitle: l10n.t('monitoreo_y_atencion_de_casos'),
                    onTap: () => context.go('/operator/incidents'),
                  ),
                  const Divider(height: 1, indent: 68),
                  _NavTile(
                    icon: Icons.route_outlined,
                    iconColor: TravelBoxBrand.primaryBlue,
                    title: l10n.t('tracking_logistico'),
                    subtitle: l10n.t('seguimiento_de_deliveries_en_vivo'),
                    onTap: () => context.go('/operator/tracking'),
                  ),
                  const Divider(height: 1, indent: 68),
                  _NavTile(
                    icon: Icons.qr_code_scanner_outlined,
                    iconColor: TravelBoxBrand.copper,
                    title: l10n.t('qr_y_pin_operativo'),
                    subtitle: l10n.t('operator_qr_subtitle'),
                    onTap: () => context.go('/ops/qr-handoff'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (pendingApprovals > 0)
              Card(
                color: const Color(0xFFFFF7E8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0B2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pendingApprovals ${l10n.t('operator_pending_approvals_suffix')}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.t('operator_pending_approvals_subtitle'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () => context.go('/ops/qr-handoff'),
                        child: Text(l10n.t('revisar')),
                      ),
                    ],
                  ),
                ),
              ),
            if (pendingApprovals > 0) const SizedBox(height: 12),
            pendingCash.when(
              data: (pageResult) {
                final items = pageResult.items;
                if (items.isEmpty) {
                  return EmptyStateView(
                    message: l10n.t('operator_no_pending_cash'),
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('operator_recent_pending_title'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...items
                            .take(5)
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${l10n.t('operator_attempt')} #${item.paymentIntentId} - ${l10n.t('operator_reservation')} #${item.reservationId}',
                                ),
                                subtitle: Text(
                                  '${item.userName} - S/${item.amount.toStringAsFixed(2)}',
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const LoadingStateView(),
              error: (error, _) => ErrorStateView(
                message:
                    '${l10n.t('operator_pending_cash_load_failed')}: $error',
                onRetry: () => ref.invalidate(cashPendingPaymentsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.colors,
    required this.icon,
  });

  final String title;
  final String value;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(minHeight: 110),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: TravelBoxBrand.textMuted,
      ),
      onTap: onTap,
    );
  }
}
