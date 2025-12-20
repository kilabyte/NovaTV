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

  PlayerNotifier(this._ref) : super(const PlayerState());

  /// Play a channel
  Future<void> playChannel(String channelId) async {
    // Stop existing player if any
    await stop();

    // Track as recently watched
    _ref.read(recentlyWatchedNotifierProvider.notifier).addChannel(channelId);

    // Create new player
    // Note: Buffering is handled by media_kit with platform-specific backends:
    // - Desktop (macOS/Windows/Linux): Uses mpv/libmpv (can configure via mpv config files)
    // - Android: Uses ExoPlayer (buffering handled automatically)
    // - iOS: Uses AVPlayer (buffering handled automatically)
    // For desktop platforms, mpv options can be set via environment variables
    // or mpv config files, but media_kit's Player API doesn't expose direct
    // buffer configuration methods
    final player = Player();
    final controller = VideoController(player);

    state = state.copyWith(player: player, controller: controller, isMinimized: false, clearError: true);

    // Set up listeners
    player.stream.playing.listen((playing) {
      if (mounted) {
        state = state.copyWith(isPlaying: playing);
      }
    });

    player.stream.buffering.listen((buffering) {
      if (mounted) {
        state = state.copyWith(isBuffering: buffering);
      }
    });

    player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        // On Android, ExoPlayer errors might be more verbose
        // Extract meaningful error message
        String errorMsg = error;
        // Common Android/ExoPlayer error patterns
        if (error.contains('Unable to resolve host') || error.contains('ENETUNREACH')) {
          errorMsg = 'Network error: Unable to connect to stream server';
        } else if (error.contains('403') || error.contains('Forbidden')) {
          errorMsg = 'Access denied: Check your playlist credentials';
        } else if (error.contains('404') || error.contains('Not Found')) {
          errorMsg = 'Stream not found: Channel may be unavailable';
        } else if (error.contains('timeout') || error.contains('TIMED_OUT')) {
          errorMsg = 'Connection timeout: Stream server is not responding';
        }
        state = state.copyWith(errorMessage: errorMsg);
      }
    });

    // Load channel
    final repository = _ref.read(playlistRepositoryProvider);
    final result = await repository.getChannel(channelId);

    result.fold(
      (failure) {
        state = state.copyWith(errorMessage: failure.message);
      },
      (channel) async {
        try {
          state = state.copyWith(channel: channel);

          // Build HTTP headers
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

          // Open and play - wrap in try-catch to handle Android/ExoPlayer exceptions
          await player.open(Media(channel.url, httpHeaders: httpHeaders.isNotEmpty ? httpHeaders : null));
        } catch (e) {
          // Catch any exceptions from player.open() (common on Android with ExoPlayer)
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
    await state.player?.dispose();
    state = const PlayerState();
  }

  /// Retry playback
  /// Clears error state and attempts to play the channel again
  Future<void> retry() async {
    final channelId = state.channel?.id;
    if (channelId != null) {
      // Clear error state before retrying
      state = state.copyWith(clearError: true);
      // Small delay to ensure state is cleared before retry
      await Future.delayed(const Duration(milliseconds: 100));
      await playChannel(channelId);
    }
  }

  @override
  bool get mounted => true; // StateNotifier is always "mounted" while active

  @override
  void dispose() {
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
