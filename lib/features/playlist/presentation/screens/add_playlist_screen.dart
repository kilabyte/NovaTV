import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/playlist_providers.dart';

/// Add playlist screen. Supports two flows:
///   1. Direct M3U URL entry (the traditional way).
///   2. Xtream Codes credentials (server + user + pass) — turns into
///      get.php / xmltv.php URLs under the hood.
class AddPlaylistScreen extends ConsumerStatefulWidget {
  const AddPlaylistScreen({super.key});

  @override
  ConsumerState<AddPlaylistScreen> createState() => _AddPlaylistScreenState();
}

class _AddPlaylistScreenState extends ConsumerState<AddPlaylistScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _m3uFormKey = GlobalKey<FormState>();
  final _xtreamFormKey = GlobalKey<FormState>();

  // M3U tab
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _epgUrlController = TextEditingController();

  // Xtream tab
  final _xtreamNameController = TextEditingController();
  final _xtreamServerController = TextEditingController();
  final _xtreamUserController = TextEditingController();
  final _xtreamPassController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _epgUrlController.dispose();
    _xtreamNameController.dispose();
    _xtreamServerController.dispose();
    _xtreamUserController.dispose();
    _xtreamPassController.dispose();
    super.dispose();
  }

  Future<void> _savePlaylist() async {
    if (!_m3uFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(playlistNotifierProvider.notifier).addPlaylist(
            name: _nameController.text.trim(),
            url: _urlController.text.trim(),
            epgUrl: _epgUrlController.text.trim().isEmpty
                ? null
                : _epgUrlController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist added successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _saveXtream() async {
    if (!_xtreamFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(playlistNotifierProvider.notifier).addXtreamPlaylist(
            name: _xtreamNameController.text.trim(),
            server: _xtreamServerController.text.trim(),
            username: _xtreamUserController.text.trim(),
            password: _xtreamPassController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xtream playlist added successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Playlist'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'M3U URL'),
            Tab(text: 'Xtream Codes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildM3UTab(),
          _buildXtreamTab(),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildM3UTab() {
    return Form(
      key: _m3uFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildErrorBanner(),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Playlist Name',
              hintText: 'e.g., My IPTV',
              prefixIcon: Icon(Icons.label_outline),
            ),
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'M3U URL',
              hintText: 'https://example.com/playlist.m3u',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a URL';
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return 'Please enter a valid URL';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _epgUrlController,
            decoration: const InputDecoration(
              labelText: 'EPG URL (Optional)',
              hintText: 'https://example.com/epg.xml',
              prefixIcon: Icon(Icons.calendar_month_outlined),
              helperText: 'XMLTV format, supports .xml and .xml.gz',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _savePlaylist(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isLoading ? null : _savePlaylist,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add Playlist'),
          ),
        ],
      ),
    );
  }

  Widget _buildXtreamTab() {
    return Form(
      key: _xtreamFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildErrorBanner(),
          TextFormField(
            controller: _xtreamNameController,
            decoration: const InputDecoration(
              labelText: 'Provider Name',
              hintText: 'e.g., My Provider',
              prefixIcon: Icon(Icons.label_outline),
            ),
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _xtreamServerController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://server.example.com:8080',
              prefixIcon: Icon(Icons.dns_outlined),
              helperText: 'The base URL of your Xtream portal (without /player_api.php)',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: (value) => (value == null || value.isEmpty) ? 'Please enter a server URL' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _xtreamUserController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: (value) => (value == null || value.isEmpty) ? 'Please enter a username' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _xtreamPassController,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _saveXtream(),
            validator: (value) => (value == null || value.isEmpty) ? 'Please enter a password' : null,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isLoading ? null : _saveXtream,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add Xtream Playlist'),
          ),
        ],
      ),
    );
  }
}
