import 'package:equatable/equatable.dart';

import 'epg_channel.dart';
import 'program.dart';

/// Container for all EPG data from an XMLTV source
class EpgData extends Equatable {
  final String sourceUrl;
  final DateTime? generatedAt;
  final DateTime fetchedAt;
  final List<EpgChannel> channels;
  final List<Program> programs;

  const EpgData({
    required this.sourceUrl,
    this.generatedAt,
    required this.fetchedAt,
    required this.channels,
    required this.programs,
  });

  /// Get programs for a specific channel
  List<Program> getProgramsForChannel(String channelId) {
    return programs.where((p) => p.channelId == channelId).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Get current program for a channel
  Program? getCurrentProgram(String channelId) {
    final now = DateTime.now();
    try {
      return programs.firstWhere(
        (p) => p.channelId == channelId && p.start.isBefore(now) && p.end.isAfter(now),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get next program for a channel
  Program? getNextProgram(String channelId) {
    final now = DateTime.now();
    final upcoming = programs
        .where((p) => p.channelId == channelId && p.start.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  /// Get programs for a time range
  List<Program> getProgramsInRange(DateTime start, DateTime end) {
    return programs.where((p) {
      return p.end.isAfter(start) && p.start.isBefore(end);
    }).toList();
  }

  /// Get programs for a channel within a time range
  List<Program> getProgramsForChannelInRange(
    String channelId,
    DateTime start,
    DateTime end,
  ) {
    return programs.where((p) {
      return p.channelId == channelId && p.end.isAfter(start) && p.start.isBefore(end);
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Find channel by ID
  EpgChannel? findChannel(String channelId) {
    try {
      return channels.firstWhere((c) => c.id == channelId);
    } catch (_) {
      return null;
    }
  }

  /// Check if EPG data is stale (older than specified hours)
  bool isStale({int hours = 24}) {
    return DateTime.now().difference(fetchedAt).inHours >= hours;
  }

  EpgData copyWith({
    String? sourceUrl,
    DateTime? generatedAt,
    DateTime? fetchedAt,
    List<EpgChannel>? channels,
    List<Program>? programs,
  }) {
    return EpgData(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      generatedAt: generatedAt ?? this.generatedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      channels: channels ?? this.channels,
      programs: programs ?? this.programs,
    );
  }

  @override
  List<Object?> get props => [sourceUrl, generatedAt, fetchedAt, channels, programs];
}
