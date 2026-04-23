import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart' show playlistRepositoryProvider, recentlyWatchedNotifierProvider;

/// Stream health indicator — aggregates recent buffering events into a
/// green/yellow/red signal surfaced on the mini-player.
enum StreamHealth { good, okay, poor }

/// Global player state for mini-player support
class PlayerState {
  final Channel? channel;
  final Player? player;
  final VideoController? controller;
  final bool isPlaying;
  final bool isBuffering;
  final bool isMinimized;
  final String? errorMessage;

  /// Channel most recently watched BEFORE the current one — exposed so the
  /// UI (or the `L` keyboard shortcut) can jump back with one action.
  final String? previousChannelId;

  /// Rolling-window stream health score.
  final StreamHealth health;

  const PlayerState({
    this.channel,
    this.player,
    this.controller,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isMinimized = false,
    this.errorMessage,
    this.previousChannelId,
    this.health = StreamHealth.good,
  });

  PlayerState copyWith({
    Channel? channel,
    Player? player,
    VideoController? controller,
    bool? isPlaying,
    bool? isBuffering,
    bool? isMinimized,
    String? errorMessage,
    bool clearError = false,
    String? previousChannelId,
    StreamHealth? health,
  }) {
    return PlayerState(
      channel: channel ?? this.channel,
      player: player ?? this.player,
      controller: controller ?? this.controller,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isMinimized: isMinimized ?? this.isMinimized,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      previousChannelId: previousChannelId ?? this.previousChannelId,
      health: health ?? this.health,
    );
  }

  bool get hasActivePlayer => player != null && channel != null;
}

/// Global player state notifier
class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;

  /// Subscriptions to the current player's streams. Tracked so we can cancel
  /// them before disposing the player, otherwise late events from a previous
  /// player would clobber state for a new channel.
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// MIME-type hint for the next [playChannel] call. Used by the fallback
  /// chain: if a stream fails to play as-is, we try appending .m3u8, then
  /// .mpd, and record the winning extension so future opens skip retries.
  final Map<String, String> _urlMimeCache = {};

  /// Rolling timestamps of recent buffering events; we derive [StreamHealth]
  /// from their frequency.
  final List<DateTime> _bufferingEvents = [];
  Timer? _healthTimer;

  PlayerNotifier(this._ref) : super(const PlayerState());

  /// Play a channel
  Future<void> playChannel(String channelId) async {
    // Remember the currently-playing channel so the user can jump back with
    // the last-channel toggle. We capture it BEFORE stop() clears state.
    final previousChannelId = state.channel?.id;

    // Stop existing player if any
    await stop();

    // Track as recently watched
    _ref.read(recentlyWatchedNotifierProvider.notifier).addChannel(channelId);

    // Create new player
    // Note: Buffering is handled by media_kit with platform-specific backends:
    // - Desktop (macOS/Windows/Linux): Uses mpv/libmpv
    // - Android: Uses ExoPlayer
    // - iOS: Uses AVPlayer
    final player = Player();
    final controller = VideoController(player);

    // IPTV-friendly tuning for the libmpv desktop backend. mpv options don't
    // exist on Android/iOS so we guard behind a platform check; errors from
    // setProperty are fatal on those platforms.
    _applyMpvIptvTuning(player);

    state = state.copyWith(
      player: player,
      controller: controller,
      isMinimized: false,
      clearError: true,
      previousChannelId: previousChannelId,
      health: StreamHealth.good,
    );
    _bufferingEvents.clear();
    _ensureHealthTimer();

    // Set up listeners. Track subscriptions so stop() can cancel them before
    // disposing the player; without this, late events from a prior player can
    // fire state.copyWith() on the next channel's state.
    _subscriptions.add(player.stream.playing.listen((playing) {
      if (mounted) {
        state = state.copyWith(isPlaying: playing);
      }
    }));

    _subscriptions.add(player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      state = state.copyWith(isBuffering: buffering);
      if (buffering) {
        _recordBufferingEvent();
      }
    }));

    _subscriptions.add(player.stream.error.listen((error) {
      if (!mounted || error.isEmpty) return;
      // Filter out non-fatal errors - media_kit can emit warnings/info as errors
      final lowerError = error.toLowerCase();

      if (lowerError.contains('warning') ||
          lowerError.contains('deprecated') ||
          lowerError.contains('discarding') ||
          lowerError.contains('avi:') ||
          lowerError.contains('avformat') ||
          lowerError.contains('seek failed') ||
          lowerError.contains('discarding frame') ||
          lowerError.contains('corrupted') && !lowerError.contains('file')) {
        return;
      }

      // Auto-reconnect on live-window drift (common after sleep/wake on HLS
      // streams). Instead of surfacing an error, silently reopen the stream.
      if (lowerError.contains('behind live window') ||
          lowerError.contains('live window') ||
          lowerError.contains('stream disconnected')) {
        AppLogger.info('Auto-reconnecting after live-window drift');
        _tryReconnect();
        return;
      }

      String errorMsg = error;
      if (error.contains('Unable to resolve host') || error.contains('ENETUNREACH')) {
        errorMsg = 'Network error: Unable to connect to stream server';
      } else if (error.contains('403') || error.contains('Forbidden')) {
        errorMsg = 'Access denied: Check your playlist credentials';
      } else if (error.contains('404') || error.contains('Not Found')) {
        errorMsg = 'Stream not found: Channel may be unavailable';
      } else if (error.contains('timeout') || error.contains('TIMED_OUT')) {
        errorMsg = 'Connection timeout: Stream server is not responding';
      } else if (error.contains('Invalid data') || error.contains('invalid data')) {
        errorMsg = 'Invalid stream format: Channel may be offline';
      } else if (error.contains('Connection refused') || error.contains('ECONNREFUSED')) {
        errorMsg = 'Connection refused: Stream server is unavailable';
      } else if (error.contains('SSL') || error.contains('certificate')) {
        errorMsg = 'Security error: SSL/certificate issue with stream';
      }
      state = state.copyWith(errorMessage: errorMsg);
    }));

    // Load channel
    final repository = _ref.read(playlistRepositoryProvider);
    final result = await repository.getChannel(channelId);
    if (!mounted) return;

    result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
      (channel) async {
        try {
          state = state.copyWith(channel: channel);

          final httpHeaders = <String, String>{};
          if (channel.userAgent != null) {
            httpHeaders['User-Agent'] = channel.userAgent!;
          }
          if (channel.referrer != null) {
            httpHeaders['Referer'] = channel.referrer!;
          }
          if (channel.headers != null) {
            httpHeaders.addAll(channel.headers!);
          }

          await _openWithMimeFallback(player, channel.url, httpHeaders);
        } catch (e) {
          if (mounted) {
            state = state.copyWith(errorMessage: 'Failed to start playback: ${e.toString()}');
          }
        }
      },
    );
  }

  /// Minimize player (go to PiP mode)
  void minimize() {
    if (state.hasActivePlayer) {
      state = state.copyWith(isMinimized: true);
    }
  }

  /// Expand from mini-player to full screen
  void expand() {
    if (state.hasActivePlayer) {
      state = state.copyWith(isMinimized: false);
    }
  }

  /// Toggle play/pause
  void togglePlayPause() {
    state.player?.playOrPause();
  }

  /// Stop and dispose player
  Future<void> stop() async {
    // Cancel stream listeners first so late events cannot clobber the
    // subsequent state = const PlayerState() or a new channel's state.
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    // Stop the health timer too — no point polling when there's no player.
    _healthTimer?.cancel();
    _healthTimer = null;
    _bufferingEvents.clear();
    await state.player?.dispose();
    if (mounted) {
      state = const PlayerState();
    }
  }

  /// Retry playback
  Future<void> retry() async {
    final channelId = state.channel?.id;
    if (channelId != null) {
      state = state.copyWith(clearError: true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await playChannel(channelId);
    }
  }

  /// Jump to the previously watched channel, if any. Remote-control style
  /// single-key toggle; bound to `L` in the player screen's shortcuts.
  Future<void> playPreviousChannel() async {
    final prev = state.previousChannelId;
    if (prev == null) return;
    await playChannel(prev);
  }

  /// Cap the per-URL MIME cache to avoid unbounded growth in long-lived
  /// sessions that touch thousands of distinct URLs.
  static const int _urlMimeCacheMax = 500;

  /// Try opening a URL; if it fails, retry with common extensions. Remembers
  /// the winning variant per URL so subsequent opens skip the retry.
  /// If the cached variant itself starts failing (server migration, etc.),
  /// the cache entry is dropped and the fallback chain is re-entered.
  Future<void> _openWithMimeFallback(Player player, String url, Map<String, String> headers) async {
    final cached = _urlMimeCache[url];

    final candidates = <String>[
      if (cached != null) cached,
      // Always try the raw URL and common extensions in case the cached
      // variant has gone bad.
      if (cached != url) url,
      if (!url.contains('.m3u8')) '$url.m3u8',
      if (!url.contains('.mpd')) '$url.mpd',
    ];

    Object? lastError;
    for (final candidate in candidates) {
      try {
        await player.open(Media(candidate, httpHeaders: headers.isNotEmpty ? headers : null));
        // Simple FIFO eviction when the cache is full.
        if (_urlMimeCache.length >= _urlMimeCacheMax) {
          _urlMimeCache.remove(_urlMimeCache.keys.first);
        }
        _urlMimeCache[url] = candidate;
        return;
      } catch (e) {
        lastError = e;
        AppLogger.debug('MIME fallback: $candidate failed ($e), trying next');
        // The cached variant is stale — drop it so the next call to this
        // method won't loop through the same failing entry first.
        if (candidate == cached) _urlMimeCache.remove(url);
      }
    }
    if (lastError != null) throw lastError;
  }

  /// Record a buffering event and recompute the rolling-window health score.
  /// Window is the last 60 seconds; >5 events = poor, >2 = okay, else good.
  void _recordBufferingEvent() {
    final now = DateTime.now();
    _bufferingEvents.add(now);
    final cutoff = now.subtract(const Duration(seconds: 60));
    _bufferingEvents.removeWhere((t) => t.isBefore(cutoff));
    _updateHealth();
  }

  void _updateHealth() {
    if (!mounted) return;
    final count = _bufferingEvents.length;
    final newHealth = count >= 5
        ? StreamHealth.poor
        : count >= 2
            ? StreamHealth.okay
            : StreamHealth.good;
    if (newHealth != state.health) {
      state = state.copyWith(health: newHealth);
    }
  }

  /// Re-evaluate health every 15s so the indicator decays back to green when
  /// the stream has stabilised, even if no new buffering events arrive.
  void _ensureHealthTimer() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(seconds: 60));
      _bufferingEvents.removeWhere((t) => t.isBefore(cutoff));
      _updateHealth();
    });
  }

  /// Silent reconnect: re-open the current channel's URL without tearing the
  /// player down. Used when the stream drifts past its live window or the
  /// server briefly drops the connection.
  Future<void> _tryReconnect() async {
    final channel = state.channel;
    final player = state.player;
    if (channel == null || player == null) return;

    final httpHeaders = <String, String>{};
    if (channel.userAgent != null) httpHeaders['User-Agent'] = channel.userAgent!;
    if (channel.referrer != null) httpHeaders['Referer'] = channel.referrer!;
    if (channel.headers != null) httpHeaders.addAll(channel.headers!);
    try {
      await player.open(Media(channel.url, httpHeaders: httpHeaders.isNotEmpty ? httpHeaders : null));
    } catch (e) {
      AppLogger.warning('Silent reconnect failed: $e');
    }
  }

  /// Apply IPTV-friendly mpv options. mpv-only; silently skipped on
  /// Android/iOS/web. These settings cut buffering stalls and let FFmpeg
  /// automatically reconnect if the server drops the connection.
  void _applyMpvIptvTuning(Player player) {
    if (kIsWeb) return;
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    void setProp(String name, String value) {
      platform.setProperty(name, value).catchError((Object e) {
        AppLogger.warning('mpv setProperty $name=$value failed: $e');
      });
    }
    setProp('cache', 'yes');
    setProp('cache-secs', '30');
    setProp('demuxer-max-bytes', '67108864'); // 64 MiB forward buffer
    setProp('demuxer-readahead-secs', '20');
    setProp('network-timeout', '10');
    // FFmpeg HTTP reconnect on dropout — critical for IPTV.
    setProp('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    state.player?.dispose();
    super.dispose();
  }
}

/// Global player provider
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});

/// Convenience provider to check if mini-player should show
final showMiniPlayerProvider = Provider<bool>((ref) {
  final playerState = ref.watch(playerProvider);
  return playerState.hasActivePlayer && playerState.isMinimized;
});
