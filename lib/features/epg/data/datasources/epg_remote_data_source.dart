import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/epg_data.dart';
import '../parsers/xmltv_parser.dart';

/// Remote data source for fetching EPG data
abstract class EpgRemoteDataSource {
  /// Fetch and parse EPG data from a URL
  /// Supports both .xml and .xml.gz formats
  /// Pass [cancelToken] to allow aborting an in-flight download (e.g. when
  /// the playlist is deleted or the app is backgrounded).
  Future<EpgData> fetchEpg(String url, {CancelToken? cancelToken});
}

class EpgRemoteDataSourceImpl implements EpgRemoteDataSource {
  /// Overall deadline for the whole download. Dio's receiveTimeout only
  /// bounds the gap between chunks, so a server trickling bytes would
  /// otherwise keep the request alive indefinitely.
  static const Duration _overallDeadline = Duration(minutes: 15);

  final Dio _dio;
  final XmltvParser _parser;

  EpgRemoteDataSourceImpl({Dio? dio, XmltvParser? parser}) : _dio = dio ?? Dio(), _parser = parser ?? XmltvParser();

  @override
  Future<EpgData> fetchEpg(String url, {CancelToken? cancelToken}) async {
    final token = cancelToken ?? CancelToken();
    // Stream the (possibly gzipped) response to a temp file chunk by chunk
    // instead of buffering it with ResponseType.bytes: main-isolate memory
    // during an EPG refresh stays at chunk size, never the full feed. The
    // compute isolate then reads and decodes the file itself.
    final tempDir = await Directory.systemTemp.createTemp('novatv_epg_');
    final tempFile = File('${tempDir.path}${Platform.pathSeparator}epg.dat');
    try {
      final response = await _dio
          .download(
            url,
            tempFile.path,
            options: Options(receiveTimeout: const Duration(minutes: 5), headers: {'Accept': 'application/xml, text/xml, application/gzip, */*', 'Accept-Encoding': 'gzip, deflate'}),
            cancelToken: token,
          )
          .timeout(_overallDeadline, onTimeout: () {
            token.cancel('EPG download exceeded ${_overallDeadline.inMinutes} minute deadline');
            throw const NetworkException('EPG fetch timed out');
          });

      if (response.statusCode != 200) {
        throw NetworkException('Failed to fetch EPG: HTTP ${response.statusCode}');
      }

      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw const NetworkException('EPG response is empty');
      }

      // Gzip detection, encoding-declaration handling and XML parsing all
      // happen inside the compute isolate, which reads the file itself.
      return await _parser.parseFile(tempFile.path, url);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const NetworkException('EPG fetch cancelled');
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException('EPG fetch timed out');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw const NetworkException('No internet connection');
      }
      throw NetworkException('Failed to fetch EPG: ${e.message}');
    } on FormatException catch (e) {
      throw NetworkException('Invalid EPG format: ${e.message}');
    } finally {
      // Always remove the temp file, including on error, timeout and cancel.
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
