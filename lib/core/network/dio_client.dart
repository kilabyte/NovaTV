import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';
import '../utils/app_logger.dart';

/// Configured Dio HTTP client for the application
class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: AppConstants.httpTimeout),
        receiveTimeout: const Duration(seconds: AppConstants.httpTimeout),
        sendTimeout: const Duration(seconds: AppConstants.httpTimeout),
        headers: {
          'Accept': '*/*',
        },
      ),
    );

    // Add logging interceptor in debug mode
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: false,
        responseHeader: true,
        responseBody: false,
        error: true,
        logPrint: (object) => AppLogger.debug(object),
      ),
    );
  }

  /// GET request
  Future<Response<T>> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.get<T>(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: headers,
          responseType: responseType,
        ),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// POST request
  Future<Response<T>> post<T>(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      return await _dio.post<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Download file with progress
  Future<Response> download(
    String url,
    String savePath, {
    Map<String, dynamic>? headers,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    try {
      return await _dio.download(
        url,
        savePath,
        options: Options(headers: headers),
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get raw bytes from URL
  Future<List<int>> getBytes(
    String url, {
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
        ),
      );
      return response.data ?? [];
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  /// Get string content from URL
  Future<String> getString(
    String url, {
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );
      return response.data ?? '';
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  AppException _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException('Connection timeout');
      case DioExceptionType.connectionError:
        return const NetworkException('Connection error');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.statusMessage ?? 'Server error';
        return ServerException(message, statusCode: statusCode);
      case DioExceptionType.cancel:
        return const ServerException('Request cancelled');
      default:
        return ServerException(e.message ?? 'Unknown error');
    }
  }
}
