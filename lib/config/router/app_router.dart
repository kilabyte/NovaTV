import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';

import '../../features/channels/presentation/screens/channel_list_screen.dart';
import '../../features/epg/presentation/screens/tv_guide_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/player/presentation/screens/player_screen.dart';
import '../../features/playlist/presentation/screens/add_playlist_screen.dart';
import '../../features/playlist/presentation/screens/playlist_manager_screen.dart';
import '../../features/playlist/data/models/playlist_model.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';
import '../../shared/animations/page_transitions.dart';
import '../../shared/widgets/app_shell.dart';
import 'routes.dart';

/// Valid sidebar routes that can be restored on app startup
const _validSidebarRoutes = {
  Routes.channels,
  Routes.tvGuide,
  Routes.favorites,
  Routes.playlists,
  Routes.settings,
};

/// Check if user has any playlists (reads directly from Hive)
bool _hasPlaylists() {
  try {
    if (Hive.isBoxOpen('playlists')) {
      final box = Hive.box<PlaylistModel>('playlists');
      return box.isNotEmpty;
    }
  } catch (_) {
    // Box not open or error - assume no playlists
  }
  return false;
}

/// Provider for the application router
/// Reads the last selected sidebar route from settings to restore state
final appRouterProvider = Provider<GoRouter>((ref) {
  final settings = ref.read(appSettingsProvider);
  final savedRoute = settings.lastSelectedSidebarRoute;

  String initialRoute;

  if (savedRoute != null && _validSidebarRoutes.contains(savedRoute)) {
    // Use saved route if valid
    initialRoute = savedRoute;
  } else if (_hasPlaylists()) {
    // No saved route but has playlists - default to TV Guide
    initialRoute = Routes.tvGuide;
  } else {
    // No saved route and no playlists - show add playlist screen
    initialRoute = Routes.addPlaylist;
  }

  return _createRouter(initialRoute);
});

/// Creates the router with the specified initial location
GoRouter _createRouter(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  debugLogDiagnostics: true,
  routes: [
    // Main shell route with sidebar navigation
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        // Redirect home to channels
        GoRoute(
          path: Routes.home,
          name: 'home',
          redirect: (context, state) => Routes.channels,
        ),
        GoRoute(
          path: Routes.channels,
          name: 'channels',
          pageBuilder: (context, state) => FadeThroughTransition(
            key: state.pageKey,
            child: const ChannelListScreen(),
          ),
        ),
        GoRoute(
          path: Routes.tvGuide,
          name: 'tvGuide',
          pageBuilder: (context, state) => FadeThroughTransition(
            key: state.pageKey,
            child: const TvGuideScreen(),
          ),
        ),
        GoRoute(
          path: Routes.favorites,
          name: 'favorites',
          pageBuilder: (context, state) => FadeThroughTransition(
            key: state.pageKey,
            child: const FavoritesScreen(),
          ),
        ),
        GoRoute(
          path: Routes.playlists,
          name: 'playlists',
          pageBuilder: (context, state) => FadeThroughTransition(
            key: state.pageKey,
            child: const PlaylistManagerScreen(),
          ),
          routes: [
            GoRoute(
              path: 'add',
              name: 'addPlaylist',
              pageBuilder: (context, state) => ZoomFadeTransition(
                key: state.pageKey,
                child: const AddPlaylistScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: Routes.settings,
          name: 'settings',
          pageBuilder: (context, state) => FadeThroughTransition(
            key: state.pageKey,
            child: const SettingsScreen(),
          ),
        ),
        GoRoute(
          path: Routes.search,
          name: 'search',
          pageBuilder: (context, state) => FadeScaleTransition(
            key: state.pageKey,
            child: const SearchScreen(),
          ),
        ),
      ],
    ),
    // Player route (outside shell for fullscreen) - cinematic transition
    GoRoute(
      path: Routes.player,
      name: 'player',
      pageBuilder: (context, state) {
        final channelId = state.pathParameters['channelId']!;
        return CinematicSlideUpTransition(
          key: state.pageKey,
          child: PlayerScreen(channelId: channelId),
        );
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Color(0xFFFF3B5C),
          ),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            state.uri.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go(Routes.home),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Go Home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
