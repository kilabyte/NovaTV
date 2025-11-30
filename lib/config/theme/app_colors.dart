import 'package:flutter/material.dart';

/// NovaTV Premium Color Palette
/// Design: Dark OLED Luxury + Glassmorphism Accents
/// Inspired by: Apple TV+, Netflix, Disney+
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY BRAND COLORS
  // Electric Cyan - Modern, tech-forward, premium streaming feel
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF00D9FF);        // Electric Cyan
  static const Color primaryLight = Color(0xFF5CE1FF);   // Light Cyan
  static const Color primaryDark = Color(0xFF00A8CC);    // Deep Cyan
  static const Color primaryMuted = Color(0xFF0891B2);   // Muted Cyan

  // ═══════════════════════════════════════════════════════════════════════════
  // SECONDARY / ACCENT COLORS
  // Warm Amber - Premium, luxurious accent
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color secondary = Color(0xFFFFB800);      // Warm Amber
  static const Color secondaryLight = Color(0xFFFFCB45); // Light Amber
  static const Color secondaryDark = Color(0xFFE5A500);  // Deep Amber

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCENT GRADIENT COLORS
  // Aurora/Cyberpunk inspired accents for featured content
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color accent = Color(0xFFFF3B5C);         // Vibrant Red
  static const Color accentPurple = Color(0xFFA855F7);   // Electric Purple
  static const Color accentPink = Color(0xFFEC4899);     // Hot Pink
  static const Color accentBlue = Color(0xFF3B82F6);     // Royal Blue

  // Gradient pairs for featured content
  static const List<Color> gradientPrimary = [
    Color(0xFF00D9FF),
    Color(0xFFA855F7),
  ];
  static const List<Color> gradientAccent = [
    Color(0xFFFF3B5C),
    Color(0xFFFFB800),
  ];
  static const List<Color> gradientAurora = [
    Color(0xFF00D9FF),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color error = Color(0xFFFF3B5C);
  static const Color errorLight = Color(0xFFFF6B84);
  static const Color errorDark = Color(0xFFE52E4D);

  static const Color success = Color(0xFF00E676);
  static const Color successLight = Color(0xFF69F0AE);
  static const Color successDark = Color(0xFF00C853);

  static const Color warning = Color(0xFFFFB800);
  static const Color warningLight = Color(0xFFFFD54F);
  static const Color warningDark = Color(0xFFFF9800);

  static const Color live = Color(0xFFFF3B5C);           // LIVE indicator

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME - OLED OPTIMIZED
  // True blacks for OLED power savings + premium cinematic feel
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color darkBackground = Color(0xFF000000);       // True OLED black
  static const Color darkSurface = Color(0xFF0A0A0A);          // Near black
  static const Color darkSurfaceElevated = Color(0xFF121212);  // Elevated surface
  static const Color darkSurfaceVariant = Color(0xFF1A1A1A);   // Card background
  static const Color darkSurfaceHover = Color(0xFF242424);     // Hover state
  static const Color darkOnBackground = Color(0xFFFFFFFF);     // Pure white
  static const Color darkOnSurface = Color(0xFFF5F5F5);        // Off-white
  static const Color darkOnSurfaceVariant = Color(0xFF9CA3AF); // Muted text
  static const Color darkOnSurfaceMuted = Color(0xFF6B7280);   // Very muted
  static const Color darkBorder = Color(0xFF262626);           // Subtle borders
  static const Color darkDivider = Color(0xFF1F1F1F);          // Dividers

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME - PREMIUM LIGHT MODE
  // Clean whites with subtle warmth
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5);
  static const Color lightOnBackground = Color(0xFF0A0A0A);
  static const Color lightOnSurface = Color(0xFF171717);
  static const Color lightOnSurfaceVariant = Color(0xFF525252);
  static const Color lightOnSurfaceMuted = Color(0xFF737373);
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightDivider = Color(0xFFF0F0F0);

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASSMORPHISM COLORS
  // For frosted glass overlays
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color glassBackground = Color(0x1AFFFFFF);      // 10% white
  static const Color glassBorder = Color(0x33FFFFFF);          // 20% white border
  static const Color glassBackgroundDark = Color(0x33000000);  // 20% black
  static const Color glassBorderDark = Color(0x1A000000);      // 10% black border

  // ═══════════════════════════════════════════════════════════════════════════
  // EPG / TV GUIDE COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color epgNowIndicator = Color(0xFFFF3B5C);      // Current time line
  static const Color epgCurrentProgram = Color(0xFF00D9FF);    // Currently airing
  static const Color epgPastProgram = Color(0xFF374151);       // Past programs
  static const Color epgFutureProgram = Color(0xFF1F2937);     // Future programs
  static const Color epgTimeHeader = Color(0xFF0A0A0A);        // Time header bg

  // ═══════════════════════════════════════════════════════════════════════════
  // VIDEO PLAYER COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color playerBackground = Color(0xFF000000);
  static const Color playerOverlay = Color(0xB3000000);        // 70% black
  static const Color playerOverlayLight = Color(0x66000000);   // 40% black
  static const Color playerControls = Color(0xFFFFFFFF);
  static const Color playerProgress = Color(0xFF00D9FF);
  static const Color playerBuffer = Color(0x4D00D9FF);         // 30% cyan
  static const Color playerLive = Color(0xFFFF3B5C);

  // ═══════════════════════════════════════════════════════════════════════════
  // SHIMMER / LOADING COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color shimmerBase = Color(0xFF1A1A1A);
  static const Color shimmerHighlight = Color(0xFF2A2A2A);

  // ═══════════════════════════════════════════════════════════════════════════
  // CATEGORY / GENRE COLORS
  // For visual distinction of content categories
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color categoryMovies = Color(0xFFFF3B5C);
  static const Color categorySports = Color(0xFF00E676);
  static const Color categoryNews = Color(0xFF3B82F6);
  static const Color categoryKids = Color(0xFFFFB800);
  static const Color categoryMusic = Color(0xFFA855F7);
  static const Color categoryDocumentary = Color(0xFF0891B2);
}
