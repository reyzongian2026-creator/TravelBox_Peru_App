import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/domain/app_notification.dart';
import '../../shared/state/currency_preference.dart';
import '../../shared/state/notification_center_controller.dart';
import '../../shared/state/session_controller.dart';
import '../../shared/state/theme_mode_controller.dart';
import '../../shared/widgets/app_smart_image.dart';
import '../../shared/widgets/operation_guide.dart';
import '../../shared/widgets/travelbox_logo.dart';
import '../layout/responsive_layout.dart';
import '../l10n/app_localizations_fixed.dart';
import '../theme/brand_tokens.dart';
import 'app_shell_navigation.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarCollapsed = false;
  OverlayEntry? _notificationToastEntry;

  @override
  void dispose() {
    _notificationToastEntry?.remove();
    _notificationToastEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider);
    final notificationsState = ref.watch(notificationCenterControllerProvider);
    final responsive = context.responsive;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellSections = buildShellSections(session, l10n);
    final activeItem = findActiveShellItem(widget.currentRoute, shellSections);
    final localizedTitle = _localizeShellTitle(widget.title, l10n);
    final operationGuide = session.locale.languageCode.toLowerCase() == 'es'
        ? resolveOperationGuide(widget.currentRoute)
        : null;

    ref.listen<List<AppNotification>>(
      notificationCenterControllerProvider.select((state) => state.popupQueue),
      (_, nextQueue) {
        if (nextQueue.isEmpty) return;
        final next = nextQueue.first;
        final notificationsController = ref.read(
          notificationCenterControllerProvider.notifier,
        );

        if (widget.currentRoute.startsWith('/notifications')) {
          notificationsController.consumePopup(next.id);
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          notificationsController.consumePopup(next.id);
          final targetRoute = _resolveNotificationRoute(next);
          _showTopRightNotificationToast(
            context: context,
            title: next.title,
            message: next.message,
            actionLabel: l10n.t('view'),
            onTap: () {
              if (!context.mounted) return;
              if (targetRoute != null) {
                if (widget.currentRoute == targetRoute ||
                    widget.currentRoute.startsWith('$targetRoute/')) {
                  return;
                }
                context.push(targetRoute);
                return;
              }
              if (!widget.currentRoute.startsWith('/notifications')) {
                context.push('/notifications');
              }
            },
          );
        });
      },
    );

    final headerActions = <Widget>[
      if (operationGuide != null)
        _HeaderCircleButton(
          tooltip: l10n.t('flow_guide'),
          icon: Icons.help_outline_rounded,
          onPressed: () =>
              showOperationGuideSheet(context, guide: operationGuide),
        ),
      if (session.isAuthenticated)
        _NotificationBellButton(
          unreadCount: notificationsState.unreadCount,
          onPressed: () {
            if (widget.currentRoute.startsWith('/notifications')) return;
            context.push('/notifications');
          },
        ),
      const _SettingsComboMenu(),
      ...widget.actions,
      if (session.user != null)
        _HeaderProfileChip(
          userName: session.user!.name,
          profilePhotoPath: session.user!.profilePhotoPath,
        ),
    ];

    final mobileHeaderActions = <Widget>[
      if (session.isAuthenticated)
        _NotificationBellButton(
          unreadCount: notificationsState.unreadCount,
          onPressed: () {
            if (widget.currentRoute.startsWith('/notifications')) return;
            context.push('/notifications');
          },
        ),
      ...widget.actions,
      _SettingsComboMenu(compact: true),
      if (session.user != null)
        _HeaderProfileChip(
          userName: session.user!.name,
          profilePhotoPath: session.user!.profilePhotoPath,
          compact: true,
        ),
    ];

    final content = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11182D) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF25304D) : TravelBoxBrand.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: widget.child,
      ),
    );

    final backgroundGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172C), Color(0xFF111A31), Color(0xFF151D36)],
          )
        : TravelBoxBrand.shellGradient;

    if (responsive.useDesktopShell) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDark
            ? TravelBoxBrand.darkBackground
            : TravelBoxBrand.surface,
        floatingActionButton: widget.floatingActionButton,
        body: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopSidebar(
                        collapsed: _sidebarCollapsed,
                        sections: shellSections,
                        activeRoute: widget.currentRoute,
                        onToggleCollapse: () {
                          setState(
                            () => _sidebarCollapsed = !_sidebarCollapsed,
                          );
                        },
                        onNavigate: (route) => context.go(route),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            _DesktopShellHeader(
                              title: localizedTitle,
                              activeLabel: activeItem?.label,
                              onOpenMenu: () {
                                setState(() {
                                  _sidebarCollapsed = !_sidebarCollapsed;
                                });
                              },
                              actions: headerActions,
                            ),
                            const SizedBox(height: 18),
                            Expanded(child: content),
                          ],
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark
          ? TravelBoxBrand.darkBackground
          : TravelBoxBrand.surface,
      drawer: _MobileShellDrawer(
        sections: shellSections,
        activeRoute: widget.currentRoute,
        onNavigate: (route) {
          Navigator.of(context).pop();
          context.go(route);
        },
      ),
      appBar: AppBar(
        titleSpacing: 0,
        title: _ShellCompactTitle(
          title: localizedTitle,
          compact: responsive.isMobile,
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: responsive.isMobile ? mobileHeaderActions : headerActions,
      ),
      floatingActionButton: widget.floatingActionButton,
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: responsive.pageInsets(
              top: 10,
              bottom: responsive.sectionGap,
            ),
            child: content,
          ),
        ),
      ),
    );
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

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.collapsed,
    required this.sections,
    required this.activeRoute,
    required this.onToggleCollapse,
    required this.onNavigate,
  });

  final bool collapsed;
  final List<ShellNavSection> sections;
  final String activeRoute;
  final VoidCallback onToggleCollapse;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = collapsed ? 104.0 : 286.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? TravelBoxBrand.darkSidebar : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF25304D) : TravelBoxBrand.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 14 : 18, 18, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: TravelBoxLogo(
                    compact: collapsed,
                    showSubtitle: false,
                    showWordmark: !collapsed,
                  ),
                ),
                IconButton(
                  onPressed: onToggleCollapse,
                  tooltip: collapsed ? 'Expandir' : 'Contraer',
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_right_rounded
                        : Icons.keyboard_double_arrow_left_rounded,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
              children: sections
                  .map(
                    (section) => _SidebarSection(
                      section: section,
                      activeRoute: activeRoute,
                      collapsed: collapsed,
                      onNavigate: onNavigate,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({
    required this.section,
    required this.activeRoute,
    required this.collapsed,
    required this.onNavigate,
  });

  final ShellNavSection section;
  final String activeRoute;
  final bool collapsed;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                section.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark
                      ? const Color(0xFF7D8CA8)
                      : TravelBoxBrand.textMuted,
                ),
              ),
            ),
          ...section.items.map(
            (item) => _SidebarItemTile(
              item: item,
              selected: item.matches(activeRoute),
              collapsed: collapsed,
              onTap: () => onNavigate(item.route),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemTile extends StatelessWidget {
  const _SidebarItemTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final ShellNavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = selected
        ? (isDark ? const Color(0xFF23345A) : const Color(0xFFE9F0FF))
        : Colors.transparent;
    final iconColor = selected
        ? TravelBoxBrand.primaryBlue
        : (isDark ? const Color(0xFFA8B5D1) : const Color(0xFF7F8AA3));
    final textColor = selected
        ? (isDark ? Colors.white : TravelBoxBrand.ink)
        : (isDark ? const Color(0xFFD6DEEF) : TravelBoxBrand.textBody);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: collapsed
                ? Center(child: Icon(item.icon, color: iconColor))
                : Row(
                    children: [
                      Icon(item.icon, color: iconColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: TravelBoxBrand.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _MobileShellDrawer extends StatelessWidget {
  const _MobileShellDrawer({
    required this.sections,
    required this.activeRoute,
    required this.onNavigate,
  });

  final List<ShellNavSection> sections;
  final String activeRoute;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? TravelBoxBrand.darkSidebar : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TravelBoxLogo(
                  compact: false,
                  showSubtitle: true,
                  darkBackground: isDark,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: sections
                    .map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              child: Text(
                                section.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: isDark
                                      ? const Color(0xFF7D8CA8)
                                      : TravelBoxBrand.textMuted,
                                ),
                              ),
                            ),
                            ...section.items.map(
                              (item) => _SidebarItemTile(
                                item: item,
                                selected: item.matches(activeRoute),
                                collapsed: false,
                                onTap: () => onNavigate(item.route),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopShellHeader extends StatelessWidget {
  const _DesktopShellHeader({
    required this.title,
    required this.activeLabel,
    required this.onOpenMenu,
    required this.actions,
  });

  final String title;
  final String? activeLabel;
  final VoidCallback onOpenMenu;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11182D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF25304D) : TravelBoxBrand.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _HeaderCircleButton(
            tooltip: 'Menú',
            icon: Icons.menu_rounded,
            onPressed: onOpenMenu,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (activeLabel != null)
                  Text(
                    activeLabel!,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ...actions,
        ],
      ),
    );
  }
}

class _ShellCompactTitle extends StatelessWidget {
  const _ShellCompactTitle({required this.title, this.compact = false});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    if (compact) {
      return Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: responsive.adaptiveFont(
            mobileSmall: 18,
            mobile: 20,
            tablet: 20,
            desktopSmall: 20,
            desktop: 20,
          ),
        ),
      );
    }
    return Row(
      children: [
        const Expanded(
          child: TravelBoxLogo(compact: true, showSubtitle: false),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2642) : const Color(0xFFF3F6FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2B3A61) : TravelBoxBrand.border,
            ),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HeaderCircleButton(
          tooltip: l10n.t('notifications'),
          icon: Icons.notifications_none_rounded,
          onPressed: onPressed,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFED4C5C),
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderProfileChip extends StatelessWidget {
  const _HeaderProfileChip({
    required this.userName,
    this.profilePhotoPath,
    this.compact = false,
  });

  final String userName;
  final String? profilePhotoPath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = userName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part.trim().substring(0, 1).toUpperCase())
        .join();
    if (compact) {
      return Container(
        margin: const EdgeInsets.only(left: 4, right: 4),
        child: _HeaderAvatar(
          initials: initials,
          profilePhotoPath: profilePhotoPath,
          radius: 18,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111F3A) : const Color(0xFFF6F8FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3A61) : TravelBoxBrand.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderAvatar(
            initials: initials,
            profilePhotoPath: profilePhotoPath,
            radius: 16,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              userName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.initials,
    required this.profilePhotoPath,
    required this.radius,
  });

  final String initials;
  final String? profilePhotoPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = profilePhotoPath?.trim();
    if (photo != null && photo.isNotEmpty) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.72),
            width: 1.2,
          ),
        ),
        child: ClipOval(
          child: AppSmartImage(
            source: photo,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            fallback: _InitialsAvatar(initials: initials, radius: radius),
          ),
        ),
      );
    }
    return _InitialsAvatar(initials: initials, radius: radius);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.radius});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: TravelBoxBrand.primaryBlue,
      child: Text(
        initials.isEmpty ? 'I' : initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius <= 16 ? 12 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingsComboMenu extends ConsumerWidget {
  const _SettingsComboMenu({this.compact = false});

  static const _items = <MapEntry<String, String>>[
    MapEntry('es', 'ES'),
    MapEntry('en', 'EN'),
  ];

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final themeMode = ref.watch(themeModeControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final userCurrency = ref.watch(currencyPreferenceProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentLocaleCode = session.locale.languageCode.toLowerCase();

    return PopupMenuButton<String>(
      tooltip: l10n.t('settings_options'),
      icon: Icon(compact ? Icons.more_horiz_rounded : Icons.tune_rounded),
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
    default:
      return rawTitle;
  }
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
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14213D).withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(16),
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
                            color: Color(0xFF9CC2FF),
                            fontWeight: FontWeight.w700,
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
