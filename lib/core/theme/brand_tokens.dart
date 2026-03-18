import 'package:flutter/material.dart';

class TravelBoxBrand {
  const TravelBoxBrand._();

  static const primaryBlue = Color(0xFF3C50E0);
  static const primaryTeal = Color(0xFF465FFF);
  static const seafoam = Color(0xFF80CAEE);
  static const sand = Color(0xFFF0950C);
  static const surface = Color(0xFFEFF4FB);
  static const surfaceSoft = Color(0xFFF7F9FC);
  static const border = Color(0xFFE5E8EC);
  static const textBody = Color(0xFF64748B);
  static const darkSidebar = Color(0xFF1C2434);
  static const darkBackground = Color(0xFF1E1C2A);

  static const authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F7FF), Color(0xFFEFF4FB), Color(0xFFF9FBFE)],
  );

  static const shellGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4F7FC), Color(0xFFEFF4FB)],
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C50E0), Color(0xFF465FFF), Color(0xFF80CAEE)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C50E0), Color(0xFF4D67FF)],
  );
}
