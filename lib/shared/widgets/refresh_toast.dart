import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';

/// State for tracking background refresh operations
class RefreshState {
  final bool isRefreshingPlaylist;
  final bool isRefreshingEpg;
  final String? message;
  final bool isSuccess;
  final bool isError;

  const RefreshState({
    this.isRefreshingPlaylist = false,
    this.isRefreshingEpg = false,
    this.message,
    this.isSuccess = false,
    this.isError = false,
  });

  bool get isRefreshing => isRefreshingPlaylist || isRefreshingEpg;

  RefreshState copyWith({
    bool? isRefreshingPlaylist,
    bool? isRefreshingEpg,
    String? message,
    bool? isSuccess,
    bool? isError,
  }) {
    return RefreshState(
      isRefreshingPlaylist: isRefreshingPlaylist ?? this.isRefreshingPlaylist,
      isRefreshingEpg: isRefreshingEpg ?? this.isRefreshingEpg,
      message: message ?? this.message,
      isSuccess: isSuccess ?? this.isSuccess,
      isError: isError ?? this.isError,
    );
  }

  String get displayMessage {
    if (message != null) return message!;
    if (isRefreshingPlaylist && isRefreshingEpg) return 'Refreshing playlist & EPG...';
    if (isRefreshingPlaylist) return 'Refreshing playlist...';
    if (isRefreshingEpg) return 'Refreshing EPG data...';
    if (isSuccess) return 'Refresh complete';
    if (isError) return 'Refresh failed';
    return '';
  }
}

/// Notifier for managing refresh state
class RefreshNotifier extends StateNotifier<RefreshState> {
  Timer? _hideTimer;

  RefreshNotifier() : super(const RefreshState());

  void startPlaylistRefresh() {
    _hideTimer?.cancel();
    state = state.copyWith(
      isRefreshingPlaylist: true,
      isSuccess: false,
      isError: false,
    );
  }

  void startEpgRefresh() {
    _hideTimer?.cancel();
    state = state.copyWith(
      isRefreshingEpg: true,
      isSuccess: false,
      isError: false,
    );
  }

  void completePlaylistRefresh({bool success = true}) {
    state = state.copyWith(
      isRefreshingPlaylist: false,
      isSuccess: success && !state.isRefreshingEpg,
      isError: !success && !state.isRefreshingEpg,
    );
    _scheduleHide();
  }

  void completeEpgRefresh({bool success = true}) {
    state = state.copyWith(
      isRefreshingEpg: false,
      isSuccess: success && !state.isRefreshingPlaylist,
      isError: !success && !state.isRefreshingPlaylist,
    );
    _scheduleHide();
  }

  void showMessage(String message, {bool isError = false}) {
    _hideTimer?.cancel();
    state = RefreshState(
      message: message,
      isSuccess: !isError,
      isError: isError,
    );
    _scheduleHide();
  }

  void _scheduleHide() {
    if (!state.isRefreshing) {
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          state = const RefreshState();
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

/// Provider for refresh state
final refreshStateProvider = StateNotifierProvider<RefreshNotifier, RefreshState>((ref) {
  return RefreshNotifier();
});

/// Toast widget that shows refresh status
class RefreshToast extends ConsumerWidget {
  const RefreshToast({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refreshStateProvider);

    // Don't show if nothing is happening
    if (!state.isRefreshing && !state.isSuccess && !state.isError && state.message == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 80, // Above bottom nav
      left: 16,
      right: 16,
      child: SafeArea(
        child: Center(
          child: AnimatedOpacity(
            opacity: (state.isRefreshing || state.isSuccess || state.isError || state.message != null) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: state.isError
                    ? AppColors.error.withValues(alpha: 0.95)
                    : state.isSuccess
                    ? AppColors.success.withValues(alpha: 0.95)
                    : AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.isError
                      ? AppColors.error
                      : state.isSuccess
                      ? AppColors.success
                      : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isRefreshing)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  else if (state.isSuccess)
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 18)
                  else if (state.isError)
                    Icon(Icons.error_outline_rounded, color: Colors.white, size: 18)
                  else
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      state.displayMessage,
                      style: TextStyle(
                        color: (state.isSuccess || state.isError) ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
