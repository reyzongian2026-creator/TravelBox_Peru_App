import 'package:flutter/material.dart';

import '../layout/responsive_layout.dart';

class ResponsivePaginationBar extends StatelessWidget {
  const ResponsivePaginationBar({
    super.key,
    required this.pageLabel,
    required this.totalLabel,
    required this.canGoFirst,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.canGoLast,
    this.onFirst,
    this.onPrevious,
    this.onNext,
    this.onLast,
    this.trailing,
  });

  final String pageLabel;
  final String totalLabel;
  final bool canGoFirst;
  final bool canGoPrevious;
  final bool canGoNext;
  final bool canGoLast;
  final VoidCallback? onFirst;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onLast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final controls = Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          onPressed: canGoFirst ? onFirst : null,
          icon: const Icon(Icons.first_page),
          tooltip: 'Primera página',
        ),
        IconButton(
          onPressed: canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Página anterior',
        ),
        Text(
          pageLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Página siguiente',
        ),
        IconButton(
          onPressed: canGoLast ? onLast : null,
          icon: const Icon(Icons.last_page),
          tooltip: 'Última página',
        ),
      ],
    );

    if (responsive.isMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            controls,
            const SizedBox(height: 6),
            Text(totalLabel, textAlign: TextAlign.center),
            if (trailing != null) ...[
              const SizedBox(height: 8),
              trailing!,
            ],
          ],
        ),
      );
    }

    if (responsive.isTablet) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            controls,
            Text(totalLabel),
            if (trailing != null) ...[trailing!],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          controls,
          const SizedBox(width: 16),
          Text(totalLabel),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
