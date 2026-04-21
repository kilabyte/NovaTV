import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart' show playlistRepositoryProvider, recentlyWatchedNotifierProvider;

/// Global player state for mini-player support
class PlayerState {
  final Channel? channel;
  final Player? player;
  final VideoController? controller;
  final bool isPlaying;
  final bool isBuffering;
  final bool isMinimized;
  final String? errorMessage;

  const PlayerState({this.channel, this.player, this.controller, this.isPlaying = false, this.isBuffering = false, this.isMinimized = false, this.errorMessage});

  PlayerState copyWith({Channel? channel, Player? player, VideoController? controller, bool? isPlaying, bool? isBuffering, bool? isMinimized, String? errorMessage, bool clearError = false}) {
    return PlayerState(channel: channel ?? this.channel, player: player ?? this.player, controller: controller ?? this.controller, isPlaying: isPlaying ?? this.isPlaying, isBuffering: isBuffering ?? this.isBuffering, isMinimized: isMinimized ?? this.isMinimized, errorMessage: clearError ? null : (errorMessage ?? this.errorMessage));
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

  PlayerNotifier(this._ref) : super(const PlayerState());

  /// Play a channel
  Future<void> playChannel(String channelId) async {
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

    state = state.copyWith(player: player, controller: controller, isMinimized: false, clearError: true);

    // Set up listeners. Track subscriptions so stop() can cancel them before
    // disposing the player; without this, late events from a prior player can
    // fire state.copyWith() on the next channel's state.
    _subscriptions.add(player.stream.playing.listen((playing) {
      if (mounted) {
        state = state.copyWith(isPlaying: playing);
      }
    }));

    _subscriptions.add(player.stream.buffering.listen((buffering) {
      if (mounted) {
        state = state.copyWith(isBuffering: buffering);
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

          await player.open(Media(channel.url, httpHeaders: httpHeaders.isNotEmpty ? httpHeaders : null));
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

  @override
  void dispose() {
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
