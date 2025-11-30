import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/epg_data.dart';
import '../parsers/xmltv_parser.dart';

/// Remote data source for fetching EPG data
abstract class EpgRemoteDataSource {
  /// Fetch and parse EPG data from a URL
  /// Supports both .xml and .xml.gz formats
  Future<EpgData> fetchEpg(String url);
}

class EpgRemoteDataSourceImpl implements EpgRemoteDataSource {
  final Dio _dio;
  final XmltvParser _parser;

  EpgRemoteDataSourceImpl({
    Dio? dio,
    XmltvParser? parser,
  })  : _dio = dio ?? Dio(),
        _parser = parser ?? XmltvParser();

  @override
  Future<EpgData> fetchEpg(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5),
          headers: {
            'Accept': 'application/xml, text/xml, application/gzip, */*',
            'Accept-Encoding': 'gzip, deflate',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException(
          'Failed to fetch EPG: HTTP ${response.statusCode}',
        );
      }

      final bytes = Uint8List.fromList(response.data ?? []);
      if (bytes.isEmpty) {
        throw const NetworkException('EPG response is empty');
      }

      return _parser.parseBytes(bytes, url);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException('EPG fetch timed out');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw const NetworkException('No internet connection');
      }
      throw NetworkException('Failed to fetch EPG: ${e.message}');
    } on FormatException catch (e) {
      throw NetworkException('Invalid EPG format: ${e.message}');
    }
  }
}
