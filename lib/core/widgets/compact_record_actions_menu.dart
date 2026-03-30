import 'package:flutter/material.dart';

import '../layout/responsive_layout.dart';

class CompactRecordAction {
  const CompactRecordAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
}

class CompactRecordActionsMenu extends StatelessWidget {
  const CompactRecordActionsMenu({
    super.key,
    required this.primaryAction,
    required this.secondaryActions,
  });

  final CompactRecordAction primaryAction;
  final List<CompactRecordAction> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final hasSecondary = secondaryActions.any((action) => action.onPressed != null);
    if (!responsive.isMobile && !responsive.isTablet) {
      return Wrap(
        spacing: responsive.itemGap,
        runSpacing: responsive.itemGap,
        children: [
          OutlinedButton.icon(
            onPressed: primaryAction.onPressed,
            icon: Icon(primaryAction.icon),
            label: Text(primaryAction.label),
          ),
          ...secondaryActions.map(
            (action) => OutlinedButton.icon(
              onPressed: action.onPressed,
              icon: Icon(action.icon),
              label: Text(action.label),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: primaryAction.onPressed,
            icon: Icon(primaryAction.icon),
            label: Text(primaryAction.label),
          ),
        ),
        if (hasSecondary) ...[
          const SizedBox(width: 8),
          PopupMenuButton<int>(
            tooltip: 'Más acciones',
            itemBuilder: (context) => [
              for (var i = 0; i < secondaryActions.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      Icon(
                        secondaryActions[i].icon,
                        color: secondaryActions[i].destructive
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          secondaryActions[i].label,
                          style: secondaryActions[i].destructive
                              ? TextStyle(color: Theme.of(context).colorScheme.error)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onSelected: (index) => secondaryActions[index].onPressed?.call(),
            child: const SizedBox(
              height: 44,
              width: 44,
              child: Icon(Icons.more_horiz_rounded),
            ),
          ),
        ],
      ],
    );
  }
}
