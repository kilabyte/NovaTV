// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_channel_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EpgChannelModelAdapter extends TypeAdapter<EpgChannelModel> {
  @override
  final typeId = 4;

  @override
  EpgChannelModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EpgChannelModel(
      id: fields[0] as String,
      displayName: fields[1] as String?,
      iconUrl: fields[2] as String?,
      url: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EpgChannelModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.iconUrl)
      ..writeByte(3)
      ..write(obj.url);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpgChannelModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
