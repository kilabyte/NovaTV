import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/channels/presentation/screens/channel_list_screen.dart';
import '../../features/epg/presentation/screens/tv_guide_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/player/presentation/screens/player_screen.dart';
import '../../features/playlist/presentation/screens/add_playlist_screen.dart';
import '../../features/playlist/presentation/screens/playlist_manager_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/animations/page_transitions.dart';
import '../../shared/widgets/app_shell.dart';
import 'routes.dart';

/// Application router configuration using go_router
/// Features premium page transitions for a cinematic experience
final GoRouter appRouter = GoRouter(
  initialLocation: Routes.channels, // Start directly at channels
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
