import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../data/models/app_settings_model.dart';

/// Provider for the settings box
final settingsBoxProvider = FutureProvider<Box<AppSettingsModel>>((ref) async {
  return Hive.openBox<AppSettingsModel>('app_settings');
});

/// Provider for current app settings
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsModel>((ref) {
  return AppSettingsNotifier();
});

/// Provider for theme mode
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(appSettingsProvider);
  switch (settings.themeMode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});

class AppSettingsNotifier extends StateNotifier<AppSettingsModel> {
  static const String _settingsKey = 'settings';
  Box<AppSettingsModel>? _box;

  AppSettingsNotifier() : super(_loadInitialSettings()) {
    // Box is already open from bootstrap, just store reference
    _box = Hive.box<AppSettingsModel>('app_settings');
  }

  /// Load settings synchronously since box is pre-opened in bootstrap
  static AppSettingsModel _loadInitialSettings() {
    try {
      if (Hive.isBoxOpen('app_settings')) {
        final box = Hive.box<AppSettingsModel>('app_settings');
        final settings = box.get(_settingsKey);
        if (settings != null) {
          return settings;
        }
      }
    } catch (_) {
      // Fall back to defaults if any error
    }
    return AppSettingsModel();
  }

  Future<void> _saveSettings() async {
    await _box?.put(_settingsKey, state);
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    _saveSettings();
  }

  void setAutoRefreshPlaylists(bool value) {
    state = state.copyWith(autoRefreshPlaylists: value);
    _saveSettings();
  }

  void setPlaylistRefreshInterval(int hours) {
    state = state.copyWith(playlistRefreshInterval: hours);
    _saveSettings();
  }

  void setHardwareAcceleration(bool value) {
    state = state.copyWith(hardwareAcceleration: value);
    _saveSettings();
  }

  void setDefaultAspectRatio(String ratio) {
    state = state.copyWith(defaultAspectRatio: ratio);
    _saveSettings();
  }

  void setEpgTimezoneOffset(int minutes) {
    state = state.copyWith(epgTimezoneOffset: minutes);
    _saveSettings();
  }

  void setAutoRefreshEpg(bool value) {
    state = state.copyWith(autoRefreshEpg: value);
    _saveSettings();
  }

  void setEpgRefreshInterval(int hours) {
    state = state.copyWith(epgRefreshInterval: hours);
    _saveSettings();
  }

  void setShowChannelNumbers(bool value) {
    state = state.copyWith(showChannelNumbers: value);
    _saveSettings();
  }

  void setDefaultChannelView(String view) {
    state = state.copyWith(defaultChannelView: view);
    _saveSettings();
  }

  void setRememberLastChannel(bool value) {
    state = state.copyWith(rememberLastChannel: value);
    _saveSettings();
  }

  void setLastPlayedChannelId(String? channelId) {
    state = state.copyWith(lastPlayedChannelId: channelId);
    _saveSettings();
  }

  void setLastTvGuideCategory(String? category) {
    if (category == null) {
      state = state.copyWith(clearLastTvGuideCategory: true);
    } else {
      state = state.copyWith(lastTvGuideCategory: category);
    }
    _saveSettings();
  }

  void setLastSelectedSidebarRoute(String route) {
    state = state.copyWith(lastSelectedSidebarRoute: route);
    _saveSettings();
  }

  void setGroupsSectionExpanded(bool expanded) {
    state = state.copyWith(groupsSectionExpanded: expanded);
    _saveSettings();
  }

  Future<void> resetToDefaults() async {
    state = AppSettingsModel();
    await _saveSettings();
  }
}
