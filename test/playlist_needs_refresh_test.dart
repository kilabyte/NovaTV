import 'package:flutter_test/flutter_test.dart';
import 'package:novaiptv/features/playlist/domain/entities/playlist.dart';

void main() {
  group('Playlist.needsRefresh', () {
    Playlist make({
      DateTime? lastRefreshed,
      bool autoRefresh = true,
      int intervalHours = 24,
    }) {
      return Playlist(
        id: 'p1',
        name: 'Test',
        url: 'http://example.com/list.m3u',
        createdAt: DateTime(2020, 1, 1),
        lastRefreshed: lastRefreshed,
        autoRefresh: autoRefresh,
        refreshIntervalHours: intervalHours,
      );
    }

    test('treats a never-refreshed playlist as stale', () {
      expect(make(lastRefreshed: null).needsRefresh, isTrue);
    });

    test('treats auto-refresh=false as never stale', () {
      expect(make(autoRefresh: false, lastRefreshed: null).needsRefresh, isFalse);
    });

    test('is stale when older than the interval', () {
      final old = DateTime.now().subtract(const Duration(hours: 25));
      expect(make(lastRefreshed: old, intervalHours: 24).needsRefresh, isTrue);
    });

    test('is fresh when younger than the interval', () {
      final recent = DateTime.now().subtract(const Duration(hours: 1));
      expect(make(lastRefreshed: recent, intervalHours: 24).needsRefresh, isFalse);
    });

    test('boundary: exactly equal to the interval is considered stale', () {
      final boundary = DateTime.now().subtract(const Duration(hours: 24));
      expect(make(lastRefreshed: boundary, intervalHours: 24).needsRefresh, isTrue);
    });
  });

  group('Playlist.hasEpg', () {
    Playlist withEpg(String? url) => Playlist(
          id: 'p1',
          name: 'Test',
          url: 'http://x',
          createdAt: DateTime(2020, 1, 1),
          epgUrl: url,
        );

    test('null epgUrl → false', () => expect(withEpg(null).hasEpg, isFalse));
    test('empty epgUrl → false', () => expect(withEpg('').hasEpg, isFalse));
    test('populated epgUrl → true', () =>
        expect(withEpg('http://x/epg.xml').hasEpg, isTrue));
  });
}
