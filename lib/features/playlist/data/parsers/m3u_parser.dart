import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/channel.dart';

/// Parser for M3U and M3U8 playlist files with extended attributes
class M3UParser {
  static const _uuid = Uuid();

  // EXTINF pattern: #EXTINF:duration tvg-attributes,channel-name
  static final _extinfPattern = RegExp(
    r'^#EXTINF:\s*(-?\d+)\s*(.*?),\s*(.*)$',
    multiLine: true,
  );

  // Attribute patterns for tvg-* attributes
  static final _tvgIdPattern = RegExp(r'tvg-id="([^"]*)"', caseSensitive: false);
  static final _tvgNamePattern = RegExp(r'tvg-name="([^"]*)"', caseSensitive: false);
  static final _tvgLogoPattern = RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false);
  static final _groupTitlePattern = RegExp(r'group-title="([^"]*)"', caseSensitive: false);
  static final _tvgLanguagePattern = RegExp(r'tvg-language="([^"]*)"', caseSensitive: false);
  static final _tvgCountryPattern = RegExp(r'tvg-country="([^"]*)"', caseSensitive: false);
  static final _tvgShiftPattern = RegExp(r'tvg-shift="([^"]*)"', caseSensitive: false);
  static final _tvgChnoPattern = RegExp(r'tvg-chno="([^"]*)"', caseSensitive: false);

  // Catchup patterns
  static final _catchupPattern = RegExp(r'catchup="([^"]*)"', caseSensitive: false);
  static final _catchupSourcePattern = RegExp(r'catchup-source="([^"]*)"', caseSensitive: false);
  static final _catchupDaysPattern = RegExp(r'catchup-days="([^"]*)"', caseSensitive: false);

  // KODIPROP patterns for DRM and custom properties
  static final _licenseUrlPattern = RegExp(
    r'^#KODIPROP:inputstream\.adaptive\.license_key=(.*)$',
    multiLine: true,
    caseSensitive: false,
  );
  static final _licenseTypePattern = RegExp(
    r'^#KODIPROP:inputstream\.adaptive\.license_type=(.*)$',
    multiLine: true,
    caseSensitive: false,
  );

  // URL pattern (http/https/rtsp/rtmp)
  static final _urlPattern = RegExp(
    r'^(https?|rtsp|rtmp|mms|udp)://[^\s]+$',
    multiLine: true,
    caseSensitive: false,
  );

  /// Parse M3U content and return list of channels
  ///
  /// [content] - The M3U file content as string
  /// [playlistId] - The ID of the playlist these channels belong to
  ///
  /// Throws [ParseException] if the content is not valid M3U format
  List<Channel> parse(String content, String playlistId) {
    if (content.isEmpty) {
      throw const ParseException('Empty playlist content');
    }

    // Normalize line endings
    final normalizedContent = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalizedContent.split('\n');

    if (lines.isEmpty || !lines.first.trim().startsWith('#EXTM3U')) {
      throw const ParseException('Invalid M3U format: Missing #EXTM3U header');
    }

    final channels = <Channel>[];
    String? currentExtinf;
    String? currentUserAgent;
    String? currentReferrer;
    String? currentLicenseUrl;
    String? currentLicenseType;
    String? currentExtgrp;
    final currentHeaders = <String, String>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty || line == '#EXTM3U') {
        continue;
      }

      // Parse EXTINF line
      if (line.startsWith('#EXTINF:')) {
        currentExtinf = line;
        continue;
      }

      // Parse EXTVLCOPT for user agent
      if (line.toLowerCase().startsWith('#extvlcopt:http-user-agent=')) {
        currentUserAgent = line.substring('#extvlcopt:http-user-agent='.length);
        continue;
      }

      // Parse EXTVLCOPT for referrer
      if (line.toLowerCase().startsWith('#extvlcopt:http-referrer=')) {
        currentReferrer = line.substring('#extvlcopt:http-referrer='.length);
        continue;
      }

      // Parse KODIPROP for license URL
      if (line.toLowerCase().contains('license_key=')) {
        final match = _licenseUrlPattern.firstMatch(line);
        if (match != null) {
          currentLicenseUrl = match.group(1)?.trim();
        }
        continue;
      }

      // Parse KODIPROP for license type
      if (line.toLowerCase().contains('license_type=')) {
        final match = _licenseTypePattern.firstMatch(line);
        if (match != null) {
          currentLicenseType = match.group(1)?.trim();
        }
        continue;
      }

      // Parse EXTGRP
      if (line.startsWith('#EXTGRP:')) {
        currentExtgrp = line.substring('#EXTGRP:'.length).trim();
        continue;
      }

      // Parse generic EXTVLCOPT headers
      if (line.toLowerCase().startsWith('#extvlcopt:http-') && line.contains('=')) {
        final keyValue = line.substring('#extvlcopt:http-'.length);
        final eqIndex = keyValue.indexOf('=');
        if (eqIndex > 0) {
          final key = keyValue.substring(0, eqIndex);
          final value = keyValue.substring(eqIndex + 1);
          currentHeaders[key] = value;
        }
        continue;
      }

      // Skip other directives
      if (line.startsWith('#')) {
        continue;
      }

      // Check if this is a URL line and we have an EXTINF
      if (_urlPattern.hasMatch(line) && currentExtinf != null) {
        final channel = _parseChannel(
          extinfLine: currentExtinf,
          url: line,
          playlistId: playlistId,
          userAgent: currentUserAgent,
          referrer: currentReferrer,
          licenseUrl: currentLicenseUrl,
          licenseType: currentLicenseType,
          extgrp: currentExtgrp,
          headers: currentHeaders.isNotEmpty ? Map<String, String>.from(currentHeaders) : null,
          channelIndex: channels.length,
        );

        if (channel != null) {
          channels.add(channel);
        }

        // Reset state for next channel
        currentExtinf = null;
        currentUserAgent = null;
        currentReferrer = null;
        currentLicenseUrl = null;
        currentLicenseType = null;
        currentExtgrp = null;
        currentHeaders.clear();
      }
    }

    return channels;
  }

  /// Parse a single channel from EXTINF and URL
  Channel? _parseChannel({
    required String extinfLine,
    required String url,
    required String playlistId,
    String? userAgent,
    String? referrer,
    String? licenseUrl,
    String? licenseType,
    String? extgrp,
    Map<String, String>? headers,
    required int channelIndex,
  }) {
    final match = _extinfPattern.firstMatch(extinfLine);
    if (match == null) {
      return null;
    }

    final attributes = match.group(2) ?? '';
    final name = match.group(3)?.trim() ?? 'Unknown Channel';

    // Extract tvg-id
    final tvgIdMatch = _tvgIdPattern.firstMatch(attributes);
    final tvgId = tvgIdMatch?.group(1);

    // Extract tvg-name
    final tvgNameMatch = _tvgNamePattern.firstMatch(attributes);
    final tvgName = tvgNameMatch?.group(1);

    // Extract tvg-logo
    final tvgLogoMatch = _tvgLogoPattern.firstMatch(attributes);
    final logoUrl = tvgLogoMatch?.group(1);

    // Extract group-title (or use EXTGRP)
    final groupMatch = _groupTitlePattern.firstMatch(attributes);
    final group = groupMatch?.group(1) ?? extgrp;

    // Extract tvg-language
    final languageMatch = _tvgLanguagePattern.firstMatch(attributes);
    final language = languageMatch?.group(1);

    // Extract tvg-country
    final countryMatch = _tvgCountryPattern.firstMatch(attributes);
    final country = countryMatch?.group(1);

    // Extract tvg-shift
    final shiftMatch = _tvgShiftPattern.firstMatch(attributes);
    final tvgShift = shiftMatch != null ? int.tryParse(shiftMatch.group(1) ?? '') : null;

    // Extract tvg-chno (channel number)
    final chnoMatch = _tvgChnoPattern.firstMatch(attributes);
    final channelNumber = chnoMatch != null ? int.tryParse(chnoMatch.group(1) ?? '') : null;

    // Extract catchup attributes
    final catchupMatch = _catchupPattern.firstMatch(attributes);
    final catchupType = catchupMatch?.group(1);

    final catchupSourceMatch = _catchupSourcePattern.firstMatch(attributes);
    final catchupSource = catchupSourceMatch?.group(1);

    final catchupDaysMatch = _catchupDaysPattern.firstMatch(attributes);
    final catchupDays = catchupDaysMatch != null ? int.tryParse(catchupDaysMatch.group(1) ?? '') : null;

    // Generate unique ID using UUID or tvg-id if available
    final id = tvgId?.isNotEmpty == true ? '${playlistId}_$tvgId' : '${playlistId}_${_uuid.v4()}';

    return Channel(
      id: id,
      name: name,
      url: url,
      playlistId: playlistId,
      tvgId: tvgId?.isNotEmpty == true ? tvgId : null,
      tvgName: tvgName?.isNotEmpty == true ? tvgName : null,
      logoUrl: logoUrl?.isNotEmpty == true ? logoUrl : null,
      group: group?.isNotEmpty == true ? group : null,
      language: language?.isNotEmpty == true ? language : null,
      country: country?.isNotEmpty == true ? country : null,
      tvgShift: tvgShift,
      userAgent: userAgent,
      referrer: referrer,
      headers: headers,
      licenseUrl: licenseUrl?.isNotEmpty == true ? licenseUrl : null,
      licenseType: licenseType?.isNotEmpty == true ? licenseType : null,
      channelNumber: channelNumber ?? channelIndex,
      catchupType: catchupType?.isNotEmpty == true ? catchupType : null,
      catchupSource: catchupSource?.isNotEmpty == true ? catchupSource : null,
      catchupDays: catchupDays,
    );
  }

  /// Extract x-tvg-url attribute from M3U header (EPG URL)
  String? extractEpgUrl(String content) {
    final headerLine = content.split('\n').first;
    final pattern = RegExp(r'x-tvg-url="([^"]*)"', caseSensitive: false);
    final match = pattern.firstMatch(headerLine);
    return match?.group(1);
  }

  /// Extract url-tvg attribute from M3U header (alternative EPG URL format)
  String? extractUrlTvg(String content) {
    final headerLine = content.split('\n').first;
    final pattern = RegExp(r'url-tvg="([^"]*)"', caseSensitive: false);
    final match = pattern.firstMatch(headerLine);
    return match?.group(1);
  }

  /// Get list of unique groups from channels
  List<String> extractGroups(List<Channel> channels) {
    final groups = channels
        .where((c) => c.group != null && c.group!.isNotEmpty)
        .map((c) => c.group!)
        .toSet()
        .toList();
    groups.sort();
    return groups;
  }

  /// Validate if content is valid M3U
  bool isValidM3U(String content) {
    if (content.isEmpty) return false;
    final firstLine = content.split('\n').first.trim();
    return firstLine.startsWith('#EXTM3U');
  }
}
