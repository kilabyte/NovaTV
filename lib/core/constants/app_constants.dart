/// Application-wide constants
class AppConstants {
  AppConstants._();

  /// App name
  static const String appName = 'NovaTV';

  /// App version
  static const String appVersion = '1.0.0';

  /// Default HTTP timeout in seconds
  static const int httpTimeout = 30;

  /// Default cache duration in hours
  static const int defaultCacheDuration = 24;

  /// Default playlist refresh interval in hours
  static const int defaultPlaylistRefreshInterval = 12;

  /// Default EPG refresh interval in hours
  static const int defaultEpgRefreshInterval = 24;

  /// Minimum search query length
  static const int minSearchLength = 2;

  /// Maximum recent items to store
  static const int maxRecentItems = 50;

  /// Maximum favorites to display on home
  static const int maxHomeFavorites = 10;

  /// EPG grid pixels per minute
  static const double epgPixelsPerMinute = 4.0;

  /// EPG default visible hours
  static const int epgDefaultVisibleHours = 6;

  /// Player controls auto-hide delay in seconds
  static const int playerControlsHideDelay = 5;

  /// Channel logo placeholder
  static const String channelLogoPlaceholder = 'assets/images/channel_placeholder.png';
}

/// Responsive breakpoints
class Breakpoints {
  Breakpoints._();

  /// Mobile breakpoint
  static const double mobile = 600;

  /// Tablet breakpoint
  static const double tablet = 1200;

  /// Grid columns for mobile
  static const int mobileColumns = 2;

  /// Grid columns for tablet
  static const int tabletColumns = 4;

  /// Grid columns for desktop
  static const int desktopColumns = 6;
}
