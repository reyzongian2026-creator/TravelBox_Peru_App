import 'dart:math' as math;

import 'package:flare_flutter/flare.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flutter/material.dart';

class AuthTeddyAnimation extends StatefulWidget {
  const AuthTeddyAnimation({
    required this.animation,
    required this.compact,
    this.lookOffsetX = 0,
    super.key,
  });

  final String animation;
  final bool compact;
  final double lookOffsetX;

  @override
  State<AuthTeddyAnimation> createState() => _AuthTeddyAnimationState();
}

class _AuthTeddyAnimationState extends State<AuthTeddyAnimation> {
  late final _TeddyEyesController _eyesController;

  @override
  void initState() {
    super.initState();
    _eyesController = _TeddyEyesController();
    _eyesController.lookOffsetX = widget.lookOffsetX;
  }

  @override
  void didUpdateWidget(covariant AuthTeddyAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _eyesController.lookOffsetX = widget.lookOffsetX;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: widget.compact ? 170 : 220,
        height: widget.compact ? 170 : 220,
        child: FlareActor(
          'assets/branding/teddy.flr',
          alignment: Alignment.bottomCenter,
          fit: BoxFit.contain,
          animation: widget.animation,
          controller: _eyesController,
        ),
      ),
    );
  }
}

class _TeddyEyesController extends FlareController {
  static const double _maxEyesShiftX = 9.0;
  static const double _epsilon = 0.001;
  ActorNode? _eyesNode;
  double _baseEyesX = 0;
  double _target = 0;
  double _current = 0;

  set lookOffsetX(double value) {
    _target = value.clamp(-1.0, 1.0);
    if ((_target - _current).abs() > _epsilon) {
      isActive.value = true;
    }
  }

  @override
  void initialize(FlutterActorArtboard artboard) {
    _eyesNode = artboard.getNode<ActorNode>('ctrl_eyes');
    if (_eyesNode != null) {
      _baseEyesX = _eyesNode!.x;
      _current = 0;
      _applyCurrent();
    }
    isActive.value = false;
  }

  @override
  bool advance(FlutterActorArtboard artboard, double elapsed) {
    if (_eyesNode == null) {
      return false;
    }
    final diff = _target - _current;
    if (diff.abs() <= _epsilon) {
      return false;
    }
    final smoothing = math.min(1.0, elapsed * 14.0);
    _current += diff * smoothing;
    if ((_target - _current).abs() <= _epsilon) {
      _current = _target;
    }
    _applyCurrent();
    return (_target - _current).abs() > _epsilon;
  }

  @override
  void setViewTransform(Mat2D viewTransform) {}

  void _applyCurrent() {
    if (_eyesNode == null) {
      return;
    }
    _eyesNode!.x = _baseEyesX + (_current * _maxEyesShiftX);
  }
}

