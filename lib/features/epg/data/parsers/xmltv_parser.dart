import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../domain/entities/epg_channel.dart';
import '../../domain/entities/epg_data.dart';
import '../../domain/entities/program.dart';
import '../compute/xml_parse_compute.dart';

/// Parser for XMLTV EPG data format
/// Supports both plain .xml and compressed .xml.gz files
class XmltvParser {
  /// Parse XMLTV content from raw bytes (handles gzip decompression)
  Future<EpgData> parseBytes(Uint8List bytes, String sourceUrl) async {
    String content;

    // Check for gzip magic bytes
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      // Gzip compressed
      content = utf8.decode(gzip.decode(bytes));
    } else {
      // Plain XML
      content = utf8.decode(bytes);
    }

    return parse(content, sourceUrl);
  }

  /// Parse XMLTV content from a string
  /// Uses compute isolate for heavy XML parsing to prevent UI blocking
  Future<EpgData> parse(String content, String sourceUrl) async {
    // Use compute isolate for heavy XML parsing (especially for large EPG files)
    // This prevents UI freezing on Android when parsing thousands of programs
    final result = await compute(parseXmltvContent, ParseXmltvParams(content: content, sourceUrl: sourceUrl));

    // Reconstruct EpgData from JSON result
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
