import 'package:flutter/material.dart';

class AppColors {
  // Primary - Deep Indigo & Electric Blue
  static const Color primary = Color(0xFF312E81); // Deep Indigo
  static const Color primaryLight = Color(0xFF4F46E5); // Indigo 500
  static const Color primaryDark = Color(0xFF1E1B4B); // Indigo 950

  static const Color electricBlue = Color(0xFF3B82F6); // Blue 500
  static const Color electricBlueLight = Color(0xFF60A5FA); // Blue 400

  // Accent - Amber / Coral
  static const Color secondary = Color(0xFFF59E0B); // Amber 500
  static const Color secondaryLight = Color(0xFFFCD34D); // Amber 300
  static const Color secondaryDark = Color(0xFF0891B2); // Cyan 600 - Added back for compatibility
  
  static const Color coral = Color(0xFFF43F5E); // Rose 500
  static const Color discount = Color(0xFFF43F5E); // Rose 500 - Added back for compatibility
  
  static const Color accentPurple = Color(0xFF8B5CF6); // Added back for compatibility
  static const Color accentPink = Color(0xFFEC4899); // Added back for compatibility

  // Neutral Colors (Light mode)
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF111827); // Gray 900
  static const Color background = Color(0xFFF9FAFB); // Gray 50
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient electricGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonGradient = LinearGradient(
    colors: [secondary, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient discountGradient = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  // Flat modern design prefers subtle/no shadows. We keep basic glow.
  static List<BoxShadow> softCard = [
    BoxShadow(
      color: AppColors.gray800.withOpacity(0.03),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> neonGlow = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.gray800.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double button = 12.0;
  static const double input = 14.0;
  static const double card = 16.0;
  static const double full = 50.0;
  
  // Backwards compatibility for old code that uses AppRadius.lg and AppRadius.xl
  static const double lg = 16.0; 
  static const double xl = 16.0;
}
