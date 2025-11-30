import 'package:hive_ce/hive.dart';

import '../../domain/entities/epg_channel.dart';

part 'epg_channel_model.g.dart';

@HiveType(typeId: 4)
class EpgChannelModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? displayName;

  @HiveField(2)
  final String? iconUrl;

  @HiveField(3)
  final String? url;

  EpgChannelModel({
    required this.id,
    this.displayName,
    this.iconUrl,
    this.url,
  });

  factory EpgChannelModel.fromEntity(EpgChannel entity) {
    return EpgChannelModel(
      id: entity.id,
      displayName: entity.displayName,
      iconUrl: entity.iconUrl,
      url: entity.url,
    );
  }

  EpgChannel toEntity() {
    return EpgChannel(
      id: id,
      displayName: displayName,
      iconUrl: iconUrl,
      url: url,
    );
  }
}
