import 'dart:async';

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../playlist/domain/entities/channel.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart'
    show playlistRepositoryProvider, recentlyWatchedNotifierProvider;
import '../../data/services/bonsoir_chromecast_discovery_provider.dart';
import '../../data/services/hls_transmux_server.dart';
import 'player_providers.dart';

/// Lifecycle of the Chromecast feature.
enum CastPhase {
  /// Not casting and not scanning.
  idle,

  /// Scanning the local network for Cast devices.
  discovering,

  /// A device was chosen and we are opening the session / loading media.
  connecting,

  /// Connected to a device and (attempting to) play media on it.
  connected,

  /// The last cast attempt failed; [CastState.errorMessage] explains why.
  error,
}

/// Immutable Chromecast state, exposed via [castProvider].
class CastState {
  final CastPhase phase;

  /// Devices found during the current discovery scan.
  final List<CastDevice> devices;

  /// The device we are connecting to / connected to.
  final CastDevice? device;

  /// The channel currently being cast.
  final Channel? channel;

  /// Whether the device reports it is playing.
  final bool isPlaying;

  /// Whether the device reports it is loading/buffering.
  final bool isBuffering;

  /// Set on a failed cast attempt for one-shot UI surfacing.
  final String? errorMessage;

  const CastState({
    this.phase = CastPhase.idle,
    this.devices = const [],
    this.device,
    this.channel,
    this.isPlaying = false,
    this.isBuffering = false,
    this.errorMessage,
  });

  /// True while a device is targeted (connecting OR connected). Local mpv
  /// playback must stand down while this holds so the IPTV provider's
  /// concurrent-connection slot stays free for the Cast device.
  bool get isCasting =>
      device != null &&
      (phase == CastPhase.connecting || phase == CastPhase.connected);

  /// True once the session is fully connected and accepting commands.
  bool get isConnected => phase == CastPhase.connected && device != null;

  CastState copyWith({
    CastPhase? phase,
    List<CastDevice>? devices,
    CastDevice? device,
    Channel? channel,
    bool? isPlaying,
    bool? isBuffering,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CastState(
      phase: phase ?? this.phase,
      devices: devices ?? this.devices,
      device: device ?? this.device,
      channel: channel ?? this.channel,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns the dart_cast [CastService], device discovery, the active session, and
/// the bridge to the local player. Mirrors the PlayerNotifier pattern.
///
/// Casting flow: discover -> connect (TLS to device) -> stop local mpv ->
/// loadMedia (device pulls the stream through dart_cast's header-injecting
/// proxy). Channel changes while connected reload media on the device instead
/// of opening a local connection (see [PlayerNotifier.playChannel]).
class CastNotifier extends StateNotifier<CastState> {
  final Ref _ref;

  CastService? _service;
  CastSession? _session;
  StreamSubscription<List<CastDevice>>? _discoverySub;
  StreamSubscription<SessionState>? _sessionStateSub;

  /// Active on-device transmux server, when casting a raw-TS channel.
  HlsTransmuxServer? _transmux;

  CastNotifier(this._ref) : super(const CastState());

  /// Grace period between releasing one connection (local mpv or the Cast
  /// device) and opening the other. IPTV plans cap concurrent connections and
  /// free a slot only a moment after the socket closes; without this pause the
  /// hand-off can momentarily need one extra slot and the new connection is
  /// refused (manifest loads but segments 403 → "title shows, nothing plays").
  static const Duration _handoffGrace = Duration(seconds: 2);

  CastService _ensureService() {
    return _service ??= CastService(
      discoveryProviders: [BonsoirChromecastDiscoveryProvider()],
      sessionFactory: (device) => ChromecastSession(device: device),
    );
  }

  /// Begin scanning for Cast devices. Results stream into [CastState.devices].
  void startDiscovery() {
    final service = _ensureService();
    _discoverySub?.cancel();
    if (!state.isConnected) {
      state = state.copyWith(
        phase: CastPhase.discovering,
        devices: const [],
        clearError: true,
      );
    }
    _discoverySub = service
        .startDiscovery(timeout: const Duration(seconds: 15))
        .listen(
      (devices) {
        if (mounted) state = state.copyWith(devices: devices);
      },
      onError: (Object e) {
        AppLogger.warning('Cast discovery error: $e');
        if (mounted && state.phase == CastPhase.discovering) {
          state = state.copyWith(phase: CastPhase.idle);
        }
      },
      onDone: () {
        if (mounted && state.phase == CastPhase.discovering) {
          state = state.copyWith(phase: CastPhase.idle);
        }
      },
    );
  }

  /// Stop an active discovery scan.
  void stopDiscovery() {
    _discoverySub?.cancel();
    _discoverySub = null;
    _service?.stopDiscovery();
    if (mounted && state.phase == CastPhase.discovering) {
      state = state.copyWith(phase: CastPhase.idle);
    }
  }

  /// Connect to [device] and select it as the app's cast target. Returns
  /// `null` on success or a user-facing error message on failure.
  ///
  /// Casts the channel currently playing locally, if any. When invoked from
  /// the global sidebar with nothing playing, it connects idle — the next
  /// [PlayerNotifier.playChannel] then loads onto the device automatically.
  ///
  /// Connects first (no provider slot used yet), then releases the local mpv
  /// connection, then loads the stream on the device — minimising any window
  /// where both the app and the Cast device hold a connection.
  Future<String?> connectToDevice(CastDevice device) async {
    stopDiscovery();
    final channel = _ref.read(playerProvider).channel;
    state = state.copyWith(
      phase: CastPhase.connecting,
      device: device,
      channel: channel,
      devices: const [],
      isPlaying: false,
      isBuffering: channel != null,
      clearError: true,
    );

    final service = _ensureService();
    CastSession session;
    try {
      session = await service.connect(device);
    } catch (e) {
      AppLogger.warning('Cast connect to "${device.name}" failed: $e');
      // Local playback was never interrupted — just report and bail.
      final message = 'Could not connect to ${device.name}';
      if (mounted) {
        state = CastState(phase: CastPhase.error, errorMessage: message);
      }
      return message;
    }

    if (!mounted) {
      unawaited(session.disconnect().catchError((Object _) {}));
      return null;
    }
    _session = session;
    _bindSession(session);

    // Nothing playing locally — stay connected and wait for a channel.
    if (channel == null) {
      state = state.copyWith(phase: CastPhase.connected, isBuffering: false);
      return null;
    }

    // Release the local connection slot, then hand the stream to the device.
    // Wait out the provider's slot-release lag so the local and cast
    // connections never overlap against the plan's concurrent-connection cap.
    await _ref.read(playerProvider.notifier).stop();
    await Future<void>.delayed(_handoffGrace);
    if (!mounted) {
      await _disconnectSession();
      return null;
    }

    final media = await _buildMedia(channel, device);
    if (media == null || !mounted) {
      await _disconnectSession();
      final message = 'Could not cast “${channel.displayName}”';
      _failAndResumeLocal(message, channel);
      return message;
    }
    try {
      await session.loadMedia(media);
    } catch (e) {
      AppLogger.warning('Cast loadMedia failed: $e');
      await _disconnectSession();
      // We already stopped local playback — resume it so the user isn't
      // stranded on a blank screen.
      final message = 'Could not cast “${channel.displayName}”';
      _failAndResumeLocal(message, channel);
      return message;
    }

    if (!mounted) {
      await _disconnectSession();
      return null;
    }
    state = state.copyWith(
      phase: CastPhase.connected,
      isPlaying: true,
      isBuffering: false,
    );
    _ref.read(recentlyWatchedNotifierProvider.notifier).addChannel(channel.id);
    return null;
  }

  /// Load a different channel on the already-connected device. Called by
  /// [PlayerNotifier.playChannel] when the user zaps while casting.
  Future<void> castChannelById(String channelId) async {
    final session = _session;
    final device = state.device;
    if (session == null || device == null) return;
    // Already casting this channel (e.g. the player screen was re-opened for
    // it) — don't reload and re-buffer the same stream on the device.
    if (state.channel?.id == channelId) return;

    final result = await _ref.read(playlistRepositoryProvider).getChannel(channelId);
    final channel = result.fold<Channel?>((_) => null, (c) => c);
    if (channel == null || !mounted) return;

    state = state.copyWith(channel: channel, isBuffering: true, clearError: true);
    _ref.read(recentlyWatchedNotifierProvider.notifier).addChannel(channelId);

    final media = await _buildMedia(channel, device);
    if (media == null || !mounted) {
      if (mounted) state = state.copyWith(isBuffering: false);
      return;
    }
    try {
      await session.loadMedia(media);
      if (mounted) {
        state = state.copyWith(isPlaying: true, isBuffering: false);
      }
    } catch (e) {
      AppLogger.warning('Cast channel switch failed: $e');
      if (mounted) state = state.copyWith(isBuffering: false);
    }
  }

  /// Toggle play/pause on the cast device.
  Future<void> togglePlayPause() async {
    final session = _session;
    if (session == null) return;
    try {
      if (state.isPlaying) {
        await session.pause();
        if (mounted) state = state.copyWith(isPlaying: false);
      } else {
        await session.play();
        if (mounted) state = state.copyWith(isPlaying: true);
      }
    } catch (e) {
      AppLogger.warning('Cast play/pause failed: $e');
    }
  }

  /// Stop casting. By default resumes local playback of the channel that was
  /// being cast so the user keeps watching where they left off.
  Future<void> stopCasting({bool resumeLocal = true}) async {
    final channel = state.channel;
    await _disconnectSession();
    if (mounted) state = const CastState();
    if (resumeLocal && channel != null) {
      // Let the provider release the cast connection slot before reopening
      // locally, so the two never overlap against the connection cap.
      await Future<void>.delayed(_handoffGrace);
      // isCasting is now false, so this opens a local mpv connection.
      await _ref.read(playerProvider.notifier).playChannel(channel.id);
    }
  }

  void _bindSession(CastSession session) {
    _sessionStateSub?.cancel();
    _sessionStateSub = session.stateStream.listen((s) {
      if (!mounted) return;
      switch (s) {
        case SessionState.playing:
          state = state.copyWith(
            phase: CastPhase.connected,
            isPlaying: true,
            isBuffering: false,
          );
        case SessionState.paused:
          state = state.copyWith(isPlaying: false, isBuffering: false);
        case SessionState.loading:
        case SessionState.buffering:
          state = state.copyWith(isBuffering: true);
        case SessionState.idle:
          state = state.copyWith(isBuffering: false);
        case SessionState.disconnected:
          _onRemoteDisconnect();
        default:
          break;
      }
    });
  }

  /// The device dropped the session itself (powered off, left the network).
  /// Tear down without resuming local playback — the user may have walked away.
  void _onRemoteDisconnect() {
    _sessionStateSub?.cancel();
    _sessionStateSub = null;
    _session = null;
    unawaited(_stopTransmux());
    if (mounted) state = const CastState();
  }

  void _failAndResumeLocal(String message, Channel channel) {
    if (mounted) {
      state = CastState(phase: CastPhase.error, errorMessage: message);
    }
    _ref.read(playerProvider.notifier).playChannel(channel.id);
  }

  Future<void> _disconnectSession() async {
    // Cancel the state subscription first so our own disconnect() does not
    // re-enter _onRemoteDisconnect via the "disconnected" event.
    _sessionStateSub?.cancel();
    _sessionStateSub = null;
    final session = _session;
    _session = null;
    if (session != null) {
      try {
        await session.disconnect();
      } catch (e) {
        AppLogger.warning('Cast disconnect failed: $e');
      }
    }
    await _stopTransmux();
  }

  /// Builds the [CastMedia] for [channel].
  ///
  /// Real HLS/MP4/MKV is cast directly via dart_cast's proxy (it injects the
  /// channel headers on the manifest + segments). Raw MPEG-TS — the common
  /// IPTV case (Xtream-style extension-less / `.ts`), which the Chromecast
  /// receiver can't play — is transmuxed to HLS on-device by
  /// [HlsTransmuxServer] and loaded directly ([CastMedia.directLoad]). Returns
  /// null if no LAN address is available to host the transmux server.
  Future<CastMedia?> _buildMedia(Channel channel, CastDevice device) async {
    final headers = buildChannelStreamHeaders(channel);
    final logo = channel.logoUrl;
    final image = (logo != null && logo.isNotEmpty) ? logo : null;
    final path = (Uri.tryParse(channel.url)?.path ?? channel.url).toLowerCase();

    CastMediaType? directType;
    if (path.endsWith('.m3u8')) {
      directType = CastMediaType.hls;
    } else if (path.endsWith('.mp4')) {
      directType = CastMediaType.mp4;
    } else if (path.endsWith('.mkv')) {
      directType = CastMediaType.mkv;
    }

    // Tear down any previous transmux server before switching sources.
    await _stopTransmux();

    if (directType != null) {
      return CastMedia(
        url: channel.url,
        type: directType,
        httpHeaders: headers,
        title: channel.displayName,
        imageUrl: image,
      );
    }

    // Raw MPEG-TS: transmux to HLS on-device and cast the local URL directly.
    final lan = await lanAddressForDevice(device.address);
    if (lan == null) {
      AppLogger.warning('Cast: no reachable LAN address to host transmux');
      return null;
    }
    final server = HlsTransmuxServer(upstreamUrl: channel.url, headers: headers);
    _transmux = server;
    final playlistUrl = await server.start(lan);
    // Wait for the first segments so the receiver gets a non-empty playlist.
    final ready = await server.waitUntilReady();
    if (!ready || !mounted || !identical(_transmux, server)) {
      await server.stop();
      if (identical(_transmux, server)) _transmux = null;
      return null;
    }
    return CastMedia(
      url: playlistUrl,
      type: CastMediaType.hls,
      directLoad: true,
      title: channel.displayName,
      imageUrl: image,
    );
  }

  Future<void> _stopTransmux() async {
    final t = _transmux;
    _transmux = null;
    if (t != null) await t.stop();
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    _sessionStateSub?.cancel();
    unawaited(_stopTransmux());
    final service = _service;
    _service = null;
    // service.dispose() disconnects the session and disposes discovery
    // providers; fire-and-forget since StateNotifier.dispose is synchronous.
    unawaited(Future(() async {
      try {
        await service?.dispose();
      } catch (_) {}
    }));
    super.dispose();
  }
}

/// Global Chromecast provider.
final castProvider = StateNotifierProvider<CastNotifier, CastState>((ref) {
  return CastNotifier(ref);
});

/// Convenience flag: true whenever a Cast session is active (connecting or
/// connected). Drives the global cast bar's visibility.
final isCastingProvider = Provider<bool>((ref) {
  return ref.watch(castProvider).isCasting;
});
