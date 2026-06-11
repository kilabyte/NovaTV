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
      AppLogger.info('Refreshing EPG for playlist: ${p.name}');
      // refreshEpg never throws; failures come back as false (and land in
      // the EPG notifier's error state).
      final ok = await ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(p.id, p.epgUrl!);
      if (!ok) AppLogger.warning('Failed to refresh EPG for ${p.name}');
      return ok;
    }

    // Chain each playlist's EPG refresh directly onto that playlist's own
    // refresh rather than running a separate pass after ALL playlists finish.
    // refreshPlaylist already fires a background EPG refresh on success, so
    // calling refreshEpg immediately afterwards dedupes onto that in-flight
    // download (the notifier's _inFlight map) instead of fetching the feed a
    // second time; the old two-phase structure left a window where a small
    // EPG could complete before the second pass started and be re-downloaded.
    final epgFutures = <Future<bool>>[];
    final playlistFutures = stalePlaylists.map((p) {
      final playlistFuture = refreshOne(p);
      if (staleEpgs.contains(p)) {
        epgFutures.add(playlistFuture.then((_) => refreshEpg(p)));
      }
      return playlistFuture;
    }).toList();

    if (playlistFutures.isNotEmpty) {
      final results = await Future.wait(playlistFutures, eagerError: false);
      refreshNotifier.completePlaylistRefresh(success: results.every((ok) => ok));
      ref.read(goToNowTriggerProvider.notifier).state++;
    }

    if (epgFutures.isNotEmpty) {
      final results = await Future.wait(epgFutures, eagerError: false);
      refreshNotifier.completeEpgRefresh(success: results.every((ok) => ok));
      ref.read(goToNowTriggerProvider.notifier).state++;
    }

    AppLogger.info('Auto-refresh completed');
  } catch (e, st) {
    AppLogger.error('Error during auto-refresh: $e', e, st);
    ref.read(refreshStateProvider.notifier).showMessage('Refresh failed', isError: true);
  }
}
