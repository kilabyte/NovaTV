import 'dart:math';

import 'package:http/http.dart' as http;

import 'plist_codec.dart';

/// Low-level HTTP client for AirPlay video casting endpoints.
///
/// Sends requests to an AirPlay device at the given [host] and [port].
/// All requests include `User-Agent: MediaControl/1.0` and a consistent
/// `X-Apple-Session-ID` header that is regenerated after [stop].
class AirPlayClient {
  /// The AirPlay device hostname or IP address.
  final String host;

  /// The AirPlay device port (typically 7000).
  final int port;

  final http.Client _httpClient;

  String _sessionId;

  /// The underlying HTTP client. Exposed so pair-verify can share
  /// the same connection for authenticated requests.
  http.Client get httpClient => _httpClient;

  /// Creates an [AirPlayClient] targeting the given [host] and [port].
  ///
  /// An optional [httpClient] can be provided for testing.
  AirPlayClient({
    required this.host,
    required this.port,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client(),
       _sessionId = _generateUuid();

  /// The current session ID.
  String get sessionId => _sessionId;

  /// Common headers included in every request.
  Map<String, String> get _headers => {
    'User-Agent': 'MediaControl/1.0',
    'X-Apple-Session-ID': _sessionId,
  };

  /// Starts playback of a video URL on the AirPlay device.
  ///
  /// [url] is the media URL (typically an HLS manifest).
  /// [startPosition] is a fraction from 0.0 to 1.0.
  Future<void> play(String url, {double startPosition = 0.0}) async {
    final body = 'Content-Location: $url\nStart-Position: $startPosition\n';
    final response = await _httpClient.post(
      _uri('/play'),
      headers: {..._headers, 'Content-Type': 'text/parameters'},
      body: body,
    );
    _checkResponse(response, 'play');
  }

  /// Seeks to an absolute position in seconds.
  Future<void> scrub(double positionSeconds) async {
    final response = await _httpClient.post(
      _uri('/scrub', queryParameters: {'position': '$positionSeconds'}),
      headers: _headers,
    );
    _checkResponse(response, 'scrub');
  }

  /// Sets the playback rate (0 = pause, 1 = play).
  Future<void> rate(num value) async {
    final response = await _httpClient.post(
      _uri('/rate', queryParameters: {'value': '${value.toDouble()}'}),
      headers: _headers,
    );
    _checkResponse(response, 'rate');
  }

  /// Stops playback and generates a new session ID.
  Future<void> stop() async {
    final response = await _httpClient.post(_uri('/stop'), headers: _headers);
    _checkResponse(response, 'stop');
    // Generate a new session ID for the next playback session
    _sessionId = _generateUuid();
  }

  /// Gets detailed playback state as a [PlaybackInfo].
  Future<PlaybackInfo> getPlaybackInfo() async {
    final response = await _httpClient.get(
      _uri('/playback-info'),
      headers: _headers,
    );
    _checkResponse(response, 'playback-info');
    return PlistCodec.parsePlaybackInfo(response.body);
  }

  /// Gets device information as a [ServerInfo].
  Future<ServerInfo> getServerInfo() async {
    final response = await _httpClient.get(
      _uri('/server-info'),
      headers: _headers,
    );
    _checkResponse(response, 'server-info');
    return PlistCodec.parseServerInfo(response.body);
  }

  /// Gets the current scrub position as (duration, position) in seconds.
  Future<({double duration, double position})> getScrubPosition() async {
    final response = await _httpClient.get(_uri('/scrub'), headers: _headers);
    _checkResponse(response, 'scrub');
    return _parseTextParameters(response.body);
  }

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close();
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: path,
      queryParameters: queryParameters,
    );
  }

  void _checkResponse(http.Response response, String endpoint) {
    if (response.statusCode != 200) {
      throw AirPlayClientException(
        'AirPlay $endpoint failed with status ${response.statusCode}',
      );
    }
  }

  /// Parses a text/parameters response (key: value pairs separated by newlines).
  static ({double duration, double position}) _parseTextParameters(
    String body,
  ) {
    double duration = 0;
    double position = 0;
    for (final line in body.trim().split('\n')) {
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;
      final key = line.substring(0, colonIndex).trim();
      final value = double.tryParse(line.substring(colonIndex + 1).trim()) ?? 0;
      if (key == 'duration') duration = value;
      if (key == 'position') position = value;
    }
    return (duration: duration, position: position);
  }

  /// Generates a UUID v4-like string.
  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}

/// Exception thrown when an AirPlay HTTP request fails.
class AirPlayClientException implements Exception {
  /// Description of the error.
  final String message;

  /// Creates an [AirPlayClientException].
  AirPlayClientException(this.message);

  @override
  String toString() => 'AirPlayClientException: $message';
}
