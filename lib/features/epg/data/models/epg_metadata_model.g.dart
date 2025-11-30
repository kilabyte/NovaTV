// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_metadata_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EpgMetadataModelAdapter extends TypeAdapter<EpgMetadataModel> {
  @override
  final typeId = 5;

  @override
  EpgMetadataModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EpgMetadataModel(
      sourceUrl: fields[0] as String,
      playlistId: fields[1] as String,
      generatedAt: fields[2] as DateTime?,
      fetchedAt: fields[3] as DateTime,
      channelCount: (fields[4] as num).toInt(),
      programCount: (fields[5] as num).toInt(),
      lastError: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EpgMetadataModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.sourceUrl)
      ..writeByte(1)
      ..write(obj.playlistId)
      ..writeByte(2)
      ..write(obj.generatedAt)
      ..writeByte(3)
      ..write(obj.fetchedAt)
      ..writeByte(4)
      ..write(obj.channelCount)
      ..writeByte(5)
      ..write(obj.programCount)
      ..writeByte(6)
      ..write(obj.lastError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpgMetadataModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
