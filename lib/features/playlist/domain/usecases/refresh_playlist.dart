import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/playlist.dart';
import '../repositories/playlist_repository.dart';

/// Use case for refreshing a playlist
class RefreshPlaylist implements UseCase<Playlist, String> {
  final PlaylistRepository _repository;

  RefreshPlaylist(this._repository);

  @override
  Future<Either<Failure, Playlist>> call(String playlistId) {
    return _repository.refreshPlaylist(playlistId);
  }
}
