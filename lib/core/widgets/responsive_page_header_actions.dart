import 'package:flutter/material.dart';

import '../layout/responsive_layout.dart';

class ResponsiveHeaderAction {
  const ResponsiveHeaderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.prominentOnTablet = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool prominentOnTablet;
  final bool enabled;
}

class ResponsivePageHeaderActions extends StatelessWidget {
  const ResponsivePageHeaderActions({
    super.key,
    required this.actions,
    this.mobileVisibleCount = 1,
    this.tabletVisibleCount = 2,
  });

  final List<ResponsiveHeaderAction> actions;
  final int mobileVisibleCount;
  final int tabletVisibleCount;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final enabledActions = actions.where((action) => action.enabled).toList();
    if (enabledActions.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!responsive.isMobile && !responsive.isTablet) {
      return Wrap(
        spacing: responsive.itemGap,
        runSpacing: responsive.itemGap,
        children: enabledActions.map((action) => _buildButton(context, action)).toList(),
      );
    }

    final visibleCount = responsive.isMobile ? mobileVisibleCount : tabletVisibleCount;
    final primary = enabledActions.where((action) => action.primary).toList();
    final secondary = enabledActions.where((action) => !action.primary).toList();
    final ordered = [...primary, ...secondary];
    final visible = ordered.take(visibleCount).toList();
    final overflow = ordered.skip(visible.length).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: responsive.itemGap,
          runSpacing: responsive.itemGap,
          children: [
            ...visible.map(
              (action) => SizedBox(
                width: responsive.isMobile ? double.infinity : null,
                child: _buildButton(context, action),
              ),
            ),
            if (overflow.isNotEmpty)
              SizedBox(
                width: responsive.isMobile ? double.infinity : null,
                child: OutlinedButton.icon(
                  onPressed: () => _openOverflowSheet(context, overflow),
                  icon: const Icon(Icons.more_horiz_rounded),
                  label: const Text('Más acciones'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildButton(BuildContext context, ResponsiveHeaderAction action) {
    final buttonChild = action.primary
        ? FilledButton.icon(
            onPressed: action.onPressed,
            icon: Icon(action.icon),
            label: Text(action.label),
          )
        : OutlinedButton.icon(
            onPressed: action.onPressed,
            icon: Icon(action.icon),
            label: Text(action.label),
          );
    return buttonChild;
  }

  Future<void> _openOverflowSheet(
    BuildContext context,
    List<ResponsiveHeaderAction> overflow,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: overflow.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final action = overflow[index];
            return ListTile(
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: action.onPressed == null
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      action.onPressed?.call();
                    },
            );
          },
        );
      },
    );
  }
}
