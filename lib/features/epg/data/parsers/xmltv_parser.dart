import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../domain/entities/epg_channel.dart';
import '../../domain/entities/epg_data.dart';
import '../../domain/entities/program.dart';

/// Parser for XMLTV EPG data format
/// Supports both plain .xml and compressed .xml.gz files
class XmltvParser {
  /// Parse XMLTV content from raw bytes (handles gzip decompression)
  EpgData parseBytes(Uint8List bytes, String sourceUrl) {
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
  EpgData parse(String content, String sourceUrl) {
    final document = XmlDocument.parse(content);
    final tv = document.rootElement;

    if (tv.name.local != 'tv') {
      throw FormatException('Invalid XMLTV format: root element is not <tv>');
    }

    // Parse generator date if available
    DateTime? generatedAt;
    final generatorDate = tv.getAttribute('date');
    if (generatorDate != null) {
      generatedAt = _parseXmltvDate(generatorDate);
    }

    // Parse channels
    final channels = <EpgChannel>[];
    for (final channelElement in tv.findAllElements('channel')) {
      final channel = _parseChannel(channelElement);
      if (channel != null) {
        channels.add(channel);
      }
    }

    // Parse programs
    final programs = <Program>[];
    for (final programElement in tv.findAllElements('programme')) {
      final program = _parseProgram(programElement);
      if (program != null) {
        programs.add(program);
      }
    }

    return EpgData(
      sourceUrl: sourceUrl,
      generatedAt: generatedAt,
      fetchedAt: DateTime.now(),
      channels: channels,
      programs: programs,
    );
  }

  /// Parse a channel element
  EpgChannel? _parseChannel(XmlElement element) {
    final id = element.getAttribute('id');
    if (id == null || id.isEmpty) return null;

    String? displayName;
    String? iconUrl;
    String? url;

    // Get display name (can be multiple, we take the first)
    final displayNameElements = element.findAllElements('display-name');
    if (displayNameElements.isNotEmpty) {
      displayName = displayNameElements.first.innerText.trim();
    }

    // Get icon URL
    final iconElements = element.findAllElements('icon');
    if (iconElements.isNotEmpty) {
      iconUrl = iconElements.first.getAttribute('src');
    }

    // Get URL
    final urlElements = element.findAllElements('url');
    if (urlElements.isNotEmpty) {
      url = urlElements.first.innerText.trim();
    }

    return EpgChannel(
      id: id,
      displayName: displayName,
      iconUrl: iconUrl,
      url: url,
    );
  }

  /// Parse a programme element
  Program? _parseProgram(XmlElement element) {
    final channelId = element.getAttribute('channel');
    final startStr = element.getAttribute('start');
    final stopStr = element.getAttribute('stop');

    if (channelId == null || startStr == null || stopStr == null) {
      return null;
    }

    final start = _parseXmltvDate(startStr);
    final stop = _parseXmltvDate(stopStr);

    if (start == null || stop == null) return null;

    // Title (required)
    String? title;
    final titleElements = element.findAllElements('title');
    if (titleElements.isNotEmpty) {
      title = titleElements.first.innerText.trim();
    }
    if (title == null || title.isEmpty) return null;

    // Subtitle
    String? subtitle;
    final subTitleElements = element.findAllElements('sub-title');
    if (subTitleElements.isNotEmpty) {
      subtitle = subTitleElements.first.innerText.trim();
    }

    // Description
    String? description;
    final descElements = element.findAllElements('desc');
    if (descElements.isNotEmpty) {
      description = descElements.first.innerText.trim();
    }

    // Category
    String? category;
    final categoryElements = element.findAllElements('category');
    if (categoryElements.isNotEmpty) {
      category = categoryElements.first.innerText.trim();
    }

    // Icon
    String? iconUrl;
    final iconElements = element.findAllElements('icon');
    if (iconElements.isNotEmpty) {
      iconUrl = iconElements.first.getAttribute('src');
    }

    // Episode number
    String? episodeNum;
    final episodeElements = element.findAllElements('episode-num');
    for (final ep in episodeElements) {
      final system = ep.getAttribute('system');
      if (system == 'onscreen' || system == 'xmltv_ns') {
        episodeNum = ep.innerText.trim();
        break;
      }
    }
    if (episodeNum == null && episodeElements.isNotEmpty) {
      episodeNum = episodeElements.first.innerText.trim();
    }

    // Rating
    String? rating;
    final ratingElements = element.findAllElements('rating');
    if (ratingElements.isNotEmpty) {
      final valueElements = ratingElements.first.findAllElements('value');
      if (valueElements.isNotEmpty) {
        rating = valueElements.first.innerText.trim();
      }
    }

    // Flags
    bool isNew = false;
    bool isLive = false;
    bool isPremiere = false;

    if (element.findAllElements('new').isNotEmpty) {
      isNew = true;
    }
    if (element.findAllElements('live').isNotEmpty) {
      isLive = true;
    }
    if (element.findAllElements('premiere').isNotEmpty) {
      isPremiere = true;
    }

    // Generate unique ID
    final id = '${channelId}_${start.millisecondsSinceEpoch}';

    return Program(
      id: id,
      channelId: channelId,
      title: title,
      start: start,
      end: stop,
      subtitle: subtitle,
      description: description,
      category: category,
      iconUrl: iconUrl,
      episodeNum: episodeNum,
      rating: rating,
      isNew: isNew,
      isLive: isLive,
      isPremiere: isPremiere,
    );
  }

  /// Parse XMLTV date format: YYYYMMDDHHmmss +/-HHMM
  /// Examples: "20231215120000 +0000", "20231215120000", "2023121512"
  DateTime? _parseXmltvDate(String dateStr) {
    try {
      // Remove any whitespace
      dateStr = dateStr.trim();

      // Extract timezone offset if present
      String? tzOffset;
      final spaceIndex = dateStr.indexOf(' ');
      if (spaceIndex > 0) {
        tzOffset = dateStr.substring(spaceIndex + 1).trim();
        dateStr = dateStr.substring(0, spaceIndex);
      }

      // Pad to at least 14 characters (YYYYMMDDHHmmss)
      dateStr = dateStr.padRight(14, '0');

      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      final hour = int.parse(dateStr.substring(8, 10));
      final minute = int.parse(dateStr.substring(10, 12));
      final second = int.parse(dateStr.substring(12, 14));

      var dateTime = DateTime.utc(year, month, day, hour, minute, second);

      // Apply timezone offset if present
      if (tzOffset != null && tzOffset.isNotEmpty) {
        final isNegative = tzOffset.startsWith('-');
        tzOffset = tzOffset.replaceAll(RegExp(r'[+-]'), '');

        if (tzOffset.length >= 4) {
          final tzHours = int.parse(tzOffset.substring(0, 2));
          final tzMinutes = int.parse(tzOffset.substring(2, 4));
          final offset = Duration(hours: tzHours, minutes: tzMinutes);

          if (isNegative) {
            dateTime = dateTime.add(offset);
          } else {
            dateTime = dateTime.subtract(offset);
          }
        }
      }

      // Convert to local time
      return dateTime.toLocal();
    } catch (e) {
      return null;
    }
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
