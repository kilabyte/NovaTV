import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:novaiptv/core/error/failures.dart';
import 'package:novaiptv/features/epg/domain/entities/epg_data.dart';
import 'package:novaiptv/features/epg/domain/repositories/epg_repository.dart';
import 'package:novaiptv/features/epg/presentation/providers/epg_providers.dart';

/// Hand-rolled fake: only fetchAndStoreEpg matters here. Each call hands the
/// test a completer so it can resolve the "download" at the exact moment the
/// scenario needs (mid-flight cancel, deleted playlist, hard failure).
class _FakeEpgRepository implements EpgRepository {
  final Map<String, Completer<Either<Failure, EpgData>>> pending = {};
  final Map<String, CancelToken?> tokens = {};

  @override
  Future<Either<Failure, EpgData>> fetchAndStoreEpg(String playlistId, String url, {CancelToken? cancelToken}) {
    tokens[playlistId] = cancelToken;
    final completer = Completer<Either<Failure, EpgData>>();
    pending[playlistId] = completer;
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName} not stubbed');
}

EpgData _emptyEpgData() => EpgData(sourceUrl: 'http://x/epg.xml', fetchedAt: DateTime.now(), channels: const [], programs: const []);

void main() {
  late _FakeEpgRepository repository;
  late EpgRefreshNotifier notifier;

  setUp(() {
    repository = _FakeEpgRepository();
    notifier = EpgRefreshNotifier(repository);
  });

  tearDown(() {
    notifier.dispose();
  });

  test('successful refresh resolves the batch to data and returns true', () async {
    final future = notifier.refreshEpg('pl1', 'http://x/epg.xml');
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.isLoading, isTrue);

    repository.pending['pl1']!.complete(Right(_emptyEpgData()));

    expect(await future, isTrue);
    expect(notifier.state, const AsyncValue<void>.data(null));
  });

  test('cancel mid-flight resolves silently: no stranded loading state, no error, returns true', () async {
    final future = notifier.refreshEpg('pl1', 'http://x/epg.xml');
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.isLoading, isTrue);

    notifier.cancelRefresh('pl1');
    expect(repository.tokens['pl1']!.isCancelled, isTrue);
    // The data source surfaces a cancelled download as a failure result.
    repository.pending['pl1']!.complete(const Left(NetworkFailure('EPG fetch cancelled')));

    expect(await future, isTrue);
    expect(notifier.state.isLoading, isFalse, reason: 'a cancelled refresh must not strand the refresh toast in loading');
    expect(notifier.state.hasError, isFalse);
  });

  test('playlist deleted before the refresh started (CancelledFailure, token never cancelled) is dropped silently', () async {
    final future = notifier.refreshEpg('pl1', 'http://x/epg.xml');
    await Future<void>.delayed(Duration.zero);

    // Token is NOT cancelled: the delete happened before this refresh began,
    // so only the repository's existence re-check catches it.
    expect(repository.tokens['pl1']!.isCancelled, isFalse);
    repository.pending['pl1']!.complete(const Left(CancelledFailure('Playlist pl1 was deleted during EPG refresh; discarding fetched data')));

    expect(await future, isTrue);
    expect(notifier.state.hasError, isFalse, reason: 'deleting a playlist must not produce an EPG error toast');
    expect(notifier.state.isLoading, isFalse);
  });

  test('a real failure still surfaces as batch error state and returns false', () async {
    final future = notifier.refreshEpg('pl1', 'http://x/epg.xml');
    await Future<void>.delayed(Duration.zero);

    repository.pending['pl1']!.complete(const Left(NetworkFailure('server exploded')));

    expect(await future, isFalse);
    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.error.toString(), contains('server exploded'));
  });

  test('cancellation of one playlist does not mask another playlist\'s real failure in the same batch', () async {
    final future1 = notifier.refreshEpg('pl1', 'http://x/epg1.xml');
    final future2 = notifier.refreshEpg('pl2', 'http://x/epg2.xml');
    await Future<void>.delayed(Duration.zero);

    notifier.cancelRefresh('pl1');
    repository.pending['pl1']!.complete(const Left(NetworkFailure('EPG fetch cancelled')));
    repository.pending['pl2']!.complete(const Left(NetworkFailure('server exploded')));

    expect(await future1, isTrue);
    expect(await future2, isFalse);
    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.error.toString(), contains('server exploded'));
  });

  test('concurrent refreshes for the same playlist dedupe onto one in-flight download', () async {
    final future1 = notifier.refreshEpg('pl1', 'http://x/epg.xml');
    final future2 = notifier.refreshEpg('pl1', 'http://x/epg.xml');
    expect(identical(future1, future2), isTrue);
    await Future<void>.delayed(Duration.zero);

    repository.pending['pl1']!.complete(Right(_emptyEpgData()));
    expect(await future1, isTrue);
  });
}
