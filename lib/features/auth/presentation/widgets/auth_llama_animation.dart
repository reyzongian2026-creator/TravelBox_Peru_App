import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Peruvian llama bust-portrait mascot for the InkaVoy auth flow.
/// Chullo hat + Andean collar, Teddy-style fluid animations.
/// States: idle, test (eye tracking), hands_up, hands_down, success, fail
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
  late final AnimationController _lookCtrl;
  double _prevLookX = 0;
  double _targetLookX = 0;

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _lookCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _prevLookX = widget.lookOffsetX;
    _targetLookX = widget.lookOffsetX;
  }

  @override
  void didUpdateWidget(covariant AuthLlamaAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      _transCtrl.forward(from: 0);
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
    _idleCtrl.dispose();
    _transCtrl.dispose();
    _lookCtrl.dispose();
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
          animation: Listenable.merge([_idleCtrl, _transCtrl, _lookCtrl]),
          builder: (_, _) => CustomPaint(
            painter: _LlamaBustPainter(
              idlePhase: _idleCtrl.value,
              transPhase: _transCtrl.value,
              eyeX: _smoothLookX.clamp(-1.0, 1.0),
              animState: widget.animation,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LLAMA BUST-PORTRAIT PAINTER
// ═══════════════════════════════════════════════════════════════════

class _LlamaBustPainter extends CustomPainter {
  const _LlamaBustPainter({
    required this.idlePhase,
    required this.transPhase,
    required this.eyeX,
    required this.animState,
  });

  final double idlePhase;
  final double transPhase;
  final double eyeX;
  final String animState;

  // ── wool palette ──
  static const _cream = Color(0xFFF8F0E0);
  static const _woolLight = Color(0xFFFDF8F0);
  static const _wool = Color(0xFFEEE2C8);
  static const _tan = Color(0xFFDFCCA5);
  static const _shadow = Color(0xFFCDB890);

  // ── feature palette ──
  static const _ink = Color(0xFF2C1810);
  static const _darkBrown = Color(0xFF5A3D20);
  static const _brown = Color(0xFF8A6540);
  static const _nose = Color(0xFFEAAD90);
  static const _blush = Color(0xFFF4A0A0);
  static const _earInner = Color(0xFFDEA080);

  // ── hat & textile palette ──
  static const _hatRed = Color(0xFFC43535);
  static const _hatRedDark = Color(0xFFA02828);
  static const _hatTeal = Color(0xFF2AB5A0);
  static const _hatGold = Color(0xFFE8B84A);
  static const _hatOrange = Color(0xFFE88530);

  // ── pompom colours ──
  static const _pompYellow = Color(0xFFF0C840);
  static const _pompTeal = Color(0xFF2CC5B0);
  static const _pompRed = Color(0xFFD94545);

  bool get _isHandsUp => animState == 'hands_up';
  bool get _isHandsDown => animState == 'hands_down';
  bool get _isSuccess => animState == 'success';
  bool get _isFail => animState == 'fail';

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── animation math ──
    final breathY = math.sin(idlePhase * math.pi * 2) * 1.6;
    final bounceY =
        _isSuccess ? math.sin(transPhase * math.pi) * -10.0 : 0.0;
    final shakeX = _isFail
        ? math.sin(transPhase * math.pi * 4) * 3.5 * (1 - transPhase)
        : 0.0;
    final earSwing = math.sin(idlePhase * math.pi * 4) * 0.06;
    final headTilt = _isFail ? math.sin(transPhase * math.pi) * 0.07 : 0.0;
    final pompSwing = math.sin(idlePhase * math.pi * 2 + 0.8) * 2.5;

    canvas.save();
    canvas.translate(shakeX, breathY + bounceY);

    _drawShadow(canvas, w, h);
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
    _drawWoolTufts(canvas, w, h);
    _drawChullo(canvas, w, h);
    _drawHatPatterns(canvas, w, h);
    _drawHatEarFlaps(canvas, w, h, earSwing);
    _drawHatFlapPompoms(canvas, w, h, earSwing, pompSwing);
    _drawHatTopPompom(canvas, w, h);
    _drawSnout(canvas, w, h);
    _drawEyes(canvas, w, h);
    _drawEyelashes(canvas, w, h);
    _drawMouth(canvas, w, h);
    _drawBlush(canvas, w, h);
    if (_isHandsUp || (_isHandsDown && transPhase < 0.65)) {
      _drawCoveringHooves(canvas, w, h);
    }

    canvas.restore();
    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────────
  //  SHADOW
  // ────────────────────────────────────────────────────────────────
  void _drawShadow(Canvas canvas, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.97),
        width: w * 0.52,
        height: h * 0.035,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  NECK
  // ────────────────────────────────────────────────────────────────
  void _drawNeck(Canvas canvas, double w, double h) {
    final path = Path()
      ..moveTo(w * 0.37, h * 0.60)
      ..quadraticBezierTo(w * 0.35, h * 0.68, w * 0.34, h * 0.78)
      ..lineTo(w * 0.66, h * 0.78)
      ..quadraticBezierTo(w * 0.65, h * 0.68, w * 0.63, h * 0.60)
      ..close();
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_cream, _wool],
    ).createShader(Rect.fromLTWH(w * 0.34, h * 0.60, w * 0.32, h * 0.18));
    canvas.drawPath(path, Paint()..shader = shader);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _tan.withValues(alpha: 0.35)
        ..strokeWidth = 0.8,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  ANDEAN COLLAR / NECKLACE
  // ────────────────────────────────────────────────────────────────
  void _drawCollar(Canvas canvas, double w, double h) {
    final collarPath = Path()
      ..moveTo(w * 0.24, h * 0.72)
      ..quadraticBezierTo(w * 0.22, h * 0.76, w * 0.22, h * 0.80)
      ..quadraticBezierTo(w * 0.24, h * 0.90, w * 0.50, h * 0.92)
      ..quadraticBezierTo(w * 0.76, h * 0.90, w * 0.78, h * 0.80)
      ..quadraticBezierTo(w * 0.78, h * 0.76, w * 0.76, h * 0.72)
      ..quadraticBezierTo(w * 0.66, h * 0.68, w * 0.50, h * 0.67)
      ..quadraticBezierTo(w * 0.34, h * 0.68, w * 0.24, h * 0.72)
      ..close();

    // base red
    final cShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_hatRed, _hatRedDark],
    ).createShader(Rect.fromLTWH(w * 0.22, h * 0.67, w * 0.56, h * 0.25));
    canvas.drawPath(collarPath, Paint()..shader = cShader);

    // pattern bands
    final bandPaint = Paint()
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // gold band
    bandPaint.color = _hatGold;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.25, h * 0.76)
        ..quadraticBezierTo(w * 0.50, h * 0.73, w * 0.75, h * 0.76),
      bandPaint,
    );
    // teal band
    bandPaint.color = _hatTeal;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, h * 0.80)
        ..quadraticBezierTo(w * 0.50, h * 0.77, w * 0.76, h * 0.80),
      bandPaint,
    );
    // gold band lower
    bandPaint.color = _hatGold;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.25, h * 0.84)
        ..quadraticBezierTo(w * 0.50, h * 0.82, w * 0.75, h * 0.84),
      bandPaint,
    );

    // small diamond motifs
    final diamPaint = Paint()..color = Colors.white.withValues(alpha: 0.80);
    for (var i = 0; i < 5; i++) {
      final dx = w * (0.34 + i * 0.08);
      _drawDiamond(canvas, dx, h * 0.785, w * 0.010, diamPaint);
    }

    // border
    canvas.drawPath(
      collarPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _darkBrown.withValues(alpha: 0.25)
        ..strokeWidth = 0.9,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  COLLAR TASSELS / POMPOMS
  // ────────────────────────────────────────────────────────────────
  void _drawCollarPompoms(Canvas canvas, double w, double h, double swing) {
    final colors = [_pompYellow, _pompTeal, _pompRed, _hatGold, _pompTeal];
    for (var i = 0; i < 5; i++) {
      final bx = w * (0.30 + i * 0.10);
      final dx = swing * (i.isEven ? 1 : -1) * 0.4;
      // thread
      canvas.drawLine(
        Offset(bx, h * 0.885),
        Offset(bx + dx, h * 0.935),
        Paint()
          ..color = _hatGold.withValues(alpha: 0.70)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
      // pompom
      _drawMiniPompom(canvas, Offset(bx + dx, h * 0.945), w * 0.022, colors[i]);
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  EARS
  // ────────────────────────────────────────────────────────────────
  void _drawEars(Canvas canvas, double w, double h, double swing) {
    _drawSingleEar(canvas, w * 0.27, h * 0.20, true, -0.28 + swing);
    _drawSingleEar(canvas, w * 0.73, h * 0.20, false, 0.28 - swing);
  }

  void _drawSingleEar(
    Canvas canvas,
    double cx,
    double cy,
    bool isLeft,
    double angle,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    final outer = Path()
      ..moveTo(-8, 12)
      ..quadraticBezierTo(-12, -6, 0, -24)
      ..quadraticBezierTo(12, -6, 8, 12)
      ..close();
    canvas.drawPath(outer, Paint()..color = _wool);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.50)
        ..strokeWidth = 0.9,
    );
    final inner = Path()
      ..moveTo(-5, 10)
      ..quadraticBezierTo(-8, -3, 0, -17)
      ..quadraticBezierTo(8, -3, 5, 10)
      ..close();
    canvas.drawPath(inner, Paint()..color = _earInner.withValues(alpha: 0.40));
    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────────
  //  HEAD SHAPE
  // ────────────────────────────────────────────────────────────────
  void _drawHeadShape(Canvas canvas, double w, double h) {
    final headRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.40),
      width: w * 0.58,
      height: h * 0.42,
    );
    final shader = RadialGradient(
      center: const Alignment(-0.12, -0.30),
      radius: 0.85,
      colors: [_woolLight, _cream, _wool],
    ).createShader(headRect);
    canvas.drawOval(headRect, Paint()..shader = shader);
    canvas.drawOval(
      headRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _tan.withValues(alpha: 0.35)
        ..strokeWidth = 1.0,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  WOOL TEXTURE (fluffy arcs)
  // ────────────────────────────────────────────────────────────────
  void _drawWoolTufts(Canvas canvas, double w, double h) {
    final tuftPaint = Paint()
      ..color = _woolLight.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // left cheek tufts
    _drawTuft(canvas, w * 0.26, h * 0.36, w * 0.04, true, tuftPaint);
    _drawTuft(canvas, w * 0.24, h * 0.42, w * 0.035, true, tuftPaint);
    _drawTuft(canvas, w * 0.25, h * 0.48, w * 0.04, true, tuftPaint);

    // right cheek tufts
    _drawTuft(canvas, w * 0.74, h * 0.36, w * 0.04, false, tuftPaint);
    _drawTuft(canvas, w * 0.76, h * 0.42, w * 0.035, false, tuftPaint);
    _drawTuft(canvas, w * 0.75, h * 0.48, w * 0.04, false, tuftPaint);

    // forehead tufts (visible below hat)
    final topTuft = Paint()
      ..color = _cream.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final cx = w * (0.42 + i * 0.08);
      final cy = h * 0.27;
      final p = Path()
        ..moveTo(cx, cy)
        ..quadraticBezierTo(cx + w * 0.02, cy - h * 0.018, cx + w * 0.04, cy);
      canvas.drawPath(p, topTuft);
    }

    // chin tufts
    _drawTuft(canvas, w * 0.42, h * 0.58, w * 0.03, true, tuftPaint);
    _drawTuft(canvas, w * 0.50, h * 0.59, w * 0.03, false, tuftPaint);
    _drawTuft(canvas, w * 0.58, h * 0.58, w * 0.03, false, tuftPaint);
  }

  void _drawTuft(
    Canvas canvas,
    double x,
    double y,
    double size,
    bool curveLeft,
    Paint paint,
  ) {
    final dir = curveLeft ? -1.0 : 1.0;
    final p = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(x + dir * size * 0.6, y - size * 0.8, x + dir * size, y + size * 0.2);
    canvas.drawPath(p, paint);
  }

  // ────────────────────────────────────────────────────────────────
  //  CHULLO HAT (base dome)
  // ────────────────────────────────────────────────────────────────
  void _drawChullo(Canvas canvas, double w, double h) {
    final hatPath = Path()
      ..moveTo(w * 0.26, h * 0.28)
      ..quadraticBezierTo(w * 0.26, h * 0.22, w * 0.30, h * 0.16)
      ..quadraticBezierTo(w * 0.36, h * 0.08, w * 0.50, h * 0.06)
      ..quadraticBezierTo(w * 0.64, h * 0.08, w * 0.70, h * 0.16)
      ..quadraticBezierTo(w * 0.74, h * 0.22, w * 0.74, h * 0.28)
      ..lineTo(w * 0.26, h * 0.28)
      ..close();

    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_hatRed, _hatRedDark],
    ).createShader(Rect.fromLTWH(w * 0.26, h * 0.06, w * 0.48, h * 0.22));
    canvas.drawPath(hatPath, Paint()..shader = shader);

    // hat brim — slight overhang
    final brimPath = Path()
      ..moveTo(w * 0.24, h * 0.28)
      ..quadraticBezierTo(w * 0.50, h * 0.30, w * 0.76, h * 0.28)
      ..quadraticBezierTo(w * 0.50, h * 0.32, w * 0.24, h * 0.28)
      ..close();
    canvas.drawPath(brimPath, Paint()..color = _hatRedDark);

    // forehead shadow from hat brim
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, h * 0.29)
        ..quadraticBezierTo(w * 0.50, h * 0.31, w * 0.72, h * 0.29)
        ..quadraticBezierTo(w * 0.50, h * 0.33, w * 0.28, h * 0.29),
      Paint()..color = _shadow.withValues(alpha: 0.20),
    );

    // border
    canvas.drawPath(
      hatPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _darkBrown.withValues(alpha: 0.22)
        ..strokeWidth = 0.8,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HAT PATTERN BANDS
  // ────────────────────────────────────────────────────────────────
  void _drawHatPatterns(Canvas canvas, double w, double h) {
    // Wide teal band with zigzag
    final bandY1 = h * 0.145;
    final bandY2 = h * 0.195;
    final bandY3 = h * 0.245;

    // teal base band
    _drawHatBand(canvas, w, bandY1, 2.8, _hatTeal);
    // gold band
    _drawHatBand(canvas, w, bandY2, 2.8, _hatGold);
    // orange/teal lower band
    _drawHatBand(canvas, w, bandY3, 2.4, _hatOrange);

    // zigzag on teal band
    _drawZigzag(canvas, w, bandY1 - 4, bandY1 + 4, _hatGold.withValues(alpha: 0.85), 1.2);

    // small diamond motifs on gold band
    final diamPaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i < 4; i++) {
      final dx = w * (0.37 + i * 0.07);
      _drawDiamond(canvas, dx, bandY2, w * 0.008, diamPaint);
    }

    // zigzag on orange band
    _drawZigzag(canvas, w, bandY3 - 3, bandY3 + 3, _hatTeal.withValues(alpha: 0.75), 1.0);

    // gold trim lines between bands
    final trimPaint = Paint()
      ..color = _hatGold.withValues(alpha: 0.50)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.30, bandY1 + 8), Offset(w * 0.70, bandY1 + 8), trimPaint);
    canvas.drawLine(Offset(w * 0.29, bandY2 + 8), Offset(w * 0.71, bandY2 + 8), trimPaint);
  }

  void _drawHatBand(Canvas canvas, double w, double y, double thickness, Color color) {
    // curved band following hat dome
    final halfw = w * 0.20;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.50 - halfw, y)
        ..quadraticBezierTo(w * 0.50, y - 2, w * 0.50 + halfw, y),
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawZigzag(
    Canvas canvas,
    double w,
    double yTop,
    double yBot,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final steps = 8;
    final startX = w * 0.33;
    final endX = w * 0.67;
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
  //  HAT EAR FLAPS
  // ────────────────────────────────────────────────────────────────
  void _drawHatEarFlaps(Canvas canvas, double w, double h, double swing) {
    _drawSingleFlap(canvas, w, h, true, swing);
    _drawSingleFlap(canvas, w, h, false, -swing);
  }

  void _drawSingleFlap(
    Canvas canvas,
    double w,
    double h,
    bool isLeft,
    double swing,
  ) {
    final cx = isLeft ? w * 0.26 : w * 0.74;
    final topY = h * 0.26;
    final botY = h * 0.46;
    final flapW = w * 0.09;
    final dx = swing * 6;

    final path = Path()
      ..moveTo(cx - flapW, topY)
      ..lineTo(cx + flapW, topY)
      ..quadraticBezierTo(
        cx + flapW + dx * 0.3, (topY + botY) / 2,
        cx + flapW * 0.6 + dx, botY,
      )
      ..lineTo(cx - flapW * 0.6 + dx, botY)
      ..quadraticBezierTo(
        cx - flapW + dx * 0.3, (topY + botY) / 2,
        cx - flapW, topY,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = _hatRed);

    // pattern on flap
    final midY = (topY + botY) / 2;
    final bandP = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    bandP.color = _hatTeal;
    canvas.drawLine(
      Offset(cx - flapW * 0.5 + dx * 0.15, midY - 4),
      Offset(cx + flapW * 0.5 + dx * 0.15, midY - 4),
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
      Offset(cx - flapW * 0.5 + dx * 0.25, midY + 8),
      Offset(cx + flapW * 0.5 + dx * 0.25, midY + 8),
      bandP,
    );

    // border
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _darkBrown.withValues(alpha: 0.18)
        ..strokeWidth = 0.7,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  HAT FLAP POMPOMS (on strings)
  // ────────────────────────────────────────────────────────────────
  void _drawHatFlapPompoms(
    Canvas canvas,
    double w,
    double h,
    double swing,
    double pompSwing,
  ) {
    // Left flap pompom
    final lFlapBot = Offset(w * 0.26 + swing * 6, h * 0.46);
    final lPompCenter = Offset(
      lFlapBot.dx + pompSwing * 0.5,
      lFlapBot.dy + h * 0.08,
    );
    // string
    canvas.drawLine(
      lFlapBot,
      lPompCenter,
      Paint()
        ..color = _hatGold.withValues(alpha: 0.65)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    _drawColorfulPompom(canvas, lPompCenter, w * 0.035, _pompYellow, _pompTeal, _pompRed);

    // Right flap pompom
    final rFlapBot = Offset(w * 0.74 - swing * 6, h * 0.46);
    final rPompCenter = Offset(
      rFlapBot.dx - pompSwing * 0.5,
      rFlapBot.dy + h * 0.08,
    );
    canvas.drawLine(
      rFlapBot,
      rPompCenter,
      Paint()
        ..color = _hatGold.withValues(alpha: 0.65)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    _drawColorfulPompom(canvas, rPompCenter, w * 0.035, _pompTeal, _pompRed, _pompYellow);
  }

  // ────────────────────────────────────────────────────────────────
  //  HAT TOP POMPOM
  // ────────────────────────────────────────────────────────────────
  void _drawHatTopPompom(Canvas canvas, double w, double h) {
    // string from hat top to pompom
    canvas.drawLine(
      Offset(w * 0.50, h * 0.06),
      Offset(w * 0.50, h * 0.025),
      Paint()
        ..color = _hatGold.withValues(alpha: 0.50)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    _drawColorfulPompom(
      canvas,
      Offset(w * 0.50, h * 0.022),
      w * 0.032,
      _pompRed,
      _pompYellow,
      _pompTeal,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  SNOUT
  // ────────────────────────────────────────────────────────────────
  void _drawSnout(Canvas canvas, double w, double h) {
    final snoutRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.50),
      width: w * 0.24,
      height: h * 0.095,
    );
    final shader = RadialGradient(
      center: const Alignment(0, -0.3),
      radius: 0.9,
      colors: [_nose, _nose.withValues(alpha: 0.75)],
    ).createShader(snoutRect);
    canvas.drawOval(snoutRect, Paint()..shader = shader);
    canvas.drawOval(
      snoutRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.22)
        ..strokeWidth = 0.7,
    );

    // nostrils
    final np = Paint()..color = _darkBrown.withValues(alpha: 0.40);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.465, h * 0.508),
        width: w * 0.042,
        height: h * 0.022,
      ),
      np,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.535, h * 0.508),
        width: w * 0.042,
        height: h * 0.022,
      ),
      np,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  EYES (all states)
  // ────────────────────────────────────────────────────────────────
  void _drawEyes(Canvas canvas, double w, double h) {
    final lEye = Offset(w * 0.39, h * 0.39);
    final rEye = Offset(w * 0.61, h * 0.39);
    final r = w * 0.052;

    if (_isHandsUp) {
      // eyes squeezed shut (peeking not possible)
      _drawClosedEye(canvas, lEye, r);
      _drawClosedEye(canvas, rEye, r);
    } else if (_isHandsDown && transPhase < 0.5) {
      // still opening
      _drawClosedEye(canvas, lEye, r);
      _drawClosedEye(canvas, rEye, r);
    } else if (_isFail && transPhase > 0.30) {
      _drawSadEye(canvas, lEye, r);
      _drawSadEye(canvas, rEye, r);
    } else if (_isSuccess && transPhase > 0.20) {
      _drawHappyEye(canvas, lEye, r * 1.05);
      _drawHappyEye(canvas, rEye, r * 1.05);
    } else {
      final shift = eyeX * r * 0.45;
      _drawNormalEye(canvas, lEye, r, shift);
      _drawNormalEye(canvas, rEye, r, shift);
    }
  }

  void _drawNormalEye(Canvas canvas, Offset c, double r, double shiftX) {
    // white
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _ink.withValues(alpha: 0.80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    // iris
    final iC = Offset(c.dx + shiftX, c.dy + 0.5);
    canvas.drawCircle(iC, r * 0.58, Paint()..color = const Color(0xFF3D2010));
    // pupil
    canvas.drawCircle(iC, r * 0.34, Paint()..color = _ink);
    // catchlights
    canvas.drawCircle(
      Offset(c.dx + shiftX - r * 0.22, c.dy - r * 0.22),
      r * 0.19,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(c.dx + shiftX + r * 0.14, c.dy + r * 0.10),
      r * 0.09,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );
  }

  void _drawClosedEye(Canvas canvas, Offset c, double r) {
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.0),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _ink
        ..strokeWidth = 2.2
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
        ..strokeWidth = 1.1,
    );
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.25), r * 0.48, Paint()..color = _ink);
    // drooping upper eyelid
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r, c.dy - r * 0.10)
        ..quadraticBezierTo(c.dx, c.dy - r * 0.52, c.dx + r, c.dy - r * 0.10),
      Paint()..color = _wool,
    );
  }

  void _drawHappyEye(Canvas canvas, Offset c, double r) {
    // squinted happy arc (upside-down U)
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.4),
      0,
      math.pi,
      false,
      Paint()
        ..color = _ink
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  EYELASHES
  // ────────────────────────────────────────────────────────────────
  void _drawEyelashes(Canvas canvas, double w, double h) {
    if (_isHandsUp || (_isHandsDown && transPhase < 0.5)) return;
    if (_isSuccess && transPhase > 0.20) return;

    final lash = Paint()
      ..color = _brown.withValues(alpha: 0.60)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // left
    canvas.drawLine(
      Offset(w * 0.355, h * 0.373),
      Offset(w * 0.340, h * 0.358),
      lash,
    );
    canvas.drawLine(
      Offset(w * 0.365, h * 0.368),
      Offset(w * 0.355, h * 0.352),
      lash,
    );
    // right
    canvas.drawLine(
      Offset(w * 0.645, h * 0.373),
      Offset(w * 0.660, h * 0.358),
      lash,
    );
    canvas.drawLine(
      Offset(w * 0.635, h * 0.368),
      Offset(w * 0.645, h * 0.352),
      lash,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  MOUTH
  // ────────────────────────────────────────────────────────────────
  void _drawMouth(Canvas canvas, double w, double h) {
    final mp = Paint()
      ..color = _brown.withValues(alpha: 0.65)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (_isFail && transPhase > 0.30) {
      // frown
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.45, h * 0.545)
          ..quadraticBezierTo(w * 0.50, h * 0.535, w * 0.55, h * 0.545),
        mp,
      );
    } else if (_isSuccess && transPhase > 0.20) {
      // big smile
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.44, h * 0.535)
          ..quadraticBezierTo(w * 0.50, h * 0.565, w * 0.56, h * 0.535),
        mp,
      );
    } else {
      // neutral cute smile
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.46, h * 0.540)
          ..quadraticBezierTo(w * 0.50, h * 0.550, w * 0.54, h * 0.540),
        mp,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  BLUSH
  // ────────────────────────────────────────────────────────────────
  void _drawBlush(Canvas canvas, double w, double h) {
    final bp = Paint()..color = _blush.withValues(alpha: 0.25);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.34, h * 0.44),
        width: w * 0.055,
        height: h * 0.028,
      ),
      bp,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.66, h * 0.44),
        width: w * 0.055,
        height: h * 0.028,
      ),
      bp,
    );
  }

  // ────────────────────────────────────────────────────────────────
  //  COVERING HOOVES (password state)
  // ────────────────────────────────────────────────────────────────
  void _drawCoveringHooves(Canvas canvas, double w, double h) {
    final eyeLevel = h * 0.39;
    final startY = h * 0.88;

    double currentY;
    if (_isHandsUp) {
      final t = Curves.easeOutBack.transform(transPhase.clamp(0.0, 1.0));
      currentY = startY + (eyeLevel - startY) * t;
    } else {
      // hands_down
      final t = Curves.easeIn.transform(transPhase.clamp(0.0, 1.0));
      currentY = eyeLevel + (startY - eyeLevel) * t;
    }

    _drawHoof(canvas, Offset(w * 0.35, currentY));
    _drawHoof(canvas, Offset(w * 0.65, currentY));
  }

  void _drawHoof(Canvas canvas, Offset center) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 26, height: 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(rr, Paint()..color = _cream);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _brown.withValues(alpha: 0.50)
        ..strokeWidth = 1.0,
    );
    // toe lines
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(center.dx + i * 5.0, center.dy + 3),
        Offset(center.dx + i * 5.0, center.dy + 9),
        Paint()
          ..color = _darkBrown.withValues(alpha: 0.55)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ────────────────────────────────────────────────────────────────
  //  HELPERS
  // ────────────────────────────────────────────────────────────────

  void _drawColorfulPompom(
    Canvas canvas,
    Offset center,
    double radius,
    Color main,
    Color accent1,
    Color accent2,
  ) {
    canvas.drawCircle(center, radius, Paint()..color = main);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.30, center.dy - radius * 0.20),
      radius * 0.42,
      Paint()..color = accent1,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.32, center.dy - radius * 0.10),
      radius * 0.35,
      Paint()..color = accent2,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius * 0.18),
      radius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    // highlight
    canvas.drawCircle(
      Offset(center.dx - radius * 0.18, center.dy - radius * 0.35),
      radius * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  void _drawMiniPompom(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.30),
      radius * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
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
      old.animState != animState;
}
