import 'package:flutter/material.dart';

enum ResponsiveTier { mobileSmall, mobile, tablet, desktopSmall, desktop }

class ResponsiveLayout {
  const ResponsiveLayout({
    required this.size,
    required this.safePadding,
    required this.viewInsets,
  });

  final Size size;
  final EdgeInsets safePadding;
  final EdgeInsets viewInsets;

  static ResponsiveLayout of(BuildContext context) {
    final media = MediaQuery.of(context);
    return ResponsiveLayout(
      size: media.size,
      safePadding: media.padding,
      viewInsets: media.viewInsets,
    );
  }

  double get width => size.width;
  double get height => size.height;
  double get shortestSide => size.shortestSide;
  double get longestSide => size.longestSide;
  bool get keyboardVisible => viewInsets.bottom > 0;

  ResponsiveTier get tier {
    if (width <= 360) return ResponsiveTier.mobileSmall;
    if (width <= 480) return ResponsiveTier.mobile;
    if (width <= 768) return ResponsiveTier.tablet;
    if (width <= 1024) return ResponsiveTier.desktopSmall;
    return ResponsiveTier.desktop;
  }

  bool get isMobile =>
      tier == ResponsiveTier.mobileSmall || tier == ResponsiveTier.mobile;
  bool get isTablet => tier == ResponsiveTier.tablet;
  bool get isDesktopLike =>
      tier == ResponsiveTier.desktopSmall || tier == ResponsiveTier.desktop;

  bool get useDesktopShell => width >= 1024;

  double get horizontalPadding {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
        return 12;
      case ResponsiveTier.mobile:
        return 14;
      case ResponsiveTier.tablet:
        return 18;
      case ResponsiveTier.desktopSmall:
        return 20;
      case ResponsiveTier.desktop:
        return 24;
    }
  }

  double get verticalPadding {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
        return 10;
      case ResponsiveTier.mobile:
        return 12;
      case ResponsiveTier.tablet:
        return 14;
      case ResponsiveTier.desktopSmall:
      case ResponsiveTier.desktop:
        return 18;
    }
  }

  double get sectionGap {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
        return 10;
      case ResponsiveTier.mobile:
        return 12;
      case ResponsiveTier.tablet:
        return 14;
      case ResponsiveTier.desktopSmall:
      case ResponsiveTier.desktop:
        return 16;
    }
  }

  double get itemGap {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
      case ResponsiveTier.mobile:
        return 8;
      case ResponsiveTier.tablet:
        return 10;
      case ResponsiveTier.desktopSmall:
      case ResponsiveTier.desktop:
        return 12;
    }
  }

  double get cardPadding {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
        return 12;
      case ResponsiveTier.mobile:
        return 13;
      case ResponsiveTier.tablet:
      case ResponsiveTier.desktopSmall:
      case ResponsiveTier.desktop:
        return 14;
    }
  }

  double get pageMaxWidth {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
      case ResponsiveTier.mobile:
      case ResponsiveTier.tablet:
        return double.infinity;
      case ResponsiveTier.desktopSmall:
        return 1060;
      case ResponsiveTier.desktop:
        return 1240;
    }
  }

  int gridColumns({
    required int mobile,
    required int tablet,
    required int desktopSmall,
    required int desktop,
  }) {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
      case ResponsiveTier.mobile:
        return mobile;
      case ResponsiveTier.tablet:
        return tablet;
      case ResponsiveTier.desktopSmall:
        return desktopSmall;
      case ResponsiveTier.desktop:
        return desktop;
    }
  }

  EdgeInsets pageInsets({double top = 0, double bottom = 0}) {
    return EdgeInsets.fromLTRB(
      horizontalPadding,
      top,
      horizontalPadding,
      bottom,
    );
  }

  double adaptiveFont({
    required double mobileSmall,
    required double mobile,
    required double tablet,
    required double desktopSmall,
    required double desktop,
  }) {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
        return mobileSmall;
      case ResponsiveTier.mobile:
        return mobile;
      case ResponsiveTier.tablet:
        return tablet;
      case ResponsiveTier.desktopSmall:
        return desktopSmall;
      case ResponsiveTier.desktop:
        return desktop;
    }
  }

  double mapHeight({double max = 560}) {
    final base = adaptiveFont(
      mobileSmall: 320,
      mobile: 350,
      tablet: 400,
      desktopSmall: 420,
      desktop: 460,
    );
    final dynamicByHeight = (height * 0.58).clamp(300, max);
    return base > dynamicByHeight ? base : dynamicByHeight.toDouble();
  }

  double navBarBaseHeight() {
    switch (tier) {
      case ResponsiveTier.mobileSmall:
        return 72;
      case ResponsiveTier.mobile:
        return 76;
      case ResponsiveTier.tablet:
        return 80;
      case ResponsiveTier.desktopSmall:
        return 84;
      case ResponsiveTier.desktop:
        return 0;
    }
  }
}

extension ResponsiveLayoutX on BuildContext {
  ResponsiveLayout get responsive => ResponsiveLayout.of(this);
}
