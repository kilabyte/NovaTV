import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/playlist.dart';
import '../repositories/playlist_repository.dart';

/// Parameters for adding a playlist
class AddPlaylistParams {
  final String name;
  final String url;
  final String? epgUrl;

  const AddPlaylistParams({
    required this.name,
    required this.url,
    this.epgUrl,
  });
}

/// Use case for adding a new playlist
class AddPlaylist implements UseCase<Playlist, AddPlaylistParams> {
  final PlaylistRepository _repository;

  AddPlaylist(this._repository);

  @override
  Future<Either<Failure, Playlist>> call(AddPlaylistParams params) {
    return _repository.addPlaylist(
      name: params.name,
      url: params.url,
      epgUrl: params.epgUrl,
    );
  }
}
