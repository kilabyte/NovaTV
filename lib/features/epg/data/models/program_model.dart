import 'package:hive_ce/hive.dart';

import '../../domain/entities/program.dart';

part 'program_model.g.dart';

@HiveType(typeId: 3)
class ProgramModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String channelId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final DateTime start;

  @HiveField(4)
  final DateTime end;

  @HiveField(5)
  final String? subtitle;

  @HiveField(6)
  final String? description;

  @HiveField(7)
  final String? category;

  @HiveField(8)
  final String? iconUrl;

  @HiveField(9)
  final String? episodeNum;

  @HiveField(10)
  final String? rating;

  @HiveField(11)
  final bool isNew;

  @HiveField(12)
  final bool isLive;

  @HiveField(13)
  final bool isPremiere;

  ProgramModel({
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

  factory ProgramModel.fromEntity(Program entity) {
    return ProgramModel(
      id: entity.id,
      channelId: entity.channelId,
      title: entity.title,
      start: entity.start,
      end: entity.end,
      subtitle: entity.subtitle,
      description: entity.description,
      category: entity.category,
      iconUrl: entity.iconUrl,
      episodeNum: entity.episodeNum,
      rating: entity.rating,
      isNew: entity.isNew,
      isLive: entity.isLive,
      isPremiere: entity.isPremiere,
    );
  }

  Program toEntity() {
    return Program(
      id: id,
      channelId: channelId,
      title: title,
      start: start,
      end: end,
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
}
