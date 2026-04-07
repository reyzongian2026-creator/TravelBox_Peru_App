import 'package:flutter/material.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/l10n/app_localizations_fixed.dart';
import '../../../../core/theme/brand_tokens.dart';
import '../../../../shared/widgets/travelbox_logo.dart';
import 'auth_llama_animation.dart';

class AuthUi {
  const AuthUi._();

  static const backgroundGradient = TravelBoxBrand.authGradient;

  static const cardRadius = 24.0;
  static const actionColor = TravelBoxBrand.primaryBlue;

  static InputDecoration lineFieldDecoration(
    String hintText, {
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: TravelBoxBrand.textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.only(left: 2, right: 8),
              child: Icon(prefixIcon, size: 19, color: TravelBoxBrand.textMuted),
            )
          : null,
      prefixIconConstraints: const BoxConstraints(
        minWidth: 38,
        minHeight: 38,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 22),
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
        color: isDark ? TravelBoxBrand.darkCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(AuthUi.cardRadius),
        border: Border.all(
          color: isDark ? TravelBoxBrand.darkCardBorder : const Color(0xFFE0E7F1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          if (!isDark)
            BoxShadow(
              color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.04),
              blurRadius: 40,
              offset: const Offset(0, 20),
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
    this.showGuardianLlama = true,
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
  final bool showGuardianLlama;
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
              child: LayoutBuilder(
                builder: (context, outerConstraints) {
                  final outScreenW = MediaQuery.of(context).size.width;
                  final outIsMobile = outScreenW <= 480;
                  final outerPad = outIsMobile
                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                      : EdgeInsets.all(responsive.horizontalPadding + 4);
                  return Padding(
                    padding: outerPad,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 980;
                        final screenW = MediaQuery.of(context).size.width;
                        if (compact) {
                          final isMobileSmall = screenW <= 360;
                          final isMobile = screenW <= 480;
                          final heroHeight = constraints.maxWidth < 520
                              ? 188.0
                              : 224.0;
                          final cardPadding = isMobileSmall
                              ? const EdgeInsets.fromLTRB(18, 8, 18, 10)
                              : isMobile
                                  ? const EdgeInsets.fromLTRB(22, 10, 22, 14)
                                  : const EdgeInsets.fromLTRB(26, 14, 26, 16);
                          final sheetPadding = isMobile
                              ? EdgeInsets.zero
                              : constraints.maxWidth < 520
                                  ? const EdgeInsets.fromLTRB(8, 4, 8, 8)
                                  : const EdgeInsets.fromLTRB(10, 6, 10, 10);
                          if (!showCompactHero) {
                            final isDarkCompact =
                                Theme.of(context).brightness == Brightness.dark;
                            if (isMobile) {
                              return AuthCard(
                                scrollable: true,
                                padding: cardPadding,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight -
                                        cardPadding.vertical - 4,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      formChild,
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 24),
                                        child: _MobileTravelTeaser(
                                            isDark: isDarkCompact),
                                      ),
                                    ],
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AuthCard(
                                      scrollable: false,
                                      padding: cardPadding,
                                      child: formChild,
                                    ),
                                    const SizedBox(height: 20),
                                    _MobileTravelTeaser(
                                        isDark: isDarkCompact),
                                  ],
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: heroHeight,
                                    child: AuthHeroPanel(
                                      label: heroLabel,
                                      title: heroTitle,
                                      subtitle: heroSubtitle,
                                      compact: true,
                                      showGuardianLlama: showGuardianLlama,
                                      showHeroIllustration:
                                          showHeroIllustration,
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
                                ? TravelBoxBrand.darkPanelSurface
                                : Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: isDark
                                  ? TravelBoxBrand.darkCardBorder
                                  : const Color(0xFFE0E7F1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.28 : 0.08,
                                ),
                                blurRadius: 40,
                                offset: const Offset(0, 18),
                              ),
                              if (!isDark)
                                BoxShadow(
                                  color: TravelBoxBrand.primaryBlue
                                      .withValues(alpha: 0.05),
                                  blurRadius: 60,
                                  offset: const Offset(0, 30),
                                ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: AuthHeroPanel(
                                    label: heroLabel,
                                    title: heroTitle,
                                    subtitle: heroSubtitle,
                                    compact: false,
                                    showGuardianLlama: showGuardianLlama,
                                    showHeroIllustration:
                                        showHeroIllustration,
                                    heroAnimation: heroAnimation,
                                  ),
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                color: isDark
                                    ? TravelBoxBrand.darkCardBorder
                                    : const Color(0xFFE8EDF5),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24, 22, 24, 22,
                                  ),
                                  child: AuthCard(
                                    padding: const EdgeInsets.fromLTRB(
                                      28, 26, 28, 26,
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
                  );
                },
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
    required this.showGuardianLlama,
    required this.showHeroIllustration,
    required this.heroAnimation,
    super.key,
  });

  final String label;
  final String title;
  final String subtitle;
  final bool compact;
  final bool showGuardianLlama;
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
          if (showGuardianLlama)
            Positioned(
              right: compact ? 8 : 14,
              top: compact ? 10 : 14,
              child: AuthLlamaAnimation(
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
              SizedBox(
                height: compact ? 80 : 160,
                child: showHeroIllustration
                    ? _AuthHeroIllustration(compact: compact)
                    : const SizedBox.shrink(),
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

class _MobileTravelTeaser extends StatelessWidget {
  const _MobileTravelTeaser({required this.isDark});

  final bool isDark;

  static const _destinations = [
    ('Lima', Icons.location_city_outlined),
    ('Cusco', Icons.temple_hindu_outlined),
    ('Arequipa', Icons.landscape_outlined),
    ('Puno', Icons.water_outlined),
    ('Ica', Icons.wb_sunny_outlined),
    ('Trujillo', Icons.account_balance_outlined),
    ('Piura', Icons.beach_access_outlined),
    ('Máncora', Icons.surfing_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final chipColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.55);
    final chipBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.8);
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF475569);
    final accentColor = isDark
        ? const Color(0xFF60A5FA)
        : TravelBoxBrand.primaryBlue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.luggage_outlined, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                'Almacenamiento seguro en +10 ciudades',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _destinations.map((d) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipBorder, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(d.$2, size: 13, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      d.$1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Viaja ligero · Guarda seguro · Explora libre',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.35)
                  : const Color(0xFF94A3B8),
            ),
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
          left: compact ? 4 : 10,
          top: compact ? 4 : 8,
          child: _AuthFloatingBadge(
            icon: Icons.flight_takeoff_rounded,
            label: '4 rutas activas',
            compact: compact,
          ),
        ),
        Positioned(
          right: compact ? 4 : 10,
          top: compact ? 28 : 40,
          child: _AuthFloatingBadge(
            icon: Icons.luggage_outlined,
            label: '12 entregas hoy',
            compact: compact,
          ),
        ),
        Positioned(
          left: compact ? 4 : 10,
          bottom: compact ? 24 : 28,
          child: _AuthFloatingBadge(
            icon: Icons.verified_user_outlined,
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
              label,
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

class AuthLineField extends StatefulWidget {
  const AuthLineField({required this.child, super.key});

  final Widget child;

  @override
  State<AuthLineField> createState() => _AuthLineFieldState();
}

class _AuthLineFieldState extends State<AuthLineField> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final focusBorderColor = TravelBoxBrand.primaryBlue;
    final idleBorderColor =
        isDark ? const Color(0xFF2E3A52) : const Color(0xFFDDE3EE);
    final idleBg = isDark ? const Color(0xFF1A1F34) : const Color(0xFFFCFCFD);
    final focusBg = isDark ? const Color(0xFF1A1E2E) : Colors.white;

    return Focus(
      onFocusChange: (focused) => setState(() => _hasFocus = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: MediaQuery.of(context).size.shortestSide < 600 ? 48 : 54,
        decoration: BoxDecoration(
          color: _hasFocus ? focusBg : idleBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasFocus ? focusBorderColor : idleBorderColor,
            width: _hasFocus ? 1.6 : 1.0,
          ),
          boxShadow: [
            if (_hasFocus)
              BoxShadow(
                color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.12),
                blurRadius: 0,
                spreadRadius: 3,
              )
            else if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: _hasFocus ? 4.0 : 3.5,
              height: double.infinity,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _hasFocus
                      ? [
                          TravelBoxBrand.primaryBlue,
                          TravelBoxBrand.seafoam,
                        ]
                      : [
                          TravelBoxBrand.primaryBlue.withValues(alpha: 0.35),
                          TravelBoxBrand.seafoam.withValues(alpha: 0.25),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: widget.child,
              ),
            ),
          ],
        ),
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
    final foreground = filled
        ? Colors.white
        : (isDark ? const Color(0xFFF2E9DE) : TravelBoxBrand.ink);
    final borderColor = filled
        ? Colors.transparent
        : (isDark ? const Color(0xFF2E3A52) : const Color(0xFFDDE3EE));
    final iconBg = filled
        ? Colors.white.withValues(alpha: 0.18)
        : (isDark ? const Color(0xFF252A3E) : const Color(0xFFF0F4FA));
    final iconColor = filled ? Colors.white : TravelBoxBrand.primaryBlue;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.50 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          splashColor: filled
              ? Colors.white.withValues(alpha: 0.12)
              : TravelBoxBrand.primaryBlue.withValues(alpha: 0.08),
          child: Ink(
            height: MediaQuery.of(context).size.shortestSide < 600 ? 48 : 54,
            decoration: BoxDecoration(
              gradient: filled ? TravelBoxBrand.discoveryGradient : null,
              color: filled
                  ? null
                  : (isDark ? const Color(0xFF1A1F34) : Colors.white),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: TravelBoxBrand.primaryBlue.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: MediaQuery.of(context).size.shortestSide < 600 ? 48 : 54,
                  height: MediaQuery.of(context).size.shortestSide < 600 ? 48 : 54,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(17),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (filled)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withValues(alpha: 0.70),
                      size: 20,
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
  // Real Peru border from Natural Earth GeoJSON (76 points, normalised).
  static const _peruBorder = <List<double>>[
    [0.911, 0.9404], [0.8907, 0.9673], [0.852, 0.9808],
    [0.7763, 0.9506], [0.7698, 0.929], [0.6202, 0.8762],
    [0.4849, 0.8187], [0.4267, 0.7863], [0.3955, 0.7429],
    [0.4079, 0.7278], [0.344, 0.6588], [0.2696, 0.5618],
    [0.1983, 0.4571], [0.1675, 0.4331], [0.1437, 0.3944],
    [0.0851, 0.3601], [0.0314, 0.3388], [0.0558, 0.3154],
    [0.0192, 0.2652], [0.0427, 0.2284], [0.1028, 0.1952],
    [0.1118, 0.2171], [0.0903, 0.2296], [0.0923, 0.2489],
    [0.1235, 0.2447], [0.154, 0.2504], [0.1856, 0.2769],
    [0.2283, 0.2553], [0.2426, 0.2198], [0.2888, 0.1741],
    [0.3795, 0.1534], [0.4618, 0.0983], [0.4852, 0.0641],
    [0.4747, 0.0242], [0.4948, 0.0192], [0.545, 0.0441],
    [0.5691, 0.0689], [0.604, 0.0825], [0.6484, 0.1376],
    [0.7046, 0.1442], [0.7462, 0.1303], [0.7734, 0.1394],
    [0.8187, 0.1349], [0.8765, 0.1595], [0.8278, 0.213],
    [0.8503, 0.2142], [0.8881, 0.2422], [0.8201, 0.2397],
    [0.81, 0.2476], [0.7482, 0.2577], [0.6619, 0.2935],
    [0.6564, 0.318], [0.6372, 0.3363], [0.6447, 0.3648],
    [0.5991, 0.3799], [0.5992, 0.4021], [0.5793, 0.4117],
    [0.6107, 0.4591], [0.6526, 0.4911], [0.6366, 0.5136],
    [0.6867, 0.5167], [0.7152, 0.5447], [0.7818, 0.5461],
    [0.8437, 0.5151], [0.8387, 0.595], [0.873, 0.601],
    [0.9155, 0.592], [0.9808, 0.6766], [0.9645, 0.6944],
    [0.9608, 0.7313], [0.9594, 0.776], [0.9299, 0.8023],
    [0.9434, 0.8218], [0.9261, 0.8395], [0.9585, 0.8837],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Radial glows ──
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.15),
      w * 0.30,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.78, h * 0.15), radius: w * 0.30),
        ),
    );
    canvas.drawCircle(
      Offset(w * 0.12, h * 0.68),
      w * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.12, h * 0.68), radius: w * 0.22),
        ),
    );

    // ═══════════════════════════════════════════
    // LARGE PERU MAP (centered, real GeoJSON 76 points)
    // ═══════════════════════════════════════════
    {
      // Map occupies 70% width, 90% height, centered
      final mapW = w * 0.70;
      final mapH = h * 0.90;
      final mapX = (w - mapW) / 2; // centered horizontally
      final mapY = (h - mapH) / 2; // centered vertically

      // Build Peru path using Catmull-Rom spline
      final pts = _peruBorder
          .map((p) => Offset(mapX + p[0] * mapW, mapY + p[1] * mapH))
          .toList();
      final n = pts.length;
      final peruPath = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 0; i < n; i++) {
        final p0 = pts[(i - 1 + n) % n];
        final p1 = pts[i];
        final p2 = pts[(i + 1) % n];
        final p3 = pts[(i + 2) % n];
        peruPath.cubicTo(
          p1.dx + (p2.dx - p0.dx) / 6,
          p1.dy + (p2.dy - p0.dy) / 6,
          p2.dx - (p3.dx - p1.dx) / 6,
          p2.dy - (p3.dy - p1.dy) / 6,
          p2.dx,
          p2.dy,
        );
      }
      peruPath.close();

      // Shadow
      canvas.drawPath(
        peruPath.shift(const Offset(3, 5)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      // Gradient fill
      canvas.drawPath(
        peruPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF5B9BD5).withValues(alpha: 0.18),
              const Color(0xFF2B5EA7).withValues(alpha: 0.22),
              const Color(0xFF1A3360).withValues(alpha: 0.28),
            ],
          ).createShader(Rect.fromLTWH(mapX, mapY, mapW, mapH)),
      );

      // Outline
      canvas.drawPath(
        peruPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.18),
      );

      // Grid lines clipped inside Peru
      canvas.save();
      canvas.clipPath(peruPath);
      final gridPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.white.withValues(alpha: 0.06);
      for (var i = 0; i < 7; i++) {
        final y = mapY + mapH * (0.10 + i * 0.12);
        canvas.drawLine(Offset(mapX, y), Offset(mapX + mapW, y), gridPaint);
      }
      for (var i = 0; i < 5; i++) {
        final x = mapX + mapW * (0.12 + i * 0.18);
        canvas.drawLine(Offset(x, mapY), Offset(x, mapY + mapH), gridPaint);
      }
      canvas.restore();

      // Tourist destinations with real geographic coordinates
      final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.70);
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      // Major city: slightly bigger dots
      final majorDot = Paint()..color = Colors.white.withValues(alpha: 0.80);
      final majorRing = Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final majorGlow = Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      // All positions calculated from real lat/lon
      final major = <String, Offset>{
        'Lima': Offset(mapX + mapW * 0.338, mapY + mapH * 0.656),
        'Cusco': Offset(mapX + mapW * 0.738, mapY + mapH * 0.737),
        'Arequipa': Offset(mapX + mapW * 0.772, mapY + mapH * 0.894),
        'Iquitos': Offset(mapX + mapW * 0.637, mapY + mapH * 0.203),
      };
      final tourist = <String, Offset>{
        'Machu Picchu': Offset(mapX + mapW * 0.693, mapY + mapH * 0.717),
        'Puno': Offset(mapX + mapW * 0.892, mapY + mapH * 0.863),
        'Trujillo': Offset(mapX + mapW * 0.181, mapY + mapH * 0.441),
        'Nazca': Offset(mapX + mapW * 0.490, mapY + mapH * 0.808),
        'Huaraz': Offset(mapX + mapW * 0.300, mapY + mapH * 0.518),
        'Paracas': Offset(mapX + mapW * 0.401, mapY + mapH * 0.753),
        'Lago Titicaca': Offset(mapX + mapW * 0.946, mapY + mapH * 0.862),
        'Chachapoyas': Offset(mapX + mapW * 0.273, mapY + mapH * 0.338),
        'Máncora': Offset(mapX + mapW * 0.022, mapY + mapH * 0.222),
        'Colca': Offset(mapX + mapW * 0.745, mapY + mapH * 0.852),
        'Huacachina': Offset(mapX + mapW * 0.439, mapY + mapH * 0.767),
        'Tarapoto': Offset(mapX + mapW * 0.392, mapY + mapH * 0.352),
        'Cajamarca': Offset(mapX + mapW * 0.223, mapY + mapH * 0.389),
        'Ayacucho': Offset(mapX + mapW * 0.560, mapY + mapH * 0.716),
        'P. Maldonado': Offset(mapX + mapW * 0.957, mapY + mapH * 0.686),
      };

      // Dashed route connecting major cities + key tourist circuit
      final routePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;
      final routePath = Path()
        ..moveTo(major['Iquitos']!.dx, major['Iquitos']!.dy)
        ..lineTo(major['Lima']!.dx, major['Lima']!.dy)
        ..lineTo(tourist['Nazca']!.dx, tourist['Nazca']!.dy)
        ..lineTo(major['Arequipa']!.dx, major['Arequipa']!.dy)
        ..lineTo(tourist['Puno']!.dx, tourist['Puno']!.dy)
        ..lineTo(major['Cusco']!.dx, major['Cusco']!.dy)
        ..lineTo(tourist['Machu Picchu']!.dx, tourist['Machu Picchu']!.dy);
      for (final m in routePath.computeMetrics()) {
        var d = 0.0;
        while (d < m.length) {
          final end = (d + 3.5).clamp(0.0, m.length);
          canvas.drawPath(m.extractPath(d, end), routePaint);
          d += 7.0;
        }
      }

      // Draw major cities (bigger)
      for (final entry in major.entries) {
        final pos = entry.value;
        canvas.drawCircle(pos, 6, majorGlow);
        canvas.drawCircle(pos, 3.8, majorRing);
        canvas.drawCircle(pos, 2.0, majorDot);
        final tp = TextPainter(
          text: TextSpan(
            text: entry.key,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 6.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Position label: avoid overlap by placing some to the left
        final leftAlign = entry.key == 'Arequipa' || entry.key == 'Cusco';
        final dx = leftAlign ? pos.dx - tp.width - 4 : pos.dx + 5;
        tp.paint(canvas, Offset(dx, pos.dy - tp.height / 2));
      }

      // Draw tourist spots (smaller, softer)
      for (final entry in tourist.entries) {
        final pos = entry.value;
        canvas.drawCircle(pos, 4, glowPaint);
        canvas.drawCircle(pos, 2.5, ringPaint);
        canvas.drawCircle(pos, 1.3, dotPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: entry.key,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 5.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Smart label placement to reduce overlap
        final bool placeLeft = entry.key == 'Colca' ||
            entry.key == 'Lago Titicaca' ||
            entry.key == 'Machu Picchu' ||
            entry.key == 'Puno' ||
            entry.key == 'P. Maldonado';
        final bool placeAbove = entry.key == 'Huacachina' ||
            entry.key == 'Ayacucho';
        double dx, dy;
        if (placeLeft) {
          dx = pos.dx - tp.width - 3;
          dy = pos.dy - tp.height / 2;
        } else if (placeAbove) {
          dx = pos.dx - tp.width / 2;
          dy = pos.dy - tp.height - 3;
        } else {
          dx = pos.dx + 4;
          dy = pos.dy - tp.height / 2;
        }
        tp.paint(canvas, Offset(dx, dy));
      }
    }

    // ── Stroke paints ──
    final lp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.15);
    final lpBright = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.22);

    // ═══════════════════════════════════════════
    // 1. AIRPLANE (MDI real SVG — viewBox 24×24)
    //    Dashed flight trail + airplane from real bezier paths
    // ═══════════════════════════════════════════
    final trailPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final trailPath = Path()
      ..moveTo(w * 0.02, h * 0.55)
      ..cubicTo(w * 0.20, h * 0.35, w * 0.50, h * 0.20, w * 0.88, h * 0.12);
    for (final m in trailPath.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final end = (d + 8.0).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(d, end), trailPaint);
        d += 16.0;
      }
    }
    // Real MDI airplane SVG path (cubicTo bezier curves)
    canvas.save();
    canvas.translate(w * 0.84, h * 0.11);
    canvas.rotate(-0.6);
    final apS = w * 0.0032;  // scale 24-unit viewbox to panel size
    canvas.scale(apS, apS);
    canvas.translate(-12, -12); // center the 24x24 icon
    final airplane = Path()
      ..moveTo(20.56, 3.91)
      ..cubicTo(21.15, 4.50, 21.15, 5.45, 20.56, 6.03)
      ..lineTo(16.67, 9.92)
      ..lineTo(18.79, 19.11)
      ..lineTo(17.38, 20.53)
      ..lineTo(13.50, 13.10)
      ..lineTo(9.60, 17.00)
      ..lineTo(9.96, 19.47)
      ..lineTo(8.89, 20.53)
      ..lineTo(7.13, 17.35)
      ..lineTo(3.94, 15.58)
      ..lineTo(5.00, 14.50)
      ..lineTo(7.50, 14.87)
      ..lineTo(11.37, 11.00)
      ..lineTo(3.94, 7.09)
      ..lineTo(5.36, 5.68)
      ..lineTo(14.55, 7.80)
      ..lineTo(18.44, 3.91)
      ..cubicTo(19.00, 3.33, 20.00, 3.33, 20.56, 3.91)
      ..close();
    canvas.drawPath(airplane, lpBright);
    canvas.restore();

    // ═══════════════════════════════════════════
    // 2. LLAMA (Twemoji real SVG — viewBox 36×36)
    //    Full body with smooth cubic bezier curves
    // ═══════════════════════════════════════════
    canvas.save();
    canvas.translate(w * 0.02, h * 0.26);
    final llS = w * 0.0050; // scale 36-unit viewbox
    canvas.scale(llS, llS);
    final llama = Path()
      ..moveTo(8.19, 0.74)
      ..cubicTo(8.52, 1.07, 8.93, 3.13, 8.93, 3.13)
      ..cubicTo(8.93, 3.13, 10.21, 3.22, 11.33, 3.92)
      ..cubicTo(15.83, 6.69, 13.88, 13.46, 15.28, 15.02)
      ..cubicTo(15.71, 15.50, 24.96, 13.38, 29.50, 15.56)
      ..cubicTo(33.34, 17.41, 32.58, 20.21, 33.58, 20.83)
      ..cubicTo(34.34, 21.31, 31.58, 22.08, 31.00, 18.52)
      ..cubicTo(30.50, 29.67, 29.93, 32.39, 29.33, 34.87)
      ..cubicTo(28.99, 36.28, 27.35, 36.48, 27.54, 34.54)
      ..cubicTo(27.64, 33.51, 28.00, 27.32, 26.96, 25.75)
      ..cubicTo(26.21, 24.62, 22.25, 28.17, 15.25, 27.52)
      ..cubicTo(14.77, 31.80, 14.15, 34.66, 13.98, 35.04)
      ..cubicTo(13.42, 36.27, 12.12, 36.26, 12.30, 35.03)
      ..cubicTo(12.49, 33.80, 12.75, 30.08, 11.42, 26.02)
      ..cubicTo(5.79, 22.04, 9.79, 11.83, 8.16, 9.88)
      ..cubicTo(7.80, 9.44, 5.52, 8.90, 4.85, 8.83)
      ..cubicTo(4.18, 8.76, 3.59, 8.66, 3.19, 8.59)
      ..cubicTo(2.79, 8.52, 2.19, 6.81, 2.26, 6.35)
      ..cubicTo(2.33, 5.88, 2.65, 5.72, 3.52, 5.39)
      ..cubicTo(4.39, 5.06, 4.51, 5.17, 4.46, 4.66)
      ..cubicTo(4.36, 3.61, 6.64, 2.89, 7.94, 3.02)
      ..cubicTo(7.81, 2.89, 6.86, 1.23, 6.59, 0.63)
      ..cubicTo(6.24, -0.15, 7.66, 0.18, 8.19, 0.74)
      ..close();
    // Ear paths from Twemoji SVG
    final llamaEar = Path()
      ..moveTo(6.76, 2.25)
      ..cubicTo(6.31, 1.88, 5.71, 1.27, 5.13, 0.95)
      ..cubicTo(4.63, 0.67, 4.88, 1.87, 5.30, 2.34)
      ..cubicTo(5.72, 2.81, 7.12, 3.68, 7.76, 4.15)
      ..cubicTo(8.39, 4.62, 8.69, 4.55, 8.07, 3.68)
      ..cubicTo(7.42, 2.77, 6.76, 2.25, 6.76, 2.25)
      ..close();
    // Eye dot
    final llamaEye = Path()
      ..addOval(Rect.fromCircle(center: const Offset(6.85, 4.81), radius: 0.73));
    canvas.drawPath(llama, lp);
    canvas.drawPath(llamaEar, lp);
    canvas.drawPath(llamaEye, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 0.5
      ..color = Colors.white.withValues(alpha: 0.13));
    canvas.restore();

    // ═══════════════════════════════════════════
    // 3. INTI / SOL INCA (MDI sun-compass — viewBox 24×24)
    //    Real SVG compound path with rays, circle, inner diamond
    // ═══════════════════════════════════════════
    canvas.save();
    canvas.translate(w * 0.74, h * 0.40);
    final intiS = w * 0.0040;
    canvas.scale(intiS, intiS);
    canvas.translate(-12, -12); // center 24x24
    final inti = Path()
      // Top ray
      ..moveTo(9.70, 4.30)
      ..lineTo(12.00, 1.00)
      ..lineTo(14.30, 4.30)
      ..cubicTo(13.60, 4.10, 12.80, 4.00, 12.00, 4.00)
      ..cubicTo(11.20, 4.00, 10.40, 4.10, 9.70, 4.30)
      // Top-right ray
      ..moveTo(17.50, 6.20)
      ..cubicTo(18.60, 7.30, 19.50, 8.70, 19.80, 10.30)
      ..lineTo(21.50, 6.60)
      ..lineTo(17.50, 6.20)
      // Top-left ray
      ..moveTo(5.00, 8.10)
      ..cubicTo(5.10, 8.00, 5.10, 8.00, 5.00, 8.10)
      ..cubicTo(5.10, 8.00, 5.10, 8.00, 5.10, 7.90)
      ..cubicTo(5.50, 7.30, 6.00, 6.70, 6.50, 6.20)
      ..lineTo(2.50, 6.50)
      ..lineTo(4.20, 10.20)
      ..cubicTo(4.40, 9.50, 4.70, 8.70, 5.00, 8.10)
      // Bottom-right ray
      ..moveTo(19.20, 15.40)
      ..cubicTo(19.20, 15.40, 19.20, 15.50, 19.20, 15.40)
      ..cubicTo(19.10, 15.60, 19.00, 15.80, 18.90, 15.90)
      ..lineTo(18.90, 16.10)
      ..cubicTo(18.50, 16.80, 18.00, 17.30, 17.50, 17.90)
      ..lineTo(21.60, 17.60)
      ..lineTo(19.90, 13.90)
      ..cubicTo(19.70, 14.40, 19.50, 14.90, 19.20, 15.40)
      // Bottom-left ray
      ..moveTo(5.20, 16.20)
      ..cubicTo(5.20, 16.10, 5.10, 16.10, 5.10, 16.00)
      ..cubicTo(5.00, 15.90, 5.00, 15.90, 5.00, 15.80)
      ..cubicTo(4.90, 15.60, 4.80, 15.50, 4.80, 15.30)
      ..cubicTo(4.60, 14.80, 4.40, 14.30, 4.30, 13.80)
      ..lineTo(2.60, 17.50)
      ..lineTo(6.70, 17.80)
      ..cubicTo(6.00, 17.30, 5.60, 16.80, 5.20, 16.20)
      // Bottom ray
      ..moveTo(12.60, 20.00)
      ..lineTo(11.40, 20.00)
      ..cubicTo(10.80, 20.00, 10.20, 19.80, 9.70, 19.70)
      ..lineTo(12.00, 23.00)
      ..lineTo(14.30, 19.70)
      ..cubicTo(13.80, 19.80, 13.20, 19.90, 12.60, 20.00)
      // Main circle
      ..moveTo(16.20, 7.80)
      ..cubicTo(13.90, 5.50, 10.10, 5.50, 7.70, 7.80)
      ..cubicTo(5.30, 10.10, 5.40, 13.90, 7.70, 16.30)
      ..cubicTo(10.00, 18.70, 13.80, 18.60, 16.20, 16.30)
      ..cubicTo(18.60, 14.00, 18.60, 10.10, 16.20, 7.80)
      // Inner diamond (compass rose)
      ..moveTo(8.50, 15.50)
      ..lineTo(10.60, 10.60)
      ..lineTo(15.60, 8.40)
      ..lineTo(13.50, 13.30)
      ..lineTo(8.50, 15.50)
      // Center eye
      ..moveTo(12.70, 12.70)
      ..cubicTo(12.30, 13.10, 11.70, 13.10, 11.30, 12.70)
      ..cubicTo(10.90, 12.30, 10.90, 11.70, 11.30, 11.30)
      ..cubicTo(11.70, 10.90, 12.30, 10.90, 12.70, 11.30)
      ..cubicTo(13.10, 11.70, 13.10, 12.30, 12.70, 12.70)
      ..close();
    canvas.drawPath(inti, lp);
    canvas.restore();

    // ═══════════════════════════════════════════
    // 4. CONDOR / BIRD (MDI real SVG — viewBox 24×24)
    //    Flying bird with cubic bezier wing and body
    // ═══════════════════════════════════════════
    canvas.save();
    canvas.translate(w * 0.20, h * 0.06);
    final cdS = w * 0.0035;
    canvas.scale(cdS, cdS);
    canvas.translate(-12, -12); // center 24x24
    final condor = Path()
      ..moveTo(23.00, 11.50)
      ..lineTo(19.95, 10.37)
      ..cubicTo(19.69, 9.22, 19.04, 8.56, 19.04, 8.56)
      ..cubicTo(17.40, 6.92, 14.75, 6.92, 13.11, 8.56)
      ..lineTo(11.63, 10.04)
      ..lineTo(5.00, 3.00)
      ..cubicTo(4.00, 7.00, 5.00, 11.00, 7.45, 14.22)
      ..lineTo(2.00, 19.50)
      ..cubicTo(2.00, 19.50, 10.89, 21.50, 16.07, 17.45)
      ..cubicTo(18.83, 15.29, 19.45, 14.03, 19.84, 12.70)
      ..lineTo(23.00, 11.50)
      // Eye circle
      ..moveTo(17.71, 11.72)
      ..cubicTo(17.32, 12.11, 16.68, 12.11, 16.29, 11.72)
      ..cubicTo(15.90, 11.33, 15.90, 10.70, 16.29, 10.31)
      ..cubicTo(16.68, 9.92, 17.32, 9.92, 17.71, 10.31)
      ..cubicTo(18.10, 10.70, 18.10, 11.33, 17.71, 11.72)
      ..close();
    canvas.drawPath(condor, lp);
    canvas.restore();

    // ═══════════════════════════════════════════
    // 5. PYRAMID / MACHU PICCHU (MDI real SVG — viewBox 24×24)
    //    3D Inca pyramid with visible face divisions
    // ═══════════════════════════════════════════
    canvas.save();
    canvas.translate(w * 0.56, h * 0.03);
    final pyS = w * 0.0036;
    canvas.scale(pyS, pyS);
    canvas.translate(-12, -12); // center 24x24
    final pyramid = Path()
      ..moveTo(21.85, 16.96)
      ..lineTo(21.85, 16.96)
      ..lineTo(12.85, 2.47)
      ..cubicTo(12.65, 2.16, 12.33, 2.00, 12.00, 2.00)
      ..cubicTo(11.67, 2.00, 11.35, 2.16, 11.15, 2.47)
      ..lineTo(2.15, 16.96)
      ..lineTo(2.15, 16.96)
      ..cubicTo(1.84, 17.45, 2.00, 18.18, 2.64, 18.43)
      ..lineTo(11.64, 21.93)
      ..cubicTo(11.75, 22.00, 11.88, 22.00, 12.00, 22.00)
      ..cubicTo(12.12, 22.00, 12.25, 22.00, 12.36, 21.93)
      ..lineTo(21.36, 18.43)
      ..cubicTo(22.00, 18.18, 22.16, 17.45, 21.85, 16.96)
      // Left face
      ..moveTo(11.00, 6.50)
      ..lineTo(11.00, 13.32)
      ..lineTo(5.42, 15.50)
      ..lineTo(11.00, 6.50)
      // Bottom base
      ..moveTo(12.00, 19.93)
      ..lineTo(5.76, 17.50)
      ..lineTo(12.00, 15.07)
      ..lineTo(18.24, 17.50)
      ..lineTo(12.00, 19.93)
      // Right face
      ..moveTo(13.00, 13.32)
      ..lineTo(13.00, 6.50)
      ..lineTo(18.58, 15.50)
      ..lineTo(13.00, 13.32)
      ..close();
    canvas.drawPath(pyramid, lp);
    canvas.restore();

    // ═══════════════════════════════════════════
    // 6. TUMI KNIFE (improved geometry)
    // ═══════════════════════════════════════════
    canvas.save();
    canvas.translate(w * 0.90, h * 0.52);
    final tmS = w * 0.0020;
    canvas.scale(tmS, tmS);
    final tumi = Path()
      // Blade
      ..moveTo(0, 0)..lineTo(-8, 40)..lineTo(8, 40)..lineTo(0, 0)
      // Handle semicircle
      ..moveTo(-10, 0)
      ..quadraticBezierTo(-14, -16, 0, -20)
      ..quadraticBezierTo(14, -16, 10, 0)
      // Face in handle
      ..moveTo(-4, -10)..lineTo(-2, -8)
      ..moveTo(4, -10)..lineTo(2, -8)
      ..moveTo(-2, -4)..quadraticBezierTo(0, -2, 2, -4);
    canvas.drawPath(tumi, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.12));
    canvas.restore();

    // ═══════════════════════════════════════════
    // 7. ANDES MOUNTAINS (bottom, layered + snow)
    // ═══════════════════════════════════════════
    final mt1 = Path()
      ..moveTo(w * 0.35, h * 0.94)
      ..lineTo(w * 0.45, h * 0.82)..lineTo(w * 0.52, h * 0.86)
      ..lineTo(w * 0.60, h * 0.76)..lineTo(w * 0.68, h * 0.82)
      ..lineTo(w * 0.76, h * 0.72)..lineTo(w * 0.85, h * 0.79)
      ..lineTo(w * 0.92, h * 0.74)..lineTo(w, h * 0.78)
      ..lineTo(w, h * 0.94)..close();
    canvas.drawPath(mt1, Paint()
      ..color = Colors.white.withValues(alpha: 0.04)..style = PaintingStyle.fill);
    final mt2 = Path()
      ..moveTo(w * 0.42, h * 0.94)
      ..lineTo(w * 0.52, h * 0.83)..lineTo(w * 0.57, h * 0.87)
      ..lineTo(w * 0.64, h * 0.78)..lineTo(w * 0.70, h * 0.83)
      ..lineTo(w * 0.78, h * 0.73)..lineTo(w * 0.87, h * 0.82)
      ..lineTo(w * 0.95, h * 0.76)..lineTo(w, h * 0.80);
    canvas.drawPath(mt2, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.12));
    final snow = Paint()..color = Colors.white.withValues(alpha: 0.14)..style = PaintingStyle.fill;
    _drawSnowCap(canvas, w * 0.78, h * 0.73, w * 0.018, snow);
    _drawSnowCap(canvas, w * 0.64, h * 0.78, w * 0.014, snow);
    _drawSnowCap(canvas, w * 0.92, h * 0.74, w * 0.013, snow);

    // ═══════════════════════════════════════════
    // 8. CHAKANA — Inca cross (precise geometry)
    // ═══════════════════════════════════════════
    _drawChakana(canvas, Offset(w * 0.48, h * 0.58), w * 0.022,
      Colors.white.withValues(alpha: 0.09));
    _drawChakana(canvas, Offset(w * 0.14, h * 0.20), w * 0.015,
      Colors.white.withValues(alpha: 0.07));

    // ═══════════════════════════════════════════
    // 9. Scatter dots
    // ═══════════════════════════════════════════
    final sDot = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (final p in [
      Offset(w * 0.30, h * 0.12), Offset(w * 0.42, h * 0.18),
      Offset(w * 0.70, h * 0.60), Offset(w * 0.55, h * 0.68),
      Offset(w * 0.92, h * 0.28), Offset(w * 0.08, h * 0.48),
      Offset(w * 0.35, h * 0.90), Offset(w * 0.65, h * 0.92),
    ]) {
      canvas.drawCircle(p, 1.2, sDot);
    }
  }

  void _drawSnowCap(Canvas canvas, double cx, double cy, double r, Paint paint) {
    final p = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - r, cy + r * 1.2)
      ..lineTo(cx + r, cy + r * 1.2)
      ..close();
    canvas.drawPath(p, paint);
  }

  void _drawChakana(Canvas canvas, Offset center, double size, Color color) {
    final s = size;
    final cx = center.dx;
    final cy = center.dy;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = color;
    // Stepped Inca cross — 12-vertex polygon (geometrically precise)
    final path = Path()
      ..moveTo(cx - s * 0.33, cy - s)
      ..lineTo(cx + s * 0.33, cy - s)
      ..lineTo(cx + s * 0.33, cy - s * 0.33)
      ..lineTo(cx + s, cy - s * 0.33)
      ..lineTo(cx + s, cy + s * 0.33)
      ..lineTo(cx + s * 0.33, cy + s * 0.33)
      ..lineTo(cx + s * 0.33, cy + s)
      ..lineTo(cx - s * 0.33, cy + s)
      ..lineTo(cx - s * 0.33, cy + s * 0.33)
      ..lineTo(cx - s, cy + s * 0.33)
      ..lineTo(cx - s, cy - s * 0.33)
      ..lineTo(cx - s * 0.33, cy - s * 0.33)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PeruMapArtPainter extends CustomPainter {
  // Real Peru border from Natural Earth GeoJSON (76 points, normalised).
  static const _border = <List<double>>[
    [0.911, 0.9404], [0.8907, 0.9673], [0.852, 0.9808],
    [0.7763, 0.9506], [0.7698, 0.929], [0.6202, 0.8762],
    [0.4849, 0.8187], [0.4267, 0.7863], [0.3955, 0.7429],
    [0.4079, 0.7278], [0.344, 0.6588], [0.2696, 0.5618],
    [0.1983, 0.4571], [0.1675, 0.4331], [0.1437, 0.3944],
    [0.0851, 0.3601], [0.0314, 0.3388], [0.0558, 0.3154],
    [0.0192, 0.2652], [0.0427, 0.2284], [0.1028, 0.1952],
    [0.1118, 0.2171], [0.0903, 0.2296], [0.0923, 0.2489],
    [0.1235, 0.2447], [0.154, 0.2504], [0.1856, 0.2769],
    [0.2283, 0.2553], [0.2426, 0.2198], [0.2888, 0.1741],
    [0.3795, 0.1534], [0.4618, 0.0983], [0.4852, 0.0641],
    [0.4747, 0.0242], [0.4948, 0.0192], [0.545, 0.0441],
    [0.5691, 0.0689], [0.604, 0.0825], [0.6484, 0.1376],
    [0.7046, 0.1442], [0.7462, 0.1303], [0.7734, 0.1394],
    [0.8187, 0.1349], [0.8765, 0.1595], [0.8278, 0.213],
    [0.8503, 0.2142], [0.8881, 0.2422], [0.8201, 0.2397],
    [0.81, 0.2476], [0.7482, 0.2577], [0.6619, 0.2935],
    [0.6564, 0.318], [0.6372, 0.3363], [0.6447, 0.3648],
    [0.5991, 0.3799], [0.5992, 0.4021], [0.5793, 0.4117],
    [0.6107, 0.4591], [0.6526, 0.4911], [0.6366, 0.5136],
    [0.6867, 0.5167], [0.7152, 0.5447], [0.7818, 0.5461],
    [0.8437, 0.5151], [0.8387, 0.595], [0.873, 0.601],
    [0.9155, 0.592], [0.9808, 0.6766], [0.9645, 0.6944],
    [0.9608, 0.7313], [0.9594, 0.776], [0.9299, 0.8023],
    [0.9434, 0.8218], [0.9261, 0.8395], [0.9585, 0.8837],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPeruPath(size);

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(4, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Gradient fill
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5B9BD5).withValues(alpha: 0.60),
            const Color(0xFF2B5EA7).withValues(alpha: 0.70),
            const Color(0xFF1A3360).withValues(alpha: 0.80),
          ],
        ).createShader(Offset.zero & size),
    );

    // Outline
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.28),
    );

    // Grid lines clipped inside Peru
    canvas.save();
    canvas.clipPath(path);
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.12 + i * 0.14);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.12 + i * 0.18);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    canvas.restore();

    // City dots with labels: Lima, Cusco, Arequipa, Iquitos
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final cities = <String, Offset>{
      'Lima': Offset(size.width * 0.34, size.height * 0.645),
      'Cusco': Offset(size.width * 0.73, size.height * 0.724),
      'Arequipa': Offset(size.width * 0.76, size.height * 0.877),
      'Iquitos': Offset(size.width * 0.63, size.height * 0.201),
    };

    // Route line connecting cities
    final routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final routePath = Path()
      ..moveTo(cities['Iquitos']!.dx, cities['Iquitos']!.dy)
      ..lineTo(cities['Lima']!.dx, cities['Lima']!.dy)
      ..lineTo(cities['Cusco']!.dx, cities['Cusco']!.dy)
      ..lineTo(cities['Arequipa']!.dx, cities['Arequipa']!.dy);
    // Dashed route
    final metrics = routePath.computeMetrics();
    for (final m in metrics) {
      var d = 0.0;
      while (d < m.length) {
        final end = (d + 4.0).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(d, end), routePaint);
        d += 8.0;
      }
    }

    for (final entry in cities.entries) {
      final pos = entry.value;
      canvas.drawCircle(pos, 6, glowPaint);
      canvas.drawCircle(pos, 4, ringPaint);
      canvas.drawCircle(pos, 2.2, dotPaint);

      // City name label
      final tp = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 7,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx + 5, pos.dy - tp.height / 2));
    }
  }

  Path _buildPeruPath(Size size) {
    final pts = _border
        .map((p) => Offset(p[0] * size.width, p[1] * size.height))
        .toList();
    final n = pts.length;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = pts[(i + 2) % n];
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
