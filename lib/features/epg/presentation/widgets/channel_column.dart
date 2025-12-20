import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../playlist/domain/entities/channel.dart';

/// Channel column widget showing channel logos and names
class ChannelColumn extends StatelessWidget {
  final ScrollController scrollController;
  final List<Channel> channels;
  final double width;
  final double rowHeight;
  final void Function(Channel)? onChannelTap;

  const ChannelColumn({super.key, required this.scrollController, required this.channels, this.width = 120, this.rowHeight = 60, this.onChannelTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant, width: 1)),
      ),
      child: ListView.builder(
        controller: scrollController,
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return _ChannelRow(channel: channel, height: rowHeight, onTap: onChannelTap != null ? () => onChannelTap!(channel) : null);
        },
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final Channel channel;
  final double height;
  final VoidCallback? onTap;

  const _ChannelRow({required this.channel, required this.height, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: [
            // Channel logo
            if (channel.logoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: channel.logoUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  // Add memory limits for better performance on Android
                  memCacheWidth: 32,
                  memCacheHeight: 32,
                  placeholder: (_, __) => Container(
                    width: 32,
                    height: 32,
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Icon(Icons.tv, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 32,
                    height: 32,
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Icon(Icons.tv, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(4)),
                child: Icon(Icons.tv, size: 16, color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(width: 8),
            // Channel name
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channel.channelNumber != null) Text('Ch. ${channel.channelNumber}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
