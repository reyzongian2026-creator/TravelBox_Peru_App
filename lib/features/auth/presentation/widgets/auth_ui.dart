import 'package:flutter/material.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/l10n/app_localizations_fixed.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../shared/widgets/travelbox_logo.dart';
import 'auth_teddy_animation.dart';

class AuthUi {
  const AuthUi._();

  static const backgroundGradient = TravelBoxBrand.authGradient;

  static const cardRadius = 24.0;
  static const actionColor = TravelBoxBrand.primaryBlue;

  static InputDecoration lineFieldDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      isDense: true,
      filled: false,
    );
  }
}

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({required this.child, this.maxWidth = 760, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = context.responsive;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E152A),
                    Color(0xFF121A31),
                    Color(0xFF172039),
                  ],
                )
              : AuthUi.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.horizontalPadding + 6,
                  vertical: responsive.verticalPadding + 6,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    this.scrollable = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A30) : Colors.white,
        borderRadius: BorderRadius.circular(AuthUi.cardRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3550) : TravelBoxBrand.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: scrollable
          ? SingleChildScrollView(padding: padding, child: child)
          : Padding(padding: padding, child: child),
    );
  }
}

class AuthSplitScaffold extends StatelessWidget {
  const AuthSplitScaffold({
    required this.formChild,
    required this.heroTitle,
    required this.heroSubtitle,
    this.heroLabel = 'InkaVoy',
    this.showGuardianBear = true,
    this.showHeroIllustration = true,
    this.showCompactHero = true,
    this.heroAnimation = 'idle',
    this.maxWidth = 1260,
    super.key,
  });

  final Widget formChild;
  final String heroTitle;
  final String heroSubtitle;
  final String heroLabel;
  final bool showGuardianBear;
  final bool showHeroIllustration;
  final bool showCompactHero;
  final String heroAnimation;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = context.responsive;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF060E1C),
                    Color(0xFF0B1220),
                    Color(0xFF111827),
                  ],
                )
              : AuthUi.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.all(responsive.horizontalPadding + 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 980;
                    if (compact) {
                      final heroHeight = constraints.maxWidth < 520
                          ? 188.0
                          : 224.0;
                      final cardPadding = constraints.maxWidth < 520
                          ? const EdgeInsets.fromLTRB(14, 14, 14, 18)
                          : const EdgeInsets.fromLTRB(18, 18, 18, 20);
                      final sheetPadding = constraints.maxWidth < 520
                          ? const EdgeInsets.fromLTRB(10, 8, 10, 14)
                          : const EdgeInsets.fromLTRB(12, 8, 12, 14);
                      if (!showCompactHero) {
                        return SingleChildScrollView(
                          padding: sheetPadding,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: AuthCard(
                              scrollable: false,
                              padding: cardPadding,
                              child: formChild,
                            ),
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        padding: sheetPadding,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: heroHeight,
                                child: AuthHeroPanel(
                                  label: heroLabel,
                                title: heroTitle,
                                subtitle: heroSubtitle,
                                compact: true,
                                showGuardianBear: showGuardianBear,
                                showHeroIllustration: showHeroIllustration,
                                heroAnimation: heroAnimation,
                              ),
                            ),
                              const SizedBox(height: 12),
                              AuthCard(
                                scrollable: false,
                                padding: cardPadding,
                                child: formChild,
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF11182D)
                            : TravelBoxBrand.mist,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2B3550)
                              : TravelBoxBrand.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.28 : 0.09,
                            ),
                            blurRadius: 36,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                18,
                              ),
                              child: AuthHeroPanel(
                                label: heroLabel,
                                title: heroTitle,
                                subtitle: heroSubtitle,
                                compact: false,
                                showGuardianBear: showGuardianBear,
                                showHeroIllustration: showHeroIllustration,
                                heroAnimation: heroAnimation,
                              ),
                            ),
                          ),
                          const VerticalDivider(
                            width: 1,
                            color: TravelBoxBrand.border,
                          ),
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                20,
                                22,
                                20,
                              ),
                              child: AuthCard(
                                padding: const EdgeInsets.fromLTRB(
                                  30,
                                  28,
                                  30,
                                  28,
                                ),
                                child: formChild,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.showGuardianBear,
    required this.showHeroIllustration,
    required this.heroAnimation,
    super.key,
  });

  final String label;
  final String title;
  final String subtitle;
  final bool compact;
  final bool showGuardianBear;
  final bool showHeroIllustration;
  final String heroAnimation;

  @override
  Widget build(BuildContext context) {
    final badgeText = compact
        ? 'Operaciones para viajeros'
        : 'Almacenaje y operaciones para viajeros';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 30),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: TravelBoxBrand.heroGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _AuthHeroPainter())),
          if (showGuardianBear)
            Positioned(
              right: compact ? 8 : 14,
              top: compact ? 10 : 14,
              child: AuthTeddyAnimation(
                animation: heroAnimation,
                compact: compact,
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TravelBoxLogo(
                compact: compact,
                darkBackground: true,
                showSubtitle: false,
              ),
              SizedBox(height: compact ? 10 : 14),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              SizedBox(height: compact ? 12 : 18),
              Expanded(
                child: showHeroIllustration
                    ? _AuthHeroIllustration(compact: compact)
                    : const SizedBox.expand(),
              ),
              SizedBox(height: compact ? 14 : 20),
              Text(
                context.l10n.t('auth_hero_welcome_back'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: compact ? 16 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 30 : 46,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 0.96,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: compact ? 72 : 88,
                height: 5,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFD6E4FF)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 260 : 360),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: compact ? 12 : 13,
                    height: 1.5,
                  ),
                ),
              ),
              if (!compact) const SizedBox(height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthHeroIllustration extends StatelessWidget {
  const _AuthHeroIllustration({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    const image = _PeruMapHeroArt();

    return Stack(
      children: [
        Positioned(
          left: compact ? 6 : 14,
          top: compact ? 16 : 20,
          child: _AuthFloatingBadge(
            icon: Icons.inventory_2_outlined,
            label: 'Equipaje seguro',
            compact: compact,
          ),
        ),
        Positioned(
          right: compact ? 4 : 10,
          top: compact ? 0 : 8,
          child: _AuthFloatingBadge(
            icon: Icons.map_outlined,
            label: 'Rutas y sedes',
            compact: compact,
          ),
        ),
        Positioned(
          right: compact ? 6 : 14,
          bottom: compact ? 30 : 34,
          child: _AuthFloatingBadge(
            icon: Icons.badge_outlined,
            label: 'Check-in rápido',
            compact: compact,
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 20,
              compact ? 16 : 20,
              compact ? 12 : 18,
              compact ? 14 : 10,
            ),
            child: image,
          ),
        ),
      ],
    );
  }
}

class _PeruMapHeroArt extends StatelessWidget {
  const _PeruMapHeroArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.82,
              maxHeight: constraints.maxHeight * 0.94,
            ),
            child: AspectRatio(
              aspectRatio: 0.8,
              child: CustomPaint(painter: _PeruMapArtPainter()),
            ),
          ),
        );
      },
    );
  }
}

class _AuthFloatingBadge extends StatelessWidget {
  const _AuthFloatingBadge({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 14 : 16,
              color: Colors.white.withValues(alpha: 0.96),
            ),
            SizedBox(width: compact ? 5 : 6),
            Text(
              label.replaceAll('rÃ¡pido', 'rápido'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthLineField extends StatelessWidget {
  const AuthLineField({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1718) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF4A3934) : TravelBoxBrand.border,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0x144C2512),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: double.infinity,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [TravelBoxBrand.terracotta, TravelBoxBrand.copper],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthStripeButton extends StatelessWidget {
  const AuthStripeButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.filled,
    super.key,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = filled ? TravelBoxBrand.primaryBlue : Colors.white;
    final foreground = filled
        ? Colors.white
        : (isDark ? const Color(0xFFF2E9DE) : TravelBoxBrand.ink);
    final borderColor = filled
        ? TravelBoxBrand.primaryBlue
        : (isDark ? const Color(0xFF4A3934) : TravelBoxBrand.border);
    final iconBg = filled
        ? Colors.white.withValues(alpha: 0.16)
        : (isDark ? const Color(0xFF2A2021) : const Color(0xFFF7EFE5));
    final iconColor = filled ? Colors.white : TravelBoxBrand.terracotta;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              gradient: filled ? TravelBoxBrand.discoveryGradient : null,
              color: filled
                  ? null
                  : (isDark ? const Color(0xFF1C1617) : background),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
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

class _AuthHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blobPaintA = Paint()..color = Colors.white.withValues(alpha: 0.07);
    final blobPaintB = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final glowPaint = Paint()..color = const Color(0x33A6C8FF);

    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.5,
        size.height * 0.1,
        size.width * 0.34,
        size.height * 0.24,
      ),
      blobPaintA,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.06,
        size.height * 0.34,
        size.width * 0.36,
        size.height * 0.28,
      ),
      blobPaintB,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.36,
        size.height * 0.56,
        size.width * 0.28,
        size.height * 0.18,
      ),
      blobPaintA,
    );

    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.45),
      size.width * 0.045,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.73, size.height * 0.22),
      size.width * 0.038,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.74),
      size.width * 0.032,
      glowPaint,
    );

    final mountainPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final mountain = Path()
      ..moveTo(size.width * 0.58, size.height * 0.9)
      ..lineTo(size.width * 0.68, size.height * 0.8)
      ..lineTo(size.width * 0.76, size.height * 0.88)
      ..lineTo(size.width * 0.84, size.height * 0.76)
      ..lineTo(size.width * 0.94, size.height * 0.9);
    canvas.drawPath(mountain, mountainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PeruMapArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.58, size.height * 0.3);
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0x55A9C5FF),
              const Color(0x11336BFF),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.38),
          );

    canvas.drawCircle(center, size.shortestSide * 0.34, glowPaint);
    canvas.drawCircle(
      Offset(size.width * 0.42, size.height * 0.78),
      size.shortestSide * 0.18,
      Paint()..color = const Color(0x1AF7FBFF),
    );

    final shadowPath = _buildPeruPath(size).shift(const Offset(8, 10));
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    final path = _buildPeruPath(size);
    final mapPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4C91B5), Color(0xFF254F79), Color(0xFF1B2747)],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, mapPaint);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    final goldAccent = Path()
      ..moveTo(size.width * 0.42, size.height * 0.64)
      ..lineTo(size.width * 0.48, size.height * 0.61)
      ..lineTo(size.width * 0.53, size.height * 0.72)
      ..lineTo(size.width * 0.46, size.height * 0.76)
      ..close();
    canvas.drawPath(goldAccent, Paint()..color = const Color(0xD7D2A34E));

    final texturePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 5; i++) {
      final bandPath = Path()
        ..moveTo(
          size.width * (0.28 + i * 0.05),
          size.height * (0.18 + i * 0.08),
        )
        ..quadraticBezierTo(
          size.width * 0.54,
          size.height * (0.24 + i * 0.05),
          size.width * 0.66,
          size.height * (0.3 + i * 0.11),
        )
        ..quadraticBezierTo(
          size.width * 0.63,
          size.height * (0.44 + i * 0.08),
          size.width * (0.48 + i * 0.02),
          size.height * (0.62 + i * 0.06),
        );
      canvas.drawPath(bandPath, texturePaint);
    }
  }

  Path _buildPeruPath(Size size) {
    return Path()
      ..moveTo(size.width * 0.38, size.height * 0.08)
      ..lineTo(size.width * 0.3, size.height * 0.18)
      ..lineTo(size.width * 0.22, size.height * 0.29)
      ..lineTo(size.width * 0.27, size.height * 0.4)
      ..lineTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.24, size.height * 0.64)
      ..lineTo(size.width * 0.2, size.height * 0.79)
      ..lineTo(size.width * 0.31, size.height * 0.9)
      ..lineTo(size.width * 0.38, size.height * 0.98)
      ..lineTo(size.width * 0.52, size.height * 0.94)
      ..lineTo(size.width * 0.58, size.height * 0.84)
      ..lineTo(size.width * 0.66, size.height * 0.75)
      ..lineTo(size.width * 0.61, size.height * 0.6)
      ..lineTo(size.width * 0.68, size.height * 0.45)
      ..lineTo(size.width * 0.63, size.height * 0.31)
      ..lineTo(size.width * 0.67, size.height * 0.19)
      ..lineTo(size.width * 0.58, size.height * 0.12)
      ..lineTo(size.width * 0.52, size.height * 0.02)
      ..lineTo(size.width * 0.45, size.height * 0.08)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
