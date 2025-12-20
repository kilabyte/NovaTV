import 'package:flutter/foundation.dart';

import '../../domain/entities/channel.dart';
import '../parsers/m3u_parser.dart';

/// Parameters for M3U parsing compute function
class ParseM3UParams {
  final String content;
  final String playlistId;

  ParseM3UParams({required this.content, required this.playlistId});
}

/// Top-level function for parsing M3U content using compute isolate
/// This processes large playlists off the main thread to prevent UI freezing
@pragma('vm:entry-point')
List<Map<String, dynamic>> parseM3UContent(ParseM3UParams params) {
  final parser = M3UParser();
  final channels = parser.parse(params.content, params.playlistId);

  // Convert channels to JSON for serialization
  return channels.map((channel) {
    return {'id': channel.id, 'name': channel.name, 'url': channel.url, 'playlistId': channel.playlistId, 'tvgId': channel.tvgId, 'tvgName': channel.tvgName, 'logoUrl': channel.logoUrl, 'group': channel.group, 'language': channel.language, 'country': channel.country, 'tvgShift': channel.tvgShift, 'userAgent': channel.userAgent, 'referrer': channel.referrer, 'headers': channel.headers, 'licenseUrl': channel.licenseUrl, 'licenseType': channel.licenseType, 'isFavorite': channel.isFavorite, 'channelNumber': channel.channelNumber, 'catchupType': channel.catchupType, 'catchupSource': channel.catchupSource, 'catchupDays': channel.catchupDays};
  }).toList();
}
