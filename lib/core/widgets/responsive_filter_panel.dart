import 'package:flutter/material.dart';

import '../layout/responsive_layout.dart';
import '../theme/brand_tokens.dart';

class ResponsiveFilterPanel extends StatelessWidget {
  const ResponsiveFilterPanel({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding:
          padding ??
          EdgeInsets.all(
            responsive.isMobile ? responsive.cardPadding : responsive.cardPadding + 2,
          ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11182D) : Colors.white,
        borderRadius: BorderRadius.circular(responsive.isMobile ? 24 : 28),
        border: Border.all(
          color: isDark ? const Color(0xFF25304D) : TravelBoxBrand.border,
        ),
      ),
      child: child,
    );
  }
}
