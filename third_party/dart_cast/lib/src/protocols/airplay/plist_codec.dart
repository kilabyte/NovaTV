/// Parses Apple XML plist format used in AirPlay responses.
///
/// Supports the subset needed for AirPlay: `<real>`, `<integer>`,
/// `<string>`, `<true/>`, `<false/>`, `<dict>`, and `<array>`.
class PlistCodec {
  PlistCodec._();

  /// Parses an XML plist string into a [Map<String, dynamic>].
  ///
  /// Returns an empty map if the input is empty, malformed, or does not
  /// contain a top-level `<dict>`.
  static Map<String, dynamic> parseXmlPlist(String xml) {
    if (xml.isEmpty) return {};

    try {
      final dictMatch = RegExp(
        r'<plist[^>]*>\s*<dict>(.*)</dict>\s*</plist>',
        dotAll: true,
      ).firstMatch(xml);
      if (dictMatch == null) return {};

      return _parseDict(dictMatch.group(1)!);
    } catch (_) {
      return {};
    }
  }

  /// Parses the inner content of a `<dict>` element into a map.
  static Map<String, dynamic> _parseDict(String content) {
    final result = <String, dynamic>{};
    final tokens = _tokenize(content);

    int i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      if (token.tag == 'key') {
        if (i + 1 < tokens.length) {
          result[token.value!] = _tokenValue(tokens, i + 1);
          // Skip past the value token(s)
          i = _skipValue(tokens, i + 1) + 1;
        } else {
          i++;
        }
      } else {
        i++;
      }
    }

    return result;
  }

  /// Extracts the Dart value from a token at the given index.
  static dynamic _tokenValue(List<_Token> tokens, int index) {
    if (index >= tokens.length) return null;
    final token = tokens[index];

    switch (token.tag) {
      case 'real':
        return double.tryParse(token.value ?? '') ?? 0.0;
      case 'integer':
        return int.tryParse(token.value ?? '') ?? 0;
      case 'string':
        return token.value ?? '';
      case 'true':
        return true;
      case 'false':
        return false;
      case 'dict':
        return _parseDict(token.value ?? '');
      case 'array':
        return _parseArray(token.value ?? '');
      default:
        return null;
    }
  }

  /// Returns the index of the last token consumed by the value at [index].
  static int _skipValue(List<_Token> tokens, int index) {
    // All value tokens are single tokens in our tokenizer.
    return index;
  }

  /// Parses the inner content of an `<array>` element into a list.
  static List<dynamic> _parseArray(String content) {
    final items = <dynamic>[];
    final tokens = _tokenize(content);

    int i = 0;
    while (i < tokens.length) {
      items.add(_tokenValue(tokens, i));
      i++;
    }

    return items;
  }

  /// Tokenizes plist XML content into a flat list of [_Token]s.
  ///
  /// Handles self-closing tags (`<true/>`, `<false/>`), simple value tags
  /// (`<real>...</real>`), and block tags (`<dict>...</dict>`, `<array>...</array>`).
  static List<_Token> _tokenize(String content) {
    final tokens = <_Token>[];
    int pos = 0;
    while (pos < content.length) {
      // Skip whitespace
      while (pos < content.length && _isWhitespace(content[pos])) {
        pos++;
      }
      if (pos >= content.length) break;

      if (content[pos] != '<') {
        pos++;
        continue;
      }

      // Self-closing boolean tags
      final boolMatch = RegExp(
        r'<(true|false)\s*/>',
      ).matchAsPrefix(content, pos);
      if (boolMatch != null) {
        tokens.add(_Token(boolMatch.group(1)!, null));
        pos = boolMatch.end;
        continue;
      }

      // Simple value tags: key, real, integer, string
      final simpleMatch = RegExp(
        r'<(key|real|integer|string)>(.*?)</\1>',
        dotAll: true,
      ).matchAsPrefix(content, pos);
      if (simpleMatch != null) {
        tokens.add(_Token(simpleMatch.group(1)!, simpleMatch.group(2)!));
        pos = simpleMatch.end;
        continue;
      }

      // Block tags: dict, array — need to find matching close tag
      final blockOpen = RegExp(r'<(dict|array)>').matchAsPrefix(content, pos);
      if (blockOpen != null) {
        final tag = blockOpen.group(1)!;
        final innerStart = blockOpen.end;
        final closeIndex = _findMatchingClose(content, innerStart, tag);
        if (closeIndex != -1) {
          final inner = content.substring(innerStart, closeIndex);
          tokens.add(_Token(tag, inner));
          pos = closeIndex + '</$tag>'.length;
          continue;
        }
      }

      // Skip unrecognized content
      pos++;
    }

    return tokens;
  }

  /// Finds the index of the matching `</tag>` for a given open tag,
  /// handling nesting.
  static int _findMatchingClose(String content, int start, String tag) {
    final openTag = '<$tag>';
    final closeTag = '</$tag>';
    int depth = 1;
    int pos = start;

    while (pos < content.length && depth > 0) {
      final nextOpen = content.indexOf(openTag, pos);
      final nextClose = content.indexOf(closeTag, pos);

      if (nextClose == -1) return -1;

      if (nextOpen != -1 && nextOpen < nextClose) {
        depth++;
        pos = nextOpen + openTag.length;
      } else {
        depth--;
        if (depth == 0) return nextClose;
        pos = nextClose + closeTag.length;
      }
    }

    return -1;
  }

  static bool _isWhitespace(String ch) =>
      ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';

  /// Parses an AirPlay `/playback-info` XML plist response.
  static PlaybackInfo parsePlaybackInfo(String xml) {
    final map = parseXmlPlist(xml);
    return PlaybackInfo(
      duration: (map['duration'] as num?)?.toDouble() ?? 0.0,
      position: (map['position'] as num?)?.toDouble() ?? 0.0,
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      readyToPlay: map['readyToPlay'] as bool? ?? false,
      playbackBufferEmpty: map['playbackBufferEmpty'] as bool? ?? false,
      playbackLikelyToKeepUp: map['playbackLikelyToKeepUp'] as bool? ?? false,
    );
  }

  /// Parses an AirPlay `/server-info` XML plist response.
  static ServerInfo parseServerInfo(String xml) {
    final map = parseXmlPlist(xml);
    return ServerInfo(
      deviceId: map['deviceid'] as String? ?? '',
      features: (map['features'] as int?) ?? 0,
      model: map['model'] as String? ?? '',
    );
  }
}

/// Parsed AirPlay playback info.
class PlaybackInfo {
  /// Total media duration in seconds.
  final double duration;

  /// Current playback position in seconds.
  final double position;

  /// Playback rate (0.0 = paused, 1.0 = playing).
  final double rate;

  /// Whether the device has buffered enough to begin playback.
  final bool readyToPlay;

  /// Whether the playback buffer has run dry.
  final bool playbackBufferEmpty;

  /// Whether buffering is sufficient for smooth playback.
  final bool playbackLikelyToKeepUp;

  const PlaybackInfo({
    required this.duration,
    required this.position,
    required this.rate,
    required this.readyToPlay,
    required this.playbackBufferEmpty,
    required this.playbackLikelyToKeepUp,
  });

  @override
  String toString() =>
      'PlaybackInfo(duration: $duration, position: $position, rate: $rate, '
      'readyToPlay: $readyToPlay)';
}

/// Parsed AirPlay server info.
class ServerInfo {
  /// Device MAC address / identifier.
  final String deviceId;

  /// Feature bitmask.
  final int features;

  /// Hardware model identifier (e.g. "AppleTV3,2").
  final String model;

  const ServerInfo({
    required this.deviceId,
    required this.features,
    required this.model,
  });

  @override
  String toString() =>
      'ServerInfo(deviceId: $deviceId, features: $features, model: $model)';
}

/// Internal token representation for plist parsing.
class _Token {
  final String tag;
  final String? value;

  const _Token(this.tag, this.value);
}
