import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/channel.dart';
import '../repositories/playlist_repository.dart';

/// Use case for getting channels by playlist
class GetChannels implements UseCase<List<Channel>, String> {
  final PlaylistRepository _repository;

  GetChannels(this._repository);

  @override
  Future<Either<Failure, List<Channel>>> call(String playlistId) {
    return _repository.getChannels(playlistId);
  }
}

/// Use case for getting all channels
class GetAllChannels implements UseCase<List<Channel>, NoParams> {
  final PlaylistRepository _repository;

  GetAllChannels(this._repository);

  @override
  Future<Either<Failure, List<Channel>>> call(NoParams params) {
    return _repository.getAllChannels();
  }
}
