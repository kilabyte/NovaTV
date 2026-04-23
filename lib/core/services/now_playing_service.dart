import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/player/presentation/providers/player_providers.dart';
import '../utils/app_logger.dart';

/// Bridge to the native macOS Now Playing / MPRemoteCommandCenter set up in
/// AppDelegate.swift. Pushes metadata every time the player state changes
/// and forwards play/pause commands (headphone buttons, Control Center,
/// Touch Bar, keyboard media keys) back into Dart.
class NowPlayingService {
  static const MethodChannel _channel = MethodChannel('io.kilabyte.novatv/nowplaying');

  final Ref _ref;
  ProviderSubscription<PlayerState>? _subscription;

  NowPlayingService(this._ref);

  bool get _supported => !kIsWeb && Platform.isMacOS;

  void start() {
    if (!_supported) return;
    _channel.setMethodCallHandler(_handleRemoteCommand);
    // Push initial metadata and subscribe to changes.
    _subscription = _ref.listen<PlayerState>(
      playerProvider,
      (previous, next) => _push(next),
      fireImmediately: true,
    );
  }

  void dispose() {
    if (!_supported) return;
    _subscription?.close();
    _subscription = null;
    _channel.invokeMethod<void>('clear').catchError((Object _) {});
  }

  Future<void> _push(PlayerState state) async {
    if (!_supported) return;
    final channel = state.channel;
    if (channel == null) {
      await _channel.invokeMethod<void>('clear');
      return;
    }
    try {
      await _channel.invokeMethod<void>('update', {
        'title': channel.name,
        'subtitle': channel.group ?? '',
        'isPlaying': state.isPlaying,
      });
    } catch (e) {
      AppLogger.warning('NowPlayingService push failed: $e');
    }
  }

  Future<dynamic> _handleRemoteCommand(MethodCall call) async {
    final notifier = _ref.read(playerProvider.notifier);
    switch (call.method) {
      case 'play':
      case 'pause':
      case 'togglePlayPause':
        notifier.togglePlayPause();
        return null;
      case 'stop':
        await notifier.stop();
        return null;
      default:
        return null;
    }
  }
}

/// Provider that wires up Now Playing on first read and tears down on
/// dispose. Read from NovaApp.initState to start the bridge.
final nowPlayingServiceProvider = Provider<NowPlayingService>((ref) {
  final service = NowPlayingService(ref)..start();
  ref.onDispose(service.dispose);
  return service;
});
