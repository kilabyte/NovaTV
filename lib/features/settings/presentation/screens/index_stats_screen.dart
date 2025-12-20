import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/storage/index_service.dart';

/// Screen to display Hive index statistics for monitoring
class IndexStatsScreen extends ConsumerStatefulWidget {
  const IndexStatsScreen({super.key});

  @override
  ConsumerState<IndexStatsScreen> createState() => _IndexStatsScreenState();
}

class _IndexStatsScreenState extends ConsumerState<IndexStatsScreen> {
  IndexStatistics? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    final stats = await IndexService.getStatistics();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _rebuildIndexes() async {
    setState(() => _isLoading = true);
    await IndexService.buildAllIndexes();
    await _loadStatistics();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Indexes rebuilt successfully'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Index Statistics'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadStatistics, tooltip: 'Refresh statistics'),
          IconButton(icon: const Icon(Icons.build_rounded), onPressed: _rebuildIndexes, tooltip: 'Rebuild all indexes'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _stats == null
          ? Center(
              child: Text('No statistics available', style: TextStyle(color: AppColors.textSecondary)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(title: 'Channel Indexes', children: [_buildStatRow('Total Channels', '${_stats!.totalChannels}'), _buildStatRow('Group Index Entries', '${_stats!.channelGroupIndexEntries}'), _buildStatRow('Favorite Index Entries', '${_stats!.channelFavoriteIndexEntries}'), _buildStatRow('Group Index Coverage', '${_stats!.getChannelGroupIndexCoverage().toStringAsFixed(1)}%'), _buildStatRow('Favorite Index Coverage', '${_stats!.getChannelFavoriteIndexCoverage().toStringAsFixed(1)}%')]),
                  const SizedBox(height: 24),
                  _buildSection(title: 'EPG Program Indexes', children: [_buildStatRow('Total Programs', '${_stats!.totalPrograms}'), _buildStatRow('Program Boxes', '${_stats!.programBoxesCount}'), _buildStatRow('ChannelId Index Entries', '${_stats!.programChannelIndexEntries}'), _buildStatRow('StartDate Index Entries', '${_stats!.programDateIndexEntries}')]),
                  const SizedBox(height: 24),
                  _buildSection(title: 'Summary', children: [_buildStatRow('Total Indexed Items', '${_stats!.channelGroupIndexEntries + _stats!.channelFavoriteIndexEntries + _stats!.programChannelIndexEntries + _stats!.programDateIndexEntries}')]),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(
            value,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
