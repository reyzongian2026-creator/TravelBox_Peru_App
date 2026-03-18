import 'package:flutter/material.dart';

class AuthTeddyAnimation extends StatelessWidget {
  const AuthTeddyAnimation({
    required this.animation,
    required this.compact,
    super.key,
  });

  final String animation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isChecking = animation == 'test';
    final isHandsUp = animation == 'hands_up';
    final isSuccess = animation == 'success';
    final isFail = animation == 'fail';
    final rotation = isChecking
        ? -0.03
        : isFail
        ? 0.035
        : 0.0;
    final scale = isSuccess ? 1.05 : 1.0;
    final yOffset = isHandsUp ? -4.0 : 0.0;

    return IgnorePointer(
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 240),
        turns: rotation,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 240),
          scale: scale,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 240),
            offset: Offset(0, yOffset / 120),
            child: SizedBox(
              width: compact ? 170 : 220,
              height: compact ? 170 : 220,
              child: Image.asset(
                'assets/branding/teddy_bear.gif',
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

