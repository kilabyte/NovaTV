// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgramModelAdapter extends TypeAdapter<ProgramModel> {
  @override
  final typeId = 3;

  @override
  ProgramModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgramModel(
      id: fields[0] as String,
      channelId: fields[1] as String,
      title: fields[2] as String,
      start: fields[3] as DateTime,
      end: fields[4] as DateTime,
      subtitle: fields[5] as String?,
      description: fields[6] as String?,
      category: fields[7] as String?,
      iconUrl: fields[8] as String?,
      episodeNum: fields[9] as String?,
      rating: fields[10] as String?,
      isNew: fields[11] == null ? false : fields[11] as bool,
      isLive: fields[12] == null ? false : fields[12] as bool,
      isPremiere: fields[13] == null ? false : fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ProgramModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.channelId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.start)
      ..writeByte(4)
      ..write(obj.end)
      ..writeByte(5)
      ..write(obj.subtitle)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.iconUrl)
      ..writeByte(9)
      ..write(obj.episodeNum)
      ..writeByte(10)
      ..write(obj.rating)
      ..writeByte(11)
      ..write(obj.isNew)
      ..writeByte(12)
      ..write(obj.isLive)
      ..writeByte(13)
      ..write(obj.isPremiere);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
