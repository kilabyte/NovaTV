import 'dart:convert';
import 'dart:io';

import 'hls_alt_audio_proxy.dart';
import 'hls_parser.dart';
import 'ts_alt_audio_remuxer.dart';
import '../utils/logger.dart';

/// Handles fetching an HLS playlist and streaming its segments as a
/// continuous MPEG-TS byte stream.
///
/// Used by DLNA renderers that do not understand HLS — instead of
/// pointing the TV at an m3u8 URL, we resolve segments server-side and
/// concatenate them into a single `video/mp2t` response.
///
/// ## Alternate audio renditions
///
/// Sources whose master playlist declares `EXT-X-MEDIA:TYPE=AUDIO` with
/// matching variant `AUDIO="<group>"` reference are handled by routing
/// through [HlsAltAudioPlanner] + [TsAltAudioRemuxer]: each video
/// segment is fetched together with the chosen audio rendition's
/// segment, the pair is remuxed into a single TS, and the muxed bytes
/// are written to the response. The TV sees one continuous TS with
/// both streams just like a legacy muxed HLS source.
class HlsStreamHandler {
  final HttpClient _httpClient;

  /// Creates an [HlsStreamHandler] with an optional [HttpClient].
  HlsStreamHandler({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  /// Fetches the HLS playlist at [m3u8Url], resolves segments, and streams
  /// them sequentially into [response].
  ///
  /// If the playlist is a master playlist, the highest-bandwidth variant is
  /// selected automatically.
  ///
  /// [headers] are forwarded to all upstream requests (playlist + segments).
  ///
  /// [preferredAudioLanguage] is matched (case-insensitive substring)
  /// against each `EXT-X-MEDIA:TYPE=AUDIO` rendition's `NAME` attribute
  /// when the source uses alt-audio, falling back to `DEFAULT=YES` then
  /// the first rendition.
  Future<void> streamAsTransportStream(
    String m3u8Url,
    Map<String, String> headers,
    HttpResponse response, {
    String? preferredAudioLanguage,
  }) async {
    try {
      final playlistContent = await _fetchString(m3u8Url, headers);

      // Alt-audio HLS — mux video + audio per segment, concatenate.
      if (HlsParser.isMasterPlaylist(playlistContent)) {
        final variants = HlsParser.extractVariants(playlistContent, m3u8Url);
        if (variants.isEmpty) {
          response.statusCode = HttpStatus.badGateway;
          await response.close();
          return;
        }

        final picked = variants.first;
        final audioGroup = picked.audioGroup;
        if (audioGroup != null && audioGroup.isNotEmpty) {
          final audioRenditions = HlsParser.extractAudioRenditions(
            playlistContent,
            m3u8Url,
          );
          final hasMatchingAudioPlaylist = audioRenditions.any(
            (r) => r.groupId == audioGroup && r.uri != null,
          );
          if (hasMatchingAudioPlaylist) {
            await _streamMuxedAltAudio(
              m3u8Url: m3u8Url,
              headers: headers,
              response: response,
              preferredAudioLanguage: preferredAudioLanguage,
            );
            return;
          }
        }

        // Single-stream master — fetch the chosen variant playlist and
        // fall through to the legacy concat path below.
        final mediaPlaylistContent = await _fetchString(picked.url, headers);
        await _streamConcatenated(
          mediaPlaylistUrl: picked.url,
          mediaPlaylistContent: mediaPlaylistContent,
          headers: headers,
          response: response,
        );
        return;
      }

      // Media playlist directly — concat its segments.
      await _streamConcatenated(
        mediaPlaylistUrl: m3u8Url,
        mediaPlaylistContent: playlistContent,
        headers: headers,
        response: response,
      );
    } catch (e, stack) {
      CastLogger.error(
        'HlsStreamHandler: failed to stream TS playlist: $e\n$stack',
      );
      try {
        response.statusCode = HttpStatus.badGateway;
        await response.close();
      } catch (_) {
        // Response may already be closed.
      }
    }
  }

  /// Concatenates a media playlist's segments to [response] as a single
  /// `video/mp2t` body. Used for the simple "all-muxed segments" case.
  Future<void> _streamConcatenated({
    required String mediaPlaylistUrl,
    required String mediaPlaylistContent,
    required Map<String, String> headers,
    required HttpResponse response,
  }) async {
    final segmentUrls = HlsParser.extractSegmentUrls(
      mediaPlaylistContent,
      mediaPlaylistUrl,
    );
    if (segmentUrls.isEmpty) {
      response.statusCode = HttpStatus.badGateway;
      await response.close();
      return;
    }

    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.set('Accept-Ranges', 'none');
    response.headers.set('Access-Control-Allow-Origin', '*');

    for (final segmentUrl in segmentUrls) {
      try {
        final segUri = Uri.parse(segmentUrl);
        final segRequest = await _httpClient.openUrl('GET', segUri);
        for (final entry in headers.entries) {
          segRequest.headers.set(entry.key, entry.value);
        }
        final segResponse = await segRequest.close();
        if (segResponse.statusCode == HttpStatus.ok) {
          await for (final chunk in segResponse) {
            response.add(chunk);
          }
        } else {
          await segResponse.drain<void>();
        }
      } catch (_) {
        // Skip segments that fail to fetch.
      }
    }
    await response.close();
  }

  /// Fetches an alt-audio HLS plan, mux-then-writes each segment pair
  /// to [response] sequentially. The TV receives one continuous TS
  /// stream with both video and audio.
  Future<void> _streamMuxedAltAudio({
    required String m3u8Url,
    required Map<String, String> headers,
    required HttpResponse response,
    String? preferredAudioLanguage,
  }) async {
    final planner = HlsAltAudioPlanner(httpClient: _httpClient);
    final plan = await planner.plan(
      masterUrl: m3u8Url,
      headers: headers,
      preferredAudioLanguage: preferredAudioLanguage,
    );
    if (plan == null) {
      // Shouldn't happen — caller already verified alt-audio — but
      // handle defensively.
      response.statusCode = HttpStatus.badGateway;
      await response.close();
      return;
    }
    CastLogger.info(
      'HlsStreamHandler: streaming ${plan.segments.length} alt-audio '
      'segments as concatenated muxed TS',
    );

    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.set('Accept-Ranges', 'none');
    response.headers.set('Access-Control-Allow-Origin', '*');

    final muxer = HlsAltAudioSegmentMuxer(planner: planner);
    for (var i = 0; i < plan.segments.length; i++) {
      try {
        final muxed = await muxer.muxSegment(plan: plan, segmentIndex: i);
        response.add(muxed.bytes);
      } catch (e) {
        CastLogger.warning(
          'HlsStreamHandler: skipping segment $i — mux failed: $e',
        );
        // Skip the segment rather than abort the whole response —
        // matches the behaviour of [_streamConcatenated].
      }
    }
    await response.close();
  }

  /// Fetches a URL and returns the body as a string.
  Future<String> _fetchString(String url, Map<String, String> headers) async {
    final uri = Uri.parse(url);
    final request = await _httpClient.openUrl('GET', uri);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    final response = await request.close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );
    return utf8.decode(bytes);
  }

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close(force: true);
  }
}
