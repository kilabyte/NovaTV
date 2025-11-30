import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/channel.dart';
import '../repositories/playlist_repository.dart';

/// Use case for searching channels
class SearchChannels implements UseCase<List<Channel>, String> {
  final PlaylistRepository _repository;

  SearchChannels(this._repository);

  @override
  Future<Either<Failure, List<Channel>>> call(String query) {
    return _repository.searchChannels(query);
  }
}
