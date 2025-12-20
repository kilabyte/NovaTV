import 'package:flutter/foundation.dart';

import '../../../playlist/domain/entities/channel.dart';
import '../../domain/entities/program.dart';

/// Parameters for groupProgramsByChannel compute function
class GroupProgramsParams {
  final List<Map<String, dynamic>> programsJson;
  final List<Map<String, dynamic>> channelsJson;
  final int startTimeMs;
  final int endTimeMs;

  GroupProgramsParams({required this.programsJson, required this.channelsJson, required this.startTimeMs, required this.endTimeMs});
}

/// Top-level function for grouping programs by channel using compute isolate
/// This processes heavy EPG data off the main thread to prevent UI freezing
@pragma('vm:entry-point')
Map<String, List<Map<String, dynamic>>> groupProgramsByChannel(GroupProgramsParams params) {
  final programsJson = params.programsJson;
  final channelsJson = params.channelsJson;
  final startTimeMs = params.startTimeMs;
  final endTimeMs = params.endTimeMs;

  // Reconstruct channels from JSON (for serialization)
  final channels = channelsJson.map((json) {
    return Channel(id: json['id'] as String, name: json['name'] as String, url: json['url'] as String, playlistId: json['playlistId'] as String, tvgId: json['tvgId'] as String?, tvgName: json['tvgName'] as String?, logoUrl: json['logoUrl'] as String?, group: json['group'] as String?, language: json['language'] as String?, country: json['country'] as String?, tvgShift: json['tvgShift'] as int?, userAgent: json['userAgent'] as String?, referrer: json['referrer'] as String?, headers: json['headers'] != null ? Map<String, String>.from(json['headers'] as Map) : null, licenseUrl: json['licenseUrl'] as String?, licenseType: json['licenseType'] as String?, isFavorite: json['isFavorite'] as bool? ?? false, channelNumber: json['channelNumber'] as int?, catchupType: json['catchupType'] as String?, catchupSource: json['catchupSource'] as String?, catchupDays: json['catchupDays'] as int?);
  }).toList();

  final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
  final endTime = DateTime.fromMillisecondsSinceEpoch(endTimeMs);

  // Reconstruct programs from JSON
  final programs = programsJson.map((json) {
    return Program(id: json['id'] as String, channelId: json['channelId'] as String, title: json['title'] as String, start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int), end: DateTime.fromMillisecondsSinceEpoch(json['end'] as int), subtitle: json['subtitle'] as String?, description: json['description'] as String?, category: json['category'] as String?, iconUrl: json['iconUrl'] as String?, episodeNum: json['episodeNum'] as String?, rating: json['rating'] as String?, isNew: json['isNew'] as bool? ?? false, isLive: json['isLive'] as bool? ?? false, isPremiere: json['isPremiere'] as bool? ?? false);
  }).toList();

  final map = <String, List<Map<String, dynamic>>>{};

  // Create a mapping from epgId (tvgId or id) to channelId for fast lookup
  final epgIdToChannelId = <String, String>{};
  for (final channel in channels) {
    final epgId = channel.epgId; // This is tvgId ?? id
    epgIdToChannelId[epgId] = channel.id;
    // Also map tvgId directly if it exists
    if (channel.tvgId != null && channel.tvgId != epgId) {
      epgIdToChannelId[channel.tvgId!] = channel.id;
    }
    // And map id directly
    epgIdToChannelId[channel.id] = channel.id;
  }

  // Pre-filter programs by time range for better performance
  final filteredPrograms = programs.where((p) => p.end.isAfter(startTime) && p.start.isBefore(endTime)).toList();

  // Group programs by channel ID - single pass, O(n) complexity
  for (final program in filteredPrograms) {
    // program.channelId contains the tvgId from XMLTV (or sometimes the channel id)
    // Match it using epgId mapping
    final matchedChannelId = epgIdToChannelId[program.channelId];

    if (matchedChannelId != null) {
      final list = map.putIfAbsent(matchedChannelId, () => <Map<String, dynamic>>[]);
      list.add({'id': program.id, 'channelId': program.channelId, 'title': program.title, 'start': program.start.millisecondsSinceEpoch, 'end': program.end.millisecondsSinceEpoch, 'subtitle': program.subtitle, 'description': program.description, 'category': program.category, 'iconUrl': program.iconUrl, 'episodeNum': program.episodeNum, 'rating': program.rating, 'isNew': program.isNew, 'isLive': program.isLive, 'isPremiere': program.isPremiere});
    }
  }

  // Sort programs by start time for each channel (only once, after grouping)
  for (final key in map.keys) {
    map[key]!.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
  }

  return map;
}

/// Helper to convert Channel to JSON for serialization
Map<String, dynamic> channelToJson(Channel channel) {
  return {'id': channel.id, 'name': channel.name, 'url': channel.url, 'playlistId': channel.playlistId, 'tvgId': channel.tvgId, 'tvgName': channel.tvgName, 'logoUrl': channel.logoUrl, 'group': channel.group, 'language': channel.language, 'country': channel.country, 'tvgShift': channel.tvgShift, 'userAgent': channel.userAgent, 'referrer': channel.referrer, 'headers': channel.headers, 'licenseUrl': channel.licenseUrl, 'licenseType': channel.licenseType, 'isFavorite': channel.isFavorite, 'channelNumber': channel.channelNumber, 'catchupType': channel.catchupType, 'catchupSource': channel.catchupSource, 'catchupDays': channel.catchupDays};
}
