import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Action Colors - Supernova/Duolingo inspired
  static const Color primary = Color(0xFF58CC02); // Vibrant Green
  static const Color primaryDark = Color(0xFF46A302);
  static const Color primaryLight = Color(0xFF89E219);
  
  static const Color secondary = Color(0xFF1CB0F6); // Vibrant Blue
  static const Color secondaryDark = Color(0xFF1899D6);
  static const Color secondaryLight = Color(0xFF6ED0FA);
  
  static const Color accentPurple = Color(0xFFCE82FF); 
  static const Color accentPurpleDark = Color(0xFFA568CC);
  
  static const Color accentOrange = Color(0xFFFF9600);
  static const Color accentRed = Color(0xFFFF4B4B);

  // Backgrounds & Neutrals
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundOffWhite = Color(0xFFF7F7F7); // Typical Duolingo background
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color textDark = Color(0xFF4B4B4B); // Softer than black, very readable
  static const Color textMedium = Color(0xFF777777);
  static const Color textLight = Color(0xFFAFAFAF);
  
  static const Color borderLight = Color(0xFFE5E5E5);
  static const Color borderMedium = Color(0xFFD4D4D4);

  // Success & Feedback
  static const Color success = Color(0xFF58CC02);
  static const Color warning = Color(0xFFFFC800);
  static const Color error = Color(0xFFFF4B4B);
  
  // Gradients for special badges/cards
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFFCE82FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve bouncyCurve = Curves.elasticOut;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
        onSurface: AppColors.textDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundOffWhite,
      textTheme: GoogleFonts.nunitoTextTheme( // Nunito provides that friendly, rounded look
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
          displayMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
          displaySmall: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          headlineMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          bodyLarge: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700, // Slightly bolder body text
            color: AppColors.textDark,
            height: 1.4,
          ),
          bodyMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textMedium,
            height: 1.4,
          ),
          bodySmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
          ),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800, // Very bold buttons
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0, 
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: const BorderSide(color: AppColors.borderLight, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundOffWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight, width: 2), // Outline cards
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surface, // Solid white app bar instead of transparent/glass
        foregroundColor: AppColors.textDark,
        centerTitle: true,
        scrolledUnderElevation: 2, // Slight shadow on scroll
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          fontFamily: 'Nunito',
        ),
        iconTheme: IconThemeData(color: AppColors.textMedium),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 2,
        space: 24,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
      ),
    );
  }

  // Fallback dark theme
  static ThemeData get darkTheme {
    return lightTheme; // In Duolingo style apps, light mode is preferred, dark mode is just an inverted light mode. We will stick to light mode for now to ensure consistency.
  }
}
