import '../../../playlist/domain/entities/channel.dart';
import '../../domain/entities/program.dart';

/// Arguments for [groupProgramsForGuide]. Entities are plain immutable Dart
/// objects, so they cross the compute-isolate boundary as-is with no JSON
/// round-trip on the main isolate.
class GuideGroupArgs {
  final List<Program> programs;
  final List<Channel> channels;
  final DateTime startTime;
  final DateTime endTime;

  const GuideGroupArgs({required this.programs, required this.channels, required this.startTime, required this.endTime});
}

/// Group programs by channel id for the TV Guide grid. Top-level so it can
/// run in a compute isolate; also used directly for small datasets.
///
/// Two behaviors that a naive grouping gets wrong:
/// - The epg-id mapping is one-to-many: playlists routinely list HD/SD/FHD
///   variants sharing one tvg-id, and a last-writer-wins map left every
///   sibling variant with an empty guide row.
/// - tvg-shift is applied per channel: timeshifted +1/+2 variants reuse the
///   base channel's EPG with programme times offset by the shift amount, so
///   range-filtering happens after the shift.
@pragma('vm:entry-point')
Map<String, List<Program>> groupProgramsForGuide(GuideGroupArgs args) {
  final epgIdToChannelIds = <String, List<String>>{};
  final shiftByChannelId = <String, int>{};

  void register(String key, String channelId) {
    final ids = epgIdToChannelIds.putIfAbsent(key, () => <String>[]);
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
    final channelIds = epgIdToChannelIds[program.channelId];
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

  // Sort programs by start time for each channel
  for (final list in map.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }

  return map;
}
