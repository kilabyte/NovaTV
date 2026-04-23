import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_logger.dart';
import '../../features/epg/presentation/providers/epg_providers.dart';
import '../../features/playlist/domain/entities/playlist.dart';
import '../../features/playlist/presentation/providers/playlist_providers.dart';
import 'refresh_toast.dart';

/// Process-wide flag so we perform the startup auto-refresh at most once per
/// launch, regardless of which widget first kicks it off.
bool _startupRefreshRan = false;

/// Refresh stale playlists and their EPG on app launch. Safe to call from
/// multiple places (NovaApp initState + AppShell) — later calls no-op.
///
/// Lives outside AppShell so deep-link launches that skip the shell (e.g.
/// `/player/:id`) still get a refresh.
Future<void> performStartupRefresh(WidgetRef ref) async {
  if (_startupRefreshRan) return;
  _startupRefreshRan = true;

  AppLogger.info('Starting auto-refresh on startup (background thread)...');

  try {
    final playlists = await ref.read(playlistsProvider.future);
    if (playlists.isEmpty) {
      AppLogger.info('No playlists to refresh');
      return;
    }

    final stalePlaylists = playlists.where((p) => p.needsRefresh).toList();
    final staleEpgs = playlists
        .where((p) => p.hasEpg && p.epgUrl != null && p.epgUrl!.isNotEmpty && p.needsRefresh)
        .toList();

    if (stalePlaylists.isEmpty && staleEpgs.isEmpty) {
      AppLogger.info('Auto-refresh: nothing stale, skipping');
      return;
    }

    final refreshNotifier = ref.read(refreshStateProvider.notifier);
    if (stalePlaylists.isNotEmpty) refreshNotifier.startPlaylistRefresh();
    if (staleEpgs.isNotEmpty) refreshNotifier.startEpgRefresh();

    Future<bool> refreshOne(Playlist p) async {
      try {
        AppLogger.info('Refreshing playlist: ${p.name}');
        await ref.read(playlistNotifierProvider.notifier).refreshPlaylist(p.id);
        return true;
      } catch (e) {
        AppLogger.warning('Failed to refresh playlist ${p.name}: $e');
        return false;
      }
    }

    Future<bool> refreshEpg(Playlist p) async {
      try {
        AppLogger.info('Refreshing EPG for playlist: ${p.name}');
        await ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(p.id, p.epgUrl!);
        return true;
      } catch (e) {
        AppLogger.warning('Failed to refresh EPG for ${p.name}: $e');
        return false;
      }
    }

    if (stalePlaylists.isNotEmpty) {
      final results = await Future.wait(stalePlaylists.map(refreshOne), eagerError: false);
      refreshNotifier.completePlaylistRefresh(success: results.every((ok) => ok));
      ref.read(goToNowTriggerProvider.notifier).state++;
    }

    if (staleEpgs.isNotEmpty) {
      final results = await Future.wait(staleEpgs.map(refreshEpg), eagerError: false);
      refreshNotifier.completeEpgRefresh(success: results.every((ok) => ok));
      ref.read(goToNowTriggerProvider.notifier).state++;
    }

    AppLogger.info('Auto-refresh completed');
  } catch (e, st) {
    AppLogger.error('Error during auto-refresh: $e', e, st);
    ref.read(refreshStateProvider.notifier).showMessage('Refresh failed', isError: true);
  }
}
