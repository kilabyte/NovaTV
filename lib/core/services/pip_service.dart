import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show Player;

import '../../config/router/app_router.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import '../utils/app_logger.dart';

/// True while the OS-level picture-in-picture window is showing the app.
/// The root overlay watches this to swap the whole UI for bare video.
final systemPipActiveProvider = StateProvider<bool>((ref) => false);

/// Bridge to the Android system picture-in-picture support in
/// MainActivity.kt. Pushes playback eligibility (so swiping home while a
/// channel plays auto-enters PiP) plus the video aspect ratio, and reacts to
/// PiP enter/exit/dismiss events from the platform.
///
/// iOS is intentionally not wired up: media_kit renders through libmpv into a
/// Flutter texture, and AVKit's PiP only accepts AVPlayerLayer or an
/// AVSampleBufferDisplayLayer fed with raw frames, which media_kit does not
/// expose. System PiP there is blocked until upstream support exists.
class PipService {
  static const MethodChannel _channel = MethodChannel('io.kilabyte.novatv/pip');

  final Ref _ref;
  ProviderSubscription<PlayerState>? _playerSubscription;
  final List<StreamSubscription<dynamic>> _sizeSubscriptions = [];
  Player? _observedPlayer;

  /// Last values pushed to the platform, so steady-state player updates
  /// (volume changes, buffering flickers) don't spam the method channel.
  bool? _sentEligible;
  int? _sentWidth;
  int? _sentHeight;

  PipService(this._ref);

  bool get _supported => !kIsWeb && Platform.isAndroid;

  void start() {
    if (!_supported) return;
    _channel.setMethodCallHandler(_handlePlatformCall);
    _playerSubscription = _ref.listen<PlayerState>(
      playerProvider,
      (previous, next) => _onPlayerState(next),
      fireImmediately: true,
    );
  }

  void dispose() {
    if (!_supported) return;
    _channel.setMethodCallHandler(null);
    _playerSubscription?.close();
    _playerSubscription = null;
    _clearSizeSubscriptions();
  }

  void _onPlayerState(PlayerState state) {
    // The video dimensions live on the Player's own streams, not in
    // PlayerState, so re-subscribe whenever the player instance changes.
    if (!identical(state.player, _observedPlayer)) {
      _observedPlayer = state.player;
      _clearSizeSubscriptions();
      final player = state.player;
      if (player != null) {
        _sizeSubscriptions.add(player.stream.width.listen((_) => _push()));
        _sizeSubscriptions.add(player.stream.height.listen((_) => _push()));
      }
    }
    _push();
  }

  void _clearSizeSubscriptions() {
    for (final sub in _sizeSubscriptions) {
      sub.cancel();
    }
    _sizeSubscriptions.clear();
  }

  Future<void> _push() async {
    final state = _ref.read(playerProvider);
    final eligible = state.hasActivePlayer && state.errorMessage == null && state.isPlaying;
    final width = state.player?.state.width ?? 0;
    final height = state.player?.state.height ?? 0;
    if (eligible == _sentEligible && width == _sentWidth && height == _sentHeight) {
      return;
    }
    _sentEligible = eligible;
    _sentWidth = width;
    _sentHeight = height;
    try {
      await _channel.invokeMethod<void>('updatePipParams', {
        'eligible': eligible,
        'width': width,
        'height': height,
      });
    } catch (e) {
      // Roll back the dedup cache so the next player state change retries
      // the push instead of treating the failed values as delivered.
      _sentEligible = null;
      _sentWidth = null;
      _sentHeight = null;
      AppLogger.warning('PipService updatePipParams failed: $e');
    }
  }

  Future<dynamic> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'pipChanged':
        final active = call.arguments == true;
        _ref.read(systemPipActiveProvider.notifier).state = active;
        return null;
      case 'pipClosed':
        // The user dismissed the PiP window with X: stop the stream so a
        // backgrounded app doesn't hold one of the provider's connection
        // slots, and back out of the now-dead fullscreen player route so
        // reopening the app lands somewhere sensible.
        _ref.read(systemPipActiveProvider.notifier).state = false;
        await _ref.read(playerProvider.notifier).stop();
        final router = _ref.read(appRouterProvider);
        if (router.routerDelegate.currentConfiguration.uri.path.startsWith('/player')) {
          if (router.canPop()) {
            router.pop();
          }
        }
        return null;
      default:
        return null;
    }
  }
}

/// Provider that wires up the PiP bridge on first read and tears down on
/// dispose. Read from NovaApp.initState on Android.
final pipServiceProvider = Provider<PipService>((ref) {
  final service = PipService(ref)..start();
  ref.onDispose(service.dispose);
  return service;
});
