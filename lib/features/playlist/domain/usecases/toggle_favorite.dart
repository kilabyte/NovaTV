import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/channel.dart';
import '../repositories/playlist_repository.dart';

/// Use case for toggling channel favorite status
class ToggleFavorite implements UseCase<Channel, String> {
  final PlaylistRepository _repository;

  ToggleFavorite(this._repository);

  @override
  Future<Either<Failure, Channel>> call(String channelId) {
    return _repository.toggleFavorite(channelId);
  }
}

/// Use case for getting favorite channels
class GetFavoriteChannels implements UseCase<List<Channel>, NoParams> {
  final PlaylistRepository _repository;

  GetFavoriteChannels(this._repository);

  @override
  Future<Either<Failure, List<Channel>>> call(NoParams params) {
    return _repository.getFavoriteChannels();
  }
}
