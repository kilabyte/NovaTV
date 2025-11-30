import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';

/// Remote data source for fetching playlist content
abstract class PlaylistRemoteDataSource {
  /// Fetch M3U playlist content from URL
  Future<String> fetchPlaylist(String url, {Map<String, String>? headers});
}

/// Implementation of PlaylistRemoteDataSource using Dio
class PlaylistRemoteDataSourceImpl implements PlaylistRemoteDataSource {
  final Dio _dio;

  PlaylistRemoteDataSourceImpl(this._dio);

  @override
  Future<String> fetchPlaylist(String url, {Map<String, String>? headers}) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }

      throw ServerException(
        'Failed to fetch playlist',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
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
    } catch (e) {
      throw ServerException('Failed to fetch playlist: $e');
    }
  }
}
