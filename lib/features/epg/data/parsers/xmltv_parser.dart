import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../domain/entities/epg_channel.dart';
import '../../domain/entities/epg_data.dart';
import '../../domain/entities/program.dart';
import '../compute/xml_parse_compute.dart';

/// Parser for XMLTV EPG data format
/// Supports both plain .xml and compressed .xml.gz files
class XmltvParser {
  /// Parse XMLTV content from a file on disk (handles gzip decompression).
  /// Only the path crosses the isolate boundary: the compute isolate reads,
  /// gunzips and decodes the file itself, so the main isolate never holds
  /// the raw feed or the decompressed string (hundreds of MB for real
  /// provider feeds).
  Future<EpgData> parseFile(String filePath, String sourceUrl) async {
    final result = await compute(parseXmltvContent, ParseXmltvParams(filePath: filePath, sourceUrl: sourceUrl));
    return _epgDataFromResult(result);
  }

  /// Parse XMLTV content from raw bytes already in memory (handles gzip
  /// decompression inside the compute isolate). Prefer [parseFile] for
  /// downloads so the full feed never lives on the main isolate.
  Future<EpgData> parseBytes(Uint8List bytes, String sourceUrl) async {
    final result = await compute(parseXmltvContent, ParseXmltvParams(bytes: bytes, sourceUrl: sourceUrl));
    return _epgDataFromResult(result);
  }

  /// Parse XMLTV content from a string
  /// Uses compute isolate for heavy XML parsing to prevent UI blocking
  Future<EpgData> parse(String content, String sourceUrl) async {
    // Use compute isolate for heavy XML parsing (especially for large EPG files)
    // This prevents UI freezing on Android when parsing thousands of programs
    final result = await compute(parseXmltvContent, ParseXmltvParams(content: content, sourceUrl: sourceUrl));
    return _epgDataFromResult(result);
  }

  /// Reconstruct EpgData from the compute isolate's JSON result
  EpgData _epgDataFromResult(Map<String, dynamic> result) {
    final channels = (result['channels'] as List).map((json) {
      return EpgChannel(id: json['id'] as String, displayName: json['displayName'] as String?, iconUrl: json['iconUrl'] as String?, url: json['url'] as String?);
    }).toList();

    final programs = (result['programs'] as List).map((json) {
      return Program(id: json['id'] as String, channelId: json['channelId'] as String, title: json['title'] as String, start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int), end: DateTime.fromMillisecondsSinceEpoch(json['end'] as int), subtitle: json['subtitle'] as String?, description: json['description'] as String?, category: json['category'] as String?, iconUrl: json['iconUrl'] as String?, episodeNum: json['episodeNum'] as String?, rating: json['rating'] as String?, isNew: json['isNew'] as bool? ?? false, isLive: json['isLive'] as bool? ?? false, isPremiere: json['isPremiere'] as bool? ?? false);
    }).toList();

    return EpgData(sourceUrl: result['sourceUrl'] as String, generatedAt: result['generatedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(result['generatedAt'] as int) : null, fetchedAt: DateTime.fromMillisecondsSinceEpoch(result['fetchedAt'] as int), channels: channels, programs: programs);
  }

  /// Check if content appears to be valid XMLTV
  bool isValidXmltv(String content) {
    try {
      final document = XmlDocument.parse(content);
      return document.rootElement.name.local == 'tv';
    } catch (_) {
      return false;
    }
  }
}
