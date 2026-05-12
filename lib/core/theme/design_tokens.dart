import 'package:flutter/material.dart';

/// VoiceBridge design tokens (YAML palette + electric accent for mock parity).
abstract final class VbColor {
  static const Color surface = Color(0xFF131313);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceBright = Color(0xFF393939);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1B1B1B);
  static const Color surfaceContainer = Color(0xFF1F1F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353535);
  static const Color onSurface = Color(0xFFE2E2E2);
  static const Color onSurfaceVariant = Color(0xFFCFC4C5);
  static const Color inverseSurface = Color(0xFFE2E2E2);
  static const Color inverseOnSurface = Color(0xFF303030);
  static const Color outline = Color(0xFF988E90);
  static const Color outlineVariant = Color(0xFF4C4546);
  static const Color surfaceTint = Color(0xFFC6C6C6);
  static const Color primary = Color(0xFFC6C6C6);
  static const Color onPrimary = Color(0xFF303030);
  static const Color primaryContainer = Color(0xFF000000);
  static const Color onPrimaryContainer = Color(0xFF757575);
  static const Color inversePrimary = Color(0xFF5E5E5E);
  static const Color secondary = Color(0xFFC6C6C7);
  static const Color onSecondary = Color(0xFF2F3131);
  static const Color secondaryContainer = Color(0xFF454747);
  static const Color onSecondaryContainer = Color(0xFFB4B5B5);
  static const Color tertiary = Color(0xFFDDB7FF);
  static const Color onTertiary = Color(0xFF490080);
  static const Color tertiaryContainer = Color(0xFF000000);
  static const Color onTertiaryContainer = Color(0xFF9C49EB);
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);
  static const Color primaryFixed = Color(0xFFE2E2E2);
  static const Color primaryFixedDim = Color(0xFFC6C6C6);
  static const Color onPrimaryFixed = Color(0xFF1B1B1B);
  static const Color onPrimaryFixedVariant = Color(0xFF474747);
  static const Color secondaryFixed = Color(0xFFE2E2E2);
  static const Color secondaryFixedDim = Color(0xFFC6C6C7);
  static const Color onSecondaryFixed = Color(0xFF1A1C1C);
  static const Color onSecondaryFixedVariant = Color(0xFF454747);
  static const Color tertiaryFixed = Color(0xFFF0DBFF);
  static const Color tertiaryFixedDim = Color(0xFFDDB7FF);
  static const Color onTertiaryFixed = Color(0xFF2C0051);
  static const Color onTertiaryFixedVariant = Color(0xFF6900B3);
  static const Color background = Color(0xFF131313);
  static const Color onBackground = Color(0xFFE2E2E2);
  static const Color surfaceVariant = Color(0xFF353535);

  /// Reference “Electric Purple” — voice, active nav, progress glow.
  static const Color accentElectric = Color(0xFFA855F7);

  static const Color glassFill = Color(0x0DFFFFFF); // ~5% white
  static const Color borderIdle = Color(0x33FFFFFF); // ~20% white hairline feel
}

abstract final class VbSpacing {
  static const double xs = 4;
  static const double sm = 12;
  static const double base = 8;
  static const double md = 24;
  static const double lg = 48;
  static const double xl = 80;
  static const double marginMobile = 20;
  static const double marginDesktop = 64;
}

abstract final class VbRadii {
  static const double sm = 4; // 0.25rem
  static const double defaultR = 8; // 0.5rem
  static const double md = 12; // 0.75rem
  static const double lg = 16; // 1rem — card squircle
  static const double xl = 24; // 1.5rem
  static const double full = 9999;
}

abstract final class VbTypography {
  static const double displayDotSize = 48;
  static const double headlineLg = 32;
  static const double headlineMd = 24;
  static const double bodyLg = 18;
  static const double bodyMd = 16;
  static const double labelCaps = 12;
}

/// Dot grid pitch (px) per spec.
const double vbDotGridPitch = 24;
