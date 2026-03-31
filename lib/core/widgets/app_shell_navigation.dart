import 'package:flutter/material.dart';

import '../../shared/state/session_controller.dart';
import '../l10n/app_localizations_fixed.dart';

class ShellNavSection {
  const ShellNavSection({
    required this.label,
    required this.items,
  });

  final String label;
  final List<ShellNavItem> items;
}

class ShellNavItem {
  const ShellNavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.matchPrefixes = const [],
  });

  final String label;
  final IconData icon;
  final String route;
  final List<String> matchPrefixes;

  bool matches(String path) {
    if (path == route || path.startsWith('$route/')) {
      return true;
    }
    for (final prefix in matchPrefixes) {
      if (path == prefix || path.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }
}

List<ShellNavSection> buildShellSections(
  SessionState session,
  AppLocalizations l10n,
) {
  if (session.isAdmin) {
    return [
      ShellNavSection(
        label: 'Dashboard',
        items: [
          ShellNavItem(
            label: l10n.t('dashboard'),
            icon: Icons.grid_view_rounded,
            route: '/admin/dashboard',
            matchPrefixes: const ['/admin'],
          ),
        ],
      ),
      ShellNavSection(
        label: 'Operaciones',
        items: [
          ShellNavItem(
            label: l10n.t('users'),
            icon: Icons.group_outlined,
            route: '/admin/users',
          ),
          ShellNavItem(
            label: l10n.t('admin_warehouses_title'),
            icon: Icons.apartment_outlined,
            route: '/admin/warehouses',
          ),
          ShellNavItem(
            label: l10n.t('reservas'),
            icon: Icons.luggage_outlined,
            route: '/admin/reservations',
          ),
          ShellNavItem(
            label: l10n.t('tracking_logistico'),
            icon: Icons.local_shipping_outlined,
            route: '/admin/delivery',
          ),
          ShellNavItem(
            label: l10n.t('incidencias'),
            icon: Icons.report_problem_outlined,
            route: '/admin/incidents',
          ),
          ShellNavItem(
            label: l10n.t('cobros_en_caja'),
            icon: Icons.point_of_sale_outlined,
            route: '/admin/cash-payments',
          ),
          ShellNavItem(
            label: l10n.t('qr_y_pin_operativo'),
            icon: Icons.qr_code_scanner_outlined,
            route: '/admin/qr-handoff',
            matchPrefixes: const ['/ops/qr-handoff'],
          ),
          ShellNavItem(
            label: l10n.t('payments'),
            icon: Icons.payments_outlined,
            route: '/admin/payments-history',
          ),
          ShellNavItem(
            label: l10n.t('reports'),
            icon: Icons.insights_outlined,
            route: '/admin/ratings',
          ),
        ],
      ),
      ShellNavSection(
        label: 'Sistema',
        items: [
          ShellNavItem(
            label: l10n.t('settings'),
            icon: Icons.tune_outlined,
            route: '/admin/system',
          ),
          ShellNavItem(
            label: l10n.t('profile'),
            icon: Icons.person_outline_rounded,
            route: '/profile',
            matchPrefixes: const ['/profile'],
          ),
        ],
      ),
    ];
  }

  if (session.isSupport) {
    return [
      ShellNavSection(
        label: 'Soporte',
        items: [
          ShellNavItem(
            label: l10n.t('incidencias'),
            icon: Icons.support_agent_outlined,
            route: '/support/incidents',
            matchPrefixes: const ['/support'],
          ),
          ShellNavItem(
            label: l10n.t('notifications'),
            icon: Icons.notifications_none_rounded,
            route: '/notifications',
          ),
          ShellNavItem(
            label: l10n.t('profile'),
            icon: Icons.person_outline_rounded,
            route: '/profile',
            matchPrefixes: const ['/profile'],
          ),
        ],
      ),
    ];
  }

  if (session.isCourier) {
    return [
      ShellNavSection(
        label: 'Courier',
        items: [
          ShellNavItem(
            label: l10n.t('courier_dashboard_title'),
            icon: Icons.grid_view_rounded,
            route: '/courier/panel',
            matchPrefixes: const ['/courier/panel'],
          ),
          ShellNavItem(
            label: l10n.t('services'),
            icon: Icons.route_outlined,
            route: '/courier/services',
            matchPrefixes: const ['/courier/services', '/courier/tracking'],
          ),
          ShellNavItem(
            label: l10n.t('profile'),
            icon: Icons.person_outline_rounded,
            route: '/profile',
            matchPrefixes: const ['/profile'],
          ),
        ],
      ),
    ];
  }

  if (session.canAccessAdmin) {
    return [
      ShellNavSection(
        label: 'Operaciones',
        items: [
          ShellNavItem(
            label: l10n.t('operations_panel'),
            icon: Icons.grid_view_rounded,
            route: '/operator/panel',
            matchPrefixes: const ['/operator/panel'],
          ),
          ShellNavItem(
            label: l10n.t('reservas'),
            icon: Icons.luggage_outlined,
            route: '/operator/reservations',
            matchPrefixes: const ['/operator/reservations'],
          ),
          ShellNavItem(
            label: l10n.t('cobros_en_caja'),
            icon: Icons.point_of_sale_outlined,
            route: '/operator/cash-payments',
          ),
          ShellNavItem(
            label: l10n.t('tracking_logistico'),
            icon: Icons.local_shipping_outlined,
            route: '/operator/tracking',
            matchPrefixes: const ['/operator/tracking'],
          ),
          ShellNavItem(
            label: l10n.t('incidencias'),
            icon: Icons.report_problem_outlined,
            route: '/operator/incidents',
          ),
        ],
      ),
      ShellNavSection(
        label: 'Cuenta',
        items: [
          ShellNavItem(
            label: l10n.t('notifications'),
            icon: Icons.notifications_none_rounded,
            route: '/notifications',
          ),
          ShellNavItem(
            label: l10n.t('profile'),
            icon: Icons.person_outline_rounded,
            route: '/profile',
            matchPrefixes: const ['/profile'],
          ),
        ],
      ),
    ];
  }

  return [
    ShellNavSection(
      label: 'Viaje',
      items: [
        ShellNavItem(
          label: l10n.t('discover'),
          icon: Icons.explore_outlined,
          route: '/discovery',
          matchPrefixes: const ['/warehouse', '/reservation/new', '/checkout'],
        ),
        ShellNavItem(
          label: l10n.t('reservations'),
          icon: Icons.luggage_outlined,
          route: '/reservations',
          matchPrefixes: const ['/reservation/'],
        ),
        ShellNavItem(
          label: l10n.t('tracking_logistico'),
          icon: Icons.local_shipping_outlined,
          route: '/reservations',
          matchPrefixes: const ['/delivery/'],
        ),
      ],
    ),
    ShellNavSection(
      label: 'Cuenta',
      items: [
        ShellNavItem(
          label: l10n.t('notifications'),
          icon: Icons.notifications_none_rounded,
          route: '/notifications',
        ),
        ShellNavItem(
          label: l10n.t('incidencias'),
          icon: Icons.support_agent_outlined,
          route: '/incidents-history',
          matchPrefixes: const ['/incidents'],
        ),
        ShellNavItem(
          label: l10n.t('payments'),
          icon: Icons.receipt_long_outlined,
          route: '/payments-history',
        ),
        ShellNavItem(
          label: l10n.t('profile'),
          icon: Icons.person_outline_rounded,
          route: '/profile',
          matchPrefixes: const ['/profile'],
        ),
      ],
    ),
  ];
}

ShellNavItem? findActiveShellItem(
  String currentRoute,
  List<ShellNavSection> sections,
) {
  for (final section in sections) {
    for (final item in section.items) {
      if (item.matches(currentRoute)) {
        return item;
      }
    }
  }
  return null;
}
