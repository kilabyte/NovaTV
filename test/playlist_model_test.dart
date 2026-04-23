import 'package:flutter_test/flutter_test.dart';
import 'package:novaiptv/features/playlist/data/models/playlist_model.dart';

void main() {
  group('PlaylistModel.copyWith', () {
    PlaylistModel seed() => PlaylistModel(
          id: 'a',
          name: 'My list',
          url: 'http://x',
          createdAt: DateTime(2020, 1, 1),
          lastRefreshed: DateTime(2021, 1, 1),
          lastError: 'boom',
        );

    test('clearLastError=true drops the error', () {
      final updated = seed().copyWith(clearLastError: true);
      expect(updated.lastError, isNull);
    });

    test('plain lastError: null keeps existing error (the legacy no-op)', () {
      final updated = seed().copyWith(lastError: null);
      // This was the previous bug we're memorializing: `lastError: null` is a
      // no-op because of the `??` coalesce. Callers must use clearLastError.
      expect(updated.lastError, equals('boom'));
    });

    test('lastError: "new" overwrites', () {
      final updated = seed().copyWith(lastError: 'new');
      expect(updated.lastError, equals('new'));
    });

    test('preserves unrelated fields', () {
      final updated = seed().copyWith(clearLastError: true, channelCount: 42);
      expect(updated.id, equals('a'));
      expect(updated.url, equals('http://x'));
      expect(updated.channelCount, equals(42));
    });
  });
}
