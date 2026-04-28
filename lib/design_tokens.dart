import 'package:flutter/material.dart';

/// Industrial Atelier Design System Tokens
/// Centralized design constants for the Labour Management App.
class DS {
  DS._();

  // ── Surface Hierarchy ──
  static const Color surface = Color(0xFFFAF9F6);
  static const Color surfaceContainerLow = Color(0xFFF4F3F0);
  static const Color surfaceContainer = Color(0xFFEFEEEB);
  static const Color surfaceContainerHigh = Color(0xFFE9E8E5);
  static const Color surfaceContainerHighest = Color(0xFFE3E2DF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFDBDAD7);

  // ── Primary / Brand ──
  static const Color primaryContainer = Color(0xFF121826);
  static const Color onPrimaryContainer = Color(0xFF7E8395);
  static const Color onPrimaryFixed = Color(0xFF151B29);

  // ── Text ──
  static const Color onSurface = Color(0xFF1A1C1A);
  static const Color onSurfaceVariant = Color(0xFF45464C);
  static const Color outline = Color(0xFF76777D);
  static const Color outlineVariant = Color(0xFFC6C6CC);

  // ── Accent ──
  static const Color secondary = Color(0xFF006C49);
  static const Color secondaryFixed = Color(0xFF6FFBBE);
  static const Color secondaryContainer = Color(0xFF6CF8BB);
  static const Color green = Color(0xFF10B981);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color tertiary = Color(0xFF3980F4);

  // ── Shadows ──
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF151B29).withAlpha(15),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> cardShadowLight = [
    BoxShadow(
      color: const Color(0xFF151B29).withAlpha(5),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: const Color(0xFF10B981).withAlpha(100),
      blurRadius: 24,
      offset: const Offset(0, 12),
      spreadRadius: -8,
    ),
  ];

  // ── Typography (Manrope = Headlines, Inter = Body) ──
  static const String fontHeadline = 'Manrope';
  static const String fontBody = 'Inter';

  static const TextStyle displayLg = TextStyle(
    fontFamily: fontHeadline,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: onSurface,
  );
  static const TextStyle headlineMd = TextStyle(
    fontFamily: fontHeadline,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: onSurface,
  );
  static const TextStyle titleLg = TextStyle(
    fontFamily: fontHeadline,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: onSurface,
  );
  static const TextStyle titleMd = TextStyle(
    fontFamily: fontHeadline,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: onSurface,
  );
  static const TextStyle bodyMd = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: onSurface,
  );
  static const TextStyle bodySm = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: onSurfaceVariant,
  );
  static const TextStyle labelLg = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: onSurfaceVariant,
  );
  static const TextStyle labelSm = TextStyle(
    fontFamily: fontBody,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: onSurfaceVariant,
  );
  static const TextStyle labelXs = TextStyle(
    fontFamily: fontBody,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: onSurfaceVariant,
  );

  // ── Spacing ──
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radiusFull = 9999;

  // ── Component Heights (64px for primary actions) ──
  static const double buttonHeight = 64;
  static const double inputHeight = 64;
  static const double cardMinHeight = 80;
}
