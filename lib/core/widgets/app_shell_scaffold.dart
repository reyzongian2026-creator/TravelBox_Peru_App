import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/domain/app_notification.dart';
import '../../shared/state/notification_center_controller.dart';
import '../../shared/state/session_controller.dart';
import '../../shared/state/theme_mode_controller.dart';
import '../../shared/widgets/operation_guide.dart';
import '../../shared/widgets/travelbox_logo.dart';
import '../layout/responsive_layout.dart';
import '../l10n/app_localizations.dart';
import '../theme/brand_tokens.dart';

class AppShellScaffold extends ConsumerWidget {
  const AppShellScaffold({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.child,
    this.floatingActionButton,
    this.actions = const [],
  });

  final String title;
  final String currentRoute;
  final Widget child;
  final Widget? floatingActionButton;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider);
    final notificationsState = ref.watch(notificationCenterControllerProvider);
    final mediaQuery = MediaQuery.of(context);
    final responsive = context.responsive;
    final screenWidth = mediaQuery.size.width;
    final safeBottomInset = mediaQuery.padding.bottom;
    final compactTopBar = screenWidth < 390;
    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final operationGuide = resolveOperationGuide(currentRoute);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBackground = isDark
        ? const Color(0xFF060E1C)
        : TravelBoxBrand.surface;
    final shellGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1427), Color(0xFF0F172A), Color(0xFF111827)],
          )
        : TravelBoxBrand.shellGradient;
    final panelBorderColor = isDark
        ? const Color(0xFF1F2A3E)
        : TravelBoxBrand.border;

    ref.listen<List<AppNotification>>(
      notificationCenterControllerProvider.select((state) => state.popupQueue),
      (_, nextQueue) {
        if (nextQueue.isEmpty) return;
        final next = nextQueue.first;
        final notificationsController = ref.read(
          notificationCenterControllerProvider.notifier,
        );

        if (currentRoute.startsWith('/notifications')) {
          notificationsController.consumePopup(next.id);
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          notificationsController.consumePopup(next.id);
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          final targetRoute = _resolveNotificationRoute(next);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${next.title}: ${next.message}'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: l10n.t('view'),
                onPressed: () {
                  if (!context.mounted) return;
                  if (targetRoute != null) {
                    if (currentRoute == targetRoute ||
                        currentRoute.startsWith('$targetRoute/')) {
                      return;
                    }
                    context.push(targetRoute);
                    return;
                  }
                  if (!currentRoute.startsWith('/notifications')) {
                    context.push('/notifications');
                  }
                },
              ),
            ),
          );
        });
      },
    );

    final appBarActions = <Widget>[
      const _SettingsComboMenu(),
      if (operationGuide != null && !compactTopBar)
        IconButton(
          tooltip: l10n.t('flow_guide'),
          onPressed: () =>
              showOperationGuideSheet(context, guide: operationGuide),
          icon: const Icon(Icons.help_outline),
        ),
      if (session.isAuthenticated)
        _NotificationBellButton(
          unreadCount: notificationsState.unreadCount,
          onPressed: () {
            if (currentRoute.startsWith('/notifications')) return;
            context.push('/notifications');
          },
        ),
      ...actions,
    ];

    final navItems = session.isCourier
        ? <_NavItem>[
            const _NavItem(
              label: 'Courier',
              icon: Icons.delivery_dining_outlined,
              route: '/courier/panel',
            ),
            const _NavItem(
              label: 'Servicios',
              icon: Icons.route_outlined,
              route: '/courier/services',
            ),
            _NavItem(
              label: l10n.t('profile'),
              icon: Icons.person_outline,
              route: '/profile',
            ),
          ]
        : session.isSupport
        ? <_NavItem>[
            const _NavItem(
              label: 'Incidencias',
              icon: Icons.support_agent_outlined,
              route: '/support/incidents',
            ),
            _NavItem(
              label: l10n.t('profile'),
              icon: Icons.person_outline,
              route: '/profile',
            ),
          ]
        : <_NavItem>[
            _NavItem(
              label: l10n.t('discover'),
              icon: Icons.map_outlined,
              route: '/discovery',
            ),
            _NavItem(
              label: l10n.t('reservations'),
              icon: Icons.luggage_outlined,
              route: '/reservations',
            ),
            _NavItem(
              label: l10n.t('profile'),
              icon: Icons.person_outline,
              route: '/profile',
            ),
            if (session.isAdmin)
              _NavItem(
                label: l10n.t('admin'),
                icon: Icons.admin_panel_settings_outlined,
                route: '/admin/dashboard',
              ),
            if (!session.isAdmin && session.canAccessAdmin)
              const _NavItem(
                label: 'Operaciones',
                icon: Icons.point_of_sale_outlined,
                route: '/operator/panel',
              ),
          ];

    final routeForSelection = currentRoute.startsWith('/ops')
        ? session.isCourier
              ? '/courier/services'
              : session.isAdmin
              ? '/admin/dashboard'
              : session.canAccessAdmin
              ? '/operator/panel'
              : currentRoute
        : currentRoute.startsWith('/support')
        ? '/support/incidents'
        : currentRoute;

    final selectedIndex = navItems.indexWhere(
      (item) =>
          routeForSelection.startsWith(item.route) ||
          (item.route == '/admin/dashboard' &&
              routeForSelection.startsWith('/admin')) ||
          (item.route == '/operator/panel' &&
              routeForSelection.startsWith('/operator')) ||
          (item.route == '/support/incidents' &&
              routeForSelection.startsWith('/support')) ||
          (item.route == '/courier/panel' &&
              routeForSelection.startsWith('/courier')) ||
          (item.route == '/courier/services' &&
              routeForSelection.startsWith('/courier')),
    );
    final navBarBaseHeight = responsive.navBarBaseHeight();
    final mobileBottomInset = responsive.shellBottomPadding(
      safeBottom: safeBottomInset,
      navHeight: navBarBaseHeight,
    );
    final body = SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: mobileBottomInset),
        child: child,
      ),
    );

    if (responsive.useDesktopShell) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: scaffoldBackground,
        appBar: AppBar(
          title: _ShellAppBarTitle(title: title),
          actions: appBarActions,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        floatingActionButton: floatingActionButton,
        body: Container(
          decoration: BoxDecoration(gradient: shellGradient),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 92, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF3C50E0),
                            Color(0xFF465FFF),
                            Color(0xFF2E3DB8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: NavigationRail(
                        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                        onDestinationSelected: (index) {
                          context.go(navItems[index].route);
                        },
                        leading: const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 12),
                          child: _SidebarBrandIcon(),
                        ),
                        labelType: NavigationRailLabelType.none,
                        groupAlignment: -0.85,
                        backgroundColor: Colors.transparent,
                        indicatorColor: Colors.white.withValues(alpha: 0.14),
                        selectedIconTheme: const IconThemeData(
                          color: Colors.white,
                        ),
                        unselectedIconTheme: IconThemeData(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                        destinations: navItems
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.icon),
                                label: Text(item.label),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: panelBorderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.22 : 0.04,
                              ),
                              blurRadius: isDark ? 20 : 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: body,
                        ),
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

    return Scaffold(
      extendBody: true,
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: _ShellAppBarTitle(title: title),
        actions: appBarActions,
      ),
      floatingActionButton: null,
      body: body,
      bottomNavigationBar: keyboardVisible
          ? null
          : _MobileFloatingNavBar(
              items: navItems,
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              baseHeight: navBarBaseHeight,
              centerAction: floatingActionButton,
              onSelect: (index) => context.go(navItems[index].route),
              onCenterPressed: () => context.go(_resolveMobileCenterRoute()),
            ),
    );
  }
}

String? _resolveNotificationRoute(AppNotification notification) {
  final route = notification.route?.trim();
  if (route == null || route.isEmpty) {
    return null;
  }
  if (!route.startsWith('/')) {
    return '/$route';
  }
  return route;
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

String _resolveMobileCenterRoute() {
  return '/qr-scan';
}

class _MobileFloatingNavBar extends StatelessWidget {
  const _MobileFloatingNavBar({
    required this.items,
    required this.selectedIndex,
    required this.baseHeight,
    required this.onSelect,
    required this.onCenterPressed,
    this.centerAction,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final double baseHeight;
  final ValueChanged<int> onSelect;
  final VoidCallback onCenterPressed;
  final Widget? centerAction;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final responsive = context.responsive;
    final leftCount = (items.length / 2).floor();
    final leftItems = items.take(leftCount).toList();
    final rightItems = items.skip(leftCount).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackgroundColor = isDark ? const Color(0xFF111827) : Colors.white;
    final horizontalInset = responsive.horizontalPadding;
    final totalHeight = baseHeight + safeBottom + 8;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: horizontalInset,
            right: horizontalInset,
            bottom: 8 + safeBottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: navBackgroundColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF273449)
                      : TravelBoxBrand.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: leftItems
                            .asMap()
                            .entries
                            .map(
                              (entry) => _MobileNavItemButton(
                                item: entry.value,
                                selected: selectedIndex == entry.key,
                                onTap: () => onSelect(entry.key),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 72),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: rightItems.asMap().entries.map((entry) {
                          final absoluteIndex = leftCount + entry.key;
                          return _MobileNavItemButton(
                            item: entry.value,
                            selected: selectedIndex == absoluteIndex,
                            onTap: () => onSelect(absoluteIndex),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -4,
            child: GestureDetector(
              onTap: onCenterPressed,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: TravelBoxBrand.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2A89F8).withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child:
                    centerAction ??
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileNavItemButton extends StatelessWidget {
  const _MobileNavItemButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = selected
        ? TravelBoxBrand.primaryBlue
        : (isDark ? const Color(0xFF9BA7BD) : const Color(0xFF8B93A7));
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: iconColor),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 16 : 6,
            height: 4,
            decoration: BoxDecoration(
              color: selected ? TravelBoxBrand.primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellAppBarTitle extends StatelessWidget {
  const _ShellAppBarTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = screenWidth >= 760;
        final availableWidth = constraints.maxWidth;
        final showWordmark = screenWidth >= 392 && availableWidth >= 146;
        final showPageTitle = isWide && availableWidth >= 330;

        return Row(
          children: [
            TravelBoxLogo(
              compact: true,
              showSubtitle: false,
              showWordmark: showWordmark,
            ),
            if (showPageTitle) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = unreadCount > 99 ? '99+' : '$unreadCount';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: l10n.t('notifications'),
            onPressed: onPressed,
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsComboMenu extends ConsumerWidget {
  const _SettingsComboMenu();

  static const _items = <MapEntry<String, String>>[
    MapEntry('es', 'ES'),
    MapEntry('en', 'EN'),
    MapEntry('pt', 'PT'),
    MapEntry('fr', 'FR'),
    MapEntry('de', 'DE'),
    MapEntry('it', 'IT'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentLocaleCode = session.locale.languageCode.toLowerCase();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Opciones',
      onSelected: (value) {
        if (value == 'theme') {
          ref.read(themeModeControllerProvider.notifier).toggle();
        } else {
          ref.read(sessionControllerProvider.notifier).setLocale(Locale(value));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'theme',
          child: Row(
            children: [
              Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(isDark ? l10n.t('light_mode') : l10n.t('dark_mode')),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ..._items.map(
          (entry) => PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  currentLocaleCode == entry.key
                      ? Icons.check_circle
                      : Icons.language,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(entry.value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarBrandIcon extends StatelessWidget {
  const _SidebarBrandIcon();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'TravelBox',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.luggage_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}
