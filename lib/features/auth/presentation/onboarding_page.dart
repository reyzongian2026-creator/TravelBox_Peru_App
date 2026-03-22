import 'package:flutter/material.dart';
import '../../../core/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/travelbox_logo.dart';
import 'widgets/auth_ui.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _completing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(sessionControllerProvider);
    final firstName = session.user?.firstName.trim();
    final safeName = (firstName == null || firstName.isEmpty)
        ? l10n.t('onboarding_guest_name')
        : firstName;

    final slides = [
      _TutorialSlide(
        title: '${l10n.t('onboarding_welcome_title_prefix')}, $safeName',
        subtitle: l10n.t('onboarding_intro_subtitle'),
        icon: Icons.waving_hand_outlined,
        imageAsset: 'assets/onboarding/slide_reserva.png',
      ),
      _TutorialSlide(
        title: l10n.t('onboarding_slide_1_title'),
        subtitle: l10n.t('onboarding_slide_1_subtitle'),
        icon: Icons.location_on_outlined,
        imageAsset: 'assets/onboarding/slide_reserva.png',
      ),
      _TutorialSlide(
        title: l10n.t('onboarding_slide_2_title'),
        subtitle: l10n.t('onboarding_slide_2_subtitle'),
        icon: Icons.qr_code_2_outlined,
        imageAsset: 'assets/onboarding/slide_pago.png',
      ),
      _TutorialSlide(
        title: l10n.t('onboarding_slide_3_title'),
        subtitle: l10n.t('onboarding_slide_3_subtitle'),
        icon: Icons.luggage_outlined,
        imageAsset: 'assets/onboarding/slide_recojo.png',
      ),
    ];

    final isLast = _currentIndex == slides.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AuthUi.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: TravelBoxLogo(compact: true, showSubtitle: false),
                    ),
                    TextButton(
                      onPressed: _completing ? null : _finishTutorial,
                      child: Text(context.l10n.t('omitir')),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return _SlideCard(slide: slide);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(slides.length, (index) {
                        final selected = index == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: selected ? 26 : 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: selected
                                ? const Color(0xFFF29F05)
                                : const Color(0xFF9FB3C8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _completing
                          ? null
                          : () {
                              if (isLast) {
                                _finishTutorial();
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: const Color(0xFFF29F05),
                        foregroundColor: const Color(0xFF1B2735),
                      ),
                      child: Text(
                        _completing
                            ? l10n.t('onboarding_loading')
                            : (isLast
                                  ? l10n.t('onboarding_start_now')
                                  : l10n.t('next')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishTutorial() async {
    if (_completing) {
      return;
    }
    setState(() => _completing = true);
    try {
      await ref.read(sessionControllerProvider.notifier).completeOnboarding();
    } catch (_) {}
    final session = ref.read(sessionControllerProvider);
    if (!mounted) {
      return;
    }
    if (session.needsProfileCompletion) {
      context.go('/profile/complete');
      return;
    }
    context.go('/discovery');
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide});

  final _TutorialSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF14324A), Color(0xFF1F6E8C)],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(slide.icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              slide.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF102A43),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              slide.subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.4,
                color: const Color(0xFF334E68),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(child: _SlideImage(imageAsset: slide.imageAsset)),
          ],
        ),
      ),
    );
  }
}

class _SlideImage extends StatelessWidget {
  const _SlideImage({required this.imageAsset});

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          imageAsset,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _TutorialSlide {
  const _TutorialSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imageAsset,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String imageAsset;
}
