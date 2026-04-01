import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Premium Peruvian llama bust-portrait mascot for the InkaVoy auth flow.
///
/// Based on "Blind Box Series" figurine style — soft, rounded, expressive,
/// with fluffy wool, chullo hat, Andean collar, and colorful pompoms.
///
/// States: idle, test (eye tracking), hands_up, hands_down, success, fail
/// Features: random blink, ear spring physics, idle micro-expressions,
/// pompom pendulum, organic cubic Bézier curves, smooth transitions.
class AuthLlamaAnimation extends StatefulWidget {
  const AuthLlamaAnimation({
    required this.animation,
    required this.compact,
    this.lookOffsetX = 0,
    super.key,
  });

  final String animation;
  final bool compact;
  final double lookOffsetX;

  @override
  State<AuthLlamaAnimation> createState() => _AuthLlamaAnimationState();
}

class _AuthLlamaAnimationState extends State<AuthLlamaAnimation>
    with TickerProviderStateMixin {
  // ── idle breathing / sway ──
  late final AnimationController _idleCtrl;
  // ── state transition (hands up/down, success bounce, fail shake) ──
  late final AnimationController _transCtrl;
  // ── smooth eye tracking interpolation ──
  late final AnimationController _lookCtrl;
  // ── random blink ──
  late final AnimationController _blinkCtrl;
  // ── ear spring bounce on state change ──
  late final AnimationController _earBounceCtrl;

  double _prevLookX = 0;
  double _targetLookX = 0;

  Timer? _blinkTimer;
  final math.Random _rng = math.Random();
  bool _isBlinking = false;

  // ear spring phase (0 = rest, animates on state change)
  double _earSpringValue = 0;

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);

    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _lookCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _blinkCtrl.reverse();
        } else if (s == AnimationStatus.dismissed) {
          _isBlinking = false;
        }
      });

    _earBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        _earSpringValue =
            math.sin(_earBounceCtrl.value * math.pi * 3) *
            (1 - _earBounceCtrl.value) *
            0.12;
      });

    _prevLookX = widget.lookOffsetX;
    _targetLookX = widget.lookOffsetX;

    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    final delay = Duration(milliseconds: 2500 + _rng.nextInt(3500));
    _blinkTimer = Timer(delay, () {
      if (!mounted) return;
      if (!_isHandsUp && !_isSuccess) {
        _isBlinking = true;
        _blinkCtrl.forward(from: 0);
      }
      _scheduleNextBlink();
    });
  }

  bool get _isHandsUp => widget.animation == 'hands_up';
  bool get _isSuccess => widget.animation == 'success';

  @override
  void didUpdateWidget(covariant AuthLlamaAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      _transCtrl.forward(from: 0);
      _earBounceCtrl.forward(from: 0);
    }
    if ((widget.lookOffsetX - _targetLookX).abs() > 0.01) {
      _prevLookX = _smoothLookX;
      _targetLookX = widget.lookOffsetX;
      _lookCtrl.forward(from: 0);
    }
  }

  double get _smoothLookX {
    final t = Curves.easeOut.transform(_lookCtrl.value);
    return _prevLookX + (_targetLookX - _prevLookX) * t;
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idleCtrl.dispose();
    _transCtrl.dispose();
    _lookCtrl.dispose();
    _blinkCtrl.dispose();
    _earBounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.compact ? 180.0 : 240.0;
    return IgnorePointer(
      child: SizedBox(
        width: sz,
        height: sz,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _idleCtrl,
            _transCtrl,
            _lookCtrl,
            _blinkCtrl,
            _earBounceCtrl,
          ]),
          builder: (_, _) => CustomPaint(
            painter: _LlamaBustPainter(
              idlePhase: _idleCtrl.value,
              transPhase: _transCtrl.value,
              eyeX: _smoothLookX.clamp(-1.0, 1.0),
              animState: widget.animation,
              blinkPhase: _blinkCtrl.value,
              isBlinking: _isBlinking,
              earSpring: _earSpringValue,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PREMIUM LLAMA BUST-PORTRAIT PAINTER
//  Based on "Blind Box Series" figurine style
// ═══════════════════════════════════════════════════════════════════

class _LlamaBustPainter extends CustomPainter {
  const _LlamaBustPainter({
    required this.idlePhase,
    required this.transPhase,
    required this.eyeX,
    required this.animState,
    required this.blinkPhase,
    required this.isBlinking,
    required this.earSpring,
  });

  final double idlePhase;
  final double transPhase;
  final double eyeX;
  final String animState;
  final double blinkPhase;
  final bool isBlinking;
  final double earSpring;

  // ── wool palette (softer, more pastel for figurine look) ──
  static const _cream = Color(0xFFF5EDD8);
  static const _woolLight = Color(0xFFFCF6EA);
  static const _woolHighlight = Color(0xFFFFFDF5);
  static const _wool = Color(0xFFECDFC0);
  static const _tan = Color(0xFFDCC8A0);
  static const _shadow = Color(0xFFC8B48C);

  // ── feature palette ──
  static const _ink = Color(0xFF2C1810);
  static const _darkBrown = Color(0xFF5A3D20);
  static const _brown = Color(0xFF8A6540);
  static const _nose = Color(0xFFE8A888);
  static const _blush = Color(0xFFF4A0A0);
  static const _earInner = Color(0xFFDEA080);
  static const _mouthPink = Color(0xFFD05050);

  // ── hat & textile palette ──
  static const _hatRed = Color(0xFFCC3838);
  static const _hatRedDark = Color(0xFFA82828);
  static const _hatRedDeep = Color(0xFF8E2020);
  static const _hatTeal = Color(0xFF28B8A0);
  static const _hatGold = Color(0xFFE8B848);
  static const _hatOrange = Color(0xFFE88530);

  // ── pompom colours (brighter, more saturated like figurine) ──
  static const _pompYellow = Color(0xFFF0C830);
  static const _pompTeal = Color(0xFF28C8B0);
  static const _pompRed = Color(0xFFE04848);
  static const _pompOrange = Color(0xFFE88040);
  static const _pompBlue = Color(0xFF38A8D8);

  bool get _isHandsUp => animState == 'hands_up';
  bool get _isHandsDown => animState == 'hands_down';
  bool get _isSuccess => animState == 'success';
  bool get _isFail => animState == 'fail';

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── animation math ──
    final breathY = math.sin(idlePhase * math.pi * 2) * 1.8;
    final breathScale = 1.0 + math.sin(idlePhase * math.pi * 2) * 0.003;
    final bounceY =
        _isSuccess ? math.sin(transPhase * math.pi) * -12.0 : 0.0;
    final shakeX = _isFail
        ? math.sin(transPhase * math.pi * 5) * 4.0 * (1 - transPhase)
        : 0.0;
    final earSwing = math.sin(idlePhase * math.pi * 4) * 0.07 + earSpring;
    final headTilt = _isFail ? math.sin(transPhase * math.pi) * 0.08 : 0.0;
    final pompSwing = math.sin(idlePhase * math.pi * 2 + 0.8) * 3.0;
    // micro idle variation — subtle head sway
    final microSwayX = math.sin(idlePhase * math.pi * 1.3 + 2.1) * 0.6;

    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.scale(breathScale);
    canvas.translate(-w * 0.5, -h * 0.5);
    canvas.translate(shakeX + microSwayX, breathY + bounceY);

    _drawShadow(canvas, w, h);
    _drawBase(canvas, w, h);
    _drawNeck(canvas, w, h);
    _drawCollar(canvas, w, h);
    _drawCollarPompoms(canvas, w, h, pompSwing);

    // head group — tilts on fail
    canvas.save();
    if (headTilt != 0) {
      canvas.translate(w * 0.5, h * 0.42);
      canvas.rotate(headTilt);
      canvas.translate(-w * 0.5, -h * 0.42);
    }

    _drawEars(canvas, w, h, earSwing);
    _drawHeadShape(canvas, w, h);
    _drawWoolFluff(canvas, w, h);
    _drawChullo(canvas, w, h);
    _drawHatPatterns(canvas, w, h);
    _drawHatEarFlaps(canvas, w, h, earSwing);
    _drawHatSidePompoms(canvas, w, h, earSwing, pompSwing);
    _drawHatTopPompom(canvas, w, h, pompSwing);
    _drawSnout(canvas, w, h);
    _drawEyes(canvas, w, h);
    _drawEyebrows(canvas, w, h);
    _drawMouth(canvas, w, h);
    _drawBlush(canvas, w, h);
    if (_isHandsUp || (_isHandsDown && transPhase < 0.65)) {
      _drawCoveringHooves(canvas, w, h);
    }

    canvas.restore();
    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────────
  //  SHADOW (ground)
  // ────────────────────────────────────────────────────────────────
  void _drawShadow(Canvas canvas, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.97),
        width: w * 0.55,
        height: h * 0.04,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  BASE PEDESTAL (figurine-style)
  // ────────────────────────────────────────────────────────────────
  void _drawBase(Canvas canvas, double w, double h) {
    // subtle silver/grey base ring like the figurine
    final basePath = Path()
      ..moveTo(w * 0.25, h * 0.92)
      ..cubicTo(w * 0.25, h * 0.96, w * 0.75, h * 0.96, w * 0.75, h * 0.92)
      ..cubicTo(w * 0.75, h * 0.89, w * 0.25, h * 0.89, w * 0.25, h * 0.92)
      ..close();
    final baseShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFD0D0D5),
        const Color(0xFFB8B8C0),
        const Color(0xFFA8A8B0),
      ],
    ).createShader(Rect.fromLTWH(w * 0.25, h * 0.89, w * 0.5, h * 0.07));
    canvas.drawPath(basePath, Paint()..shader = baseShader);
    // highlight on base
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, h * 0.905)
        ..cubicTo(w * 0.30, h * 0.895, w * 0.70, h * 0.895, w * 0.70, h * 0.905),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  NECK
  // ────────────────────────────────────────────────────────────────
  void _drawNeck(Canvas canvas, double w, double h) {
    final path = Path()
      ..moveTo(w * 0.35, h * 0.58)
      ..cubicTo(w * 0.33, h * 0.65, w * 0.32, h * 0.72, w * 0.30, h * 0.82)
      ..cubicTo(w * 0.38, h * 0.88, w * 0.62, h * 0.88, w * 0.70, h * 0.82)
      ..cubicTo(w * 0.68, h * 0.72, w * 0.67, h * 0.65, w * 0.65, h * 0.58)
      ..close();
    final shader = RadialGradient(
      center: const Alignment(0, -0.2),
      radius: 1.0,
      colors: [_woolLight, _cream, _wool],
    ).createShader(Rect.fromLTWH(w * 0.30, h * 0.58, w * 0.40, h * 0.30));
    canvas.drawPath(path, Paint()..shader = shader);

    // wool texture on neck
    final woolP = Paint()
      ..color = _woolHighlight.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final cx = w * (0.38 + i * 0.04);
      final cy = h * (0.63 + (i % 2) * 0.04);
      _drawWoolCurl(canvas, cx, cy, w * 0.018, woolP);
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  ANDEAN COLLAR (bigger, more prominent like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawCollar(Canvas canvas, double w, double h) {
    final collarPath = Path()
      ..moveTo(w * 0.20, h * 0.70)
      ..cubicTo(w * 0.18, h * 0.74, w * 0.18, h * 0.80, w * 0.22, h * 0.86)
      ..cubicTo(w * 0.30, h * 0.92, w * 0.70, h * 0.92, w * 0.78, h * 0.86)
      ..cubicTo(w * 0.82, h * 0.80, w * 0.82, h * 0.74, w * 0.80, h * 0.70)
      ..cubicTo(w * 0.70, h * 0.65, w * 0.30, h * 0.65, w * 0.20, h * 0.70)
      ..close();

    // base red with gradient
    final cShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_hatRed, _hatRedDark, _hatRedDeep],
    ).createShader(Rect.fromLTWH(w * 0.18, h * 0.65, w * 0.64, h * 0.27));
    canvas.drawPath(collarPath, Paint()..shader = cShader);

    // pattern bands (thicker, more visible)
    final bandPaint = Paint()
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // teal band
    bandPaint.color = _hatTeal;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.22, h * 0.74)
        ..cubicTo(w * 0.35, h * 0.71, w * 0.65, h * 0.71, w * 0.78, h * 0.74),
      bandPaint,
    );
    // gold band
    bandPaint.color = _hatGold;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.21, h * 0.78)
        ..cubicTo(w * 0.35, h * 0.75, w * 0.65, h * 0.75, w * 0.79, h * 0.78),
      bandPaint,
    );
    // teal band lower
    bandPaint.color = _hatTeal;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.22, h * 0.82)
        ..cubicTo(w * 0.35, h * 0.80, w * 0.65, h * 0.80, w * 0.78, h * 0.82),
      bandPaint,
    );
    // gold accent
    bandPaint.color = _hatGold.withValues(alpha: 0.70);
    bandPaint.strokeWidth = 2.0;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.23, h * 0.86)
        ..cubicTo(w * 0.36, h * 0.84, w * 0.64, h * 0.84, w * 0.77, h * 0.86),
      bandPaint,
    );

    // diamond motifs
    final diamPaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i < 6; i++) {
      final dx = w * (0.32 + i * 0.07);
      _drawDiamond(canvas, dx, h * 0.765, w * 0.010, diamPaint);
    }

    // subtle border
    canvas.drawPath(
      collarPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _darkBrown.withValues(alpha: 0.20)
        ..strokeWidth = 1.0,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  COLLAR HANGING POMPOMS (bigger, more colorful like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawCollarPompoms(Canvas canvas, double w, double h, double swing) {
    final colors = [
      _pompBlue, _pompYellow, _pompOrange, _pompRed,
      _pompTeal, _pompYellow, _pompBlue,
    ];
    for (var i = 0; i < 7; i++) {
      final bx = w * (0.26 + i * 0.07);
      final dx = swing * (i.isEven ? 1 : -1) * 0.4;
      final threadLen = h * 0.04 + (i % 3) * h * 0.008;

      // thread
      final threadBot = Offset(bx + dx, h * 0.885 + threadLen);
      canvas.drawLine(
        Offset(bx, h * 0.88),
        threadBot,
        Paint()
          ..color = _hatGold.withValues(alpha: 0.65)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
      // pompom (bigger)
      _drawFuzzyPompom(
        canvas,
        Offset(threadBot.dx, threadBot.dy + w * 0.015),
        w * 0.024,
        colors[i],
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  EARS (bigger, more upright like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawEars(Canvas canvas, double w, double h, double swing) {
    _drawSingleEar(canvas, w, h, true, -0.25 + swing);
    _drawSingleEar(canvas, w, h, false, 0.25 - swing);
  }

  void _drawSingleEar(
    Canvas canvas,
    double w,
    double h,
    bool isLeft,
    double angle,
  ) {
    final cx = isLeft ? w * 0.28 : w * 0.72;
    final cy = h * 0.19;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // larger ear like figurine
    final outer = Path()
      ..moveTo(-10, 14)
      ..cubicTo(-14, 0, -10, -20, 0, -30)
      ..cubicTo(10, -20, 14, 0, 10, 14)
      ..close();

    // ear shadow
    canvas.drawPath(
      outer,
      Paint()
        ..color = _shadow.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // outer ear
    final outerShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_woolLight, _cream, _wool],
    ).createShader(const Rect.fromLTWH(-14, -30, 28, 44));
    canvas.drawPath(outer, Paint()..shader = outerShader);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _tan.withValues(alpha: 0.40)
        ..strokeWidth = 0.9,
    );

    // inner ear (pink)
    final inner = Path()
      ..moveTo(-6, 11)
      ..cubicTo(-9, 0, -7, -14, 0, -22)
      ..cubicTo(7, -14, 9, 0, 6, 11)
      ..close();
    canvas.drawPath(inner, Paint()..color = _earInner.withValues(alpha: 0.35));

    // inner ear highlight
    canvas.drawPath(
      Path()
        ..moveTo(-3, 6)
        ..cubicTo(-5, -2, -3, -10, 0, -16)
        ..cubicTo(3, -10, 5, -2, 3, 6)
        ..close(),
      Paint()..color = _earInner.withValues(alpha: 0.15),
    );

    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────────
  //  HEAD SHAPE (rounder, chubbier like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawHeadShape(Canvas canvas, double w, double h) {
    // More rounded, figurine-like head
    final headPath = Path()
      ..moveTo(w * 0.22, h * 0.42)
      ..cubicTo(w * 0.20, h * 0.30, w * 0.28, h * 0.20, w * 0.50, h * 0.19)
      ..cubicTo(w * 0.72, h * 0.20, w * 0.80, h * 0.30, w * 0.78, h * 0.42)
      ..cubicTo(w * 0.77, h * 0.52, w * 0.70, h * 0.62, w * 0.50, h * 0.63)
      ..cubicTo(w * 0.30, h * 0.62, w * 0.23, h * 0.52, w * 0.22, h * 0.42)
      ..close();

    // multi-stop radial gradient for 3D depth
    final headRect = Rect.fromLTWH(w * 0.20, h * 0.19, w * 0.60, h * 0.44);
    final shader = RadialGradient(
      center: const Alignment(-0.10, -0.35),
      radius: 0.90,
      colors: [_woolHighlight, _woolLight, _cream, _wool, _tan],
      stops: const [0.0, 0.25, 0.50, 0.80, 1.0],
    ).createShader(headRect);
    canvas.drawPath(headPath, Paint()..shader = shader);

    // subtle edge shadow for 3D depth
    canvas.drawPath(
      headPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _shadow.withValues(alpha: 0.20)
        ..strokeWidth = 1.2,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  WOOL FLUFF (more layered, fluffy like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawWoolFluff(Canvas canvas, double w, double h) {
    final fluffP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // left cheek fluff (multiple layers)
    fluffP.color = _woolHighlight.withValues(alpha: 0.50);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 2; col++) {
        final cx = w * (0.23 + col * 0.03);
        final cy = h * (0.33 + row * 0.06);
        _drawWoolCurl(canvas, cx, cy, w * 0.020, fluffP);
      }
    }

    // right cheek fluff
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 2; col++) {
        final cx = w * (0.74 + col * 0.03);
        final cy = h * (0.33 + row * 0.06);
        _drawWoolCurl(canvas, cx, cy, w * 0.020, fluffP);
      }
    }

    // forehead/crown fluff (below hat)
    fluffP.color = _woolLight.withValues(alpha: 0.55);
    fluffP.strokeWidth = 1.8;
    for (var i = 0; i < 5; i++) {
      final cx = w * (0.36 + i * 0.07);
      final cy = h * 0.25 + (i % 2) * h * 0.012;
      _drawWoolCurl(canvas, cx, cy, w * 0.018, fluffP);
    }

    // chin fluff
    fluffP.color = _woolHighlight.withValues(alpha: 0.45);
    fluffP.strokeWidth = 1.4;
    for (var i = 0; i < 4; i++) {
      final cx = w * (0.40 + i * 0.06);
      final cy = h * 0.58 + (i % 2) * h * 0.010;
      _drawWoolCurl(canvas, cx, cy, w * 0.016, fluffP);
    }

    // side wool tufts (big fluffy patches on cheeks)
    _drawFluffPatch(canvas, w * 0.24, h * 0.40, w * 0.05, true);
    _drawFluffPatch(canvas, w * 0.76, h * 0.40, w * 0.05, false);
  }

  void _drawWoolCurl(Canvas canvas, double x, double y, double size, Paint p) {
    canvas.drawPath(
      Path()
        ..moveTo(x - size, y)
        ..cubicTo(x - size, y - size * 1.2, x + size, y - size * 1.2, x + size, y),
      p,
    );
  }

  void _drawFluffPatch(Canvas canvas, double cx, double cy, double r, bool left) {
    final dir = left ? -1.0 : 1.0;
    for (var i = 0; i < 3; i++) {
      final angle = (i - 1) * 0.4;
      final px = cx + dir * math.cos(angle) * r * 0.6;
      final py = cy + math.sin(angle) * r * 0.8;
      canvas.drawCircle(
        Offset(px, py),
        r * 0.3,
        Paint()..color = _woolLight.withValues(alpha: 0.25),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  CHULLO HAT (rounder dome, more detailed like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawChullo(Canvas canvas, double w, double h) {
    // Rounded dome shape
    final hatPath = Path()
      ..moveTo(w * 0.24, h * 0.27)
      ..cubicTo(w * 0.24, h * 0.22, w * 0.28, h * 0.14, w * 0.34, h * 0.09)
      ..cubicTo(w * 0.40, h * 0.05, w * 0.46, h * 0.04, w * 0.50, h * 0.035)
      ..cubicTo(w * 0.54, h * 0.04, w * 0.60, h * 0.05, w * 0.66, h * 0.09)
      ..cubicTo(w * 0.72, h * 0.14, w * 0.76, h * 0.22, w * 0.76, h * 0.27)
      ..lineTo(w * 0.24, h * 0.27)
      ..close();

    // gradient for 3D dome
    final shader = RadialGradient(
      center: const Alignment(-0.15, -0.5),
      radius: 1.2,
      colors: [
        const Color(0xFFE04040),
        _hatRed,
        _hatRedDark,
        _hatRedDeep,
      ],
      stops: const [0.0, 0.30, 0.70, 1.0],
    ).createShader(Rect.fromLTWH(w * 0.24, h * 0.035, w * 0.52, h * 0.235));
    canvas.drawPath(hatPath, Paint()..shader = shader);

    // hat brim — thicker overhang
    final brimPath = Path()
      ..moveTo(w * 0.22, h * 0.27)
      ..cubicTo(w * 0.35, h * 0.285, w * 0.65, h * 0.285, w * 0.78, h * 0.27)
      ..cubicTo(w * 0.65, h * 0.31, w * 0.35, h * 0.31, w * 0.22, h * 0.27)
      ..close();
    canvas.drawPath(brimPath, Paint()..color = _hatRedDark);

    // brim highlight
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, h * 0.272)
        ..cubicTo(w * 0.40, h * 0.280, w * 0.60, h * 0.280, w * 0.70, h * 0.272),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // forehead shadow from brim
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.26, h * 0.28)
        ..cubicTo(w * 0.38, h * 0.30, w * 0.62, h * 0.30, w * 0.74, h * 0.28)
        ..cubicTo(w * 0.62, h * 0.33, w * 0.38, h * 0.33, w * 0.26, h * 0.28),
      Paint()..color = _shadow.withValues(alpha: 0.15),
    );

    // dome highlight (3D shine)
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.35, h * 0.08)
        ..cubicTo(w * 0.40, h * 0.06, w * 0.48, h * 0.055, w * 0.52, h * 0.06),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HAT PATTERN BANDS (more detailed geometric patterns)
  // ────────────────────────────────────────────────────────────────
  void _drawHatPatterns(Canvas canvas, double w, double h) {
    final bandY1 = h * 0.11;
    final bandY2 = h * 0.155;
    final bandY3 = h * 0.20;
    final bandY4 = h * 0.24;

    // teal band with zigzag
    _drawCurvedBand(canvas, w, bandY1, 3.5, _hatTeal);
    _drawZigzag(canvas, w, bandY1 - 5, bandY1 + 5, _hatGold.withValues(alpha: 0.85), 1.3);

    // gold band with diamonds
    _drawCurvedBand(canvas, w, bandY2, 3.5, _hatGold);
    final diamPaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i < 5; i++) {
      _drawDiamond(canvas, w * (0.36 + i * 0.07), bandY2, w * 0.008, diamPaint);
    }

    // orange band with zigzag
    _drawCurvedBand(canvas, w, bandY3, 3.0, _hatOrange);
    _drawZigzag(canvas, w, bandY3 - 4, bandY3 + 4, _hatTeal.withValues(alpha: 0.75), 1.1);

    // thin teal accent band
    _drawCurvedBand(canvas, w, bandY4, 2.0, _hatTeal.withValues(alpha: 0.70));

    // gold trim lines
    final trimPaint = Paint()
      ..color = _hatGold.withValues(alpha: 0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.30, bandY1 + 9), Offset(w * 0.70, bandY1 + 9), trimPaint);
    canvas.drawLine(Offset(w * 0.29, bandY2 + 9), Offset(w * 0.71, bandY2 + 9), trimPaint);
  }

  void _drawCurvedBand(Canvas canvas, double w, double y, double thickness, Color color) {
    final halfW = w * 0.22;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.50 - halfW, y)
        ..cubicTo(w * 0.50 - halfW * 0.3, y - 2.5, w * 0.50 + halfW * 0.3, y - 2.5, w * 0.50 + halfW, y),
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawZigzag(Canvas canvas, double w, double yTop, double yBot, Color color, double sw) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    const steps = 9;
    final startX = w * 0.32;
    final endX = w * 0.68;
    final stepW = (endX - startX) / steps;
    for (var i = 0; i <= steps; i++) {
      final x = startX + i * stepW;
      final y = i.isEven ? yTop : yBot;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  // ────────────────────────────────────────────────────────────────
  //  HAT EAR FLAPS (wider, with more detail)
  // ────────────────────────────────────────────────────────────────
  void _drawHatEarFlaps(Canvas canvas, double w, double h, double swing) {
    _drawSingleFlap(canvas, w, h, true, swing);
    _drawSingleFlap(canvas, w, h, false, -swing);
  }

  void _drawSingleFlap(Canvas canvas, double w, double h, bool isLeft, double swing) {
    final cx = isLeft ? w * 0.25 : w * 0.75;
    final topY = h * 0.25;
    final botY = h * 0.47;
    final flapW = w * 0.10;
    final dx = swing * 7;

    final path = Path()
      ..moveTo(cx - flapW, topY)
      ..lineTo(cx + flapW, topY)
      ..cubicTo(
        cx + flapW + dx * 0.2, topY + (botY - topY) * 0.3,
        cx + flapW * 0.8 + dx * 0.4, topY + (botY - topY) * 0.7,
        cx + flapW * 0.55 + dx, botY,
      )
      ..lineTo(cx - flapW * 0.55 + dx, botY)
      ..cubicTo(
        cx - flapW * 0.8 + dx * 0.4, topY + (botY - topY) * 0.7,
        cx - flapW + dx * 0.2, topY + (botY - topY) * 0.3,
        cx - flapW, topY,
      )
      ..close();

    // gradient for 3D
    final flapShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_hatRed, _hatRedDark],
    ).createShader(Rect.fromLTWH(cx - flapW, topY, flapW * 2, botY - topY));
    canvas.drawPath(path, Paint()..shader = flapShader);

    // pattern on flap
    final midY = (topY + botY) / 2;
    final bandP = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    bandP.color = _hatTeal;
    canvas.drawLine(
      Offset(cx - flapW * 0.5 + dx * 0.15, midY - 5),
      Offset(cx + flapW * 0.5 + dx * 0.15, midY - 5),
      bandP,
    );
    bandP.color = _hatGold;
    canvas.drawLine(
      Offset(cx - flapW * 0.5 + dx * 0.20, midY + 2),
      Offset(cx + flapW * 0.5 + dx * 0.20, midY + 2),
      bandP,
    );
    bandP.color = _hatOrange;
    canvas.drawLine(
      Offset(cx - flapW * 0.5 + dx * 0.25, midY + 9),
      Offset(cx + flapW * 0.5 + dx * 0.25, midY + 9),
      bandP,
    );

    // border
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _darkBrown.withValues(alpha: 0.15)
        ..strokeWidth = 0.8,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HAT SIDE POMPOMS (on flap strings — like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawHatSidePompoms(Canvas canvas, double w, double h, double swing, double pompSwing) {
    // Left flap pompom
    final lFlapBot = Offset(w * 0.25 + swing * 7, h * 0.47);
    final lString1 = Offset(lFlapBot.dx + pompSwing * 0.4, lFlapBot.dy + h * 0.06);
    final lString2 = Offset(lFlapBot.dx - pompSwing * 0.3, lFlapBot.dy + h * 0.09);

    // strings
    _drawPompomString(canvas, lFlapBot, lString1);
    _drawPompomString(canvas, lFlapBot, lString2);
    // pompoms
    _drawFuzzyPompom(canvas, Offset(lString1.dx, lString1.dy + w * 0.012), w * 0.028, _pompYellow);
    _drawFuzzyPompom(canvas, Offset(lString2.dx, lString2.dy + w * 0.012), w * 0.025, _pompTeal);

    // Right flap pompom
    final rFlapBot = Offset(w * 0.75 - swing * 7, h * 0.47);
    final rString1 = Offset(rFlapBot.dx - pompSwing * 0.4, rFlapBot.dy + h * 0.06);
    final rString2 = Offset(rFlapBot.dx + pompSwing * 0.3, rFlapBot.dy + h * 0.09);

    _drawPompomString(canvas, rFlapBot, rString1);
    _drawPompomString(canvas, rFlapBot, rString2);
    _drawFuzzyPompom(canvas, Offset(rString1.dx, rString1.dy + w * 0.012), w * 0.028, _pompRed);
    _drawFuzzyPompom(canvas, Offset(rString2.dx, rString2.dy + w * 0.012), w * 0.025, _pompOrange);
  }

  void _drawPompomString(Canvas canvas, Offset from, Offset to) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = _hatGold.withValues(alpha: 0.60)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HAT TOP POMPOM (bigger, fluffier)
  // ────────────────────────────────────────────────────────────────
  void _drawHatTopPompom(Canvas canvas, double w, double h, double swing) {
    final topX = w * 0.50 + swing * 0.3;
    final topY = h * 0.035;
    // string
    canvas.drawLine(
      Offset(w * 0.50, h * 0.05),
      Offset(topX, topY - h * 0.005),
      Paint()
        ..color = _hatGold.withValues(alpha: 0.50)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
    _drawFuzzyPompom(canvas, Offset(topX, topY - h * 0.012), w * 0.038, _pompRed);
  }

  // ────────────────────────────────────────────────────────────────
  //  SNOUT (softer, rounder like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawSnout(Canvas canvas, double w, double h) {
    final snoutCenter = Offset(w * 0.50, h * 0.50);
    final snoutRect = Rect.fromCenter(
      center: snoutCenter,
      width: w * 0.26,
      height: h * 0.10,
    );

    // snout with 3D gradient
    final shader = RadialGradient(
      center: const Alignment(0, -0.4),
      radius: 0.9,
      colors: [
        _nose.withValues(alpha: 0.90),
        _nose,
        _nose.withValues(alpha: 0.70),
      ],
    ).createShader(snoutRect);
    canvas.drawOval(snoutRect, Paint()..shader = shader);

    // subtle darker edge
    canvas.drawOval(
      snoutRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.18)
        ..strokeWidth = 0.8,
    );

    // nostrils (slightly angled like figurine)
    final np = Paint()..color = _darkBrown.withValues(alpha: 0.45);
    // left nostril
    canvas.save();
    canvas.translate(w * 0.465, h * 0.508);
    canvas.rotate(-0.1);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.045, height: h * 0.024),
      np,
    );
    canvas.restore();
    // right nostril
    canvas.save();
    canvas.translate(w * 0.535, h * 0.508);
    canvas.rotate(0.1);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.045, height: h * 0.024),
      np,
    );
    canvas.restore();

    // nose highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.49, h * 0.49),
        width: w * 0.08,
        height: h * 0.03,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  EYES (bigger, more expressive like figurine — with blink)
  // ────────────────────────────────────────────────────────────────
  void _drawEyes(Canvas canvas, double w, double h) {
    final lEye = Offset(w * 0.38, h * 0.38);
    final rEye = Offset(w * 0.62, h * 0.38);
    final r = w * 0.060; // bigger eyes

    if (_isHandsUp) {
      _drawSqueezeEye(canvas, lEye, r);
      _drawSqueezeEye(canvas, rEye, r);
    } else if (_isHandsDown && transPhase < 0.5) {
      _drawSqueezeEye(canvas, lEye, r);
      _drawSqueezeEye(canvas, rEye, r);
    } else if (_isFail && transPhase > 0.30) {
      _drawSadEye(canvas, lEye, r, true);
      _drawSadEye(canvas, rEye, r, false);
    } else if (_isSuccess && transPhase > 0.20) {
      _drawHappyEye(canvas, lEye, r);
      _drawHappyEye(canvas, rEye, r);
    } else if (isBlinking && blinkPhase > 0.3) {
      // blink: gradual close/open
      final blinkT = blinkPhase.clamp(0.0, 1.0);
      _drawBlinkingEye(canvas, lEye, r, eyeX * r * 0.45, blinkT);
      _drawBlinkingEye(canvas, rEye, r, eyeX * r * 0.45, blinkT);
    } else {
      final shift = eyeX * r * 0.45;
      _drawNormalEye(canvas, lEye, r, shift, true);
      _drawNormalEye(canvas, rEye, r, shift, false);
    }
  }

  void _drawNormalEye(Canvas canvas, Offset c, double r, double shiftX, bool isLeft) {
    // white with subtle shadow at top
    canvas.drawCircle(c, r, Paint()..color = Colors.white);

    // upper shadow (3D depth)
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 2, height: r * 2),
      -math.pi * 0.9,
      math.pi * 0.8,
      false,
      Paint()
        ..color = _shadow.withValues(alpha: 0.10)
        ..strokeWidth = r * 0.3
        ..style = PaintingStyle.stroke,
    );

    // thick dark outline (figurine style)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // iris (bigger, warmer brown)
    final iC = Offset(c.dx + shiftX, c.dy + 1);
    final irisR = r * 0.62;
    final irisShader = RadialGradient(
      center: const Alignment(-0.2, -0.2),
      radius: 0.8,
      colors: [const Color(0xFF5A3820), const Color(0xFF3D2010), _ink],
    ).createShader(Rect.fromCircle(center: iC, radius: irisR));
    canvas.drawCircle(iC, irisR, Paint()..shader = irisShader);

    // pupil
    canvas.drawCircle(iC, r * 0.32, Paint()..color = _ink);

    // large catchlight (top-left)
    canvas.drawCircle(
      Offset(c.dx + shiftX - r * 0.24, c.dy - r * 0.24),
      r * 0.22,
      Paint()..color = Colors.white,
    );
    // small catchlight (bottom-right)
    canvas.drawCircle(
      Offset(c.dx + shiftX + r * 0.16, c.dy + r * 0.12),
      r * 0.10,
      Paint()..color = Colors.white.withValues(alpha: 0.70),
    );

    // eyelashes (top, organic)
    final lashP = Paint()
      ..color = _ink.withValues(alpha: 0.65)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final dir = isLeft ? -1.0 : 1.0;
    // outer lash
    canvas.drawLine(
      Offset(c.dx + dir * r * 0.7, c.dy - r * 0.7),
      Offset(c.dx + dir * r * 1.0, c.dy - r * 1.0),
      lashP,
    );
    // middle lash
    canvas.drawLine(
      Offset(c.dx + dir * r * 0.3, c.dy - r * 0.9),
      Offset(c.dx + dir * r * 0.4, c.dy - r * 1.2),
      lashP,
    );
  }

  void _drawBlinkingEye(Canvas canvas, Offset c, double r, double shiftX, double blinkT) {
    // partial close — squish eye vertically
    final openH = r * 2 * (1 - blinkT * 0.85);
    if (openH < r * 0.3) {
      // almost closed — just draw line
      _drawSqueezeEye(canvas, c, r);
      return;
    }
    final rect = Rect.fromCenter(center: c, width: r * 2, height: openH);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(openH * 0.5));
    canvas.drawRRect(rr, Paint()..color = Colors.white);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // iris (clipped)
    canvas.save();
    canvas.clipRRect(rr);
    final iC = Offset(c.dx + shiftX, c.dy + 1);
    canvas.drawCircle(iC, r * 0.62, Paint()..color = const Color(0xFF3D2010));
    canvas.drawCircle(iC, r * 0.32, Paint()..color = _ink);
    canvas.drawCircle(
      Offset(c.dx + shiftX - r * 0.24, c.dy - r * 0.24),
      r * 0.22,
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  void _drawSqueezeEye(Canvas canvas, Offset c, double r) {
    // tight squeezed shut line (like figurine covering eyes)
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 2.0, height: r * 1.1),
      math.pi * 0.05,
      math.pi * 0.90,
      false,
      Paint()
        ..color = _ink
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // squeeze lines below
    canvas.drawArc(
      Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.15), width: r * 1.4, height: r * 0.5),
      0,
      math.pi,
      false,
      Paint()
        ..color = _ink.withValues(alpha: 0.30)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawSadEye(Canvas canvas, Offset c, double r, bool isLeft) {
    // sad droopy eye
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // small sad pupil looking down
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.20), r * 0.50, Paint()..color = const Color(0xFF3D2010));
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.20), r * 0.30, Paint()..color = _ink);
    // catchlight
    canvas.drawCircle(
      Offset(c.dx - r * 0.15, c.dy + r * 0.05),
      r * 0.16,
      Paint()..color = Colors.white,
    );

    // drooping eyelid (figurine sad look — inner brow raised)
    final browDir = isLeft ? 1.0 : -1.0;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 1.1, c.dy - r * 0.1 + browDir * r * 0.2)
        ..cubicTo(
          c.dx - r * 0.5, c.dy - r * 0.6,
          c.dx + r * 0.5, c.dy - r * 0.6 - browDir * r * 0.3,
          c.dx + r * 1.1, c.dy - r * 0.3 - browDir * r * 0.2,
        ),
      Paint()
        ..color = _wool
        ..strokeWidth = r * 0.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawHappyEye(Canvas canvas, Offset c, double r) {
    // upward arc (happy squint like figurine)
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 2.2, height: r * 1.6),
      math.pi * 0.10,
      math.pi * 0.80,
      false,
      Paint()
        ..color = _ink
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  EYEBROWS (subtle, expressive)
  // ────────────────────────────────────────────────────────────────
  void _drawEyebrows(Canvas canvas, double w, double h) {
    if (_isHandsUp || (_isHandsDown && transPhase < 0.5)) return;
    if (_isSuccess && transPhase > 0.20) return;

    final browP = Paint()
      ..color = _brown.withValues(alpha: 0.30)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (_isFail && transPhase > 0.30) {
      // worried brows (angled inward)
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.32, h * 0.32)
          ..cubicTo(w * 0.34, h * 0.30, w * 0.38, h * 0.305, w * 0.42, h * 0.315),
        browP,
      );
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.68, h * 0.32)
          ..cubicTo(w * 0.66, h * 0.30, w * 0.62, h * 0.305, w * 0.58, h * 0.315),
        browP,
      );
    } else {
      // neutral subtle brows
      browP.color = _brown.withValues(alpha: 0.18);
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.33, h * 0.325)
          ..cubicTo(w * 0.35, h * 0.318, w * 0.39, h * 0.315, w * 0.42, h * 0.320),
        browP,
      );
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.67, h * 0.325)
          ..cubicTo(w * 0.65, h * 0.318, w * 0.61, h * 0.315, w * 0.58, h * 0.320),
        browP,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  MOUTH (more expressive, wider range like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawMouth(Canvas canvas, double w, double h) {
    final mp = Paint()
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (_isFail && transPhase > 0.30) {
      // open-mouth worried/surprised (like top-left figurine)
      mp.color = _brown.withValues(alpha: 0.70);
      // outer mouth shape
      final mouthPath = Path()
        ..moveTo(w * 0.44, h * 0.54)
        ..cubicTo(w * 0.46, h * 0.545, w * 0.54, h * 0.545, w * 0.56, h * 0.54)
        ..cubicTo(w * 0.55, h * 0.56, w * 0.45, h * 0.56, w * 0.44, h * 0.54)
        ..close();
      canvas.drawPath(
        mouthPath,
        Paint()..color = _mouthPink.withValues(alpha: 0.60),
      );
      canvas.drawPath(mouthPath, mp);
    } else if (_isSuccess && transPhase > 0.20) {
      // big open smile (like bottom-center figurine)
      mp.color = _brown.withValues(alpha: 0.70);
      final smilePath = Path()
        ..moveTo(w * 0.42, h * 0.535)
        ..cubicTo(w * 0.45, h * 0.55, w * 0.55, h * 0.55, w * 0.58, h * 0.535)
        ..cubicTo(w * 0.56, h * 0.575, w * 0.44, h * 0.575, w * 0.42, h * 0.535)
        ..close();
      canvas.drawPath(
        smilePath,
        Paint()..color = _mouthPink.withValues(alpha: 0.50),
      );
      canvas.drawPath(smilePath, mp);
    } else {
      // gentle smile (default — like bottom-center figurine)
      mp.color = _brown.withValues(alpha: 0.55);
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.45, h * 0.540)
          ..cubicTo(w * 0.47, h * 0.548, w * 0.53, h * 0.548, w * 0.55, h * 0.540),
        mp,
      );
      // lower lip hint
      mp.color = _brown.withValues(alpha: 0.15);
      mp.strokeWidth = 1.0;
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.46, h * 0.544)
          ..cubicTo(w * 0.48, h * 0.555, w * 0.52, h * 0.555, w * 0.54, h * 0.544),
        mp,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  BLUSH (softer, rounder like figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawBlush(Canvas canvas, double w, double h) {
    final blushAlpha = _isSuccess && transPhase > 0.20 ? 0.35 : 0.20;
    final bp = Paint()
      ..color = _blush.withValues(alpha: blushAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.32, h * 0.44),
        width: w * 0.065,
        height: h * 0.035,
      ),
      bp,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.68, h * 0.44),
        width: w * 0.065,
        height: h * 0.035,
      ),
      bp,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  COVERING HOOVES (bigger, rounder, more finger-like — figurine)
  // ────────────────────────────────────────────────────────────────
  void _drawCoveringHooves(Canvas canvas, double w, double h) {
    final eyeLevel = h * 0.38;
    final startY = h * 0.90;

    double currentY;
    if (_isHandsUp) {
      final t = Curves.easeOutBack.transform(transPhase.clamp(0.0, 1.0));
      currentY = startY + (eyeLevel - startY) * t;
    } else {
      final t = Curves.easeIn.transform(transPhase.clamp(0.0, 1.0));
      currentY = eyeLevel + (startY - eyeLevel) * t;
    }

    _drawHoof(canvas, Offset(w * 0.36, currentY), w, true);
    _drawHoof(canvas, Offset(w * 0.64, currentY), w, false);
  }

  void _drawHoof(Canvas canvas, Offset center, double w, bool isLeft) {
    final hoofSize = w * 0.13;
    final hoofH = hoofSize * 0.75;
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: hoofSize, height: hoofH),
      Radius.circular(hoofH * 0.45),
    );

    // hoof with 3D gradient
    final shader = RadialGradient(
      center: const Alignment(-0.1, -0.4),
      radius: 1.0,
      colors: [_woolLight, _cream, _wool],
    ).createShader(rr.outerRect);
    canvas.drawRRect(rr, Paint()..shader = shader);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _tan.withValues(alpha: 0.45)
        ..strokeWidth = 1.2,
    );

    // finger/toe lines (like figurine)
    for (var i = -1; i <= 1; i++) {
      final x = center.dx + i * hoofSize * 0.20;
      canvas.drawLine(
        Offset(x, center.dy + hoofH * 0.05),
        Offset(x, center.dy + hoofH * 0.40),
        Paint()
          ..color = _shadow.withValues(alpha: 0.30)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // subtle knuckle bumps
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(
        Offset(center.dx + i * hoofSize * 0.20, center.dy - hoofH * 0.20),
        hoofSize * 0.06,
        Paint()..color = _woolHighlight.withValues(alpha: 0.30),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────────────

  /// Fuzzy pompom with textured surface (figurine style)
  void _drawFuzzyPompom(Canvas canvas, Offset center, double radius, Color color) {
    // soft shadow
    canvas.drawCircle(
      Offset(center.dx + 1, center.dy + 1),
      radius * 1.05,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // base
    final shader = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.9,
      colors: [
        Color.lerp(color, Colors.white, 0.30)!,
        color,
        Color.lerp(color, Colors.black, 0.20)!,
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..shader = shader);

    // fuzzy texture bumps
    final rng = math.Random(color.toARGB32());
    for (var i = 0; i < 6; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = radius * (0.3 + rng.nextDouble() * 0.5);
      final bx = center.dx + math.cos(angle) * dist;
      final by = center.dy + math.sin(angle) * dist;
      canvas.drawCircle(
        Offset(bx, by),
        radius * 0.25,
        Paint()..color = Color.lerp(color, Colors.white, 0.20)!.withValues(alpha: 0.40),
      );
    }

    // highlight
    canvas.drawCircle(
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.30),
      radius * 0.25,
      Paint()..color = Colors.white.withValues(alpha: 0.50),
    );
  }

  void _drawDiamond(Canvas canvas, double cx, double cy, double r, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r, cy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LlamaBustPainter old) =>
      old.idlePhase != idlePhase ||
      old.transPhase != transPhase ||
      old.eyeX != eyeX ||
      old.animState != animState ||
      old.blinkPhase != blinkPhase ||
      old.isBlinking != isBlinking ||
      old.earSpring != earSpring;
}
