import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

/// Backward-compatible aliases — prefer `Theme.of(context).colorScheme` + [VbColor] in new code.
class AppColors {
  static const Color background = VbColor.background;
  static const Color surface = VbColor.surfaceContainer;
  static const Color surfaceVariant = VbColor.surfaceContainerHigh;

  /// Interactive / voice accent (replaces legacy neon cyan).
  static const Color primary = VbColor.accentElectric;
  static const Color accentCyan = VbColor.accentElectric;
  static const Color accentBlue = VbColor.onTertiaryContainer;
  static const Color accentPurple = VbColor.accentElectric;
  static const Color accentRed = VbColor.errorContainer;

  static const Color textPrimary = VbColor.onBackground;
  static const Color textSecondary = VbColor.onSurfaceVariant;
  static const Color textTertiary = VbColor.outlineVariant;

  static const Color borderLight = VbColor.outlineVariant;
  static const Color borderMedium = VbColor.outline;

  static const Color success = Color(0xFF6EE7A8);
  static const Color warning = Color(0xFFFFD56B);
  static const Color error = VbColor.error;

  static const LinearGradient cyberGradient = LinearGradient(
    colors: [VbColor.surfaceContainerHigh, VbColor.surfaceContainerLowest],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGlassGradient = LinearGradient(
    colors: [VbColor.surfaceContainer, VbColor.surfaceContainerLowest],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient purpleNeonGradient = LinearGradient(
    colors: [VbColor.accentElectric, VbColor.onTertiaryContainer],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color primaryDark = VbColor.inversePrimary;
  static const Color primaryLight = VbColor.primaryFixed;
  static const Color secondary = VbColor.onSurfaceVariant;
  static const Color textDark = VbColor.inverseOnSurface;
  static const Color accentOrange = warning;
  static const Color backgroundCard = VbColor.surfaceContainer;
  static const Color backgroundOffWhite = VbColor.background;
  static const Color immersiveDark = VbColor.background;
  static const Color immersiveBlack = Color(0xFF000000);

  static const Color orbActive = VbColor.accentElectric;
  static const Color orbThinking = VbColor.tertiary;
  static const Color orbSpeaking = VbColor.accentElectric;

  static const Color mediumGray = VbColor.onSurfaceVariant;
  static const Color lightGray = VbColor.outlineVariant;
  static const Color successGreen = success;
  static const Color warningAmber = warning;
  static const Color errorRed = VbColor.errorContainer;
  static const Color primaryBlue = VbColor.onTertiaryContainer;
  static const Color accentTeal = VbColor.tertiary;
}

class AppAnimations {
  static const Curve smoothCurve = Curves.fastOutSlowIn;
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 500);
  static const Curve bouncyCurve = Curves.elasticOut;

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: VbColor.accentElectric.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppTheme {
  static ThemeData get lightTheme => darkTheme;

  static const ColorScheme _vbScheme = ColorScheme(
        brightness: Brightness.dark,
        primary: VbColor.primary,
        onPrimary: VbColor.onPrimary,
        primaryContainer: VbColor.primaryContainer,
        onPrimaryContainer: VbColor.onPrimaryContainer,
        secondary: VbColor.secondary,
        onSecondary: VbColor.onSecondary,
        secondaryContainer: VbColor.secondaryContainer,
        onSecondaryContainer: VbColor.onSecondaryContainer,
        tertiary: VbColor.tertiary,
        onTertiary: VbColor.onTertiary,
        tertiaryContainer: VbColor.tertiaryContainer,
        onTertiaryContainer: VbColor.onTertiaryContainer,
        error: VbColor.error,
        onError: VbColor.onError,
        errorContainer: VbColor.errorContainer,
        onErrorContainer: VbColor.onErrorContainer,
        surface: VbColor.surface,
        onSurface: VbColor.onSurface,
        surfaceContainerHighest: VbColor.surfaceContainerHighest,
        onInverseSurface: VbColor.inverseOnSurface,
        inverseSurface: VbColor.inverseSurface,
        inversePrimary: VbColor.inversePrimary,
        shadow: Colors.black,
        surfaceTint: VbColor.surfaceTint,
        outlineVariant: VbColor.outlineVariant,
        outline: VbColor.outline,
        scrim: Colors.black54,
        surfaceContainerLowest: VbColor.surfaceContainerLowest,
        surfaceContainerLow: VbColor.surfaceContainerLow,
        surfaceContainer: VbColor.surfaceContainer,
        surfaceContainerHigh: VbColor.surfaceContainerHigh,
      );

  static TextTheme _buildTextTheme() {
    final interBase = GoogleFonts.interTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(
          fontSize: VbTypography.bodyLg,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: VbColor.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: VbTypography.bodyMd,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: VbColor.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: VbColor.onSurfaceVariant,
        ),
        titleMedium: TextStyle(
          fontSize: VbTypography.bodyMd,
          fontWeight: FontWeight.w500,
          color: VbColor.onSurface,
        ),
      ),
    );

    final space = GoogleFonts.spaceMonoTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: VbTypography.displayDotSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
          letterSpacing: -0.05 * 16,
          color: VbColor.onBackground,
        ),
        displayMedium: TextStyle(
          fontSize: VbTypography.headlineLg,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: VbColor.onBackground,
        ),
        displaySmall: TextStyle(
          fontSize: VbTypography.headlineMd,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: VbColor.onBackground,
        ),
        headlineMedium: TextStyle(
          fontSize: VbTypography.headlineMd,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: VbColor.onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: VbColor.onSurface,
        ),
      ),
    );

    final jb = GoogleFonts.jetBrainsMonoTextTheme(
      const TextTheme(
        labelSmall: TextStyle(
          fontSize: VbTypography.labelCaps,
          fontWeight: FontWeight.w500,
          height: 1,
          letterSpacing: 0.1 * 12,
          color: VbColor.onSurfaceVariant,
        ),
      ),
    );

    return interBase.copyWith(
      displayLarge: space.displayLarge,
      displayMedium: space.displayMedium,
      displaySmall: space.displaySmall,
      headlineMedium: space.headlineMedium,
      headlineSmall: space.headlineSmall,
      labelSmall: jb.labelSmall,
      labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        color: VbColor.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: VbColor.inverseSurface,
      ),
    );
  }

  static ThemeData get darkTheme {
    const scheme = _vbScheme;
    final textTheme = _buildTextTheme();

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: VbColor.background,
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VbColor.inverseSurface,
          foregroundColor: VbColor.inverseOnSurface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VbRadii.full),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VbColor.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          side: const BorderSide(color: VbColor.outline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VbRadii.full),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VbColor.accentElectric,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VbColor.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VbRadii.lg),
          borderSide: const BorderSide(color: VbColor.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VbRadii.lg),
          borderSide: const BorderSide(color: VbColor.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VbRadii.lg),
          borderSide: const BorderSide(color: VbColor.inverseSurface, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(color: VbColor.onSurfaceVariant.withValues(alpha: 0.7)),
        labelStyle: GoogleFonts.inter(color: VbColor.onSurfaceVariant, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: VbColor.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VbRadii.lg),
          side: const BorderSide(color: VbColor.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: VbColor.background,
        foregroundColor: VbColor.onSurface,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.spaceMono(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: VbColor.onSurface,
          letterSpacing: 2,
        ),
        iconTheme: const IconThemeData(color: VbColor.onSurface, size: 22),
      ),
      dividerTheme: const DividerThemeData(
        color: VbColor.outlineVariant,
        thickness: 1,
        space: 24,
      ),
      iconTheme: const IconThemeData(color: VbColor.onSurface, size: 22),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: VbColor.inverseSurface,
        foregroundColor: VbColor.inverseOnSurface,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),
    );
  }
}
