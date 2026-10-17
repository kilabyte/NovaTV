import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:novaiptv/features/channels/presentation/screens/channel_list_screen.dart';
import 'package:novaiptv/features/epg/data/datasources/epg_remote_data_source.dart';
import 'package:novaiptv/features/epg/domain/entities/epg_data.dart';
import 'package:novaiptv/features/epg/presentation/providers/epg_providers.dart';
import 'package:novaiptv/features/epg/presentation/screens/tv_guide_screen.dart';
import 'package:novaiptv/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:novaiptv/features/playlist/data/datasources/playlist_local_data_source.dart';
import 'package:novaiptv/features/playlist/data/datasources/playlist_remote_data_source.dart';
import 'package:novaiptv/features/playlist/data/models/channel_model.dart';
import 'package:novaiptv/features/playlist/presentation/providers/playlist_providers.dart';
import 'package:novaiptv/features/settings/data/models/app_settings_model.dart';

import 'support/populated_fixtures.dart';

/// Network must never be touched from a widget test; the data is already in
/// Hive, so any fetch is a test bug.
class _NoNetworkPlaylistSource implements PlaylistRemoteDataSource {
  @override
  Future<String> fetchPlaylist(String url, {Map<String, String>? headers, CancelToken? cancelToken}) {
    throw StateError('unexpected playlist fetch: $url');
  }
}

class _NoNetworkEpgSource implements EpgRemoteDataSource {
  @override
  Future<EpgData> fetchEpg(String url, {CancelToken? cancelToken}) {
    throw StateError('unexpected EPG fetch: $url');
  }
}

/// Screens rendered against real persisted fixture data, as on a device
/// launch after a playlist add + EPG refresh. The provider graph is the
/// production one; only the network edges are stubbed.
///
/// Hive is real file I/O. The widget test zone's fake clock never drives
/// that, so every Hive lifecycle step and the initial pump run inside
/// [WidgetTester.runAsync]; frames are then pumped normally.
void main() {
  final now = DateTime.now();

  Widget harness(Widget child) {
    return ProviderScope(
      overrides: [
        playlistRemoteDataSourceProvider.overrideWithValue(_NoNetworkPlaylistSource()),
        epgRemoteDataSourceProvider.overrideWithValue(_NoNetworkEpgSource()),
        // A single tick instead of the real minute-aligned timer loop.
        minuteTickProvider.overrideWith((ref) => Stream.value(now)),
      ],
      child: MaterialApp(home: child),
    );
  }

  /// Pump (in real time, so Hive I/O completes) until [done] or the bound
  /// is reached; assertions after this report what was actually rendered.
  Future<void> settleUntil(WidgetTester tester, bool Function() done, {int maxFrames = 60}) async {
    await tester.runAsync(() async {
      for (var i = 0; i < maxFrames && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
  }

  bool noneOf(String text) => find.text(text).evaluate().isEmpty;
  bool anyOf(String text) => find.text(text).evaluate().isNotEmpty;

  /// Every Text currently on screen, for failure diagnostics.
  String visibleTexts(WidgetTester tester) {
    return tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText() ?? '').where((s) => s.isNotEmpty).join(' | ');
  }

  /// Seed Hive, pump [screen], run [body], tear Hive down. All I/O in real time.
  Future<void> withPopulatedScreen(WidgetTester tester, Widget screen, Size surface, bool Function() ready, Future<void> Function() body) async {
    Directory? dir;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Everything below the temp dir creation runs inside the guard so a
    // failure during seeding or the first pump still closes Hive and
    // removes the directory.
    try {
      await tester.runAsync(() async {
        dir = await initTestHive();
        await persistPopulatedFixture(now);
        // Favorite one channel through the production write path so the
        // favorites screen and the isFavorite index have real data.
        final channels = await Hive.openBox<ChannelModel>('channels');
        final espn = channels.values.firstWhere((c) => c.name == 'ESPN');
        await PlaylistLocalDataSourceImpl().saveChannel(espn.copyWith(isFavorite: true));
        await simulateRelaunch();
        // bootstrap() pre-opens these before the first frame.
        await Hive.openBox<AppSettingsModel>('app_settings');
        await tester.binding.setSurfaceSize(surface);
        await tester.pumpWidget(harness(screen));
      });
      await settleUntil(tester, ready);
      await body();
    } finally {
      final d = dir;
      if (d != null) {
        await tester.runAsync(() => disposeTestHive(d));
      }
    }
  }

  testWidgets('channel list renders every persisted channel with its airing programme', (tester) async {
    await withPopulatedScreen(tester, const ChannelListScreen(), const Size(1000, 1200), () => anyOf('No EPG Channel') && noneOf('Loading...'), () async {
      final texts = visibleTexts(tester);
      expect(find.text('All Channels'), findsOneWidget);
      for (final name in ['BBC One HD', 'BBC One SD', 'BBC One +1', 'CNN', 'ESPN', 'No EPG Channel']) {
        expect(find.text(name), findsOneWidget, reason: '$name row missing. Visible: $texts');
      }
      expect(find.text('Loading...'), findsNothing, reason: 'rows still loading. Visible: $texts');
      // The list shows the unshifted airing programme for all three BBC
      // variants (mixed-case tvg-ids, one with tvg-shift).
      expect(find.text('BBC News at Six'), findsNWidgets(3), reason: 'Visible: $texts');
      expect(find.text('CNN Newsroom'), findsOneWidget, reason: 'Visible: $texts');
      expect(find.text('SportsCenter'), findsOneWidget, reason: 'Visible: $texts');
      expect(find.text('No program info'), findsOneWidget, reason: 'only the channel without EPG should lack a programme. Visible: $texts');
    });
  });

  testWidgets('favorites screen renders the persisted favorite with its airing programme', (tester) async {
    await withPopulatedScreen(tester, const FavoritesScreen(), const Size(800, 600), () => anyOf('SportsCenter'), () async {
      final texts = visibleTexts(tester);
      expect(find.text('ESPN'), findsOneWidget, reason: 'Visible: $texts');
      expect(find.text('SportsCenter'), findsOneWidget, reason: 'Visible: $texts');
      expect(find.text('No favorites yet'), findsNothing);
    });
  });

  testWidgets('TV guide grid shows programme cells for every channel that has EPG', (tester) async {
    await withPopulatedScreen(tester, const TvGuideScreen(), const Size(1400, 900), () => anyOf('SportsCenter') && anyOf('No program data'), () async {
      // Grouping resolves through a FutureBuilder and the grid then nudges
      // its scroll position back to "now"; wait for that animation to land.
      await settleUntil(tester, () => anyOf('BBC News at Six') && anyOf('CNN Newsroom'));
      final texts = visibleTexts(tester);
      expect(find.text('TV Guide'), findsOneWidget);
      expect(find.text('No EPG data available'), findsNothing, reason: 'Visible: $texts');
      // Only the channel without any EPG mapping should show the empty row.
      expect(find.text('No program data'), findsOneWidget, reason: 'Visible: $texts');
      expect(find.text('CNN Newsroom'), findsOneWidget, reason: 'Visible: $texts');
      expect(find.text('SportsCenter'), findsOneWidget, reason: 'Visible: $texts');
      // HD, SD and the +1 (mixed-case tvg-id with tvg-shift) all get a cell.
      expect(find.text('BBC News at Six'), findsNWidgets(3), reason: 'Visible: $texts');
    });
  });
}
