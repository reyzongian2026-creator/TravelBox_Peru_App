import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

class MobileNavBehaviorConfig {
  const MobileNavBehaviorConfig({
    this.topRevealOffset = 18,
    this.hideScrollThreshold = 20,
    this.showScrollThreshold = 12,
    this.minScrollDelta = 0.8,
    this.minScrollableExtent = 44,
    this.idleRevealDelay = const Duration(milliseconds: 320),
  });

  final double topRevealOffset;
  final double hideScrollThreshold;
  final double showScrollThreshold;
  final double minScrollDelta;
  final double minScrollableExtent;
  final Duration idleRevealDelay;
}

class MobileNavBehaviorController extends ChangeNotifier {
  MobileNavBehaviorController({this.config = const MobileNavBehaviorConfig()});

  final MobileNavBehaviorConfig config;

  bool _isVisible = true;
  bool _canAutoHide = false;
  double _lastPixels = 0;
  double _accumulatedDelta = 0;
  ScrollDirection _lastDirection = ScrollDirection.idle;
  Timer? _idleTimer;

  bool get isVisible => _isVisible;
  bool get canAutoHide => _canAutoHide;

  void reset() {
    _cancelIdleTimer();
    _lastPixels = 0;
    _accumulatedDelta = 0;
    _lastDirection = ScrollDirection.idle;
    _canAutoHide = false;
    _setVisible(true);
  }

  void forceVisible({bool resetScrollState = false}) {
    if (resetScrollState) {
      _accumulatedDelta = 0;
      _lastDirection = ScrollDirection.idle;
    }
    _setVisible(true);
  }

  void handleScrollNotification(
    ScrollNotification notification, {
    required bool preventAutoHide,
  }) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return;
    }

    final pixels = metrics.pixels.clamp(0.0, metrics.maxScrollExtent);
    final isScrollable = metrics.maxScrollExtent > config.minScrollableExtent;
    final allowAutoHide = isScrollable && !preventAutoHide;

    _updateCanAutoHide(allowAutoHide);

    if (!allowAutoHide) {
      _cancelIdleTimer();
      _lastPixels = pixels;
      forceVisible(resetScrollState: true);
      return;
    }

    if (pixels <= config.topRevealOffset) {
      _lastPixels = pixels;
      _accumulatedDelta = 0;
      _lastDirection = ScrollDirection.idle;
      forceVisible();
      return;
    }

    if (notification is ScrollStartNotification) {
      _lastPixels = pixels;
      _accumulatedDelta = 0;
      _lastDirection = ScrollDirection.idle;
      return;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = pixels - _lastPixels;
      _lastPixels = pixels;
      if (delta.abs() < config.minScrollDelta) {
        return;
      }

      final direction = delta > 0
          ? ScrollDirection.reverse
          : ScrollDirection.forward;
      _consumeDirectionalDelta(direction: direction, magnitude: delta.abs());
      _scheduleIdleReveal();
      return;
    }

    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _scheduleIdleReveal();
      return;
    }

    if (notification is ScrollEndNotification) {
      _scheduleIdleReveal();
    }
  }

  void handlePointerDelta({
    required double delta,
    required bool preventAutoHide,
    required bool scrollableHint,
  }) {
    final allowAutoHide = _canAutoHide && scrollableHint && !preventAutoHide;

    if (!allowAutoHide) {
      _cancelIdleTimer();
      forceVisible(resetScrollState: true);
      return;
    }

    if (delta.abs() < config.minScrollDelta) {
      return;
    }

    final direction = delta > 0
        ? ScrollDirection.reverse
        : ScrollDirection.forward;
    _consumeDirectionalDelta(direction: direction, magnitude: delta.abs());
    _scheduleIdleReveal();
  }

  @override
  void dispose() {
    _cancelIdleTimer();
    super.dispose();
  }

  void _scheduleIdleReveal() {
    _cancelIdleTimer();
    _idleTimer = Timer(config.idleRevealDelay, () {
      _setVisible(true);
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _updateCanAutoHide(bool value) {
    if (_canAutoHide == value) {
      return;
    }
    _canAutoHide = value;
    notifyListeners();
  }

  void _setVisible(bool value) {
    if (_isVisible == value) {
      return;
    }
    _isVisible = value;
    notifyListeners();
  }

  void _consumeDirectionalDelta({
    required ScrollDirection direction,
    required double magnitude,
  }) {
    if (direction != _lastDirection) {
      _accumulatedDelta = 0;
    }
    _lastDirection = direction;
    _accumulatedDelta += magnitude;

    if (direction == ScrollDirection.reverse &&
        _accumulatedDelta >= config.hideScrollThreshold) {
      _setVisible(false);
      _accumulatedDelta = 0;
    } else if (direction == ScrollDirection.forward &&
        _accumulatedDelta >= config.showScrollThreshold) {
      _setVisible(true);
      _accumulatedDelta = 0;
    }
  }
}
