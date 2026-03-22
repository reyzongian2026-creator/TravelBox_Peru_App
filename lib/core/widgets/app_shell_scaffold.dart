import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/state/currency_preference.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/domain/app_notification.dart';
import '../../shared/state/notification_center_controller.dart';
import '../../shared/state/session_controller.dart';
import '../../shared/state/theme_mode_controller.dart';
import '../../shared/widgets/operation_guide.dart';
import '../../shared/widgets/travelbox_logo.dart';
import '../layout/mobile_nav_behavior.dart';
import '../layout/responsive_layout.dart';
import '../l10n/app_localizations.dart';
import '../theme/brand_tokens.dart';

class AppShellScaffold extends ConsumerStatefulWidget {
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
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  late final MobileNavBehaviorController _mobileNavBehavior;
  bool _preventAutoHideFromInput = false;
  int? _activePointerId;
  double? _lastPointerDy;
  OverlayEntry? _notificationToastEntry;

  @override
  void initState() {
    super.initState();
    _mobileNavBehavior = MobileNavBehaviorController();
    _mobileNavBehavior.addListener(_onMobileNavBehaviorChanged);
  }

  @override
  void didUpdateWidget(covariant AppShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      _mobileNavBehavior.reset();
    }
  }

  @override
  void dispose() {
    _notificationToastEntry?.remove();
    _notificationToastEntry = null;
    _mobileNavBehavior.removeListener(_onMobileNavBehaviorChanged);
    _mobileNavBehavior.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localizedTitle = _localizeShellTitle(widget.title, l10n);
    final session = ref.watch(sessionControllerProvider);
    final notificationsState = ref.watch(notificationCenterControllerProvider);
    final mediaQuery = MediaQuery.of(context);
    final responsive = context.responsive;
    final screenWidth = mediaQuery.size.width;
    final safeBottomInset = mediaQuery.padding.bottom;
    final compactTopBar = screenWidth < 390;
    final inputLocked = _isKeyboardOrInputVisible(mediaQuery);
    final operationGuide = session.locale.languageCode.toLowerCase() == 'es'
        ? resolveOperationGuide(currentRoute)
        : null;
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
          final targetRoute = _resolveNotificationRoute(next);
          if (kIsWeb) {
            _showTopRightNotificationToast(
              context: context,
              title: next.title,
              message: next.message,
              actionLabel: l10n.t('view'),
              onTap: () {
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
            );
            return;
          }
          messenger.hideCurrentSnackBar();
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
      ...widget.actions,
    ];

    final navItems = session.isCourier
        ? <_NavItem>[
            _NavItem(
              label: l10n.t('role_courier'),
              icon: Icons.delivery_dining_outlined,
              route: '/courier/panel',
            ),
            _NavItem(
              label: l10n.t('services'),
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
            _NavItem(
              label: l10n.t('incidencias'),
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
                label: l10n.t('role_admin'),
                icon: Icons.admin_panel_settings_outlined,
                route: '/admin/dashboard',
              ),
            if (!session.isAdmin && session.canAccessAdmin)
              _NavItem(
                label: l10n.t('operations_panel'),
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
    _preventAutoHideFromInput = inputLocked;
    final navVisible =
        inputLocked ||
        !_mobileNavBehavior.canAutoHide ||
        _mobileNavBehavior.isVisible;
    final mobileBottomInset = responsive.useDesktopShell
        ? safeBottomInset
        : _MobileFloatingNavBar.visibleContentInset(
            safeBottom: safeBottomInset,
            baseHeight: navBarBaseHeight,
          );
    final body = SafeArea(
      top: false,
      bottom: false,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerDone,
        onPointerCancel: _handlePointerDone,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _mobileNavBehavior.handleScrollNotification(
              notification,
              preventAutoHide: inputLocked,
            );
            return false;
          },
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: mobileBottomInset),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minHeight = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : mediaQuery.size.height;
                return ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: widget.child,
                );
              },
            ),
          ),
        ),
      ),
    );

    if (responsive.useDesktopShell) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: scaffoldBackground,
        appBar: AppBar(
          title: _ShellAppBarTitle(title: localizedTitle),
          actions: appBarActions,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        floatingActionButton: widget.floatingActionButton,
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
        title: _ShellAppBarTitle(title: localizedTitle),
        actions: appBarActions,
      ),
      floatingActionButton: null,
      body: body,
      bottomNavigationBar: _MobileFloatingNavBar(
        items: navItems,
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        baseHeight: navBarBaseHeight,
        centerAction: widget.floatingActionButton,
        isVisible: navVisible,
        autoHideEnabled: _mobileNavBehavior.canAutoHide && !inputLocked,
        onSelect: (index) => context.go(navItems[index].route),
        onCenterPressed: () => context.go(_resolveMobileCenterRoute()),
      ),
    );
  }

  String get currentRoute => widget.currentRoute;

  bool _isKeyboardOrInputVisible(MediaQueryData mediaQuery) {
    if (mediaQuery.viewInsets.bottom > 0) {
      return true;
    }
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || !primaryFocus.hasFocus) {
      return false;
    }
    final focusedContext = primaryFocus.context;
    if (focusedContext == null || !focusedContext.mounted) {
      return false;
    }
    final focusedWidget = focusedContext.widget;
    if (focusedWidget is! EditableText) {
      return false;
    }
    // On web, keeping nav forced-visible for any focused editable produces
    // false positives because hidden editable hosts can retain focus.
    if (kIsWeb) {
      return mediaQuery.viewInsets.bottom > 0;
    }
    return true;
  }

  void _onMobileNavBehaviorChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    _mobileNavBehavior.handlePointerDelta(
      delta: event.scrollDelta.dy,
      preventAutoHide: _preventAutoHideFromInput,
      scrollableHint: true,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointerId = event.pointer;
    _lastPointerDy = event.position.dy;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointerId != event.pointer || _lastPointerDy == null) {
      return;
    }
    final dy = event.position.dy - _lastPointerDy!;
    _lastPointerDy = event.position.dy;
    if (dy.abs() < 0.6) {
      return;
    }
    _mobileNavBehavior.handlePointerDelta(
      delta: -dy,
      preventAutoHide: _preventAutoHideFromInput,
      scrollableHint: true,
    );
  }

  void _handlePointerDone(PointerEvent event) {
    if (_activePointerId != event.pointer) {
      return;
    }
    _activePointerId = null;
    _lastPointerDy = null;
  }

  void _showTopRightNotificationToast({
    required BuildContext context,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    _notificationToastEntry?.remove();
    _notificationToastEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    final topInset = MediaQuery.of(context).padding.top;
    final entry = OverlayEntry(
      builder: (overlayContext) => _TopRightNotificationToast(
        title: title,
        message: message,
        actionLabel: actionLabel,
        topInset: topInset,
        onTap: onTap,
        onDismissed: () {
          _notificationToastEntry?.remove();
          _notificationToastEntry = null;
        },
      ),
    );
    _notificationToastEntry = entry;
    overlay.insert(entry);
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

class _TopRightNotificationToast extends StatefulWidget {
  const _TopRightNotificationToast({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.topInset,
    required this.onTap,
    required this.onDismissed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final double topInset;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  State<_TopRightNotificationToast> createState() =>
      _TopRightNotificationToastState();
}

class _TopRightNotificationToastState extends State<_TopRightNotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (!mounted) {
        return;
      }
      await _controller.reverse();
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topInset + 12,
      right: 16,
      child: IgnorePointer(
        ignoring: false,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.white),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.actionLabel,
                          style: const TextStyle(
                            color: Color(0xFF7DD3FC),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _resolveMobileCenterRoute() {
  return '/qr-scan';
}

class _MobileFloatingNavBar extends StatelessWidget {
  const _MobileFloatingNavBar({
    required this.items,
    required this.selectedIndex,
    required this.baseHeight,
    required this.isVisible,
    required this.autoHideEnabled,
    required this.onSelect,
    required this.onCenterPressed,
    this.centerAction,
  });

  static const double _dockBottomInset = 8;
  static const double _hiddenPeekInset = 8;
  static const double _contentInsetBuffer = 28;
  static const double _centerButtonSize = 56;
  static const double _centerButtonTopOffset = -2;

  static double visibleContentInset({
    required double safeBottom,
    required double baseHeight,
  }) {
    return baseHeight + safeBottom + _dockBottomInset + _contentInsetBuffer;
  }

  static double hiddenContentInset({required double safeBottom}) {
    return safeBottom + _hiddenPeekInset;
  }

  final List<_NavItem> items;
  final int selectedIndex;
  final double baseHeight;
  final bool isVisible;
  final bool autoHideEnabled;
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
    final showNav = isVisible || !autoHideEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackgroundColor = isDark ? const Color(0xFF111827) : Colors.white;
    final horizontalInset = responsive.horizontalPadding;
    final expandedHeight = baseHeight + safeBottom + _dockBottomInset;
    final collapsedHeight = hiddenContentInset(safeBottom: safeBottom);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: showNav ? expandedHeight : collapsedHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
          ignoring: !showNav,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 210),
            curve: Curves.easeOutCubic,
            offset: showNav ? Offset.zero : const Offset(0, 1.15),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              opacity: showNav ? 1 : 0,
              child: SizedBox(
                height: expandedHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      left: horizontalInset,
                      right: horizontalInset,
                      bottom: _dockBottomInset + safeBottom,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: navBackgroundColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF273449)
                                : TravelBoxBrand.border,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.28 : 0.10,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
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
                              const SizedBox(width: 64),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: rightItems.asMap().entries.map((
                                    entry,
                                  ) {
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
                      top: _centerButtonTopOffset,
                      child: GestureDetector(
                        onTap: onCenterPressed,
                        child: Container(
                          width: _centerButtonSize,
                          height: _centerButtonSize,
                          decoration: BoxDecoration(
                            gradient: TravelBoxBrand.brandGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF2A89F8,
                                ).withValues(alpha: 0.42),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child:
                              centerAction ??
                              const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    final userCurrency = ref.watch(currencyPreferenceProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentLocaleCode = session.locale.languageCode.toLowerCase();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.t('settings_options'),
      onSelected: (value) {
        if (value == 'theme') {
          ref.read(themeModeControllerProvider.notifier).toggle();
        } else if (value.startsWith('currency_')) {
          final currencyCode = value.replaceFirst('currency_', '');
          final currency = CurrencyCode.values.firstWhere(
            (c) => c.code == currencyCode,
            orElse: () => CurrencyCode.pen,
          );
          ref.read(currencyPreferenceProvider.notifier).setCurrency(currency);
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
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              const Icon(Icons.attach_money, size: 18),
              const SizedBox(width: 8),
              Text(l10n.t('currency')),
            ],
          ),
        ),
        ...CurrencyCode.values.map(
          (currency) => PopupMenuItem<String>(
            value: 'currency_${currency.code}',
            child: Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      currency.symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(currency.name),
                  if (currency == userCurrency) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, size: 18),
                  ],
                ],
              ),
            ),
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

String _localizeShellTitle(String rawTitle, AppLocalizations l10n) {
  final normalized = rawTitle.trim().toLowerCase();
  switch (normalized) {
    case 'panel admin':
      return l10n.t('dashboard');
    case 'admin incidencias':
    case 'incidencias operativas':
      return l10n.t('incidencias');
    case 'incidencias de soporte':
      return l10n.t('soporte_e_incidencias');
    case 'tracking logistico':
    case 'tracking courier':
      return l10n.t('tracking_logistico');
    case 'cobros en caja':
      return l10n.t('cobros_en_caja');
    case 'reservas operativas':
    case 'admin reservas':
      return l10n.t('reservas');
    case 'usuarios operativos':
      return l10n.t('users_and_roles');
    case 'perfil':
      return l10n.t('profile');
    default:
      return rawTitle;
  }
}

class _SidebarBrandIcon extends StatelessWidget {
  const _SidebarBrandIcon();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.t('travelbox_tooltip'),
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
