import 'package:flutter/material.dart';

/// NovaTV Color Palette - TiViMate/iMPlayer Inspired
///
/// Design Philosophy: Content-first, cable TV familiar, OLED optimized
/// Inspired by TiViMate's clean interface and iMPlayer's smooth navigation
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY BRAND COLORS - TiViMate-inspired teal accent
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary accent - Vibrant teal (TiViMate inspired)
  static const Color primary = Color(0xFF00BCD4);
  static const Color primaryLight = Color(0xFF4DD0E1);
  static const Color primaryDark = Color(0xFF0097A7);
  static const Color primaryMuted = Color(0xFF00838F);

  // ═══════════════════════════════════════════════════════════════════════════
  // SECONDARY / ACCENT COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Secondary accent - Warm orange for highlights
  static const Color secondary = Color(0xFFFF9800);
  static const Color secondaryLight = Color(0xFFFFB74D);
  static const Color secondaryDark = Color(0xFFF57C00);

  /// Category accent colors
  static const Color accent = Color(0xFFE53935);
  static const Color accentPurple = Color(0xFF8E24AA);
  static const Color accentPink = Color(0xFFD81B60);
  static const Color accentBlue = Color(0xFF1E88E5);
  static const Color accentGreen = Color(0xFF43A047);
  static const Color accentYellow = Color(0xFFFDD835);

  // Gradients for featured content
  static const List<Color> gradientPrimary = [
    Color(0xFF00BCD4),
    Color(0xFF0097A7),
  ];
  static const List<Color> gradientAccent = [
    Color(0xFFE53935),
    Color(0xFFFF9800),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color errorDark = Color(0xFFC62828);

  static const Color success = Color(0xFF43A047);
  static const Color successLight = Color(0xFF66BB6A);
  static const Color successDark = Color(0xFF2E7D32);

  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFF57C00);

  static const Color live = Color(0xFFE53935);

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME - OLED OPTIMIZED (TiViMate style)
  // True blacks for OLED + clean content-first look
  // ═══════════════════════════════════════════════════════════════════════════

  /// True black background - OLED optimized
  static const Color darkBackground = Color(0xFF000000);

  /// Sidebar background - slightly elevated
  static const Color darkSidebar = Color(0xFF0D0D0D);

  /// Surface colors - card backgrounds
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceElevated = Color(0xFF1A1A1A);
  static const Color darkSurfaceVariant = Color(0xFF1E1E1E);
  static const Color darkSurfaceHover = Color(0xFF2A2A2A);
  static const Color darkSurfaceActive = Color(0xFF333333);

  /// Text colors
  static const Color darkOnBackground = Color(0xFFFFFFFF);
  static const Color darkOnSurface = Color(0xFFF5F5F5);
  static const Color darkOnSurfaceVariant = Color(0xFFB3B3B3);
  static const Color darkOnSurfaceMuted = Color(0xFF757575);
  static const Color darkOnSurfaceDisabled = Color(0xFF4A4A4A);

  /// Border and divider colors
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkBorderLight = Color(0xFF333333);
  static const Color darkDivider = Color(0xFF1F1F1F);

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
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
  // EPG / TV GUIDE COLORS - Cable TV inspired
  // ═══════════════════════════════════════════════════════════════════════════

  /// Currently airing program highlight
  static const Color epgNow = Color(0xFF00BCD4);
  static const Color epgNowBackground = Color(0xFF002D33);

  /// Past programs - dimmed
  static const Color epgPast = Color(0xFF1A1A1A);
  static const Color epgPastText = Color(0xFF5A5A5A);

  /// Future programs
  static const Color epgFuture = Color(0xFF1E1E1E);

  /// Time indicator line (current time)
  static const Color epgTimeIndicator = Color(0xFFFF5722);
  static const Color epgNowIndicator = Color(0xFFFF5722);

  /// Selected program highlight
  static const Color epgSelected = Color(0xFF00838F);
  static const Color epgCurrentProgram = Color(0xFF00BCD4);
  static const Color epgPastProgram = Color(0xFF1A1A1A);
  static const Color epgFutureProgram = Color(0xFF1E1E1E);
  static const Color epgTimeHeader = Color(0xFF0D0D0D);

  // ═══════════════════════════════════════════════════════════════════════════
  // SIDEBAR & NAVIGATION - TiViMate style
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sidebar item selected
  static const Color sidebarSelected = Color(0xFF00BCD4);
  static const Color sidebarSelectedBg = Color(0xFF002D33);

  /// Sidebar item hover
  static const Color sidebarHover = Color(0xFF1A1A1A);

  /// Group category colors (for visual distinction)
  static const List<Color> groupColors = [
    Color(0xFF1E88E5), // Blue - All/General
    Color(0xFFE53935), // Red - Sports
    Color(0xFF43A047), // Green - News
    Color(0xFF8E24AA), // Purple - Movies
    Color(0xFFFF9800), // Orange - Entertainment
    Color(0xFFD81B60), // Pink - Kids
    Color(0xFF00ACC1), // Cyan - Documentary
    Color(0xFFFDD835), // Yellow - Music
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // VIDEO PLAYER COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color playerBackground = Color(0xFF000000);
  static const Color playerOverlay = Color(0xB3000000);
  static const Color playerOverlayLight = Color(0x66000000);
  static const Color playerControls = Color(0xFFFFFFFF);
  static const Color playerProgress = Color(0xFF00BCD4);
  static const Color playerBuffer = Color(0x4D00BCD4);
  static const Color playerLive = Color(0xFFE53935);

  /// Player overlay gradients
  static const Color playerOverlayTop = Color(0xCC000000);
  static const Color playerOverlayBottom = Color(0xE6000000);

  /// Progress bar
  static const Color progressBackground = Color(0xFF333333);
  static const Color progressBuffered = Color(0xFF666666);
  static const Color progressPlayed = Color(0xFF00BCD4);

  // ═══════════════════════════════════════════════════════════════════════════
  // CHANNEL COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Channel logo placeholder
  static const Color logoPlaceholder = Color(0xFF2A2A2A);

  /// Favorite/starred
  static const Color favorite = Color(0xFFFFB300);

  // ═══════════════════════════════════════════════════════════════════════════
  // SHIMMER / LOADING COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color shimmerBase = Color(0xFF1A1A1A);
  static const Color shimmerHighlight = Color(0xFF2A2A2A);

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASSMORPHISM COLORS (minimal use)
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color glassBackground = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassBackgroundDark = Color(0x33000000);
  static const Color glassBorderDark = Color(0x1A000000);

  // ═══════════════════════════════════════════════════════════════════════════
  // CATEGORY / GENRE COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color categoryMovies = Color(0xFF8E24AA);
  static const Color categorySports = Color(0xFFE53935);
  static const Color categoryNews = Color(0xFF1E88E5);
  static const Color categoryKids = Color(0xFFFF9800);
  static const Color categoryMusic = Color(0xFFD81B60);
  static const Color categoryDocumentary = Color(0xFF00ACC1);
  static const Color categoryEntertainment = Color(0xFF43A047);

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient playerTopGradient = LinearGradient(
    colors: [playerOverlayTop, Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient playerBottomGradient = LinearGradient(
    colors: [Colors.transparent, playerOverlayBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
