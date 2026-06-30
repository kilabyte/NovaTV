import 'dart:async';
import 'dart:io';

import '../../../../core/utils/app_logger.dart';

/// On-device live MPEG-TS → HLS transmuxer.
///
/// The Chromecast Default Media Receiver cannot play a raw MPEG-TS HTTP stream
/// (it only plays HLS/DASH/MP4; MPEG-TS is allowed only as *segments inside* an
/// HLS playlist). Most IPTV "live" URLs (Xtream-style, extension-less or `.ts`)
/// are raw MPEG-TS — frequently behind load-balanced 302 redirects and gated by
/// a User-Agent. This server reads that upstream (following redirects, sending
/// the channel's headers), splits the continuous TS into short keyframe-aligned
/// segments, and serves a rolling live HLS playlist (`/live.m3u8` + `/seg*.ts`)
/// with permissive CORS — which the Chromecast plays natively.
///
/// The receiver loads this server's URL **directly** (CastMedia.directLoad),
/// bypassing dart_cast's proxy/rewriter (which rejects live IPTV playlists).
class HlsTransmuxServer {
  HlsTransmuxServer({
    required this.upstreamUrl,
    required this.headers,
    this.targetSegmentSeconds = 4.0,
    this.segmentsToKeep = 10,
  });

  /// The channel's stream URL (raw MPEG-TS, possibly extension-less / `.ts`).
  final String upstreamUrl;

  /// HTTP headers to send upstream (User-Agent, Referer, etc.).
  final Map<String, String> headers;

  final double targetSegmentSeconds;
  final int segmentsToKeep;

  HttpServer? _server;
  HttpClient? _client;
  bool _stopped = false;
  String? _playlistUrl;

  // --- Segmenter state ---
  final List<_Segment> _segments = [];
  int _nextSeq = 0;
  int? _pmtPid;
  int? _pcrPid;
  int? _videoPid;
  List<int>? _patPacket;
  List<int>? _pmtPacket;
  final List<int> _current = [];
  int _currentPackets = 0;
  double? _segmentStartPcr;
  double? _lastPcr;
  final List<int> _carry = []; // bytes not yet aligned to a 188-byte packet

  static const int _packetSize = 188;
  // Hard cap on a segment so a stream that never signals a keyframe can't grow
  // without bound (~3000 packets ≈ 564 KB).
  static const int _maxPacketsPerSegment = 3000;

  /// Start serving and return the playlist URL the cast device should load.
  /// [lanAddress] must be an address the Chromecast can reach (same subnet).
  Future<String> start(InternetAddress lanAddress) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_handleRequest, onError: (Object e) {
      AppLogger.warning('Transmux server error: $e');
    });
    _playlistUrl = 'http://${lanAddress.address}:${_server!.port}/live.m3u8';
    AppLogger.info('Transmux: serving $_playlistUrl');
    unawaited(_pumpLoop());
    return _playlistUrl!;
  }

  /// Number of segments currently buffered.
  int get segmentCount => _segments.length;

  /// Wait until at least [minSegments] segments have been built (so the cast
  /// device gets a non-empty playlist with a little buffer) or [timeout]
  /// elapses. Returns true if at least one segment is available.
  Future<bool> waitUntilReady({
    int minSegments = 3,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_segments.length < minSegments &&
        !_stopped &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return _segments.isNotEmpty;
  }

  Future<void> stop() async {
    _stopped = true;
    _client?.close(force: true);
    _client = null;
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    _segments.clear();
  }

  /// Continuously read the upstream TS, reconnecting on drop/rotation. IPTV
  /// load balancers rotate CDN hosts and drop long-lived connections, so a
  /// single GET is not enough to keep a live cast alive.
  Future<void> _pumpLoop() async {
    var attempt = 0;
    while (!_stopped) {
      try {
        await _readUpstreamOnce();
        attempt = 0; // a clean end resets backoff
      } catch (e) {
        AppLogger.warning('Transmux upstream read failed: $e');
      }
      if (_stopped) break;
      // Short backoff before reconnecting; the playlist keeps serving the last
      // buffered segments during the gap.
      final delayMs = (300 * (1 << attempt.clamp(0, 4))).clamp(300, 5000);
      attempt++;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  Future<void> _readUpstreamOnce() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    _client = client;
    final req = await client.getUrl(Uri.parse(upstreamUrl));
    req.followRedirects = true;
    req.maxRedirects = 8;
    headers.forEach(req.headers.set);
    if (!headers.keys.any((k) => k.toLowerCase() == 'user-agent')) {
      // Many IPTV origins reject unknown UAs; this one is widely accepted.
      req.headers.set('User-Agent', 'VLC/3.0.20 LibVLC/3.0.20');
    }
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw HttpException('upstream HTTP ${resp.statusCode}');
    }
    await for (final chunk in resp) {
      if (_stopped) break;
      _feed(chunk);
    }
  }

  // --- TS demux / segmentation ---

  void _feed(List<int> data) {
    if (_carry.isEmpty) {
      _consume(data);
    } else {
      _carry.addAll(data);
      final buf = _carry.toList();
      _carry.clear();
      _consume(buf);
    }
  }

  void _consume(List<int> buf) {
    var i = 0;
    final len = buf.length;
    while (len - i >= _packetSize) {
      if (buf[i] != 0x47) {
        i++; // resync to the next TS sync byte
        continue;
      }
      _packet(buf.sublist(i, i + _packetSize));
      i += _packetSize;
    }
    if (i < len) _carry.addAll(buf.sublist(i));
  }

  void _packet(List<int> p) {
    final pid = ((p[1] & 0x1f) << 8) | p[2];
    final pusi = (p[1] & 0x40) != 0;
    final afc = (p[3] >> 4) & 0x3;
    var rai = false;
    double? pcr;
    if (afc == 2 || afc == 3) {
      final afLen = p[4];
      if (afLen > 0) {
        final flags = p[5];
        rai = (flags & 0x40) != 0;
        if ((flags & 0x10) != 0 && afLen >= 7) {
          // 33-bit PCR base (90 kHz). High bit * 2^32 avoids 32-bit shift loss.
          final base = (p[6] * 33554432) +
              (p[7] << 17) +
              (p[8] << 9) +
              (p[9] << 1) +
              (p[10] >> 7);
          pcr = base / 90000.0;
        }
      }
    }

    if (pid == 0) {
      _patPacket = p;
      _parsePat(p, pusi);
    } else if (_pmtPid != null && pid == _pmtPid) {
      _pmtPacket = p;
      _parsePmt(p, pusi);
    }
    if (pcr != null && (pid == _pcrPid || _pcrPid == null)) _lastPcr = pcr;

    final isKeyframe = _videoPid != null && pid == _videoPid && pusi && rai;
    if (isKeyframe &&
        _currentPackets > 0 &&
        _lastPcr != null &&
        _segmentStartPcr != null &&
        (_lastPcr! - _segmentStartPcr!) >= targetSegmentSeconds) {
      _finishSegment();
    }

    if (_currentPackets == 0) {
      // Make each segment independently decodable: lead with PAT + PMT.
      if (_patPacket != null) {
        _current.addAll(_patPacket!);
        _currentPackets++;
      }
      if (_pmtPacket != null) {
        _current.addAll(_pmtPacket!);
        _currentPackets++;
      }
      _segmentStartPcr = _lastPcr;
    }
    _current.addAll(p);
    _currentPackets++;
    if (_currentPackets >= _maxPacketsPerSegment) _finishSegment();
  }

  void _finishSegment() {
    if (_current.isEmpty) return;
    final dur = (_lastPcr != null && _segmentStartPcr != null)
        ? (_lastPcr! - _segmentStartPcr!).clamp(0.5, 20.0).toDouble()
        : targetSegmentSeconds;
    _segments.add(_Segment(_nextSeq++, List<int>.of(_current), dur));
    while (_segments.length > segmentsToKeep) {
      _segments.removeAt(0);
    }
    _current.clear();
    _currentPackets = 0;
    _segmentStartPcr = _lastPcr;
  }

  void _parsePat(List<int> p, bool pusi) {
    var o = 4;
    if (pusi) o += 1 + p[o]; // pointer_field
    if (o + 12 > p.length) return;
    final sectionLen = ((p[o + 1] & 0x0f) << 8) | p[o + 2];
    final end = o + 3 + sectionLen - 4; // exclude CRC32
    var i = o + 8;
    while (i + 4 <= end && i + 4 <= p.length) {
      final program = (p[i] << 8) | p[i + 1];
      final pid = ((p[i + 2] & 0x1f) << 8) | p[i + 3];
      if (program != 0) {
        _pmtPid = pid;
        break;
      }
      i += 4;
    }
  }

  void _parsePmt(List<int> p, bool pusi) {
    var o = 4;
    if (pusi) o += 1 + p[o];
    if (o + 12 > p.length) return;
    final sectionLen = ((p[o + 1] & 0x0f) << 8) | p[o + 2];
    _pcrPid = ((p[o + 8] & 0x1f) << 8) | p[o + 9];
    final programInfoLen = ((p[o + 10] & 0x0f) << 8) | p[o + 11];
    var i = o + 12 + programInfoLen;
    final end = o + 3 + sectionLen - 4;
    while (i + 5 <= end && i + 5 <= p.length) {
      final streamType = p[i];
      final elementaryPid = ((p[i + 1] & 0x1f) << 8) | p[i + 2];
      final esInfoLen = ((p[i + 3] & 0x0f) << 8) | p[i + 4];
      // H.264 (0x1b), HEVC (0x24), MPEG-1/2 (0x01/0x02), AVC-in-PES (0x06).
      if (_videoPid == null &&
          (streamType == 0x01 ||
              streamType == 0x02 ||
              streamType == 0x1b ||
              streamType == 0x24 ||
              streamType == 0x06)) {
        _videoPid = elementaryPid;
      }
      i += 5 + esInfoLen;
    }
  }

  // --- HTTP serving ---

  Future<void> _handleRequest(HttpRequest req) async {
    final res = req.response;
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Cache-Control', 'no-cache');
    try {
      final path = req.uri.path;
      if (path.endsWith('.m3u8')) {
        res.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
        res.write(_playlist());
        await res.close();
        return;
      }
      final m = RegExp(r'seg(\d+)\.ts$').firstMatch(path);
      if (m != null) {
        final seq = int.parse(m.group(1)!);
        _Segment? seg;
        for (final s in _segments) {
          if (s.seq == seq) {
            seg = s;
            break;
          }
        }
        if (seg != null) {
          res.headers.contentType = ContentType('video', 'mp2t');
          res.add(seg.bytes);
        } else {
          res.statusCode = HttpStatus.notFound;
        }
        await res.close();
        return;
      }
      res.statusCode = HttpStatus.notFound;
      await res.close();
    } catch (e) {
      AppLogger.debug('Transmux request error: $e');
      try {
        await res.close();
      } catch (_) {}
    }
  }

  String _playlist() {
    final maxDur = _segments.isEmpty
        ? targetSegmentSeconds.ceil()
        : _segments.map((s) => s.duration).reduce((a, b) => a > b ? a : b).ceil();
    final b = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#EXT-X-VERSION:3')
      ..writeln('#EXT-X-TARGETDURATION:${maxDur + 1}')
      ..writeln('#EXT-X-MEDIA-SEQUENCE:${_segments.isEmpty ? 0 : _segments.first.seq}');
    for (final s in _segments) {
      b
        ..writeln('#EXTINF:${s.duration.toStringAsFixed(3)},')
        ..writeln('seg${s.seq}.ts');
    }
    return b.toString();
  }
}

class _Segment {
  _Segment(this.seq, this.bytes, this.duration);
  final int seq;
  final List<int> bytes;
  final double duration;
}

/// Pick a local IPv4 address the cast [device] can reach — preferring one on
/// the same /24 subnet, falling back to the first non-loopback IPv4.
Future<InternetAddress?> lanAddressForDevice(InternetAddress device) async {
  final deviceParts = device.address.split('.');
  final wantPrefix = deviceParts.length == 4
      ? '${deviceParts[0]}.${deviceParts[1]}.${deviceParts[2]}.'
      : null;
  InternetAddress? fallback;
  for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final addr in ni.addresses) {
      if (addr.isLoopback) continue;
      fallback ??= addr;
      if (wantPrefix != null && addr.address.startsWith(wantPrefix)) {
        return addr;
      }
    }
  }
  return fallback;
}
