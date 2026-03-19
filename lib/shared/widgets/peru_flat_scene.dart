import 'package:flutter/material.dart';

import '../data/peru_tourism_catalog.dart';

class PeruFlatScene extends StatelessWidget {
  const PeruFlatScene({
    super.key,
    required this.city,
    this.height = 132,
    this.showLabel = true,
  });

  final String city;
  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tourism = PeruTourismCatalog.forCity(city);
    final icon = _resolveLandmarkIcon(tourism.heroLandmark);
    final isCompact = height < 70;

    return Container(
      height: height,
      padding: EdgeInsets.all(isCompact ? 7 : 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7F5FA), Color(0xFFF2F9FF)],
        ),
        border: Border.all(color: const Color(0xFFD1E4EE)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final routeBottom = isCompact ? 1.0 : 6.0;
          final landmarkSize = isCompact ? 18.0 : 30.0;
          final sunSize = isCompact ? 10.0 : 20.0;
          final labelTop = isCompact ? 1.0 : 4.0;

          return Stack(
            children: [
              Positioned(
                right: isCompact ? 3 : 8,
                top: isCompact ? 1 : 2,
                child: Container(
                  width: sunSize,
                  height: sunSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8C24D),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -8,
                right: constraints.maxWidth * 0.18,
                bottom: constraints.maxHeight * 0.28,
                child: Container(
                  height: constraints.maxHeight * 0.24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E5F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * 0.25,
                right: -10,
                bottom: constraints.maxHeight * 0.22,
                child: Container(
                  height: constraints.maxHeight * 0.22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8DCEE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: constraints.maxHeight * 0.26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EFF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                right: isCompact ? 3 : 6,
                bottom: constraints.maxHeight * 0.19,
                child: Icon(
                  icon,
                  color: const Color(0xFF1D6F90),
                  size: landmarkSize,
                ),
              ),
              Positioned(
                left: constraints.maxWidth * 0.08,
                right: constraints.maxWidth * 0.08,
                bottom: routeBottom,
                child: _RouteProgressStrip(compact: isCompact),
              ),
              if (showLabel)
                Positioned(
                  left: isCompact ? 2 : 4,
                  right: isCompact ? 20 : 22,
                  top: labelTop,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 6 : 8,
                      vertical: isCompact ? 1 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${tourism.city}: ${tourism.heroLandmark}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF1B3A4B),
                        fontWeight: FontWeight.w700,
                        fontSize: isCompact ? 9 : 12,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RouteProgressStrip extends StatelessWidget {
  const _RouteProgressStrip({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markerSize = compact ? 8.0 : 10.0;
    final stripHeight = compact ? 14.0 : 18.0;

    return SizedBox(
      height: stripHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxX = (constraints.maxWidth - markerSize)
              .clamp(0.0, double.infinity)
              .toDouble();
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: stripHeight * 0.45,
                child: Container(
                  height: compact ? 3 : 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF90AEC5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              ...[0.0, 0.5, 1.0].map((step) {
                return Positioned(
                  left: maxX * step,
                  top: stripHeight * 0.34,
                  child: Container(
                    width: markerSize,
                    height: markerSize,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3D7EA6),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
              if (!compact)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Row(
                    children: const [
                      Icon(Icons.person, color: Color(0xFF3D7EA6), size: 14),
                      SizedBox(width: 1),
                      Icon(Icons.luggage, color: Color(0xFF3D7EA6), size: 13),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

IconData _resolveLandmarkIcon(String landmark) {
  final normalized = landmark.toLowerCase();
  if (normalized.contains('machu') || normalized.contains('inca')) {
    return Icons.terrain_rounded;
  }
  if (normalized.contains('playa') || normalized.contains('costa')) {
    return Icons.waves_rounded;
  }
  if (normalized.contains('amazon')) {
    return Icons.forest_rounded;
  }
  if (normalized.contains('lago')) {
    return Icons.water_rounded;
  }
  if (normalized.contains('chan chan') || normalized.contains('centro')) {
    return Icons.account_balance_rounded;
  }
  return Icons.landscape_rounded;
}
