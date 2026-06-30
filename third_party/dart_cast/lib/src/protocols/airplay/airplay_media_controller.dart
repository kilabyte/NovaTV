import 'dart:convert';
import 'dart:math';

import 'package:dart_cast/src/core/cast_exceptions.dart';
import 'package:dart_cast/src/protocols/airplay/airplay_features.dart';
import 'package:dart_cast/src/protocols/airplay/auth/binary_plist.dart';
import 'package:dart_cast/src/protocols/airplay/auth/hap_session.dart';
import 'package:dart_cast/src/protocols/airplay/plist_codec.dart';
import 'package:dart_cast/src/utils/logger.dart';

/// Controls AirPlay video playback (play, pause, seek, stop, etc.) over an
/// existing [HapSession].
///
/// Handles V1/V2 format auto-negotiation:
/// - **V1 binary plist** (`application/x-apple-binary-plist`, no RTSP setup)
/// - **V1 text/parameters** (legacy plain-text body, no RTSP setup)
/// - **V2 binary plist** (requires RTSP SETUP + RECORD first)
///
/// All control commands go through the HTTP/1.1 channel (`sendRequest`), not
/// the RTSP channel.
class AirPlayMediaController {
  /// The encrypted HAP session used for all communication.
  final HapSession session;

  /// Feature flags for the target AirPlay device.
  final AirPlayFeatures features;

  /// Creates an [AirPlayMediaController].
  AirPlayMediaController({required this.session, required this.features});

  // ---------------------------------------------------------------------------
  // Play commands
  // ---------------------------------------------------------------------------

  /// Sends a V1 binary plist `/play` request.
  ///
  /// Does NOT set up an RTSP session first — V1 works over plain HTTP/1.1.
  Future<HapHttpResponse> playV1(String url, double startPosition) async {
    CastLogger.debug('AirPlayMediaController: playV1 url=$url');
    final body = BinaryPlistEncoder.encode({
      'Content-Location': url,
      'Start-Position': startPosition,
      'X-Apple-Session-ID': session.sessionId,
    });
    return session.sendRequest(
      'POST',
      '/play',
      headers: {
        'Content-Type': 'application/x-apple-binary-plist',
        'User-Agent': 'MediaControl/1.0',
      },
      body: body,
    );
  }

  /// Sends a V1 text/parameters `/play` request.
  ///
  /// Uses the legacy plain-text body format. Does NOT set up an RTSP session.
  Future<HapHttpResponse> playV1Text(String url, double startPosition) async {
    CastLogger.debug('AirPlayMediaController: playV1Text url=$url');
    final bodyStr = 'Content-Location: $url\nStart-Position: $startPosition\n';
    return session.sendRequest(
      'POST',
      '/play',
      headers: {
        'Content-Type': 'text/parameters',
        'User-Agent': 'MediaControl/1.0',
        'X-Apple-Session-ID': session.sessionId,
      },
      body: utf8.encode(bodyStr),
    );
  }

  /// Sends a V2 binary plist `/play` request.
  ///
  /// Calls [HapSession.setupRtspSession] first (SETUP + feedback + RECORD),
  /// then sends the extended AirPlay 2 plist body via HTTP/1.1.
  Future<HapHttpResponse> playV2(String url, double startPosition) async {
    CastLogger.debug('AirPlayMediaController: playV2 url=$url');
    await session.setupRtspSession();

    final body = BinaryPlistEncoder.encode({
      'Content-Location': url,
      'Start-Position-Seconds': startPosition,
      'uuid': _generateUuid(),
      'streamType': 1,
      'mediaType': 'file',
      'mightSupportStorePastisKeyRequests': true,
      'playbackRestrictions': 0,
      'volume': 1.0,
      'rate': 1.0,
      'SenderMACAddress': 'AA:BB:CC:DD:EE:FF',
      'model': 'iPhone14,3',
      'clientBundleID': 'dev.dartcast',
      'clientProcName': 'dart_cast',
      'osBuildVersion': '20F66',
    });

    return session.sendRequest(
      'POST',
      '/play',
      headers: {
        'Content-Type': 'application/x-apple-binary-plist',
        'User-Agent': 'AirPlay/550.10',
        'X-Apple-ProtocolVersion': '1',
        'X-Apple-Session-ID': session.sessionId,
        'X-Apple-Stream-ID': '1',
      },
      body: body,
    );
  }

  /// Auto-selects the best play format and starts video playback.
  ///
  /// Selection order:
  /// 1. V1 binary plist (`application/x-apple-binary-plist`)
  /// 2. V1 text/parameters (if V1 plist returns 404 or 415)
  /// 3. V2 with RTSP setup (if V1 text also returns 404 or 415)
  ///
  /// Throws [UnsupportedFeatureException] if the device does not support video.
  /// Throws [PlaybackException] if all formats are rejected.
  Future<void> play(String url, {double startPosition = 0.0}) async {
    if (!features.supportsVideo) {
      throw UnsupportedFeatureException(
        'Device does not support video URL cast via AirPlay',
      );
    }

    CastLogger.info('AirPlayMediaController: play (auto-negotiate)');
    CastLogger.debug('AirPlayMediaController: play url=$url');

    // Try V1 binary plist first
    var resp = await playV1(url, startPosition);
    CastLogger.debug(
      'AirPlayMediaController: playV1 response: ${resp.statusCode}',
    );
    if (resp.statusCode == 200) {
      CastLogger.info('AirPlayMediaController: playV1 accepted');
      return;
    }

    if (resp.statusCode == 404 || resp.statusCode == 415) {
      // Try V1 text/parameters
      resp = await playV1Text(url, startPosition);
      CastLogger.debug(
        'AirPlayMediaController: playV1Text response: ${resp.statusCode}',
      );
      if (resp.statusCode == 200) {
        CastLogger.info('AirPlayMediaController: playV1Text accepted');
        return;
      }
    }

    if (resp.statusCode == 404 || resp.statusCode == 415) {
      // Try V2 with RTSP
      resp = await playV2(url, startPosition);
      CastLogger.debug(
        'AirPlayMediaController: playV2 response: ${resp.statusCode}',
      );
      if (resp.statusCode == 200) {
        CastLogger.info('AirPlayMediaController: playV2 accepted');
        return;
      }
    }

    throw PlaybackException(
      'Device rejected /play: ${resp.statusCode}',
      statusCode: resp.statusCode,
    );
  }

  // ---------------------------------------------------------------------------
  // Control commands
  // ---------------------------------------------------------------------------

  /// Pauses playback by sending `POST /rate?value=0`.
  Future<void> pause() async {
    CastLogger.info('AirPlayMediaController: pause');
    await _sendControl('POST', '/rate', queryParameters: {'value': '0'});
  }

  /// Resumes playback by sending `POST /rate?value=1`.
  Future<void> resume() async {
    CastLogger.info('AirPlayMediaController: resume');
    await _sendControl('POST', '/rate', queryParameters: {'value': '1'});
  }

  /// Seeks to [positionSeconds] by sending `POST /scrub?position=<pos>`.
  Future<void> seek(double positionSeconds) async {
    CastLogger.info('AirPlayMediaController: seek to $positionSeconds');
    await _sendControl(
      'POST',
      '/scrub',
      queryParameters: {'position': '$positionSeconds'},
    );
  }

  /// Stops playback by sending `POST /stop`.
  Future<void> stop() async {
    CastLogger.info('AirPlayMediaController: stop');
    await _sendControl('POST', '/stop');
  }

  // ---------------------------------------------------------------------------
  // Info
  // ---------------------------------------------------------------------------

  /// Fetches current playback state from the device via `GET /playback-info`.
  Future<PlaybackInfo> getPlaybackInfo() async {
    CastLogger.debug('AirPlayMediaController: getPlaybackInfo');
    final resp = await session.sendRequest('GET', '/playback-info');
    return PlistCodec.parsePlaybackInfo(resp.bodyText);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Releases any resources held by this controller.
  ///
  /// Does NOT close the underlying [session] — the session is owned by the
  /// caller and should be closed separately.
  void dispose() {
    // Nothing to release; the session is externally owned.
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _sendControl(
    String method,
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    await session.sendRequest(method, path, queryParameters: queryParameters);
  }

  static final _random = Random.secure();

  static String _generateUuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
        '-${hex(bytes[4])}${hex(bytes[5])}'
        '-${hex(bytes[6])}${hex(bytes[7])}'
        '-${hex(bytes[8])}${hex(bytes[9])}'
        '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}
