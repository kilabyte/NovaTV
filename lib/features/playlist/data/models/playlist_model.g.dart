// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaylistModelAdapter extends TypeAdapter<PlaylistModel> {
  @override
  final typeId = 0;

  @override
  PlaylistModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaylistModel(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      epgUrl: fields[3] as String?,
      lastRefreshed: fields[4] as DateTime?,
      channelCount: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      autoRefresh: fields[6] == null ? true : fields[6] as bool,
      refreshIntervalHours: fields[7] == null ? 24 : (fields[7] as num).toInt(),
      lastError: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      userAgent: fields[10] as String?,
      headers: (fields[11] as Map?)?.cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, PlaylistModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.epgUrl)
      ..writeByte(4)
      ..write(obj.lastRefreshed)
      ..writeByte(5)
      ..write(obj.channelCount)
      ..writeByte(6)
      ..write(obj.autoRefresh)
      ..writeByte(7)
      ..write(obj.refreshIntervalHours)
      ..writeByte(8)
      ..write(obj.lastError)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.userAgent)
      ..writeByte(11)
      ..write(obj.headers);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
