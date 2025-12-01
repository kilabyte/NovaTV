/// Storage keys for Hive boxes and preferences
class StorageKeys {
  StorageKeys._();

  // Hive box names
  static const String playlistsBox = 'playlists_box';
  static const String channelsBox = 'channels_box';
  static const String epgBox = 'epg_box';
  static const String favoritesBox = 'favorites_box';
  static const String settingsBox = 'settings_box';
  static const String historyBox = 'history_box';

  // Settings keys
  static const String themeMode = 'theme_mode';
  static const String epgTimezoneOffset = 'epg_timezone_offset';
  static const String playerHardwareAcceleration = 'player_hardware_acceleration';
  static const String playerDefaultAspectRatio = 'player_default_aspect_ratio';
  static const String autoRefreshPlaylists = 'auto_refresh_playlists';
  static const String playlistRefreshInterval = 'playlist_refresh_interval';
  static const String epgRefreshInterval = 'epg_refresh_interval';
  static const String lastPlayedChannel = 'last_played_channel';
  static const String autoPlayLastChannel = 'auto_play_last_channel';

  // Cache keys
  static const String lastEpgUpdate = 'last_epg_update';
  static const String lastPlaylistUpdate = 'last_playlist_update';

  // Window settings keys
  static const String windowWidth = 'window_width';
  static const String windowHeight = 'window_height';
  static const String windowX = 'window_x';
  static const String windowY = 'window_y';
  static const String windowMaximized = 'window_maximized';
}

/// Hive type IDs for registered adapters
class HiveTypeIds {
  HiveTypeIds._();

  static const int playlist = 0;
  static const int channel = 1;
  static const int program = 2;
  static const int epgChannel = 3;
  static const int appSettings = 4;
  static const int playbackHistory = 5;
}
