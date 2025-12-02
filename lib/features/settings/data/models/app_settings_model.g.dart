// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsModelAdapter extends TypeAdapter<AppSettingsModel> {
  @override
  final typeId = 6;

  @override
  AppSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettingsModel(
      themeMode: fields[0] == null ? 'dark' : fields[0] as String,
      autoRefreshPlaylists: fields[1] == null ? false : fields[1] as bool,
      playlistRefreshInterval: fields[2] == null
          ? 24
          : (fields[2] as num).toInt(),
      hardwareAcceleration: fields[3] == null ? true : fields[3] as bool,
      defaultAspectRatio: fields[4] == null ? 'fit' : fields[4] as String,
      epgTimezoneOffset: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      autoRefreshEpg: fields[6] == null ? false : fields[6] as bool,
      epgRefreshInterval: fields[7] == null ? 12 : (fields[7] as num).toInt(),
      showChannelNumbers: fields[8] == null ? true : fields[8] as bool,
      defaultChannelView: fields[9] == null ? 'grid' : fields[9] as String,
      rememberLastChannel: fields[10] == null ? true : fields[10] as bool,
      lastPlayedChannelId: fields[11] as String?,
      lastTvGuideCategory: fields[12] as String?,
      lastSelectedSidebarRoute: fields[13] as String?,
      groupsSectionExpanded: fields[14] == null ? true : fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettingsModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.themeMode)
      ..writeByte(1)
      ..write(obj.autoRefreshPlaylists)
      ..writeByte(2)
      ..write(obj.playlistRefreshInterval)
      ..writeByte(3)
      ..write(obj.hardwareAcceleration)
      ..writeByte(4)
      ..write(obj.defaultAspectRatio)
      ..writeByte(5)
      ..write(obj.epgTimezoneOffset)
      ..writeByte(6)
      ..write(obj.autoRefreshEpg)
      ..writeByte(7)
      ..write(obj.epgRefreshInterval)
      ..writeByte(8)
      ..write(obj.showChannelNumbers)
      ..writeByte(9)
      ..write(obj.defaultChannelView)
      ..writeByte(10)
      ..write(obj.rememberLastChannel)
      ..writeByte(11)
      ..write(obj.lastPlayedChannelId)
      ..writeByte(12)
      ..write(obj.lastTvGuideCategory)
      ..writeByte(13)
      ..write(obj.lastSelectedSidebarRoute)
      ..writeByte(14)
      ..write(obj.groupsSectionExpanded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
