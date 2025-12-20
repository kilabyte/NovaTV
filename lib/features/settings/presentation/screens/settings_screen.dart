import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../config/router/routes.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart';
import '../providers/settings_providers.dart';
import 'index_stats_screen.dart';

/// Clean settings screen with solid dark design
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: const Text(
                'Settings',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Settings content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Appearance section
                _SettingsSection(
                  title: 'Appearance',
                  children: [
                    _SettingsTile(icon: Icons.palette_rounded, title: 'Theme', subtitle: _formatThemeMode(settings.themeMode), onTap: () => _showThemeModePicker(context, ref), showChevron: true),
                    _SettingsTile(icon: Icons.favorite_rounded, title: 'Support the Developer', subtitle: 'Help keep the app updated', onTap: () => _handleSupportDeveloper(context), iconColor: AppColors.error),
                  ],
                ),

                const SizedBox(height: 16),

                // Playlists section
                _SettingsSection(
                  title: 'Playlists',
                  children: [
                    _SettingsTile(icon: Icons.playlist_add_rounded, title: 'Manage Playlists', subtitle: 'Add, edit, or remove playlists', onTap: () => context.push(Routes.playlists), showChevron: true),
                    _ToggleTile(
                      icon: Icons.refresh_rounded,
                      title: 'Auto-refresh playlists',
                      subtitle: 'Refresh playlists automatically',
                      value: settings.autoRefreshPlaylists,
                      onChanged: (value) {
                        ref.read(appSettingsProvider.notifier).setAutoRefreshPlaylists(value);
                      },
                    ),
                    if (settings.autoRefreshPlaylists) _SettingsTile(icon: Icons.timelapse_rounded, title: 'Refresh interval', subtitle: 'Every ${settings.playlistRefreshInterval} hours', onTap: () => _showRefreshIntervalPicker(context, ref, isPlaylist: true), showChevron: true),
                  ],
                ),

                const SizedBox(height: 16),

                // EPG section
                _SettingsSection(
                  title: 'TV Guide (EPG)',
                  children: [
                    _SettingsTile(icon: Icons.cloud_download_rounded, title: 'Refresh EPG now', subtitle: 'Download latest program data', onTap: () => _refreshEpg(context, ref)),
                    _ToggleTile(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Auto-refresh EPG',
                      subtitle: 'Refresh EPG automatically',
                      value: settings.autoRefreshEpg,
                      onChanged: (value) {
                        ref.read(appSettingsProvider.notifier).setAutoRefreshEpg(value);
                      },
                    ),
                    if (settings.autoRefreshEpg) _SettingsTile(icon: Icons.timelapse_rounded, title: 'EPG refresh interval', subtitle: 'Every ${settings.epgRefreshInterval} hours', onTap: () => _showRefreshIntervalPicker(context, ref, isPlaylist: false), showChevron: true),
                    _SettingsTile(icon: Icons.access_time_rounded, title: 'Timezone offset', subtitle: _formatTimezoneOffset(settings.epgTimezoneOffset), onTap: () => _showTimezoneOffsetPicker(context, ref), showChevron: true),
                  ],
                ),

                const SizedBox(height: 16),

                // Player section
                _SettingsSection(
                  title: 'Player',
                  children: [
                    _ToggleTile(
                      icon: Icons.memory_rounded,
                      title: 'Hardware acceleration',
                      subtitle: 'Use GPU for video decoding',
                      value: settings.hardwareAcceleration,
                      onChanged: (value) {
                        ref.read(appSettingsProvider.notifier).setHardwareAcceleration(value);
                      },
                    ),
                    _SettingsTile(icon: Icons.aspect_ratio_rounded, title: 'Default aspect ratio', subtitle: _formatAspectRatio(settings.defaultAspectRatio), onTap: () => _showAspectRatioPicker(context, ref), showChevron: true),
                    _ToggleTile(
                      icon: Icons.history_rounded,
                      title: 'Remember last channel',
                      subtitle: 'Continue from last watched channel',
                      value: settings.rememberLastChannel,
                      onChanged: (value) {
                        ref.read(appSettingsProvider.notifier).setRememberLastChannel(value);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Channel List section
                _SettingsSection(
                  title: 'Channel List',
                  children: [
                    _ToggleTile(
                      icon: Icons.numbers_rounded,
                      title: 'Show channel numbers',
                      subtitle: 'Display channel numbers in the list',
                      value: settings.showChannelNumbers,
                      onChanged: (value) {
                        ref.read(appSettingsProvider.notifier).setShowChannelNumbers(value);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Data section
                _SettingsSection(
                  title: 'Data',
                  children: [
                    _SettingsTile(icon: Icons.analytics_rounded, title: 'Index Statistics', subtitle: 'View Hive index performance metrics', onTap: () => context.push('/settings/index-stats'), showChevron: true),
                    _SettingsTile(icon: Icons.delete_outline_rounded, title: 'Clear image cache', subtitle: 'Remove cached channel logos', onTap: () => _clearImageCache(context)),
                    _SettingsTile(icon: Icons.cleaning_services_rounded, title: 'Clean up old EPG data', subtitle: 'Remove EPG data older than 7 days', onTap: () => _cleanupEpgData(context, ref)),
                    _SettingsTile(icon: Icons.restore_rounded, title: 'Reset all settings', subtitle: 'Restore default settings', onTap: () => _resetSettings(context, ref), isDanger: true),
                  ],
                ),

                const SizedBox(height: 16),

                // About section
                _SettingsSection(title: 'About', children: [_AboutTile()]),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
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

  void _showThemeModePicker(BuildContext context, WidgetRef ref) {
    _showBottomSheet(
      context: context,
      title: 'Theme',
      children: [
        _OptionTile(
          icon: Icons.brightness_auto_rounded,
          title: 'System',
          subtitle: 'Follow system appearance',
          onTap: () {
            ref.read(appSettingsProvider.notifier).setThemeMode('system');
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          icon: Icons.light_mode_rounded,
          title: 'Light',
          subtitle: 'Always use light theme',
          onTap: () {
            ref.read(appSettingsProvider.notifier).setThemeMode('light');
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          icon: Icons.dark_mode_rounded,
          title: 'Dark',
          subtitle: 'Always use dark theme',
          onTap: () {
            ref.read(appSettingsProvider.notifier).setThemeMode('dark');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  void _showAspectRatioPicker(BuildContext context, WidgetRef ref) {
    _showBottomSheet(
      context: context,
      title: 'Aspect Ratio',
      children: [
        _OptionTile(
          icon: Icons.fit_screen_rounded,
          title: 'Fit to screen',
          subtitle: 'Show entire video within screen bounds',
          onTap: () {
            ref.read(appSettingsProvider.notifier).setDefaultAspectRatio('fit');
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          icon: Icons.fullscreen_rounded,
          title: 'Fill screen',
          subtitle: 'Fill screen, may crop edges',
          onTap: () {
            ref.read(appSettingsProvider.notifier).setDefaultAspectRatio('fill');
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          icon: Icons.crop_16_9_rounded,
          title: '16:9 (Widescreen)',
          onTap: () {
            ref.read(appSettingsProvider.notifier).setDefaultAspectRatio('16:9');
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          icon: Icons.crop_square_rounded,
          title: '4:3 (Standard)',
          onTap: () {
            ref.read(appSettingsProvider.notifier).setDefaultAspectRatio('4:3');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  void _showRefreshIntervalPicker(BuildContext context, WidgetRef ref, {required bool isPlaylist}) {
    _showBottomSheet(
      context: context,
      title: 'Refresh Interval',
      children: [
        for (final hours in [6, 12, 24, 48])
          _OptionTile(
            icon: Icons.schedule_rounded,
            title: 'Every $hours hours',
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
    );
  }

  void _showTimezoneOffsetPicker(BuildContext context, WidgetRef ref) {
    _showBottomSheet(
      context: context,
      title: 'Timezone Offset',
      isScrollable: true,
      children: [
        _OptionTile(
          icon: Icons.public_rounded,
          title: 'Auto-detect (UTC)',
          onTap: () {
            ref.read(appSettingsProvider.notifier).setEpgTimezoneOffset(0);
            Navigator.pop(context);
          },
        ),
        for (final offset in [-12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
          _OptionTile(
            icon: Icons.access_time_rounded,
            title: 'UTC${offset >= 0 ? '+' : ''}$offset',
            onTap: () {
              ref.read(appSettingsProvider.notifier).setEpgTimezoneOffset(offset * 60);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  void _showBottomSheet({required BuildContext context, required String title, required List<Widget> children, bool isScrollable = false}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: isScrollable,
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: isScrollable ? MediaQuery.of(context).size.height * 0.7 : double.infinity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              // Content
              if (isScrollable)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: children),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: children),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshEpg(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final playlists = ref.read(playlistNotifierProvider);
    final playlist = playlists.valueOrNull?.firstOrNull;

    if (playlist?.epgUrl != null) {
      ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist!.id, playlist.epgUrl!);
      _showSnackBar(context, 'Refreshing EPG data...', Icons.cloud_download_rounded);
    } else {
      _showSnackBar(context, 'No EPG URL configured in playlists', Icons.warning_rounded, isWarning: true);
    }
  }

  void _clearImageCache(BuildContext context) async {
    HapticFeedback.lightImpact();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    if (context.mounted) {
      _showSnackBar(context, 'Image cache cleared', Icons.check_circle_rounded);
    }
  }

  void _cleanupEpgData(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref.read(epgRefreshNotifierProvider.notifier).cleanupOldPrograms();
    if (context.mounted) {
      _showSnackBar(context, 'Old EPG data cleaned up', Icons.check_circle_rounded);
    }
  }

  void _showSnackBar(BuildContext context, String message, IconData icon, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: isWarning ? AppColors.warning : AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _resetSettings(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Reset Settings', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Text('Are you sure you want to reset all settings to defaults? This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(appSettingsProvider.notifier).resetToDefaults();
              if (context.mounted) {
                Navigator.pop(context);
                _showSnackBar(context, 'Settings reset to defaults', Icons.check_circle_rounded);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _handleSupportDeveloper(BuildContext context) {
    HapticFeedback.lightImpact();
    // TODO: Implement cross-platform in-app purchase (using in_app_purchase package)
    // Product IDs:
    //   - Apple (iOS/macOS): XXXXXXXX
    //   - Google Play (Android): XXXXXXXX
    //   - Microsoft Store (Windows): XXXXXXXX
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.favorite_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Support the Developer', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Text('Thank you for your interest in supporting development! This feature will be available soon.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CLEAN SETTINGS COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showChevron;
  final bool isDanger;
  final Color? iconColor;

  const _SettingsTile({required this.icon, required this.title, this.subtitle, required this.onTap, this.showChevron = false, this.isDanger = false, this.iconColor});

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: _isHovered ? AppColors.surfaceHover : Colors.transparent),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color:
                    widget.iconColor ??
                    (widget.isDanger
                        ? AppColors.error
                        : _isHovered
                        ? AppColors.primary
                        : AppColors.textSecondary),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(color: widget.isDanger ? AppColors.error : AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    if (widget.subtitle != null) ...[const SizedBox(height: 2), Text(widget.subtitle!, style: TextStyle(color: widget.isDanger ? AppColors.error.withValues(alpha: 0.7) : AppColors.textMuted, fontSize: 13))],
                  ],
                ),
              ),
              if (widget.showChevron) Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onChanged(!widget.value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: _isHovered ? AppColors.surfaceHover : Colors.transparent),
          child: Row(
            children: [
              Icon(widget.icon, color: _isHovered ? AppColors.primary : AppColors.textSecondary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    if (widget.subtitle != null) ...[const SizedBox(height: 2), Text(widget.subtitle!, style: TextStyle(color: AppColors.textMuted, fontSize: 13))],
                  ],
                ),
              ),
              _CleanSwitch(value: widget.value, onChanged: widget.onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _CleanSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CleanSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? AppColors.primary : AppColors.border),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _AboutTile extends StatefulWidget {
  @override
  State<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<_AboutTile> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nova IPTV',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text('Version $_version', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 2),
              Text('Build $_buildNumber', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text('© Kilabyte IO', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _OptionTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceHover : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isHovered ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: _isHovered ? AppColors.primary : AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    if (widget.subtitle != null) ...[const SizedBox(height: 2), Text(widget.subtitle!, style: TextStyle(color: AppColors.textMuted, fontSize: 13))],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
