import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Futuristic Galactic Cyan/Blue palette
  static const Color background = Color(0xFF050508);
  static const Color surface = Color(0xFF0D1117);
  static const Color surfaceVariant = Color(0xFF161B22);
  
  static const Color primary = Color(0xFF00F0FF); // Neon Cyan
  static const Color accentCyan = Color(0xFF00F0FF);
  static const Color accentBlue = Color(0xFF3A86FF);
  static const Color accentPurple = Color(0xFF8338EC);
  static const Color accentRed = Color(0xFFFF006E);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAB4C8);
  static const Color textTertiary = Color(0xFF656E83);
  
  static const Color borderLight = Color(0xFF1F2937);
  static const Color borderMedium = Color(0xFF30363D);
  
  static const Color success = Color(0xFF00FF88);
  static const Color warning = Color(0xFFFFBE0B);
  static const Color error = Color(0xFFFF006E);
  
  // Glassmorphism & Cyber Gradients
  static const LinearGradient cyberGradient = LinearGradient(
    colors: [Color(0xFF00F0FF), Color(0xFF3A86FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGlassGradient = LinearGradient(
    colors: [Color(0xFF161B22), Color(0xFF0D1117)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient purpleNeonGradient = LinearGradient(
    colors: [Color(0xFF8338EC), Color(0xFFFF006E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Mappings for retro-compat
  static const Color primaryDark = Color(0xFF3A86FF);
  static const Color primaryLight = Color(0xFFE0FBFC);
  static const Color secondary = Color(0xFF656E83);
  static const Color textDark = Color(0xFF000000);
  static const Color accentOrange = Color(0xFFFFBE0B);
  static const Color backgroundCard = Color(0xFF0D1117);
  static const Color backgroundOffWhite = Color(0xFF050508);
  static const Color immersiveDark = Color(0xFF050508);
  static const Color immersiveBlack = Color(0xFF000000);
  
  static const Color orbActive = Color(0xFF00F0FF);
  static const Color orbThinking = Color(0xFF8338EC);
  static const Color orbSpeaking = Color(0xFF00FF88);
  
  static const Color mediumGray = Color(0xFFAAB4C8);
  static const Color lightGray = Color(0xFF1F2937);
  static const Color successGreen = Color(0xFF00FF88);
  static const Color warningAmber = Color(0xFFFFBE0B);
  static const Color errorRed = Color(0xFFFF006E);
  static const Color primaryBlue = Color(0xFF3A86FF);
  static const Color accentTeal = Color(0xFF00FF88);
}

class AppAnimations {
  static const Curve smoothCurve = Curves.fastOutSlowIn;
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 500);
  static const Curve bouncyCurve = Curves.elasticOut;

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.1),
      blurRadius: 24,
      offset: const Offset(0, 8),
    )
  ];
}

class AppTheme {
  // High-end Futuristic dark theme
  static ThemeData get lightTheme => darkTheme; 

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accentBlue,
        error: AppColors.error,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      
      // Font selection: Outfit for elegance, Space Mono for dynamic metrics
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          displaySmall: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.3,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: AppColors.textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: AppColors.textTertiary,
          ),
          labelLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          splashFactory: InkRipple.splashFactory,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Sharp rounded for futurism
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          side: const BorderSide(color: AppColors.borderMedium, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.accentRed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28), // Distinct large round corners
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 1.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 32,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentRed, // Floating red dot
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const CircleBorder(),
      ),
    );
  }
}

