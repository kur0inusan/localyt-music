import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/services/audio_player_service.dart';

/// 曲のサムネイル画像を表示するWidget。
///
/// サムネイルが見つからない場合は音符アイコンを表示する。
class SongThumbnail extends StatelessWidget {
  final Song song;
  final double size;
  final double borderRadius;

  const SongThumbnail({
    super.key,
    required this.song,
    this.size = 40,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final AudioPlayerService audioService = AudioPlayerService.instance;

    if (song.thumbnailPath.isNotEmpty) {
      final File file = File(song.thumbnailPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return FutureBuilder<Uint8List?>(
      future: audioService.loadThumbnail(song),
      builder: (context, snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            Icons.music_note,
            color: colorScheme.onSurfaceVariant,
            size: size * 0.5,
          ),
        );
      },
    );
  }
}
