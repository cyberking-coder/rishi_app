import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';

/// Plays a media item. When [offline] is true it decrypts the downloaded copy
/// from the private vault; otherwise it streams from the authenticated endpoint.
///
/// For simplicity this MVP uses video_player for both video and audio (audio
/// plays with no visual surface). A dedicated just_audio screen is an easy
/// follow-up for richer audio controls.
class PlayerScreen extends StatefulWidget {
  final MediaItem item;
  final bool offline;
  const PlayerScreen({super.key, required this.item, this.offline = false});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  File? _tempFile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final VideoPlayerController controller;
      if (widget.offline) {
        // Decrypt to a temporary private file, then play it.
        _tempFile =
            await context.read<DownloadService>().openForPlayback(widget.item.id);
        controller = VideoPlayerController.file(_tempFile!);
      } else {
        final api = context.read<ApiService>();
        controller = VideoPlayerController.networkUrl(
          api.streamUri(widget.item.id),
          httpHeaders: api.authHeaders,
        );
      }
      await controller.initialize();
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Best-effort cleanup of the decrypted temp file.
    _tempFile?.delete().catchError((_) => _tempFile!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      backgroundColor: Colors.black,
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Playback error: $_error',
                    style: const TextStyle(color: Colors.white)),
              )
            : c == null
                ? const CircularProgressIndicator()
                : AspectRatio(
                    aspectRatio:
                        c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(c),
                        VideoProgressIndicator(c, allowScrubbing: true),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: c == null
          ? null
          : FloatingActionButton(
              onPressed: () => setState(
                  () => c.value.isPlaying ? c.pause() : c.play()),
              child: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
    );
  }
}
