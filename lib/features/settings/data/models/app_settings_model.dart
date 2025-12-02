import 'package:hive_ce/hive.dart';

part 'app_settings_model.g.dart';

@HiveType(typeId: 6)
class AppSettingsModel extends HiveObject {
  @HiveField(0)
  final String themeMode; // 'system', 'light', 'dark'

  @HiveField(1)
  final bool autoRefreshPlaylists;

  @HiveField(2)
  final int playlistRefreshInterval; // in hours

  @HiveField(3)
  final bool hardwareAcceleration;

  @HiveField(4)
  final String defaultAspectRatio; // 'fit', 'fill', '16:9', '4:3'

  @HiveField(5)
  final int epgTimezoneOffset; // in minutes

  @HiveField(6)
  final bool autoRefreshEpg;

  @HiveField(7)
  final int epgRefreshInterval; // in hours

  @HiveField(8)
  final bool showChannelNumbers;

  @HiveField(9)
  final String defaultChannelView; // 'grid', 'list'

  @HiveField(10)
  final bool rememberLastChannel;

  @HiveField(11)
  final String? lastPlayedChannelId;

  @HiveField(12)
  final String? lastTvGuideCategory;

  @HiveField(13)
  final String? lastSelectedSidebarRoute;

  @HiveField(14)
  final bool groupsSectionExpanded;

  AppSettingsModel({
    this.themeMode = 'dark',
    this.autoRefreshPlaylists = false,
    this.playlistRefreshInterval = 24,
    this.hardwareAcceleration = true,
    this.defaultAspectRatio = 'fit',
    this.epgTimezoneOffset = 0,
    this.autoRefreshEpg = false,
    this.epgRefreshInterval = 12,
    this.showChannelNumbers = true,
    this.defaultChannelView = 'grid',
    this.rememberLastChannel = true,
    this.lastPlayedChannelId,
    this.lastTvGuideCategory,
    this.lastSelectedSidebarRoute,
    this.groupsSectionExpanded = true,
  });

  AppSettingsModel copyWith({
    String? themeMode,
    bool? autoRefreshPlaylists,
    int? playlistRefreshInterval,
    bool? hardwareAcceleration,
    String? defaultAspectRatio,
    int? epgTimezoneOffset,
    bool? autoRefreshEpg,
    int? epgRefreshInterval,
    bool? showChannelNumbers,
    String? defaultChannelView,
    bool? rememberLastChannel,
    String? lastPlayedChannelId,
    String? lastTvGuideCategory,
    bool clearLastTvGuideCategory = false,
    String? lastSelectedSidebarRoute,
    bool? groupsSectionExpanded,
  }) {
    return AppSettingsModel(
      themeMode: themeMode ?? this.themeMode,
      autoRefreshPlaylists: autoRefreshPlaylists ?? this.autoRefreshPlaylists,
      playlistRefreshInterval: playlistRefreshInterval ?? this.playlistRefreshInterval,
      hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
      defaultAspectRatio: defaultAspectRatio ?? this.defaultAspectRatio,
      epgTimezoneOffset: epgTimezoneOffset ?? this.epgTimezoneOffset,
      autoRefreshEpg: autoRefreshEpg ?? this.autoRefreshEpg,
      epgRefreshInterval: epgRefreshInterval ?? this.epgRefreshInterval,
      showChannelNumbers: showChannelNumbers ?? this.showChannelNumbers,
      defaultChannelView: defaultChannelView ?? this.defaultChannelView,
      rememberLastChannel: rememberLastChannel ?? this.rememberLastChannel,
      lastPlayedChannelId: lastPlayedChannelId ?? this.lastPlayedChannelId,
      lastTvGuideCategory: clearLastTvGuideCategory ? null : (lastTvGuideCategory ?? this.lastTvGuideCategory),
      lastSelectedSidebarRoute: lastSelectedSidebarRoute ?? this.lastSelectedSidebarRoute,
      groupsSectionExpanded: groupsSectionExpanded ?? this.groupsSectionExpanded,
    );
  }
}
