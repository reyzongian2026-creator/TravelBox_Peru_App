import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/brand_tokens.dart';

/// Peruvian llama mascot for the InkaVoy auth flow.
/// Supports animation states: idle, test (eye tracking), hands_up, hands_down, success, fail
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
  State<AuthLlamaAnimation> createState() => _AuthLlamaState();
}

class _AuthLlamaState extends State<AuthLlamaAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _idleCtrl;
  late final AnimationController _transCtrl;

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(covariant AuthLlamaAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      _transCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _transCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.compact ? 170.0 : 220.0;
    return IgnorePointer(
      child: SizedBox(
        width: sz,
        height: sz,
        child: AnimatedBuilder(
          animation: Listenable.merge([_idleCtrl, _transCtrl]),
          builder: (_, _) => CustomPaint(
            painter: _LlamaPainter(
              idlePhase: _idleCtrl.value,
              transPhase: _transCtrl.value,
              eyeX: widget.lookOffsetX.clamp(-1.0, 1.0),
              animState: widget.animation,
            ),
          ),
        ),
      ),
    );
  }
}

class _LlamaPainter extends CustomPainter {
  const _LlamaPainter({
    required this.idlePhase,
    required this.transPhase,
    required this.eyeX,
    required this.animState,
  });

  final double idlePhase;
  final double transPhase;
  final double eyeX;
  final String animState;

  // Warm Andean llama palette
  static const _cream = Color(0xFFF7EDDA);
  static const _wool = Color(0xFFEEDFC0);
  static const _tan = Color(0xFFDFCAA0);
  static const _brown = Color(0xFFB8945A);
  static const _darkBrown = Color(0xFF7A5C30);
  static const _ink = Color(0xFF2C1810);
  static const _nose = Color(0xFFE8AD8C);
  static const _blush = Color(0xFFF4A0A0);
  static const _hoofDark = Color(0xFF8E6535);

  // Poncho / Andean colors
  static const _ponchoRed = Color(0xFFD94040);
  static const _ponchoGold = Color(0xFFE8B84A);
  static const _ponchoTeal = Color(0xFF2D9B8A);
  static const _ponchoBlue = TravelBoxBrand.primaryBlue;
  static const _terracotta = TravelBoxBrand.terracotta;

  bool get _isHandsUp => animState == 'hands_up';
  bool get _isSuccess => animState == 'success';
  bool get _isFail => animState == 'fail';

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final breathOffset = math.sin(idlePhase * math.pi * 2) * 2.5;
    final bounceOffset =
        _isSuccess ? math.sin(transPhase * math.pi) * -14.0 : 0.0;
    final failOffset = _isFail ? transPhase * 4.5 : 0.0;
    final earWag = math.sin(idlePhase * math.pi * 4) * 0.07;

    final dy = breathOffset + bounceOffset + failOffset;
    canvas.save();
    canvas.translate(0, dy);

    _drawShadow(canvas, w, h);
    _drawTail(canvas, w, h);
    _drawBackLegs(canvas, w, h);
    _drawBody(canvas, w, h);
    _drawPoncho(canvas, w, h);
    _drawNeck(canvas, w, h);
    _drawNeckWool(canvas, w, h);
    _drawHead(canvas, w, h);
    _drawEars(canvas, w, h, earWag);
    _drawEarPompoms(canvas, w, h, earWag);
    _drawSnout(canvas, w, h);
    _drawEyes(canvas, w, h);
    _drawEyelashes(canvas, w, h);
    _drawMouth(canvas, w, h);
    _drawBlush(canvas, w, h);
    _drawFrontLegs(canvas, w, h);
    if (_isHandsUp) _drawCoveringHooves(canvas, w, h);

    canvas.restore();
  }

  void _drawShadow(Canvas canvas, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.955),
        width: w * 0.58,
        height: h * 0.055,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawTail(Canvas canvas, double w, double h) {
    final tailPath = Path()
      ..moveTo(w * 0.765, h * 0.620)
      ..quadraticBezierTo(w * 0.82, h * 0.575, w * 0.80, h * 0.540)
      ..quadraticBezierTo(w * 0.78, h * 0.510, w * 0.74, h * 0.555)
      ..quadraticBezierTo(w * 0.73, h * 0.590, w * 0.735, h * 0.625);
    canvas.drawPath(tailPath, Paint()..color = _wool);
    canvas.drawPath(
      tailPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.45)
        ..strokeWidth = 1.0,
    );
    // Fluffy tip
    canvas.drawCircle(
      Offset(w * 0.795, h * 0.535),
      w * 0.028,
      Paint()..color = _cream,
    );
  }

  void _drawBody(Canvas canvas, double w, double h) {
    final bodyRect = Rect.fromCenter(
      center: Offset(w * 0.500, h * 0.695),
      width: w * 0.62,
      height: h * 0.34,
    );
    final shader = RadialGradient(
      center: const Alignment(-0.2, -0.4),
      radius: 0.95,
      colors: [_cream, _wool, _tan],
    ).createShader(bodyRect);
    canvas.drawOval(bodyRect, Paint()..shader = shader);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.40)
        ..strokeWidth = 1.2,
    );

    // Wool texture
    final fluff = Paint()
      ..color = _tan.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final cx = w * (0.30 + i * 0.10);
      final cy = h * (0.665 + (i % 2) * 0.035);
      final p = Path()
        ..moveTo(cx, cy)
        ..quadraticBezierTo(cx + w * 0.03, cy + h * 0.028, cx + w * 0.06, cy);
      canvas.drawPath(p, fluff);
    }
  }

  void _drawPoncho(Canvas canvas, double w, double h) {
    // Colorful Andean poncho draped over the back
    final ponchoPath = Path()
      ..moveTo(w * 0.32, h * 0.575)
      ..quadraticBezierTo(w * 0.35, h * 0.555, w * 0.44, h * 0.548)
      ..lineTo(w * 0.56, h * 0.548)
      ..quadraticBezierTo(w * 0.65, h * 0.555, w * 0.68, h * 0.575)
      ..quadraticBezierTo(w * 0.72, h * 0.62, w * 0.73, h * 0.68)
      ..quadraticBezierTo(w * 0.72, h * 0.74, w * 0.68, h * 0.78)
      ..quadraticBezierTo(w * 0.58, h * 0.82, w * 0.50, h * 0.82)
      ..quadraticBezierTo(w * 0.42, h * 0.82, w * 0.32, h * 0.78)
      ..quadraticBezierTo(w * 0.28, h * 0.74, w * 0.27, h * 0.68)
      ..quadraticBezierTo(w * 0.28, h * 0.62, w * 0.32, h * 0.575)
      ..close();

    // Main poncho gradient
    final ponchoShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_ponchoRed, _ponchoRed.withValues(alpha: 0.92)],
    ).createShader(
      Rect.fromLTWH(w * 0.27, h * 0.548, w * 0.46, h * 0.272),
    );
    canvas.drawPath(ponchoPath, Paint()..shader = ponchoShader);

    // Poncho border
    canvas.drawPath(
      ponchoPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _darkBrown.withValues(alpha: 0.30)
        ..strokeWidth = 1.0,
    );

    // Horizontal Andean pattern bands
    final bandPaint = Paint()
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Gold band
    bandPaint.color = _ponchoGold;
    final band1 = Path()
      ..moveTo(w * 0.30, h * 0.635)
      ..quadraticBezierTo(w * 0.50, h * 0.625, w * 0.70, h * 0.635);
    canvas.drawPath(band1, bandPaint);

    // Teal band
    bandPaint.color = _ponchoTeal;
    final band2 = Path()
      ..moveTo(w * 0.29, h * 0.670)
      ..quadraticBezierTo(w * 0.50, h * 0.660, w * 0.71, h * 0.670);
    canvas.drawPath(band2, bandPaint);

    // Blue band
    bandPaint.color = _ponchoBlue;
    final band3 = Path()
      ..moveTo(w * 0.29, h * 0.705)
      ..quadraticBezierTo(w * 0.50, h * 0.695, w * 0.71, h * 0.705);
    canvas.drawPath(band3, bandPaint);

    // Gold band bottom
    bandPaint.color = _ponchoGold;
    final band4 = Path()
      ..moveTo(w * 0.30, h * 0.740)
      ..quadraticBezierTo(w * 0.50, h * 0.730, w * 0.70, h * 0.740);
    canvas.drawPath(band4, bandPaint);

    // Small diamond motifs (Andean geometric pattern)
    final diamondPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 4; i++) {
      final dx = w * (0.36 + i * 0.08);
      final dy = h * 0.650;
      _drawSmallDiamond(canvas, dx, dy, w * 0.012, diamondPaint);
    }
    for (var i = 0; i < 3; i++) {
      final dx = w * (0.40 + i * 0.08);
      final dy = h * 0.720;
      _drawSmallDiamond(canvas, dx, dy, w * 0.010, diamondPaint);
    }

    // Fringe at bottom edges
    final fringePaint = Paint()
      ..color = _ponchoGold.withValues(alpha: 0.80)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final fx = w * (0.34 + i * 0.02);
      canvas.drawLine(
        Offset(fx, h * 0.78),
        Offset(fx - w * 0.005, h * 0.80),
        fringePaint,
      );
    }
    for (var i = 0; i < 5; i++) {
      final fx = w * (0.60 + i * 0.02);
      canvas.drawLine(
        Offset(fx, h * 0.78),
        Offset(fx + w * 0.005, h * 0.80),
        fringePaint,
      );
    }
  }

  void _drawSmallDiamond(
      Canvas canvas, double cx, double cy, double r, Paint paint) {
    final p = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
    canvas.drawPath(p, paint);
  }

  void _drawNeck(Canvas canvas, double w, double h) {
    final path = Path()
      ..moveTo(w * 0.438, h * 0.545)
      ..quadraticBezierTo(w * 0.412, h * 0.430, w * 0.430, h * 0.320)
      ..lineTo(w * 0.570, h * 0.320)
      ..quadraticBezierTo(w * 0.588, h * 0.430, w * 0.562, h * 0.545)
      ..close();
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [_tan, _cream, _tan],
    ).createShader(
      Rect.fromLTWH(w * 0.412, h * 0.320, w * 0.176, h * 0.225),
    );
    canvas.drawPath(path, Paint()..shader = shader);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.35)
        ..strokeWidth = 1.0,
    );
  }

  void _drawNeckWool(Canvas canvas, double w, double h) {
    // Fluffy wool tufts along the neck
    final wp = Paint()
      ..color = _cream.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final cy = h * (0.38 + i * 0.055);
      final p = Path()
        ..moveTo(w * 0.432, cy)
        ..quadraticBezierTo(w * 0.42, cy + h * 0.015, w * 0.435, cy + h * 0.02);
      canvas.drawPath(p, wp);
      final p2 = Path()
        ..moveTo(w * 0.568, cy)
        ..quadraticBezierTo(w * 0.58, cy + h * 0.015, w * 0.565, cy + h * 0.02);
      canvas.drawPath(p2, wp);
    }
  }

  void _drawHead(Canvas canvas, double w, double h) {
    final tilt = _isFail ? transPhase * 0.15 : 0.0;
    canvas.save();
    canvas.translate(w * 0.500, h * 0.220);
    canvas.rotate(tilt);
    canvas.translate(-w * 0.500, -h * 0.220);

    final headRect = Rect.fromCenter(
      center: Offset(w * 0.500, h * 0.220),
      width: w * 0.40,
      height: h * 0.28,
    );
    final shader = RadialGradient(
      center: const Alignment(-0.15, -0.35),
      radius: 0.85,
      colors: [_cream, _wool],
    ).createShader(headRect);
    canvas.drawOval(headRect, Paint()..shader = shader);
    canvas.drawOval(
      headRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.40)
        ..strokeWidth = 1.2,
    );

    // Top-of-head wool tuft
    final tuftPaint = Paint()..color = _cream;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.098),
        width: w * 0.14,
        height: h * 0.048,
      ),
      tuftPaint,
    );

    canvas.restore();
  }

  void _drawEars(Canvas canvas, double w, double h, double wag) {
    _drawEar(canvas, w * 0.340, h * 0.100, true, wag);
    _drawEar(canvas, w * 0.660, h * 0.100, false, -wag);
  }

  void _drawEar(
    Canvas canvas,
    double cx,
    double cy,
    bool isLeft,
    double wag,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate((isLeft ? -0.22 : 0.22) + wag);

    // Outer ear - taller, more elegant banana shape
    final outer = Path()
      ..moveTo(-9, 14)
      ..quadraticBezierTo(-14, -4, 0, -26)
      ..quadraticBezierTo(14, -4, 9, 14)
      ..close();
    canvas.drawPath(outer, Paint()..color = _wool);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.55)
        ..strokeWidth = 1.0,
    );

    // Inner ear (warm terracotta)
    final inner = Path()
      ..moveTo(-5.5, 12)
      ..quadraticBezierTo(-9, -1, 0, -18)
      ..quadraticBezierTo(9, -1, 5.5, 12)
      ..close();
    canvas.drawPath(
      inner,
      Paint()..color = _terracotta.withValues(alpha: 0.35),
    );
    canvas.restore();
  }

  void _drawEarPompoms(Canvas canvas, double w, double h, double wag) {
    _drawPompom(canvas, w * 0.280, h * 0.040, wag, true);
    _drawPompom(canvas, w * 0.720, h * 0.040, -wag, false);
  }

  void _drawPompom(
      Canvas canvas, double cx, double cy, double wag, bool isLeft) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(wag * 2.5);
    canvas.translate(-cx, -cy);

    // Thread connecting to ear
    canvas.drawLine(
      Offset(cx, cy + 8),
      Offset(cx + (isLeft ? 4 : -4), cy + 18),
      Paint()
        ..color = _ponchoGold.withValues(alpha: 0.70)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // Main pompom body (layered circles for fluffiness)
    canvas.drawCircle(
      Offset(cx, cy),
      7.0,
      Paint()..color = _ponchoRed,
    );
    canvas.drawCircle(
      Offset(cx - 2.5, cy - 1.5),
      3.5,
      Paint()..color = _ponchoGold,
    );
    canvas.drawCircle(
      Offset(cx + 2.8, cy - 1),
      3.0,
      Paint()..color = _ponchoTeal,
    );
    canvas.drawCircle(
      Offset(cx, cy + 2),
      2.8,
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );
    // Highlight
    canvas.drawCircle(
      Offset(cx - 1.5, cy - 3),
      1.8,
      Paint()..color = Colors.white.withValues(alpha: 0.60),
    );
    canvas.restore();
  }

  void _drawEyes(Canvas canvas, double w, double h) {
    final lEye = Offset(w * 0.425, h * 0.208);
    final rEye = Offset(w * 0.575, h * 0.208);
    final r = w * 0.050;

    if (_isHandsUp) {
      _drawClosedEye(canvas, lEye, r);
      _drawClosedEye(canvas, rEye, r);
    } else if (_isFail && transPhase > 0.45) {
      _drawSadEye(canvas, lEye, r);
      _drawSadEye(canvas, rEye, r);
    } else if (_isSuccess && transPhase > 0.25) {
      _drawHappyEye(canvas, lEye, r * 1.1);
      _drawHappyEye(canvas, rEye, r * 1.1);
    } else {
      final shift = eyeX * r * 0.42;
      _drawNormalEye(canvas, lEye, r, shift);
      _drawNormalEye(canvas, rEye, r, shift);
    }
  }

  void _drawNormalEye(Canvas canvas, Offset c, double r, double shiftX) {
    // Eye white
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _ink.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Iris (dark brown with warm tone)
    final irisCenter = Offset(c.dx + shiftX, c.dy + 0.6);
    canvas.drawCircle(irisCenter, r * 0.60, Paint()..color = const Color(0xFF3D2010));
    // Pupil
    canvas.drawCircle(irisCenter, r * 0.35, Paint()..color = _ink);
    // Catchlight
    canvas.drawCircle(
      Offset(c.dx + shiftX - r * 0.24, c.dy - r * 0.24),
      r * 0.20,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(c.dx + shiftX + r * 0.15, c.dy + r * 0.10),
      r * 0.10,
      Paint()..color = Colors.white.withValues(alpha: 0.70),
    );
  }

  void _drawClosedEye(Canvas canvas, Offset c, double r) {
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.1),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _ink
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawSadEye(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(c.dx, c.dy + r * 0.30),
      r * 0.50,
      Paint()..color = _ink,
    );
    // Drooping eyelid
    final lid = Path()
      ..moveTo(c.dx - r, c.dy - r * 0.08)
      ..quadraticBezierTo(c.dx, c.dy - r * 0.55, c.dx + r, c.dy - r * 0.08);
    canvas.drawPath(lid, Paint()..color = _wool);
  }

  void _drawHappyEye(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(c, r * 0.65, Paint()..color = _ink);
    canvas.drawCircle(
      Offset(c.dx - r * 0.28, c.dy - r * 0.30),
      r * 0.22,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(c.dx + r * 0.16, c.dy + r * 0.08),
      r * 0.12,
      Paint()..color = Colors.white,
    );
  }

  void _drawEyelashes(Canvas canvas, double w, double h) {
    if (_isHandsUp) return;
    final lashPaint = Paint()
      ..color = _brown.withValues(alpha: 0.65)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Left eye lashes
    final lx = w * 0.425;
    final ly = h * 0.188;
    canvas.drawLine(Offset(lx - w * 0.030, ly), Offset(lx - w * 0.040, ly - h * 0.014), lashPaint);
    canvas.drawLine(Offset(lx - w * 0.018, ly - h * 0.008), Offset(lx - w * 0.025, ly - h * 0.022), lashPaint);

    // Right eye lashes
    final rx = w * 0.575;
    final ry = h * 0.188;
    canvas.drawLine(Offset(rx + w * 0.030, ry), Offset(rx + w * 0.040, ry - h * 0.014), lashPaint);
    canvas.drawLine(Offset(rx + w * 0.018, ry - h * 0.008), Offset(rx + w * 0.025, ry - h * 0.022), lashPaint);
  }

  void _drawBlush(Canvas canvas, double w, double h) {
    // Soft cheek blush under eyes
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.385, h * 0.245),
        width: w * 0.055,
        height: h * 0.028,
      ),
      Paint()..color = _blush.withValues(alpha: 0.28),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.615, h * 0.245),
        width: w * 0.055,
        height: h * 0.028,
      ),
      Paint()..color = _blush.withValues(alpha: 0.28),
    );
  }

  void _drawSnout(Canvas canvas, double w, double h) {
    final snoutRect = Rect.fromCenter(
      center: Offset(w * 0.500, h * 0.292),
      width: w * 0.24,
      height: h * 0.105,
    );
    final shader = RadialGradient(
      center: const Alignment(0, -0.3),
      radius: 0.9,
      colors: [_nose, _nose.withValues(alpha: 0.80)],
    ).createShader(snoutRect);
    canvas.drawOval(snoutRect, Paint()..shader = shader);
    canvas.drawOval(
      snoutRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.28)
        ..strokeWidth = 0.8,
    );

    // Nostrils
    final np = Paint()..color = _darkBrown.withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.468, h * 0.304),
        width: w * 0.048,
        height: h * 0.024,
      ),
      np,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.532, h * 0.304),
        width: w * 0.048,
        height: h * 0.024,
      ),
      np,
    );
  }

  void _drawMouth(Canvas canvas, double w, double h) {
    final mp = Paint()
      ..color = _brown.withValues(alpha: 0.65)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (_isFail && transPhase > 0.40) {
      final p = Path()
        ..moveTo(w * 0.452, h * 0.340)
        ..quadraticBezierTo(w * 0.500, h * 0.330, w * 0.548, h * 0.340);
      canvas.drawPath(p, mp);
    } else if (_isSuccess && transPhase > 0.25) {
      final p = Path()
        ..moveTo(w * 0.448, h * 0.330)
        ..quadraticBezierTo(w * 0.500, h * 0.358, w * 0.552, h * 0.330);
      canvas.drawPath(p, mp);
    } else {
      // Neutral cute smile
      final p = Path()
        ..moveTo(w * 0.465, h * 0.338)
        ..quadraticBezierTo(w * 0.500, h * 0.346, w * 0.535, h * 0.338);
      canvas.drawPath(p, mp);
    }
  }

  void _drawFrontLegs(Canvas canvas, double w, double h) {
    _drawLeg(canvas, w * 0.390, h * 0.715, w * 0.380, h * 0.900, false);
    _drawLeg(canvas, w * 0.595, h * 0.715, w * 0.605, h * 0.900, false);
  }

  void _drawBackLegs(Canvas canvas, double w, double h) {
    _drawLeg(canvas, w * 0.312, h * 0.730, w * 0.302, h * 0.900, true);
    _drawLeg(canvas, w * 0.675, h * 0.730, w * 0.685, h * 0.900, true);
  }

  void _drawLeg(
    Canvas canvas,
    double topX,
    double topY,
    double botX,
    double botY,
    bool isBack,
  ) {
    final lw = isBack ? 15.0 : 17.0;
    final legPath = Path()
      ..moveTo(topX - lw / 2, topY)
      ..lineTo(topX + lw / 2, topY)
      ..lineTo(botX + lw / 2 - 1, botY - 10)
      ..quadraticBezierTo(
        botX + lw / 2 + 2.5,
        botY + 1.5,
        botX + lw / 2 - 1.5,
        botY + 5,
      )
      ..lineTo(botX - lw / 2 + 1.5, botY + 5)
      ..quadraticBezierTo(
        botX - lw / 2 - 2.5,
        botY + 1.5,
        botX - lw / 2 + 1,
        botY - 10,
      )
      ..close();

    canvas.drawPath(legPath, Paint()..color = isBack ? _tan : _cream);
    canvas.drawPath(
      legPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.45)
        ..strokeWidth = 1.0,
    );

    // Hoof
    final hoofPath = Path()
      ..moveTo(botX - lw / 2 + 1, botY - 5)
      ..lineTo(botX + lw / 2 - 1, botY - 5)
      ..quadraticBezierTo(
        botX + lw / 2 + 2.5,
        botY + 1.5,
        botX + lw / 2 - 1.5,
        botY + 5,
      )
      ..lineTo(botX - lw / 2 + 1.5, botY + 5)
      ..quadraticBezierTo(
        botX - lw / 2 - 2.5,
        botY + 1.5,
        botX - lw / 2 + 1,
        botY - 5,
      )
      ..close();
    canvas.drawPath(hoofPath, Paint()..color = _hoofDark);
  }

  void _drawCoveringHooves(Canvas canvas, double w, double h) {
    final eyeLevel = h * 0.208;
    final legTopY = h * 0.715;
    final t = Curves.easeOutBack.transform(transPhase.clamp(0.0, 1.0));
    final currentY = legTopY + (eyeLevel - legTopY) * t;

    _drawHoof(canvas, Offset(w * 0.360, currentY));
    _drawHoof(canvas, Offset(w * 0.640, currentY));
  }

  void _drawHoof(Canvas canvas, Offset center) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 24, height: 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(rr, Paint()..color = _cream);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.55)
        ..strokeWidth = 1.1,
    );
    // Toe splits
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(center.dx + i * 5.0, center.dy + 3),
        Offset(center.dx + i * 5.0, center.dy + 8),
        Paint()
          ..color = _hoofDark.withValues(alpha: 0.65)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LlamaPainter old) =>
      old.idlePhase != idlePhase ||
      old.transPhase != transPhase ||
      old.eyeX != eyeX ||
      old.animState != animState;
}
