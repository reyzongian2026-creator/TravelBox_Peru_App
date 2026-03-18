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

    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9F7F8), Color(0xFFF1F7FD)],
        ),
        border: Border.all(color: const Color(0xFFD4E6EE)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD166),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -8,
            right: 30,
            bottom: 30,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF9BD5B4),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 24,
            child: Icon(icon, color: const Color(0xFF1B6E8B), size: 34),
          ),
          Positioned(
            left: 6,
            bottom: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.person, color: Color(0xFF0F7A80), size: 18),
                SizedBox(width: 2),
                Icon(Icons.luggage, color: Color(0xFF0F7A80), size: 17),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFC9E8D1),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (showLabel)
            Positioned(
              left: 8,
              right: 8,
              top: 6,
              child: Text(
                '${tourism.city}: ${tourism.heroLandmark}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1B3A4B),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
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
