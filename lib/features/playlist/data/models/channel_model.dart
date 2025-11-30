import 'package:hive_ce/hive.dart';

import '../../domain/entities/channel.dart';

part 'channel_model.g.dart';

/// Hive model for Channel entity
@HiveType(typeId: 1)
class ChannelModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String url;

  @HiveField(3)
  final String? tvgId;

  @HiveField(4)
  final String? tvgName;

  @HiveField(5)
  final String? logoUrl;

  @HiveField(6)
  final String? group;

  @HiveField(7)
  final String? language;

  @HiveField(8)
  final String? country;

  @HiveField(9)
  final int? tvgShift;

  @HiveField(10)
  final String? userAgent;

  @HiveField(11)
  final String? referrer;

  @HiveField(12)
  final Map<String, String>? headers;

  @HiveField(13)
  final String? licenseUrl;

  @HiveField(14)
  final String? licenseType;

  @HiveField(15)
  final bool isFavorite;

  @HiveField(16)
  final int? channelNumber;

  @HiveField(17)
  final String playlistId;

  @HiveField(18)
  final String? catchupType;

  @HiveField(19)
  final String? catchupSource;

  @HiveField(20)
  final int? catchupDays;

  ChannelModel({
    required this.id,
    required this.name,
    required this.url,
    required this.playlistId,
    this.tvgId,
    this.tvgName,
    this.logoUrl,
    this.group,
    this.language,
    this.country,
    this.tvgShift,
    this.userAgent,
    this.referrer,
    this.headers,
    this.licenseUrl,
    this.licenseType,
    this.isFavorite = false,
    this.channelNumber,
    this.catchupType,
    this.catchupSource,
    this.catchupDays,
  });

  /// Convert to domain entity
  Channel toEntity() {
    return Channel(
      id: id,
      name: name,
      url: url,
      playlistId: playlistId,
      tvgId: tvgId,
      tvgName: tvgName,
      logoUrl: logoUrl,
      group: group,
      language: language,
      country: country,
      tvgShift: tvgShift,
      userAgent: userAgent,
      referrer: referrer,
      headers: headers,
      licenseUrl: licenseUrl,
      licenseType: licenseType,
      isFavorite: isFavorite,
      channelNumber: channelNumber,
      catchupType: catchupType,
      catchupSource: catchupSource,
      catchupDays: catchupDays,
    );
  }

  /// Create from domain entity
  factory ChannelModel.fromEntity(Channel channel) {
    return ChannelModel(
      id: channel.id,
      name: channel.name,
      url: channel.url,
      playlistId: channel.playlistId,
      tvgId: channel.tvgId,
      tvgName: channel.tvgName,
      logoUrl: channel.logoUrl,
      group: channel.group,
      language: channel.language,
      country: channel.country,
      tvgShift: channel.tvgShift,
      userAgent: channel.userAgent,
      referrer: channel.referrer,
      headers: channel.headers,
      licenseUrl: channel.licenseUrl,
      licenseType: channel.licenseType,
      isFavorite: channel.isFavorite,
      channelNumber: channel.channelNumber,
      catchupType: channel.catchupType,
      catchupSource: channel.catchupSource,
      catchupDays: channel.catchupDays,
    );
  }

  /// Create copy with new values
  ChannelModel copyWith({
    String? id,
    String? name,
    String? url,
    String? playlistId,
    String? tvgId,
    String? tvgName,
    String? logoUrl,
    String? group,
    String? language,
    String? country,
    int? tvgShift,
    String? userAgent,
    String? referrer,
    Map<String, String>? headers,
    String? licenseUrl,
    String? licenseType,
    bool? isFavorite,
    int? channelNumber,
    String? catchupType,
    String? catchupSource,
    int? catchupDays,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      playlistId: playlistId ?? this.playlistId,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      logoUrl: logoUrl ?? this.logoUrl,
      group: group ?? this.group,
      language: language ?? this.language,
      country: country ?? this.country,
      tvgShift: tvgShift ?? this.tvgShift,
      userAgent: userAgent ?? this.userAgent,
      referrer: referrer ?? this.referrer,
      headers: headers ?? this.headers,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      licenseType: licenseType ?? this.licenseType,
      isFavorite: isFavorite ?? this.isFavorite,
      channelNumber: channelNumber ?? this.channelNumber,
      catchupType: catchupType ?? this.catchupType,
      catchupSource: catchupSource ?? this.catchupSource,
      catchupDays: catchupDays ?? this.catchupDays,
    );
  }
}
