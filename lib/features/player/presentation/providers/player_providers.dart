import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart' show playlistRepositoryProvider, recentlyWatchedNotifierProvider;
import '../../../settings/presentation/providers/settings_providers.dart';

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

  /// User-set playback volume in the 0.0-1.0 range. media_kit's native scale
  /// is 0-100; we scale at the call site so the rest of the app stays in
  /// logical units.
  final double volume;

  /// Whether playback is muted. Kept separate from [volume] so unmute can
  /// restore the previous level.
  final bool isMuted;

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
    this.volume = 1.0,
    this.isMuted = false,
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
    double? volume,
    bool? isMuted,
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
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  /// Effective volume sent to the player: 0 when muted, otherwise the user
  /// setting.
  double get effectiveVolume => isMuted ? 0.0 : volume;

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

  /// Generation counter guarding [playChannel] against supersession. Each
  /// playChannel (and external stop) bumps it; stale continuations compare
  /// their captured value after every await and bail out, so rapid zapping
  /// can't write channel A's state over channel B's player or open() a
  /// disposed Player.
  int _playGeneration = 0;

  /// Channel id of the most recent [playChannel] request. Unlike
  /// state.channel (only set after the repository lookup succeeds), this is
  /// recorded up front so [retry] still works when the lookup itself failed.
  String? _lastRequestedChannelId;

  /// Auto-reconnect bookkeeping. [_reconnectPlayer] is the player instance
  /// the retry loop currently owns: it makes the loop single-instance per
  /// player (drop-class errors can arrive faster than open() completes) and
  /// scopes error-panel suppression to that player, so zapping to a new
  /// channel mid-loop neither swallows the new channel's errors nor blocks
  /// its own reconnect loop from starting.
  /// [_reconnectSawError] is set by the error listener during a cycle so the
  /// loop knows a reopen attempt failed without relying on state writes.
  /// [_lastDropErrorAt] timestamps the most recent drop-class error so the
  /// passive phase can tell a healed connection from one still erroring.
  Player? _reconnectPlayer;
  bool _reconnectSawError = false;
  DateTime? _lastDropErrorAt;

  /// True only when the user deliberately paused via [togglePlayPause].
  /// mpv pauses by itself while refilling an empty cache (paused-for-cache),
  /// and the reconnect loop must keep recovering through those, so player
  /// state alone cannot distinguish the two.
  bool _userPaused = false;
  static const int _maxReconnectAttempts = 5;

  PlayerNotifier(this._ref) : super(const PlayerState()) {
    // Seed volume/mute from persisted settings so the first play respects
    // what the user had before.
    final s = _ref.read(appSettingsProvider);
    state = state.copyWith(volume: s.playerVolume, isMuted: s.playerMuted);
  }

  /// Play a channel
  Future<void> playChannel(String channelId) async {
    // Claim a new generation; any in-flight playChannel becomes stale.
    final generation = ++_playGeneration;
    _lastRequestedChannelId = channelId;
    _userPaused = false;

    // Remember the currently-playing channel so the user can jump back with
    // the last-channel toggle. We capture it BEFORE stop() clears state.
    final previousChannelId = state.channel?.id;

    // Stop existing player if any (teardown only; public stop() would bump
    // the generation and invalidate this very call).
    await _teardownPlayer();
    if (!mounted || generation != _playGeneration) return;

    // Track as recently watched
    _ref.read(recentlyWatchedNotifierProvider.notifier).addChannel(channelId);

    // Create new player. media_kit drives libmpv on all native platforms
    // (desktop, Android, and iOS alike).
    final player = Player();
    final controller = VideoController(player);

    // IPTV-friendly tuning: FFmpeg reconnect-on-dropout, demuxer cache, and
    // auto-rebuffer. Applies to every libmpv-backed platform.
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

    // Apply persisted volume immediately. media_kit takes 0-100.
    player.setVolume(state.effectiveVolume * 100).catchError((Object e) {
      AppLogger.warning('Initial setVolume failed: $e');
    });

    // Set up listeners. Track subscriptions so stop() can cancel them before
    // disposing the player; without this, late events from a prior player can
    // fire state.copyWith() on the next channel's state.
    _subscriptions.add(player.stream.playing.listen((playing) {
      if (mounted) {
        // Clear any stale error once playback is confirmed running again:
        // FFmpeg auto-reconnect (see _applyMpvIptvTuning) can recover from
        // transient errors by itself, and the error panel would otherwise
        // hide live video forever.
        state = state.copyWith(isPlaying: playing, clearError: playing);
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
          // Live TS streams often refuse seeks ("...force it with
          // --force-seekable=yes") while playback continues fine behind the
          // panel, so seekability complaints are never treated as fatal.
          lowerError.contains('seekable') ||
          lowerError.contains('cannot seek') ||
          lowerError.contains('discarding frame') ||
          lowerError.contains('corrupted') && !lowerError.contains('file')) {
        return;
      }

      // Auto-reconnect on live-window drift (common after sleep/wake on HLS
      // streams) and on connection-level read failures ("tcp: ffurl_read
      // returned 0xffffff92" timeouts, resets): IPTV servers drop long-lived
      // connections routinely and a reopen almost always succeeds, so try
      // that before surfacing an error panel.
      if (lowerError.contains('behind live window') ||
          lowerError.contains('live window') ||
          lowerError.contains('stream disconnected') ||
          lowerError.contains('ffurl_read') ||
          lowerError.contains('connection reset')) {
        AppLogger.info('Stream drop detected, monitoring for recovery: $error');
        _reconnectSawError = true;
        _lastDropErrorAt = DateTime.now();
        _tryReconnect();
        return;
      }

      // While the reconnect loop is active for THIS player, every other error
      // (typically the "failed to open" from a reopen attempted while the
      // network is still down) is feedback for the loop, not something to
      // panel the user with. The loop surfaces a single readable message if
      // it gives up. Errors from a different player (after a zap) are not
      // suppressed.
      if (identical(_reconnectPlayer, player)) {
        _reconnectSawError = true;
        _lastDropErrorAt = DateTime.now();
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
      } else if (lowerError.contains('failed to open')) {
        // mpv's generic open failure hides the HTTP status. Show a readable
        // message now and probe the URL in the background to find out WHY
        // (403 connection-limit/IP block vs 404 vs unreachable), then update
        // the panel with the real cause.
        errorMsg = 'Could not connect to the stream server';
        _diagnoseStreamFailure(player);
      }
      state = state.copyWith(errorMessage: errorMsg);
    }));

    // Load channel
    final repository = _ref.read(playlistRepositoryProvider);
    final result = await repository.getChannel(channelId);
    if (!mounted || generation != _playGeneration) return;

    result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
      (channel) async {
        try {
          if (generation != _playGeneration) return;
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
          // A superseded call's open() failing on its disposed player must
          // not write a bogus error onto the new channel's state.
          if (mounted && generation == _playGeneration) {
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
    final player = state.player;
    if (player == null) return;
    // Record the user's intent BEFORE toggling: the reconnect loop must not
    // confuse a deliberate pause with mpv's own paused-for-cache state.
    // Toggling while playing means the user is pausing.
    _userPaused = player.state.playing;
    player.playOrPause();
  }

  /// Stop and dispose player
  Future<void> stop() async {
    // Invalidate any in-flight playChannel so its continuation cannot
    // resurrect state after we reset it.
    _playGeneration++;
    await _teardownPlayer();
  }

  /// In-flight teardown, if any. Rapid zapping (playChannel + playChannel or
  /// playChannel + stop) enters teardown concurrently; without coalescing the
  /// second caller would iterate _subscriptions while the first clear()s it
  /// (ConcurrentModificationError) and double-dispose the same Player, which
  /// media_kit rejects with an AssertionError.
  Future<void>? _teardownFuture;

  /// Shared teardown used by stop() and playChannel(). Does NOT bump the
  /// generation counter: playChannel calls this for its own old player and
  /// must stay the current generation. Concurrent callers await the same
  /// in-flight teardown.
  Future<void> _teardownPlayer() {
    return _teardownFuture ??= _doTeardown().whenComplete(() => _teardownFuture = null);
  }

  Future<void> _doTeardown() async {
    // Cancel stream listeners first so late events cannot clobber the
    // subsequent state = const PlayerState() or a new channel's state.
    // Snapshot-and-clear so a reentrant register cannot race the iteration.
    final subs = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    for (final sub in subs) {
      await sub.cancel();
    }
    // Stop the health timer too — no point polling when there's no player.
    _healthTimer?.cancel();
    _healthTimer = null;
    _bufferingEvents.clear();
    await state.player?.dispose();
    if (mounted) {
      state = const PlayerState();
    }
  }

  /// Retry playback. Falls back to the last requested channel id so the
  /// button still works when the initial channel lookup failed (state.channel
  /// was never set in that case).
  Future<void> retry() async {
    final channelId = state.channel?.id ?? _lastRequestedChannelId;
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

  /// Set the logical volume in the 0.0-1.0 range and persist it. Unmutes if
  /// the user is adjusting the slider while muted (the expected behaviour on
  /// every major media player).
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    final shouldUnmute = state.isMuted && clamped > 0;
    state = state.copyWith(
      volume: clamped,
      isMuted: shouldUnmute ? false : state.isMuted,
    );
    _ref.read(appSettingsProvider.notifier).setPlayerVolume(clamped);
    if (shouldUnmute) {
      _ref.read(appSettingsProvider.notifier).setPlayerMuted(false);
    }
    try {
      await state.player?.setVolume(state.effectiveVolume * 100);
    } catch (e) {
      AppLogger.warning('setVolume failed: $e');
    }
  }

  /// Toggle mute. Preserves the pre-mute volume so unmute restores it.
  Future<void> toggleMute() async {
    final newMuted = !state.isMuted;
    state = state.copyWith(isMuted: newMuted);
    _ref.read(appSettingsProvider.notifier).setPlayerMuted(newMuted);
    try {
      await state.player?.setVolume(state.effectiveVolume * 100);
    } catch (e) {
      AppLogger.warning('toggleMute setVolume failed: $e');
    }
  }

  /// Nudge the volume up or down by [delta] (in the 0.0-1.0 scale). Used by
  /// the arrow-key shortcuts on the player.
  Future<void> adjustVolume(double delta) async {
    await setVolume(state.volume + delta);
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

    // Append fallback extensions to the URL *path*, not the raw string:
    // naive '$url.m3u8' on a tokenized URL (...?token=abc) would corrupt the
    // query value. Same reason the extension check inspects the path only.
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;

    final candidates = <String>[
      if (cached != null) cached,
      // Always try the raw URL and common extensions in case the cached
      // variant has gone bad.
      if (cached != url) url,
      if (uri != null && !path.endsWith('.m3u8')) uri.replace(path: '$path.m3u8').toString(),
      if (uri != null && !path.endsWith('.mpd')) uri.replace(path: '$path.mpd').toString(),
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

  /// Probe the current channel's URL after mpv reports a generic open
  /// failure, and replace the vague error with the actual cause. IPTV
  /// providers commonly return 403 when the account's connection limit is
  /// already in use by another device or the IP is blocked - without this the
  /// user just sees "failed to open" for a perfectly valid playlist.
  Future<void> _diagnoseStreamFailure(Player player) async {
    final channel = state.channel;
    if (channel == null) return;

    final headers = <String, dynamic>{'Range': 'bytes=0-0'};
    if (channel.userAgent != null) headers['User-Agent'] = channel.userAgent!;
    if (channel.referrer != null) headers['Referer'] = channel.referrer!;
    if (channel.headers != null) headers.addAll(channel.headers!);

    String? diagnosis;
    try {
      final response = await Dio().get<void>(
        channel.url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
          followRedirects: true,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      diagnosis = switch (response.statusCode ?? 0) {
        401 || 403 =>
          'Stream server refused the connection (HTTP ${response.statusCode}). '
          'Your provider may have reached its connection limit (is another '
          'device or app streaming?) or blocked this IP address.',
        404 => 'Stream not found (HTTP 404): channel may be offline',
        >= 500 => 'Stream server error (HTTP ${response.statusCode}): the provider is having issues',
        _ => null, // Reachable: keep the generic message, the failure is format-level.
      };
    } on DioException catch (e) {
      diagnosis = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Stream server is not responding (connection timed out)',
        DioExceptionType.connectionError => 'Cannot reach the stream server: check your network',
        _ => null,
      };
    } catch (_) {
      return;
    }

    // Only annotate if this failure is still the one on screen.
    if (diagnosis != null && mounted && identical(state.player, player) && state.errorMessage != null) {
      state = state.copyWith(errorMessage: diagnosis);
    }
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

  /// Stream-drop recovery in two phases, both careful never to hold two
  /// provider connections at once (IPTV plans count concurrent streams, and
  /// a reopen racing the old session trips the max-connections limit).
  ///
  /// Phase 1 is passive: FFmpeg's own reconnect plus the large demuxer cache
  /// recover most drops on the existing connection while the user keeps
  /// watching buffered content, so nothing is reopened until playback has
  /// genuinely stalled for several consecutive seconds.
  ///
  /// Phase 2 actively reopens, but stops the current stream FIRST so the
  /// provider releases its slot before the replacement connection opens.
  /// It runs as a self-driving retry loop because a reopen attempted while
  /// the network is still down fails into mpv's idle state, which emits no
  /// further error events to re-trigger us. Exponential backoff, single
  /// instance per player, and bails the moment the user zaps away.
  Future<void> _tryReconnect() async {
    final channel = state.channel;
    final player = state.player;
    if (channel == null || player == null) return;
    // Single-instance per player. A loop still draining for a PREVIOUS
    // player (it exits at its next identity check) must not block the
    // current player's reconnect, so only bail when the running loop
    // already owns this player.
    if (identical(_reconnectPlayer, player)) return;

    _reconnectPlayer = player;
    try {
      // Phase 1: watch the existing connection. Exit early if the stream
      // heals itself (no drop errors for a while and playback running);
      // escalate to a reopen only after a sustained stall, i.e. the cache
      // ran dry and is not refilling.
      // The stall threshold must exceed cache-pause-wait (10s in
      // _applyMpvIptvTuning) or a healthy rebuffer pause would alias into
      // an unnecessary reopen.
      var stalledSeconds = 0;
      for (var i = 0; i < 150 && stalledSeconds < 14; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted || !identical(state.player, player)) return;
        if (_userPaused) {
          // A deliberate pause; leave the stream alone.
          AppLogger.info('Reconnect: user paused, leaving stream as is');
          return;
        }
        if (state.isPlaying && !state.isBuffering) {
          stalledSeconds = 0;
          final lastError = _lastDropErrorAt;
          if (lastError != null &&
              DateTime.now().difference(lastError) > const Duration(seconds: 10)) {
            AppLogger.info('Stream recovered on the existing connection, no reopen needed');
            return;
          }
        } else {
          // Not playing cleanly: either buffering or mpv's paused-for-cache
          // stall on a dead connection. Both count toward escalation.
          stalledSeconds++;
        }
      }
      if (!mounted || !identical(state.player, player)) return;
      AppLogger.info('Stream stalled after drop, reopening connection');

      for (var attempt = 1; attempt <= _maxReconnectAttempts; attempt++) {
        // Release the provider's connection slot BEFORE the backoff wait,
        // so the pause doubles as the server-side grace period and the new
        // connection never overlaps the old one.
        try {
          await player.stop();
        } catch (e) {
          AppLogger.warning('Reconnect stop() failed: $e');
        }
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
        // The user may have zapped or stopped during the backoff.
        if (!mounted || !identical(state.player, player)) return;

        _reconnectSawError = false;
        try {
          final httpHeaders = <String, String>{};
          if (channel.userAgent != null) httpHeaders['User-Agent'] = channel.userAgent!;
          if (channel.referrer != null) httpHeaders['Referer'] = channel.referrer!;
          if (channel.headers != null) httpHeaders.addAll(channel.headers!);
          // Go through the MIME fallback chain so channels that only play via
          // the cached .m3u8/.mpd variant reconnect with the right URL.
          await _openWithMimeFallback(player, channel.url, httpHeaders);
        } catch (e) {
          AppLogger.warning('Reconnect open() failed (attempt $attempt/$_maxReconnectAttempts): $e');
          continue;
        }

        // open() completing only means the command was accepted; failure
        // arrives as an async error event (recorded in _reconnectSawError by
        // the listener). Watch for a few seconds to see which way it went.
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          if (!mounted || !identical(state.player, player)) return;
          if (_reconnectSawError) break;
          if (i >= 2 && state.isPlaying && !state.isBuffering) {
            AppLogger.info('Reconnect succeeded (attempt $attempt/$_maxReconnectAttempts)');
            return;
          }
        }
        // A deliberate pause during recovery: leave the stream alone rather
        // than force another reopen that would yank it back into playback.
        if (_userPaused) {
          AppLogger.info('Reconnect: user paused during recovery, leaving stream as is');
          return;
        }
        AppLogger.warning('Reconnect attempt $attempt/$_maxReconnectAttempts did not recover');
      }

      // Out of attempts: surface the failure so the UI offers Retry instead
      // of leaving a silently frozen stream.
      if (mounted && identical(state.player, player)) {
        state = state.copyWith(errorMessage: 'Stream disconnected: automatic reconnect failed');
      }
    } finally {
      // Only release ownership if a newer loop has not claimed it; a loop
      // exiting late for a replaced player must not stomp the active one.
      if (identical(_reconnectPlayer, player)) {
        _reconnectPlayer = null;
      }
    }
  }

  /// Apply IPTV-friendly mpv options. media_kit's NativePlayer is libmpv on
  /// every native platform, Android and iOS included, so this runs everywhere
  /// except web. Without it a silent connection drop stalls playback forever
  /// (frozen frame, no error event); these settings cut buffering stalls and
  /// let FFmpeg automatically reconnect when the server drops the connection.
  void _applyMpvIptvTuning(Player player) {
    if (kIsWeb) return;
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    void setProp(String name, String value) {
      platform.setProperty(name, value).catchError((Object e) {
        AppLogger.warning('mpv setProperty $name=$value failed: $e');
      });
    }
    // Large buffer: keep up to 2 minutes / 256 MiB of stream ahead of the
    // playhead so throughput dips and server hiccups drain the cushion
    // instead of skipping. Live streams can only buffer as fast as they
    // arrive, but the headroom means every byte the server sends early is
    // kept. These are caps, not upfront allocations, so memory only grows
    // with what is actually buffered.
    setProp('cache', 'yes');
    setProp('cache-secs', '120');
    setProp('demuxer-max-bytes', '268435456'); // 256 MiB forward buffer
    setProp('demuxer-max-back-bytes', '67108864'); // 64 MiB behind playhead
    setProp('demuxer-readahead-secs', '120');
    setProp('network-timeout', '10');
    // Join HLS live streams a few segments behind the live edge: each
    // segment is typically 4-10s, so starting six back banks a 20-60s
    // cushion immediately instead of playing at the bleeding edge where
    // any throughput dip is an instant rebuffer. ffmpeg clamps this to the
    // playlist's oldest segment, so short playlists just start earliest.
    setProp('demuxer-lavf-o', 'live_start_index=-6');
    // FFmpeg HTTP reconnect on dropout — critical for IPTV. reconnect=1
    // covers read errors/premature EOF only; reconnect_on_network_error
    // adds TCP/TLS connect failures. HTTP 4xx/5xx stay fatal on purpose:
    // provider connection-limit responses must fall through to the app's
    // reconnect loop, which releases the slot before opening a new one.
    setProp('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=5');
    // Many live TS streams report themselves as unseekable; mpv then errors
    // ("you can force it with --force-seekable=yes") instead of playing.
    // Seeks resolve within the demuxer cache configured above.
    setProp('force-seekable', 'yes');
    // Auto-rebuffer to keep the stream alive: on cache underrun, pause
    // until a 10 second cushion is banked instead of resuming the moment a
    // frame is available and stuttering again seconds later. IPTV servers
    // usually burst faster than realtime when a client is behind, so the
    // pause is shorter than 10s of wall time and playback continues from
    // the cushion ("buffers in the background") afterwards. Applies to the
    // initial join too, trading a slightly slower channel start for stable
    // playback from the first second.
    setProp('cache-pause', 'yes');
    setProp('cache-pause-initial', 'yes');
    setProp('cache-pause-wait', '10');
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
