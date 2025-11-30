import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/playlist_repository.dart';

/// Use case for deleting a playlist
class DeletePlaylist implements UseCase<void, String> {
  final PlaylistRepository _repository;

  DeletePlaylist(this._repository);

  @override
  Future<Either<Failure, void>> call(String playlistId) {
    return _repository.deletePlaylist(playlistId);
  }
}
