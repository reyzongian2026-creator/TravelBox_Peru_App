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
                        color: isDark ? const Color(0xFF11182D) : TravelBoxBrand.mist,
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
    required this.heroAnimation,
    super.key,
  });

  final String label;
  final String title;
  final String subtitle;
  final bool compact;
  final bool showGuardianBear;
  final String heroAnimation;

  @override
  Widget build(BuildContext context) {
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
          Positioned(
            right: compact ? -20 : -28,
            bottom: compact ? -24 : -30,
            child: Container(
              width: compact ? 150 : 210,
              height: compact ? 150 : 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: compact ? 10 : 16,
            top: compact ? 56 : 72,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 5 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                compact ? 'Plataforma operativa' : 'Almacenaje y operaciones para viajeros',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: TravelBoxLogo(
                      compact: compact,
                      darkBackground: true,
                      showSubtitle: false,
                    ),
                  ),
                ],
              ),
              const Spacer(),
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
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final topWave = Path()
      ..moveTo(0, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.34,
        size.width * 0.46,
        size.height * 0.16,
      )
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * -0.02,
        size.width,
        size.height * 0.12,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      topWave,
      Paint()..color = const Color(0x20F4C98A),
    );

    final bottomWave = Path()
      ..moveTo(0, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.15,
        size.height * 0.73,
        size.width * 0.34,
        size.height * 0.84,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.96,
        size.width * 0.67,
        size.height * 0.82,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.71,
        size.width,
        size.height * 0.85,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      bottomWave,
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.2);
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.28),
      16,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.08),
      18,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.82),
      20,
      dotPaint,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(size.width * 0.44, size.height * 0.16),
      Offset(size.width * 0.82, size.height * 0.55),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.7),
      Offset(size.width * 0.28, size.height * 0.58),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
