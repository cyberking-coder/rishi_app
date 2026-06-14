import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../services/auth_service.dart';
import '../services/download_service.dart';
import '../services/media_service.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anurag_Rishi'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Videos'), Tab(text: 'Audio')],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') context.read<AuthService>().logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(user?.displayName ?? 'Signed in'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _MediaList(type: MediaType.video),
          _MediaList(type: MediaType.audio),
        ],
      ),
    );
  }
}

class _MediaList extends StatefulWidget {
  final MediaType type;
  const _MediaList({required this.type});

  @override
  State<_MediaList> createState() => _MediaListState();
}

class _MediaListState extends State<_MediaList> {
  late Future<List<MediaItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<MediaService>().list(type: widget.type);
  }

  Future<void> _refresh() async {
    final f = context.read<MediaService>().list(type: widget.type);
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<MediaItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [
              const SizedBox(height: 120),
              Center(child: Text('Could not load: ${snap.error}')),
            ]);
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('Nothing here yet')),
            ]);
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _MediaTile(item: items[i]),
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatefulWidget {
  final MediaItem item;
  const _MediaTile({required this.item});

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  bool _downloaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshDownloadState();
  }

  Future<void> _refreshDownloadState() async {
    final d = await context.read<DownloadService>().isDownloaded(widget.item.id);
    if (mounted) setState(() => _downloaded = d);
  }

  Future<void> _toggleDownload() async {
    final downloads = context.read<DownloadService>();
    setState(() => _busy = true);
    try {
      if (_downloaded) {
        await downloads.delete(widget.item.id);
      } else {
        await downloads.download(widget.item.id);
      }
      await _refreshDownloadState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ListTile(
      leading: CircleAvatar(
        child: Icon(item.type == MediaType.audio
            ? Icons.music_note
            : Icons.play_circle_fill),
      ),
      title: Text(item.title),
      subtitle: item.description == null ? null : Text(item.description!),
      trailing: item.isDownloadable
          ? IconButton(
              icon: _busy
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_downloaded ? Icons.download_done : Icons.download_outlined),
              onPressed: _busy ? null : _toggleDownload,
            )
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(item: item, offline: _downloaded),
        ),
      ),
    );
  }
}
