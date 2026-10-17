import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';
import 'package:novaiptv/features/epg/data/datasources/epg_local_data_source.dart';
import 'package:novaiptv/features/epg/data/datasources/epg_remote_data_source.dart';
import 'package:novaiptv/features/epg/data/parsers/xmltv_parser.dart';
import 'package:novaiptv/features/epg/data/repositories/epg_repository_impl.dart';
import 'package:novaiptv/features/epg/domain/entities/epg_data.dart';
import 'package:novaiptv/features/playlist/data/datasources/playlist_local_data_source.dart';
import 'package:novaiptv/features/playlist/data/datasources/playlist_remote_data_source.dart';
import 'package:novaiptv/features/playlist/data/parsers/m3u_parser.dart';
import 'package:novaiptv/features/playlist/data/repositories/playlist_repository_impl.dart';
import 'package:novaiptv/hive_registrar.g.dart';

/// Shared fixture plumbing for populated-data tests: a real M3U and a real
/// XMLTV document go through the production repositories (remote fetch
/// stubbed with the fixture text), so parsing, entity mapping, playlist +
/// channel persistence and EPG persistence are exactly the on-device
/// "add playlist, then refresh EPG" path.
String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// XMLTV timestamps relative to [now] so "currently airing" logic is stable.
String xmltvStamp(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)} +0000';
}

String populatedM3u() => _fixture('populated_playlist.m3u');

String populatedXmltv(DateTime now) {
  return _fixture('populated_epg.xml')
      .replaceAll('__NOW_MINUS_30__', xmltvStamp(now.subtract(const Duration(minutes: 30))))
      .replaceAll('__NOW_PLUS_30__', xmltvStamp(now.add(const Duration(minutes: 30))))
      .replaceAll('__NOW_PLUS_90__', xmltvStamp(now.add(const Duration(minutes: 90))));
}

/// Serves the M3U fixture instead of hitting the network.
class FixturePlaylistRemoteSource implements PlaylistRemoteDataSource {
  @override
  Future<String> fetchPlaylist(String url, {Map<String, String>? headers, CancelToken? cancelToken}) async => populatedM3u();
}

/// Serves the XMLTV fixture through the production parser instead of the
/// network.
class FixtureEpgRemoteSource implements EpgRemoteDataSource {
  final DateTime now;
  FixtureEpgRemoteSource(this.now);

  @override
  Future<EpgData> fetchEpg(String url, {CancelToken? cancelToken}) => XmltvParser().parse(populatedXmltv(now), url);
}

/// Initialise Hive in a fresh temp dir with every production adapter.
Future<Directory> initTestHive() async {
  final dir = await Directory.systemTemp.createTemp('novatv_populated_test_');
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapters();
  }
  return dir;
}

Future<void> disposeTestHive(Directory dir) async {
  await Hive.close();
  await Hive.deleteFromDisk();
  try {
    await dir.delete(recursive: true);
  } catch (_) {}
}

/// Add the fixture playlist and store its EPG through the production
/// repositories. Returns the generated playlist id.
Future<String> persistPopulatedFixture(DateTime now) async {
  final playlistRepo = PlaylistRepositoryImpl(
    localDataSource: PlaylistLocalDataSourceImpl(),
    remoteDataSource: FixturePlaylistRemoteSource(),
    m3uParser: M3UParser(),
  );
  final added = await playlistRepo.addPlaylist(name: 'Fixture', url: 'http://example.com/list.m3u');
  final playlist = added.fold((failure) => throw StateError('addPlaylist failed: ${failure.message}'), (p) => p);
  if (playlist.epgUrl == null || playlist.epgUrl!.isEmpty) {
    throw StateError('fixture header should carry an x-tvg-url');
  }

  final epgRepo = EpgRepositoryImpl(localDataSource: EpgLocalDataSourceImpl(), remoteDataSource: FixtureEpgRemoteSource(now));
  final stored = await epgRepo.fetchAndStoreEpg(playlist.id, playlist.epgUrl!);
  stored.fold((failure) => throw StateError('fetchAndStoreEpg failed: ${failure.message}'), (_) {});
  return playlist.id;
}

/// Close every open box so the next open re-reads from disk, like a relaunch.
Future<void> simulateRelaunch() async {
  await Hive.close();
}
