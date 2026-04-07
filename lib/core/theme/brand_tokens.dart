import 'package:flutter/material.dart';

class TravelBoxBrand {
  const TravelBoxBrand._();

  static const primaryBlue = Color(0xFF3366FF);
  static const primaryTeal = Color(0xFF0095FF);
  static const seafoam = Color(0xFF42AAFF);
  static const sand = Color(0xFFF7F9FC);
  static const terracotta = Color(0xFFFF7A59);
  static const copper = Color(0xFF598BFF);
  static const stone = Color(0xFFE4E9F2);
  static const mist = Color(0xFFF7F9FC);
  static const surface = Color(0xFFF4F6FA);
  static const surfaceSoft = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E9F2);
  static const textBody = Color(0xFF2E3A59);
  static const textMuted = Color(0xFF8F9BB3);
  static const ink = Color(0xFF1A2138);
  static const darkSidebar = Color(0xFF151A30);
  static const darkBackground = Color(0xFF101426);

  // ── Payment method colors ──
  static const yape = Color(0xFF6B2D8B);
  static const plin = Color(0xFF00BFA5);
  static const cardPayment = Color(0xFF1565C0);
  static const cashPayment = Color(0xFF2E7D32);
  static const counterPayment = Color(0xFF5D4037);
  static const qrPayment = Color(0xFF0277BD);

  // ── Status colors ──
  static const statusSuccess = Color(0xFF168F64);
  static const statusError = Color(0xFFC43D3D);
  static const statusPending = Color(0xFF1F6E8C);
  static const statusWarning = Color(0xFFF29F05);
  static const statusExpired = Color(0xFF78909C);
  static const statusActive = Color(0xFF2E7D32);

  // ── Spacing scale (8dp grid) ──
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ── Border radii ──
  static const double radiusS = 8;
  static const double radiusM = 16;
  static const double radiusL = 24;
  static const double radiusXL = 28;

  static const authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFF), Color(0xFFF2F5FC), Color(0xFFE9EEF8)],
  );

  static const shellGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFF), Color(0xFFF2F5FC), Color(0xFFEAEFF8)],
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF274BDB), Color(0xFF3366FF), Color(0xFF598BFF)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A3FB7), Color(0xFF3366FF), Color(0xFF7AA1FF)],
  );

  static const discoveryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF274BDB), Color(0xFF3366FF), Color(0xFF0095FF)],
  );

  static const panelGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
  );

  // ── Dark mode surface tokens ──
  static const darkCardSurface = Color(0xFF151A30);
  static const darkCardBorder = Color(0xFF2B3550);
  static const darkPanelSurface = Color(0xFF11182D);
  static const darkPanelBorder = Color(0xFF25304D);

  // ── Discovery/map page tokens ──
  static const discoveryControlSurface = Color(0xFF1B1718);
  static const discoveryControlBorder = Color(0xFF4A3934);

  // ── Light accent text tokens ──
  static const headlineLight = Color(0xFFF6ECDE);

  // ── Profile/admin card tokens ──
  static const adminCardBg = Color(0xFFF6F1E8);
  static const sensitiveCardBg = Color(0xFFFFF7E8);
}
