import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/routes.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../providers/settings_providers.dart';

/// Settings screen for app configuration
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Playlists section
          _SettingsSection(
            title: 'Playlists',
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_play),
                title: const Text('Manage Playlists'),
                subtitle: const Text('Add, edit, or remove playlists'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.playlists),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.refresh),
                title: const Text('Auto-refresh playlists'),
                subtitle: const Text('Refresh playlists automatically'),
                value: settings.autoRefreshPlaylists,
                onChanged: (value) {
                  ref.read(appSettingsProvider.notifier).setAutoRefreshPlaylists(value);
                },
              ),
              if (settings.autoRefreshPlaylists)
                ListTile(
                  leading: const Icon(Icons.timelapse),
                  title: const Text('Refresh interval'),
                  subtitle: Text('Every ${settings.playlistRefreshInterval} hours'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showRefreshIntervalPicker(context, ref, isPlaylist: true),
                ),
            ],
          ),

          // EPG section
          _SettingsSection(
            title: 'TV Guide (EPG)',
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh EPG now'),
                subtitle: const Text('Download latest program data'),
                onTap: () => _refreshEpg(context, ref),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome),
                title: const Text('Auto-refresh EPG'),
                subtitle: const Text('Refresh EPG automatically'),
                value: settings.autoRefreshEpg,
                onChanged: (value) {
                  ref.read(appSettingsProvider.notifier).setAutoRefreshEpg(value);
                },
              ),
              if (settings.autoRefreshEpg)
                ListTile(
                  leading: const Icon(Icons.timelapse),
                  title: const Text('EPG refresh interval'),
                  subtitle: Text('Every ${settings.epgRefreshInterval} hours'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showRefreshIntervalPicker(context, ref, isPlaylist: false),
                ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Timezone offset'),
                subtitle: Text(_formatTimezoneOffset(settings.epgTimezoneOffset)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTimezoneOffsetPicker(context, ref),
              ),
            ],
          ),

          // Player section
          _SettingsSection(
            title: 'Player',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.memory),
                title: const Text('Hardware acceleration'),
                subtitle: const Text('Use GPU for video decoding'),
                value: settings.hardwareAcceleration,
                onChanged: (value) {
                  ref.read(appSettingsProvider.notifier).setHardwareAcceleration(value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.aspect_ratio),
                title: const Text('Default aspect ratio'),
                subtitle: Text(_formatAspectRatio(settings.defaultAspectRatio)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAspectRatioPicker(context, ref),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.history),
                title: const Text('Remember last channel'),
                subtitle: const Text('Continue from last watched channel'),
                value: settings.rememberLastChannel,
                onChanged: (value) {
                  ref.read(appSettingsProvider.notifier).setRememberLastChannel(value);
                },
              ),
            ],
          ),

          // Channel List section
          _SettingsSection(
            title: 'Channel List',
            children: [
              ListTile(
                leading: const Icon(Icons.grid_view),
                title: const Text('Default view'),
                subtitle: Text(settings.defaultChannelView == 'grid' ? 'Grid' : 'List'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showViewPicker(context, ref),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.numbers),
                title: const Text('Show channel numbers'),
                subtitle: const Text('Display channel numbers in the list'),
                value: settings.showChannelNumbers,
                onChanged: (value) {
                  ref.read(appSettingsProvider.notifier).setShowChannelNumbers(value);
                },
              ),
            ],
          ),

          // Appearance section
          _SettingsSection(
            title: 'Appearance',
            children: [
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Theme'),
                subtitle: Text(_formatThemeMode(settings.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemePicker(context, ref),
              ),
            ],
          ),

          // Data section
          _SettingsSection(
            title: 'Data',
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear image cache'),
                subtitle: const Text('Remove cached channel logos'),
                onTap: () => _clearImageCache(context),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: const Text('Clean up old EPG data'),
                subtitle: const Text('Remove EPG data older than 7 days'),
                onTap: () => _cleanupEpgData(context, ref),
              ),
              ListTile(
                leading: Icon(
                  Icons.restore,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Reset all settings',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('Restore default settings'),
                onTap: () => _resetSettings(context, ref),
              ),
            ],
          ),

          // About section
          _SettingsSection(
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('NovaTV'),
                subtitle: const Text('Version 1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'NovaTV',
                  applicationVersion: '1.0.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System';
    }
  }

  String _formatAspectRatio(String ratio) {
    switch (ratio) {
      case 'fit':
        return 'Fit to screen';
      case 'fill':
        return 'Fill screen';
      case '16:9':
        return '16:9 (Widescreen)';
      case '4:3':
        return '4:3 (Standard)';
      default:
        return ratio;
    }
  }

  String _formatTimezoneOffset(int minutes) {
    if (minutes == 0) return 'UTC (Auto-detect)';
    final hours = minutes ~/ 60;
    final mins = minutes.abs() % 60;
    final sign = minutes >= 0 ? '+' : '-';
    if (mins == 0) {
      return 'UTC$sign${hours.abs()}';
    }
    return 'UTC$sign${hours.abs()}:${mins.toString().padLeft(2, '0')}';
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('System'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setThemeMode('system');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setThemeMode('light');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setThemeMode('dark');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAspectRatioPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fit_screen),
              title: const Text('Fit to screen'),
              subtitle: const Text('Show entire video within screen bounds'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setDefaultAspectRatio('fit');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Fill screen'),
              subtitle: const Text('Fill screen, may crop edges'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setDefaultAspectRatio('fill');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_16_9),
              title: const Text('16:9 (Widescreen)'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setDefaultAspectRatio('16:9');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_square),
              title: const Text('4:3 (Standard)'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setDefaultAspectRatio('4:3');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showViewPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const Text('Grid'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setDefaultChannelView('grid');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('List'),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setDefaultChannelView('list');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRefreshIntervalPicker(BuildContext context, WidgetRef ref, {required bool isPlaylist}) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final hours in [6, 12, 24, 48])
              ListTile(
                title: Text('Every $hours hours'),
                onTap: () {
                  if (isPlaylist) {
                    ref.read(appSettingsProvider.notifier).setPlaylistRefreshInterval(hours);
                  } else {
                    ref.read(appSettingsProvider.notifier).setEpgRefreshInterval(hours);
                  }
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showTimezoneOffsetPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Auto-detect (UTC)'),
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setEpgTimezoneOffset(0);
                  Navigator.pop(context);
                },
              ),
              for (final offset in [-12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
                ListTile(
                  title: Text('UTC${offset >= 0 ? '+' : ''}$offset'),
                  onTap: () {
                    ref.read(appSettingsProvider.notifier).setEpgTimezoneOffset(offset * 60);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshEpg(BuildContext context, WidgetRef ref) {
    final playlists = ref.read(playlistNotifierProvider);
    final playlist = playlists.valueOrNull?.firstOrNull;

    if (playlist?.epgUrl != null) {
      ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(
        playlist!.id,
        playlist.epgUrl!,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshing EPG data...')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No EPG URL configured in playlists')),
      );
    }
  }

  void _clearImageCache(BuildContext context) async {
    // Clear cached network images
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image cache cleared')),
      );
    }
  }

  void _cleanupEpgData(BuildContext context, WidgetRef ref) async {
    await ref.read(epgRefreshNotifierProvider.notifier).cleanupOldPrograms();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Old EPG data cleaned up')),
      );
    }
  }

  void _resetSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(appSettingsProvider.notifier).resetToDefaults();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings reset to defaults')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}
