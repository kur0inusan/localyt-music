import 'package:flutter/material.dart';
import 'package:localyt_music/models/song.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/utils/display_title.dart';
import 'package:localyt_music/widgets/artwork.dart';

/// 曲の1行。行全体がタップ対象で、再生アイコンは置かない。
///
/// 再生中の曲は背景を塗らず、曲名をアクセント色にしてサムネイルに
/// イコライザを重ねる。末尾に置くのは回数などの文字1つまで。
class SongRow extends StatelessWidget {
  const SongRow({
    super.key,
    required this.song,
    required this.onTap,
    this.playing = false,
    this.trailing,
    this.onLongPress,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool playing;
  final Widget? trailing;

  static const double height = 62;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Artwork(
                song: song,
                height: 46,
                radius: palette.radiusArtSmall,
                playing: playing,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle(song),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: playing ? palette.accent : palette.text,
                      ),
                    ),
                    if (song.artist.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// セクションの見出し。右に文字ボタンを1つまで置ける。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 30, 20, 14),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.displayStyle(
                fontSize: 22,
                color: palette.text,
                letterSpacing: -0.22,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
