// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChannelModelAdapter extends TypeAdapter<ChannelModel> {
  @override
  final typeId = 1;

  @override
  ChannelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChannelModel(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      playlistId: fields[17] as String,
      tvgId: fields[3] as String?,
      tvgName: fields[4] as String?,
      logoUrl: fields[5] as String?,
      group: fields[6] as String?,
      language: fields[7] as String?,
      country: fields[8] as String?,
      tvgShift: (fields[9] as num?)?.toInt(),
      userAgent: fields[10] as String?,
      referrer: fields[11] as String?,
      headers: (fields[12] as Map?)?.cast<String, String>(),
      licenseUrl: fields[13] as String?,
      licenseType: fields[14] as String?,
      isFavorite: fields[15] == null ? false : fields[15] as bool,
      channelNumber: (fields[16] as num?)?.toInt(),
      catchupType: fields[18] as String?,
      catchupSource: fields[19] as String?,
      catchupDays: (fields[20] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, ChannelModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.tvgId)
      ..writeByte(4)
      ..write(obj.tvgName)
      ..writeByte(5)
      ..write(obj.logoUrl)
      ..writeByte(6)
      ..write(obj.group)
      ..writeByte(7)
      ..write(obj.language)
      ..writeByte(8)
      ..write(obj.country)
      ..writeByte(9)
      ..write(obj.tvgShift)
      ..writeByte(10)
      ..write(obj.userAgent)
      ..writeByte(11)
      ..write(obj.referrer)
      ..writeByte(12)
      ..write(obj.headers)
      ..writeByte(13)
      ..write(obj.licenseUrl)
      ..writeByte(14)
      ..write(obj.licenseType)
      ..writeByte(15)
      ..write(obj.isFavorite)
      ..writeByte(16)
      ..write(obj.channelNumber)
      ..writeByte(17)
      ..write(obj.playlistId)
      ..writeByte(18)
      ..write(obj.catchupType)
      ..writeByte(19)
      ..write(obj.catchupSource)
      ..writeByte(20)
      ..write(obj.catchupDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChannelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
