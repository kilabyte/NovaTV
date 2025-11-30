import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/playlist.dart';
import '../repositories/playlist_repository.dart';

/// Use case for getting all playlists
class GetPlaylists implements UseCase<List<Playlist>, NoParams> {
  final PlaylistRepository _repository;

  GetPlaylists(this._repository);

  @override
  Future<Either<Failure, List<Playlist>>> call(NoParams params) {
    return _repository.getPlaylists();
  }
}
