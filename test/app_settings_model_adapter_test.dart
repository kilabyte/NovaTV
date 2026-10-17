import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:novaiptv/features/settings/data/models/app_settings_model.dart';

/// Writes a settings record exactly as the previous app version did (18
/// field pairs, no field 18) so the current adapter's backward-compatible
/// read path is exercised with real bytes.
class _LegacyAppSettingsAdapter extends TypeAdapter<AppSettingsModel> {
  @override
  final typeId = 6;

  @override
  AppSettingsModel read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, AppSettingsModel obj) {
    writer
      ..writeByte(18)
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
      ..write(obj.groupsSectionExpanded)
      ..writeByte(15)
      ..write(obj.playerVolume)
      ..writeByte(16)
      ..write(obj.playerMuted)
      ..writeByte(17)
      ..write(obj.sidebarCollapsed);
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('novatv_settings_adapter_');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    Hive.resetAdapters();
    await dir.delete(recursive: true);
  });

  test('field 18 (sportsEventEpgFromNames) round-trips through the adapter', () async {
    Hive.registerAdapter(AppSettingsModelAdapter());
    final box = await Hive.openBox<AppSettingsModel>('app_settings');
    await box.put('settings', AppSettingsModel(sportsEventEpgFromNames: true, sidebarCollapsed: true));
    await box.close();

    final reopened = await Hive.openBox<AppSettingsModel>('app_settings');
    final s = reopened.get('settings')!;
    expect(s.sportsEventEpgFromNames, isTrue);
    expect(s.sidebarCollapsed, isTrue);
    expect(s.themeMode, 'dark');
  });

  test('a record written by the previous version (no field 18) decodes with the default false', () async {
    Hive.registerAdapter(_LegacyAppSettingsAdapter());
    final legacyBox = await Hive.openBox<AppSettingsModel>('app_settings');
    await legacyBox.put('settings', AppSettingsModel(playerMuted: true, lastTvGuideCategory: 'NFL'));
    await Hive.close();
    Hive.resetAdapters();

    Hive.init(dir.path);
    Hive.registerAdapter(AppSettingsModelAdapter());
    final box = await Hive.openBox<AppSettingsModel>('app_settings');
    final s = box.get('settings')!;
    expect(s.sportsEventEpgFromNames, isFalse);
    expect(s.playerMuted, isTrue, reason: 'earlier fields are intact');
    expect(s.lastTvGuideCategory, 'NFL');
  });
}
