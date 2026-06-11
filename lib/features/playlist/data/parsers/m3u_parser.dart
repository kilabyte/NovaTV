import '../../../../core/error/exceptions.dart';
import '../../domain/entities/channel.dart';

/// Parser for M3U and M3U8 playlist files with extended attributes
class M3UParser {
  // EXTINF duration prefix: #EXTINF:duration, followed by attributes and name
  static final _extinfDurationPattern = RegExp(r'^#EXTINF:\s*(-?\d+(?:\.\d+)?)\s*');

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
    final usedIds = <String>{};
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

      // Parse KODIPROP for license URL / license type. Guard on the
      // #KODIPROP: prefix so stream URLs that merely contain license_key= or
      // license_type= as a query parameter are not swallowed (which silently
      // dropped the channel).
      if (line.toLowerCase().startsWith('#kodiprop:')) {
        final keyMatch = _licenseUrlPattern.firstMatch(line);
        if (keyMatch != null) {
          currentLicenseUrl = keyMatch.group(1)?.trim();
          continue;
        }
        final typeMatch = _licenseTypePattern.firstMatch(line);
        if (typeMatch != null) {
          currentLicenseType = typeMatch.group(1)?.trim();
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
          usedIds: usedIds,
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
    required Set<String> usedIds,
  }) {
    final durationMatch = _extinfDurationPattern.firstMatch(extinfLine);
    if (durationMatch == null) {
      return null;
    }

    // Split attributes from the display name at the first comma OUTSIDE
    // double quotes. Quoted attribute values commonly contain commas
    // (group-title="USA, News"), so a naive first-comma split corrupts both
    // the attributes and the name. The display name is everything after the
    // comma that follows the last attribute.
    final rest = extinfLine.substring(durationMatch.end);
    var splitIndex = -1;
    var inQuotes = false;
    for (var i = 0; i < rest.length; i++) {
      final char = rest[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        splitIndex = i;
        break;
      }
    }
    if (splitIndex < 0) {
      return null;
    }

    final attributes = rest.substring(0, splitIndex);
    final rawName = rest.substring(splitIndex + 1).trim();
    final name = rawName.isNotEmpty ? rawName : 'Unknown Channel';

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

    // Generate a stable, content-derived ID. Positional indexes shift when
    // the provider adds/removes/reorders channels upstream, which corrupted
    // the persisted recently-watched list across refreshes. tvgId/name/group
    // are included as tiebreakers because tvg-id can repeat across groups.
    final baseId = stableChannelId(playlistId: playlistId, url: url, tvgId: tvgId, name: name, group: group);
    var id = baseId;
    var bump = 1;
    // Identical duplicate entries (same URL and metadata) get a positional
    // suffix in file order so IDs stay unique within the playlist.
    while (!usedIds.add(id)) {
      id = '${baseId}_${bump++}';
    }

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

  /// Stable, content-derived base channel ID (without the duplicate suffix).
  /// Shared by the parser and the one-time legacy-ID re-key migration
  /// (ChannelIdMigration) so the two derivations cannot drift. Empty-string
  /// and null tvgId/group hash identically, matching how stored records
  /// null out empty attributes.
  static String stableChannelId({required String playlistId, required String url, String? tvgId, required String name, String? group}) {
    return '${playlistId}_${_stableHash('$url|${tvgId ?? ''}|$name|${group ?? ''}')}';
  }

  /// FNV-1a hash, hex-encoded. Used instead of String.hashCode because the
  /// resulting channel IDs are persisted (recently watched) and must stay
  /// stable across app launches and Dart versions.
  static String _stableHash(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    return (hash & 0x7fffffffffffffff).toRadixString(16);
  }

  /// First line of [content] without materializing a full line split of a
  /// potentially tens-of-MB playlist string.
  static String _firstLine(String content) {
    final newlineIndex = content.indexOf('\n');
    final line = newlineIndex < 0 ? content : content.substring(0, newlineIndex);
    return line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
  }

  /// Extract x-tvg-url attribute from M3U header (EPG URL)
  String? extractEpgUrl(String content) {
    final headerLine = _firstLine(content);
    final pattern = RegExp(r'x-tvg-url="([^"]*)"', caseSensitive: false);
    final match = pattern.firstMatch(headerLine);
    return match?.group(1);
  }

  /// Extract url-tvg attribute from M3U header (alternative EPG URL format)
  String? extractUrlTvg(String content) {
    final headerLine = _firstLine(content);
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
    return _firstLine(content).trim().startsWith('#EXTM3U');
  }
}
