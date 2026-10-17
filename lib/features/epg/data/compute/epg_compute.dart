import '../../../playlist/domain/entities/channel.dart';
import '../../domain/entities/program.dart';
import '../parsers/sports_event_name_parser.dart';

/// Arguments for [groupProgramsForGuide]. Entities are plain immutable Dart
/// objects, so they cross the compute-isolate boundary as-is with no JSON
/// round-trip on the main isolate.
class GuideGroupArgs {
  final List<Program> programs;
  final List<Channel> channels;
  final DateTime startTime;
  final DateTime endTime;

  /// Opt-in: for channels that end up with no EPG programmes, parse a
  /// kickoff out of the channel name (see [SportsEventNameParser]) and add a
  /// single synthetic cell. Off by default; never overrides real EPG data.
  final bool synthesizeSportsEvents;

  /// Anchor for resolving the year of a "MM.DD" kickoff. The guide passes
  /// the current time; tests pass a fixed date. Falls back to the grid start.
  final DateTime? synthesisReference;

  const GuideGroupArgs({
    required this.programs,
    required this.channels,
    required this.startTime,
    required this.endTime,
    this.synthesizeSportsEvents = false,
    this.synthesisReference,
  });
}

/// Prefix of ids for programmes synthesized from channel names, so callers
/// can tell them apart from feed data.
const String syntheticSportsProgramIdPrefix = 'synthetic-sports:';

/// Group programs by channel id for the TV Guide grid. Top-level so it can
/// run in a compute isolate; also used directly for small datasets.
///
/// Three behaviors that a naive grouping gets wrong:
/// - The epg-id mapping is one-to-many: playlists routinely list HD/SD/FHD
///   variants sharing one tvg-id, and a last-writer-wins map left every
///   sibling variant with an empty guide row.
/// - tvg-shift is applied per channel: timeshifted +1/+2 variants reuse the
///   base channel's EPG with programme times offset by the shift amount, so
///   range-filtering happens after the shift.
/// - Matching is case-insensitive. Providers routinely disagree on tvg-id
///   casing between the M3U ("BBC.One") and the XMLTV feed ("bbc.one");
///   every Hive read path (program indexes, the current-programs map behind
///   the channel list and favorites) already lowercases, so the guide must
///   too or those rows render "No program data" while the list shows the
///   airing show.
@pragma('vm:entry-point')
Map<String, List<Program>> groupProgramsForGuide(GuideGroupArgs args) {
  final epgIdToChannelIds = <String, List<String>>{};
  final shiftByChannelId = <String, int>{};

  void register(String key, String channelId) {
    final ids = epgIdToChannelIds.putIfAbsent(key.toLowerCase(), () => <String>[]);
    if (!ids.contains(channelId)) ids.add(channelId);
  }

  for (final channel in args.channels) {
    shiftByChannelId[channel.id] = channel.tvgShift ?? 0;
    register(channel.epgId, channel.id); // epgId is tvgId ?? id
    if (channel.tvgId != null && channel.tvgId != channel.epgId) {
      register(channel.tvgId!, channel.id);
    }
    register(channel.id, channel.id);
  }

  final map = <String, List<Program>>{};
  for (final program in args.programs) {
    // program.channelId contains the tvgId from XMLTV (or sometimes the
    // channel id).
    final channelIds = epgIdToChannelIds[program.channelId.toLowerCase()];
    if (channelIds == null) continue;

    for (final channelId in channelIds) {
      final shift = shiftByChannelId[channelId] ?? 0;
      final shifted = shift == 0
          ? program
          : program.copyWith(
              start: program.start.add(Duration(hours: shift)),
              end: program.end.add(Duration(hours: shift)),
            );
      if (!shifted.end.isAfter(args.startTime) || !shifted.start.isBefore(args.endTime)) continue;
      map.putIfAbsent(channelId, () => <Program>[]).add(shifted);
    }
  }

  if (args.synthesizeSportsEvents) {
    final parser = SportsEventNameParser();
    final reference = args.synthesisReference ?? args.startTime;
    for (final channel in args.channels) {
      // Real EPG wins: any feed programme for this channel inside the grid
      // window suppresses synthesis. (Feed listings outside the window do
      // not count, so a channel whose feed ends early can still get a cell.)
      if (map[channel.id]?.isNotEmpty ?? false) continue;
      final info = parser.parse(channel.name, reference: reference);
      if (info == null || !info.hasKickoff) continue; // unparsable or "No Event"
      final start = info.start!;
      final end = info.end!;
      if (!end.isAfter(args.startTime) || !start.isBefore(args.endTime)) continue;
      map[channel.id] = [
        Program(
          id: '$syntheticSportsProgramIdPrefix${channel.id}',
          channelId: channel.id,
          title: info.title,
          start: start,
          end: end,
          category: info.league,
          description: 'Kickoff time taken from the channel name (${info.zone}); the EPG feed has no listing for this channel.',
          isLive: true,
        ),
      ];
    }
  }

  // Sort programs by start time for each channel
  for (final list in map.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }

  return map;
}
