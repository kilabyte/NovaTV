import 'package:equatable/equatable.dart';

/// Represents a TV program/show in the EPG
class Program extends Equatable {
  final String id;
  final String channelId;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? subtitle;
  final String? description;
  final String? category;
  final String? iconUrl;
  final String? episodeNum;
  final String? rating;
  final bool isNew;
  final bool isLive;
  final bool isPremiere;

  const Program({
    required this.id,
    required this.channelId,
    required this.title,
    required this.start,
    required this.end,
    this.subtitle,
    this.description,
    this.category,
    this.iconUrl,
    this.episodeNum,
    this.rating,
    this.isNew = false,
    this.isLive = false,
    this.isPremiere = false,
  });

  /// Duration of the program in minutes
  int get durationMinutes => end.difference(start).inMinutes;

  /// Check if the program is currently airing
  bool get isCurrentlyAiring {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Check if the program has ended
  bool get hasEnded => DateTime.now().isAfter(end);

  /// Check if the program is upcoming
  bool get isUpcoming => DateTime.now().isBefore(start);

  /// Get the progress percentage (0.0 to 1.0) for currently airing programs
  double get progress {
    if (!isCurrentlyAiring) return hasEnded ? 1.0 : 0.0;
    final now = DateTime.now();
    final elapsed = now.difference(start).inSeconds;
    final total = end.difference(start).inSeconds;
    return total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
  }

  Program copyWith({
    String? id,
    String? channelId,
    String? title,
    DateTime? start,
    DateTime? end,
    String? subtitle,
    String? description,
    String? category,
    String? iconUrl,
    String? episodeNum,
    String? rating,
    bool? isNew,
    bool? isLive,
    bool? isPremiere,
  }) {
    return Program(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      category: category ?? this.category,
      iconUrl: iconUrl ?? this.iconUrl,
      episodeNum: episodeNum ?? this.episodeNum,
      rating: rating ?? this.rating,
      isNew: isNew ?? this.isNew,
      isLive: isLive ?? this.isLive,
      isPremiere: isPremiere ?? this.isPremiere,
    );
  }

  @override
  List<Object?> get props => [
        id,
        channelId,
        title,
        start,
        end,
        subtitle,
        description,
        category,
        iconUrl,
        episodeNum,
        rating,
        isNew,
        isLive,
        isPremiere,
      ];
}
