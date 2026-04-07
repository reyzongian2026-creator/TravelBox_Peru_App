import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../core/theme/brand_tokens.dart';

/// Shows a confetti celebration burst over the current screen when a payment
/// is confirmed. Call [PaymentCelebration.show] once and it auto-disposes.
class PaymentCelebration {
  PaymentCelebration._();

  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationWidget(onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _CelebrationWidget extends StatefulWidget {
  const _CelebrationWidget({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget> {
  late final ConfettiController _controller;

  static const _confettiColors = [
    TravelBoxBrand.primaryBlue,
    TravelBoxBrand.terracotta,
    TravelBoxBrand.statusSuccess,
    TravelBoxBrand.statusWarning,
    TravelBoxBrand.seafoam,
    TravelBoxBrand.copper,
  ];

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(milliseconds: 2500));
    _controller.play();
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: pi / 2, // downward
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.06,
              numberOfParticles: 20,
              gravity: 0.3,
              shouldLoop: false,
              colors: _confettiColors,
              strokeWidth: 1,
              strokeColor: Colors.transparent,
            ),
          ),
          // Second burst from center-left
          Positioned(
            left: MediaQuery.of(context).size.width * 0.2,
            top: MediaQuery.of(context).size.height * 0.1,
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: pi / 3,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.04,
              numberOfParticles: 10,
              gravity: 0.35,
              shouldLoop: false,
              colors: _confettiColors,
            ),
          ),
          // Third burst from center-right
          Positioned(
            right: MediaQuery.of(context).size.width * 0.2,
            top: MediaQuery.of(context).size.height * 0.1,
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirection: 2 * pi / 3,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.04,
              numberOfParticles: 10,
              gravity: 0.35,
              shouldLoop: false,
              colors: _confettiColors,
            ),
          ),
        ],
      ),
    );
  }
}
