/// Route path constants
class Routes {
  Routes._();

  // Main routes
  static const String home = '/';
  static const String channels = '/channels';
  static const String tvGuide = '/guide';
  static const String favorites = '/favorites';
  static const String playlists = '/playlists';
  static const String settings = '/settings';
  static const String search = '/search';

  // Nested routes
  static const String addPlaylist = '/playlists/add';
  static const String editPlaylist = '/playlists/edit/:id';

  // Player route (outside shell)
  static const String player = '/player/:channelId';

  // Helper methods to generate paths with parameters
  static String playerPath(String channelId) => '/player/$channelId';
  static String editPlaylistPath(String id) => '/playlists/edit/$id';
}
