import 'package:flutter_test/flutter_test.dart';
import 'package:novaiptv/features/playlist/data/parsers/m3u_parser.dart';

void main() {
  final parser = M3UParser();

  group('M3UParser EXTINF attribute splitting (HIGH-5)', () {
    test('preserves quoted attribute values containing commas', () {
      const content = '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="cnn" tvg-name="CNN, HD" group-title="USA, News",CNN HD\n'
          'http://example.com/cnn\n';

      final channels = parser.parse(content, 'p1');

      expect(channels, hasLength(1));
      final channel = channels.first;
      expect(channel.name, 'CNN HD');
      expect(channel.tvgId, 'cnn');
      expect(channel.tvgName, 'CNN, HD');
      expect(channel.group, 'USA, News');
    });

    test('preserves commas in the display name', () {
      const content = '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="x",News, Weather & Sports\n'
          'http://example.com/news\n';

      final channels = parser.parse(content, 'p1');

      expect(channels, hasLength(1));
      expect(channels.first.name, 'News, Weather & Sports');
    });

    test('parses a plain EXTINF with no attributes', () {
      const content = '#EXTM3U\n'
          '#EXTINF:-1,Simple Channel\n'
          'http://example.com/simple\n';

      final channels = parser.parse(content, 'p1');

      expect(channels, hasLength(1));
      expect(channels.first.name, 'Simple Channel');
    });
  });

  group('M3UParser license_key URLs (MEDIUM-20)', () {
    test('keeps channels whose stream URL carries license_key as a query parameter', () {
      const content = '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="drm",DRM Channel\n'
          'https://example.com/stream.mpd?license_key=abc123\n'
          '#EXTINF:-1 tvg-id="next",Next Channel\n'
          'https://example.com/next.m3u8\n';

      final channels = parser.parse(content, 'p1');

      expect(channels, hasLength(2));
      expect(channels[0].name, 'DRM Channel');
      expect(channels[0].url, 'https://example.com/stream.mpd?license_key=abc123');
      // The following channel must not inherit the dropped channel's EXTINF.
      expect(channels[1].name, 'Next Channel');
      expect(channels[1].url, 'https://example.com/next.m3u8');
    });

    test('still parses KODIPROP license lines', () {
      const content = '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="drm",DRM Channel\n'
          '#KODIPROP:inputstream.adaptive.license_type=com.widevine.alpha\n'
          '#KODIPROP:inputstream.adaptive.license_key=https://license.example.com/wv\n'
          'https://example.com/stream.mpd\n';

      final channels = parser.parse(content, 'p1');

      expect(channels, hasLength(1));
      expect(channels.first.licenseType, 'com.widevine.alpha');
      expect(channels.first.licenseUrl, 'https://license.example.com/wv');
    });
  });

  group('M3UParser stable channel IDs (MEDIUM-21)', () {
    const channelA = '#EXTINF:-1 tvg-id="a" group-title="G",Alpha\nhttp://example.com/a\n';
    const channelB = '#EXTINF:-1 tvg-id="b" group-title="G",Beta\nhttp://example.com/b\n';
    const channelC = '#EXTINF:-1 tvg-id="c" group-title="G",Gamma\nhttp://example.com/c\n';

    test('IDs survive upstream channel removal and reordering', () {
      final before = parser.parse('#EXTM3U\n$channelA$channelB$channelC', 'p1');
      // Provider drops Alpha and swaps the order of the survivors.
      final after = parser.parse('#EXTM3U\n$channelC$channelB', 'p1');

      final betaBefore = before.firstWhere((c) => c.name == 'Beta');
      final betaAfter = after.firstWhere((c) => c.name == 'Beta');
      final gammaBefore = before.firstWhere((c) => c.name == 'Gamma');
      final gammaAfter = after.firstWhere((c) => c.name == 'Gamma');

      expect(betaAfter.id, betaBefore.id);
      expect(gammaAfter.id, gammaBefore.id);
    });

    test('IDs differ per playlist and per channel content', () {
      final p1 = parser.parse('#EXTM3U\n$channelA$channelB', 'p1');
      final p2 = parser.parse('#EXTM3U\n$channelA', 'p2');

      expect(p1[0].id, isNot(p1[1].id));
      expect(p1[0].id, isNot(p2[0].id));
      expect(p1[0].id, startsWith('p1_'));
      expect(p2[0].id, startsWith('p2_'));
    });

    test('exact duplicate entries get unique deterministic IDs', () {
      final channels = parser.parse('#EXTM3U\n$channelA$channelA$channelA', 'p1');

      expect(channels, hasLength(3));
      final ids = channels.map((c) => c.id).toSet();
      expect(ids, hasLength(3));

      // Determinism: a re-parse yields the same IDs in the same order.
      final reparsed = parser.parse('#EXTM3U\n$channelA$channelA$channelA', 'p1');
      expect(reparsed.map((c) => c.id).toList(), channels.map((c) => c.id).toList());
    });
  });

  group('M3UParser header extraction', () {
    test('reads EPG url from the first line only', () {
      const content = '#EXTM3U x-tvg-url="http://example.com/epg.xml.gz" url-tvg="http://example.com/alt.xml"\n'
          '#EXTINF:-1,Ch\n'
          'http://example.com/ch\n';

      expect(parser.isValidM3U(content), isTrue);
      expect(parser.extractEpgUrl(content), 'http://example.com/epg.xml.gz');
      expect(parser.extractUrlTvg(content), 'http://example.com/alt.xml');
    });
  });
}
