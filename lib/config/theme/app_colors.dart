import 'package:flutter/material.dart';

/// NovaTV Clean Design Color Palette
///
/// Design Philosophy: Modern utility-focused, no gradients
/// - Solid dark surfaces
/// - Single accent color (cyan)
/// - Clean typography hierarchy
/// - Professional and minimal
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY ACCENT - Single cyan accent
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color primary = Color(0xFF00D4FF);
  static const Color primaryDark = Color(0xFF00A8CC);
  static const Color primaryMuted = Color(0xFF0088AA);

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color error = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color live = Color(0xFFFF453A);
  static const Color favorite = Color(0xFFFFD60A);

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME - Clean solid colors
  // ═══════════════════════════════════════════════════════════════════════════

  /// Main background - pure dark
  static const Color background = Color(0xFF0A0A0A);

  /// Sidebar background
  static const Color sidebar = Color(0xFF141414);

  /// Content area background
  static const Color surface = Color(0xFF1A1A1A);

  /// Elevated surfaces (cards, modals)
  static const Color surfaceElevated = Color(0xFF242424);

  /// Hover states
  static const Color surfaceHover = Color(0xFF2A2A2A);

  /// Active/pressed states
  static const Color surfaceActive = Color(0xFF333333);

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT COLORS - Clear hierarchy
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF666666);
  static const Color textDisabled = Color(0xFF444444);

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDERS & DIVIDERS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color border = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF3A3A3A);
  static const Color divider = Color(0xFF1F1F1F);

  // ═══════════════════════════════════════════════════════════════════════════
  // EPG / PROGRAM GUIDE
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color epgNow = Color(0xFF00D4FF);
  static const Color epgNowBg = Color(0xFF0D2A33);
  static const Color epgPast = Color(0xFF1A1A1A);
  static const Color epgPastText = Color(0xFF555555);
  static const Color epgFuture = Color(0xFF242424);

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAYER
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color playerBackground = Color(0xFF000000);
  static const Color playerOverlay = Color(0x99000000);
  static const Color playerControls = Color(0xFFFFFFFF);
  static const Color playerProgress = Color(0xFF00D4FF);
  static const Color playerBuffer = Color(0x4DFFFFFF);

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADING / SHIMMER
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color shimmerBase = Color(0xFF1A1A1A);
  static const Color shimmerHighlight = Color(0xFF2A2A2A);

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKWARDS COMPATIBILITY - Map old names to new
  // ═══════════════════════════════════════════════════════════════════════════

  // Old liquid glass names mapped to new solid colors
  static const Color darkBackground = background;
  static const Color darkBase = background;
  static const Color darkSurface = surface;
  static const Color darkSurfaceElevated = surfaceElevated;
  static const Color darkSurfaceVariant = surfaceElevated;
  static const Color darkSurfaceHover = surfaceHover;
  static const Color darkSurfaceActive = surfaceActive;
  static const Color darkSidebar = sidebar;
  static const Color darkOnBackground = textPrimary;
  static const Color darkOnSurface = textPrimary;
  static const Color darkOnSurfaceVariant = textSecondary;
  static const Color darkOnSurfaceMuted = textMuted;
  static const Color darkOnSurfaceDisabled = textDisabled;
  static const Color darkBorder = border;
  static const Color darkBorderLight = borderLight;
  static const Color darkDivider = divider;

  // Glass colors - now just subtle opacity
  static const Color glassBackground = Color(0x0DFFFFFF);
  static const Color glassBackgroundLight = Color(0x1AFFFFFF);
  static const Color glassBackgroundMedium = Color(0x26FFFFFF);
  static const Color glassBackgroundHeavy = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color glassBorderLight = Color(0x26FFFFFF);
  static const Color glassBorderGlow = Color(0x33FFFFFF);
  static const Color glassCyan = Color(0x1A00D4FF);

  // Old accent colors for compatibility
  static const Color secondary = Color(0xFFFF9F0A);
  static const Color secondaryLight = Color(0xFFFFBF60);
  static const Color secondaryDark = Color(0xFFE68A00);
  static const Color accent = Color(0xFFFF453A);
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentPink = Color(0xFFFF2D55);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color accentYellow = Color(0xFFFFD60A);
  static const Color accentMint = Color(0xFF00C7BE);
  static const Color accentIndigo = Color(0xFF5856D6);

  // Aurora colors - keeping for any remaining uses
  static const Color auroraCyan = primary;
  static const Color auroraPurple = accentPurple;
  static const Color auroraMagenta = accentPink;
  static const Color auroraBlue = accentBlue;
  static const Color auroraOrange = accentOrange;

  // EPG compatibility
  static const Color epgSelected = primaryDark;
  static const Color epgCurrentProgram = epgNow;
  static const Color epgPastProgram = epgPast;
  static const Color epgFutureProgram = epgFuture;
  static const Color epgTimeHeader = sidebar;
  static const Color epgTimeIndicator = warning;
  static const Color epgNowIndicator = warning;
  static const Color epgNowBackground = epgNowBg;

  // Navigation
  static const Color sidebarSelected = primary;
  static const Color sidebarSelectedBg = Color(0xFF1A2A30);
  static const Color sidebarHover = surfaceHover;
  static const Color navBarGlass = glassBackground;
  static const Color navBarBorder = glassBorder;
  static const Color navPillBackground = Color(0x3300D4FF);
  static const Color navPillBorder = Color(0x4D00D4FF);

  // Player compatibility
  static const Color playerOverlayLight = Color(0x4D000000);
  static const Color playerGlassBar = Color(0x33FFFFFF);
  static const Color playerGlassBorder = Color(0x1AFFFFFF);
  static const Color playerOverlayTop = Color(0xB3000000);
  static const Color playerOverlayBottom = Color(0xE6000000);
  static const Color progressBackground = Color(0x33FFFFFF);
  static const Color progressBuffered = playerBuffer;
  static const Color progressPlayed = playerProgress;
  static const Color playerLive = live;

  // Other
  static const Color logoPlaceholder = surfaceElevated;
  static const Color primaryLight = Color(0xFF5CE1FF);

  // Category colors
  static const Color categoryMovies = accentPurple;
  static const Color categorySports = error;
  static const Color categoryNews = accentBlue;
  static const Color categoryKids = accentOrange;
  static const Color categoryMusic = accentPink;
  static const Color categoryDocumentary = accentMint;
  static const Color categoryEntertainment = success;

  // Light theme (keeping for completeness)
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F0F0);
  static const Color lightOnBackground = Color(0xFF0A0A0A);
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  static const Color lightOnSurfaceVariant = Color(0xFF505050);
  static const Color lightOnSurfaceMuted = Color(0xFF707070);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightDivider = Color(0xFFF0F0F0);

  // Group colors for channel categories
  static const List<Color> groupColors = [
    Color(0xFF007AFF), // Blue
    Color(0xFFFF453A), // Red
    Color(0xFF30D158), // Green
    Color(0xFFBF5AF2), // Purple
    Color(0xFFFF9F0A), // Orange
    Color(0xFFFF2D55), // Pink
    Color(0xFF00C7BE), // Mint
    Color(0xFFFFD60A), // Yellow
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS - Kept for backwards compatibility but simplified
  // ═══════════════════════════════════════════════════════════════════════════

  // These are still needed for player overlays
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

  // Deprecated gradients - keeping to avoid breaking existing code
  @Deprecated('Use solid colors instead')
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
  );

  @Deprecated('Use solid colors instead')
  static const LinearGradient auroraVibrantGradient = LinearGradient(
    colors: [primary, accentPurple],
  );

  @Deprecated('Use solid colors instead')
  static const LinearGradient glassGradient = LinearGradient(
    colors: [glassBackground, glassBackground],
  );

  @Deprecated('Use solid colors instead')
  static const LinearGradient glassBorderGradient = LinearGradient(
    colors: [glassBorder, glassBorder],
  );

  @Deprecated('Use solid colors instead')
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, surface],
  );

  @Deprecated('Use solid colors instead')
  static const LinearGradient auroraBackgroundGradient = LinearGradient(
    colors: [background, background],
  );

  static const List<Color> auroraGradientDark = [background];
  static const List<Color> auroraGradientVibrant = [primary];
  static const List<Color> gradientPrimary = [primary, primaryDark];

  @Deprecated('Use solid colors instead')
  static const RadialGradient cyanGlow = RadialGradient(
    colors: [glassCyan, Colors.transparent],
  );

  @Deprecated('Use solid colors instead')
  static const RadialGradient purpleGlow = RadialGradient(
    colors: [Color(0x1ABF5AF2), Colors.transparent],
  );
}
