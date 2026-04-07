import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations_fixed.dart';

class OperationGuideStep {
  const OperationGuideStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class OperationGuideQuickAction {
  const OperationGuideQuickAction({required this.label, required this.route});

  final String label;
  final String route;
}

class OperationGuideData {
  const OperationGuideData({
    required this.title,
    required this.summary,
    required this.steps,
    this.warning,
    this.quickActions = const [],
  });

  final String title;
  final String summary;
  final List<OperationGuideStep> steps;
  final String? warning;
  final List<OperationGuideQuickAction> quickActions;
}

OperationGuideData? resolveOperationGuide(String currentRoute) {
  final route = currentRoute.trim().toLowerCase();

  if (route.startsWith('/operator/panel')) {
    return const OperationGuideData(
      title: 'operation_guide_operator_route_title',
      summary: 'operation_guide_operator_route_summary',
      steps: [
        OperationGuideStep(
          icon: Icons.point_of_sale_outlined,
          title: 'operation_guide_operator_step_1_title',
          description: 'operation_guide_operator_step_1_desc',
        ),
        OperationGuideStep(
          icon: Icons.assignment_outlined,
          title: 'operation_guide_operator_step_2_title',
          description: 'operation_guide_operator_step_2_desc',
        ),
        OperationGuideStep(
          icon: Icons.qr_code_scanner_outlined,
          title: 'operation_guide_operator_step_3_title',
          description: 'operation_guide_operator_step_3_desc',
        ),
        OperationGuideStep(
          icon: Icons.route_outlined,
          title: 'operation_guide_operator_step_4_title',
          description: 'operation_guide_operator_step_4_desc',
        ),
        OperationGuideStep(
          icon: Icons.support_agent_outlined,
          title: 'operation_guide_operator_step_5_title',
          description: 'operation_guide_operator_step_5_desc',
        ),
      ],
      warning: 'operation_guide_operator_warning',
      quickActions: [
        OperationGuideQuickAction(
          label: 'cobros_en_caja',
          route: '/operator/cash-payments',
        ),
        OperationGuideQuickAction(
          label: 'reservas',
          route: '/operator/reservations',
        ),
        OperationGuideQuickAction(label: 'qr_y_pin', route: '/ops/qr-handoff'),
      ],
    );
  }

  if (route.startsWith('/operator/cash-payments') ||
      route.startsWith('/admin/cash-payments')) {
    return const OperationGuideData(
      title: 'operation_guide_cash_title',
      summary: 'operation_guide_cash_summary',
      steps: [
        OperationGuideStep(
          icon: Icons.search_outlined,
          title: 'operation_guide_cash_step_1_title',
          description: 'operation_guide_cash_step_1_desc',
        ),
        OperationGuideStep(
          icon: Icons.receipt_long_outlined,
          title: 'operation_guide_cash_step_2_title',
          description: 'operation_guide_cash_step_2_desc',
        ),
        OperationGuideStep(
          icon: Icons.task_alt_outlined,
          title: 'operation_guide_cash_step_3_title',
          description: 'operation_guide_cash_step_3_desc',
        ),
      ],
      warning: 'operation_guide_cash_warning',
    );
  }

  if (route.startsWith('/operator/reservations') ||
      route.startsWith('/admin/reservations')) {
    return const OperationGuideData(
      title: 'operation_guide_reservations_title',
      summary: 'operation_guide_reservations_summary',
      steps: [
        OperationGuideStep(
          icon: Icons.filter_alt_outlined,
          title: 'operation_guide_reservations_step_1_title',
          description: 'operation_guide_reservations_step_1_desc',
        ),
        OperationGuideStep(
          icon: Icons.info_outline,
          title: 'operation_guide_reservations_step_2_title',
          description: 'operation_guide_reservations_step_2_desc',
        ),
        OperationGuideStep(
          icon: Icons.history_outlined,
          title: 'operation_guide_reservations_step_3_title',
          description: 'operation_guide_reservations_step_3_desc',
        ),
      ],
      quickActions: [
        OperationGuideQuickAction(
          label: 'abrir_modulo_qrpin',
          route: '/ops/qr-handoff',
        ),
        OperationGuideQuickAction(
          label: 'ver_tracking',
          route: '/operator/tracking',
        ),
      ],
    );
  }

  if (route.startsWith('/ops/qr-handoff')) {
    return const OperationGuideData(
      title: 'operation_guide_qrpin_title',
      summary: 'operation_guide_qrpin_summary',
      steps: [
        OperationGuideStep(
          icon: Icons.qr_code_scanner_outlined,
          title: 'operation_guide_qrpin_step_1_title',
          description: 'operation_guide_qrpin_step_1_desc',
        ),
        OperationGuideStep(
          icon: Icons.luggage_outlined,
          title: 'operation_guide_qrpin_step_2_title',
          description: 'operation_guide_qrpin_step_2_desc',
        ),
        OperationGuideStep(
          icon: Icons.photo_camera_back_outlined,
          title: 'operation_guide_qrpin_step_3_title',
          description: 'operation_guide_qrpin_step_3_desc',
        ),
        OperationGuideStep(
          icon: Icons.pin_outlined,
          title: 'operation_guide_qrpin_step_4_title',
          description: 'operation_guide_qrpin_step_4_desc',
        ),
        OperationGuideStep(
          icon: Icons.verified_user_outlined,
          title: 'operation_guide_qrpin_step_5_title',
          description: 'operation_guide_qrpin_step_5_desc',
        ),
      ],
      warning: 'operation_guide_qrpin_warning',
    );
  }

  if (route.startsWith('/operator/tracking') ||
      route.startsWith('/admin/tracking') ||
      route.startsWith('/courier/services') ||
      route.startsWith('/courier/tracking')) {
    return const OperationGuideData(
      title: 'operation_guide_tracking_title',
      summary: 'operation_guide_tracking_summary',
      steps: [
        OperationGuideStep(
          icon: Icons.route_outlined,
          title: 'operation_guide_tracking_step_1_title',
          description: 'operation_guide_tracking_step_1_desc',
        ),
        OperationGuideStep(
          icon: Icons.schedule_outlined,
          title: 'operation_guide_tracking_step_2_title',
          description: 'operation_guide_tracking_step_2_desc',
        ),
        OperationGuideStep(
          icon: Icons.phone_in_talk_outlined,
          title: 'operation_guide_tracking_step_3_title',
          description: 'operation_guide_tracking_step_3_desc',
        ),
      ],
    );
  }

  if (route.startsWith('/operator/incidents') ||
      route.startsWith('/admin/incidents') ||
      route.startsWith('/support/incidents')) {
    return const OperationGuideData(
      title: 'operation_guide_incidents_title',
      summary: 'operation_guide_incidents_summary',
      steps: [
        OperationGuideStep(
          icon: Icons.visibility_outlined,
          title: 'operation_guide_incidents_step_1_title',
          description: 'operation_guide_incidents_step_1_desc',
        ),
        OperationGuideStep(
          icon: Icons.chat_outlined,
          title: 'operation_guide_incidents_step_2_title',
          description: 'operation_guide_incidents_step_2_desc',
        ),
        OperationGuideStep(
          icon: Icons.task_alt_outlined,
          title: 'operation_guide_incidents_step_3_title',
          description: 'operation_guide_incidents_step_3_desc',
        ),
      ],
    );
  }

  return null;
}

Future<void> showOperationGuideSheet(
  BuildContext context, {
  required OperationGuideData guide,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final width = MediaQuery.of(context).size.width;
      final maxWidth = width >= 1000 ? 860.0 : width;
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.t(guide.title),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(context.l10n.t(guide.summary)),
                    if (guide.warning != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(context.l10n.t(guide.warning!)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ...guide.steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == guide.steps.length - 1 ? 0 : 12,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                child: Icon(
                                  step.icon,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.t(step.title),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(context.l10n.t(step.description)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (guide.quickActions.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: guide.quickActions
                            .map(
                              (action) => OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  if (GoRouterState.of(
                                        context,
                                      ).matchedLocation !=
                                      action.route) {
                                    context.go(action.route);
                                  }
                                },
                                icon: const Icon(Icons.arrow_forward_outlined),
                                label: Text(context.l10n.t(action.label)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class OperationGuideSummaryCard extends StatelessWidget {
  const OperationGuideSummaryCard({
    super.key,
    required this.guide,
    this.compact = false,
  });

  final OperationGuideData guide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visibleSteps = compact ? guide.steps.take(3).toList() : guide.steps;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.l10n.t(guide.title),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Chip(
                  label: Text(
                    '${guide.steps.length} ${context.l10n.t('operation_guide_steps_suffix')}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(context.l10n.t(guide.summary)),
            const SizedBox(height: 12),
            ...visibleSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(step.icon, size: 18, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.t(step.title),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(context.l10n.t(step.description)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (compact && guide.steps.length > visibleSteps.length)
              Text(
                context.l10n.t('operation_guide_open_full_for_more'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () =>
                      showOperationGuideSheet(context, guide: guide),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(context.l10n.t('operation_guide_view_full')),
                ),
                ...guide.quickActions
                    .take(2)
                    .map(
                      (action) => OutlinedButton(
                        onPressed: () => context.go(action.route),
                        child: Text(context.l10n.t(action.label)),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
