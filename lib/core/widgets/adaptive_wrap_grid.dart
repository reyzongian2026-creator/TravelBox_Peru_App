import 'package:flutter/widgets.dart';

import '../layout/responsive_layout.dart';

/// Adaptive grid based on current responsive tier and available width.
///
/// It keeps a single source of truth for "mobile/tablet/desktop" wrapping
/// without hardcoding fixed widths in each screen.
class AdaptiveWrapGrid extends StatelessWidget {
  const AdaptiveWrapGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopSmallColumns = 3,
    this.desktopColumns = 4,
    this.minItemWidth,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopSmallColumns;
  final int desktopColumns;
  final double? minItemWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final responsive = context.responsive;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || constraints.maxWidth <= 0) {
          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: children,
          );
        }

        var columns = responsive
            .gridColumns(
              mobile: mobileColumns,
              tablet: tabletColumns,
              desktopSmall: desktopSmallColumns,
              desktop: desktopColumns,
            )
            .clamp(1, children.length);

        if (minItemWidth != null && minItemWidth! > 0) {
          final fitByWidth =
              ((constraints.maxWidth + spacing) / (minItemWidth! + spacing))
                  .floor();
          columns = columns.clamp(1, fitByWidth < 1 ? 1 : fitByWidth);
        }

        final totalSpacing = spacing * (columns - 1);
        final itemWidth = ((constraints.maxWidth - totalSpacing) / columns)
            .clamp(0.0, constraints.maxWidth)
            .toDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
