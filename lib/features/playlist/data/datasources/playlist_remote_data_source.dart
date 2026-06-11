import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';

/// Remote data source for fetching playlist content
abstract class PlaylistRemoteDataSource {
  /// Fetch M3U playlist content from URL.
  /// Pass [cancelToken] to allow aborting an in-flight download (e.g. when
  /// the playlist is deleted mid-refresh).
  Future<String> fetchPlaylist(String url, {Map<String, String>? headers, CancelToken? cancelToken});
}

/// Implementation of PlaylistRemoteDataSource using Dio
class PlaylistRemoteDataSourceImpl implements PlaylistRemoteDataSource {
  /// Overall deadline for the whole download. The connect/receive timeouts
  /// below only bound connection setup and the gap between chunks, so a
  /// server trickling bytes would otherwise keep the request alive forever.
  static const Duration _overallDeadline = Duration(minutes: 10);

  final Dio _dio;

  PlaylistRemoteDataSourceImpl(this._dio);

  @override
  Future<String> fetchPlaylist(String url, {Map<String, String>? headers, CancelToken? cancelToken}) async {
    final token = cancelToken ?? CancelToken();
    try {
      final response = await _dio
          .get<String>(
            url,
            options: Options(
              headers: headers,
              responseType: ResponseType.plain,
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 30),
            ),
            cancelToken: token,
          )
          .timeout(_overallDeadline, onTimeout: () {
            token.cancel('Playlist download exceeded ${_overallDeadline.inMinutes} minute deadline');
            throw const ServerException('Connection timeout while fetching playlist');
          });

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }

      throw ServerException(
        'Failed to fetch playlist',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const RequestCancelledException('Playlist download cancelled');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw const ServerException('Connection timeout while fetching playlist');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }
      throw ServerException(
        'Failed to fetch playlist: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } on ServerException {
      // The non-200 throw above is already a ServerException; re-wrapping it
      // would discard its status code and double the message.
      rethrow;
    } on RequestCancelledException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch playlist: $e');
    }
  }
}
