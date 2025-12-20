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
    // Note: Buffering is handled by media_kit/mpv with default settings
    // For enhanced buffering configuration, mpv options can be set via
    // environment variables or mpv config files, but media_kit's Player API
    // doesn't expose direct buffer configuration methods
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
        state = state.copyWith(errorMessage: error);
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

        // Open and play
        await player.open(Media(channel.url, httpHeaders: httpHeaders.isNotEmpty ? httpHeaders : null));
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
  Future<void> retry() async {
    final channelId = state.channel?.id;
    if (channelId != null) {
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
