import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:localyt_music/services/play_history_service.dart';
import 'package:localyt_music/theme/app_palette.dart';
import 'package:localyt_music/theme/app_theme.dart';
import 'package:localyt_music/theme/theme_controller.dart';
import 'package:localyt_music/utils/display_title.dart';

/// 設定画面。テーマ・ライト/ダークモード・曲名の表示の切り替えと、
/// 再生履歴の記録・リセットを行う。ホームの歯車から開く。
class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController controller = ThemeController.instance;
    final AppPalette palette = AppPalette.of(context);
    final Brightness brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '戻る',
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('設定'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const _Heading(title: 'テーマ', subtitle: '色と角の丸み、浮いている部品の質感が変わります'),
              const SizedBox(height: 12),
              for (final AppThemeData theme in AppThemes.all) ...[
                _ThemeOptionCard(
                  theme: theme,
                  palette: theme.paletteFor(brightness),
                  selected: controller.themeId == theme.id,
                  onTap: () => controller.setThemeId(theme.id),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 20),
              const _Heading(title: '表示モード'),
              const SizedBox(height: 12),
              _ThemeModeSelector(
                mode: controller.themeMode,
                onChanged: controller.setThemeMode,
              ),
              const SizedBox(height: 36),
              const _Heading(title: '表示'),
              const SizedBox(height: 12),
              _SettingsGroup(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Symbols.title_rounded),
                    title: const Text('曲名を整えて表示する'),
                    subtitle: Text(
                      '【MV】や (Official Video) などを外します\n'
                      '例: ${cleanSongTitle('【MV】群青の街（Official Music Video）')}',
                    ),
                    isThreeLine: true,
                    value: controller.cleanTitles,
                    onChanged: controller.setCleanTitles,
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const _Heading(title: '再生履歴', subtitle: 'ホーム画面のおすすめやよく聴く曲に使います'),
              const SizedBox(height: 12),
              const _PlayHistorySettings(),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '再生履歴はこの端末のアプリ内にだけ保存され、'
                  'アプリを再インストールすると消えます。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: palette.textMuted,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppFonts.displayStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
        ],
      ],
    );
  }
}

/// 設定項目をまとめる面。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(palette.radiusCard);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: radius,
        boxShadow: palette.raisedShadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

/// 再生履歴の記録のオン/オフ、再生回数のリセット、履歴の削除。
class _PlayHistorySettings extends StatelessWidget {
  const _PlayHistorySettings();

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _resetPlayCounts(BuildContext context) async {
    final bool confirmed = await _confirm(
      context,
      title: '再生回数をリセット',
      message:
          '全曲の再生回数を0に戻します。よく聴く曲と'
          'おすすめの傾向が初期化されます。\n'
          '最近再生した曲と続きから再生は残ります。',
      action: 'リセット',
    );
    if (!confirmed || !context.mounted) return;
    PlayHistoryService.instance.resetPlayCounts();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('再生回数をリセットしました')));
  }

  Future<void> _clearAllHistory(BuildContext context) async {
    final bool confirmed = await _confirm(
      context,
      title: '再生履歴をすべて削除',
      message: '再生回数に加えて、最近再生した曲と続きから再生の情報も削除します。',
      action: '削除',
    );
    if (!confirmed || !context.mounted) return;
    PlayHistoryService.instance.clearAllHistory();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('再生履歴を削除しました')));
  }

  @override
  Widget build(BuildContext context) {
    final PlayHistoryService history = PlayHistoryService.instance;
    final Color error = Theme.of(context).colorScheme.error;

    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final int songCount = history.countedSongCount;
        final int playCount = history.totalPlayCount;
        return _SettingsGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Symbols.edit_note_rounded),
              title: const Text('再生履歴を記録する'),
              subtitle: const Text('オフの間は再生回数や最近再生した曲を更新しません'),
              value: history.isRecording,
              onChanged: history.setRecording,
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Symbols.restart_alt_rounded),
              title: const Text('再生回数をリセット'),
              subtitle: Text(
                playCount == 0
                    ? '記録された再生回数はありません'
                    : '$songCount曲・合計$playCount回',
              ),
              enabled: playCount > 0,
              onTap: () => _resetPlayCounts(context),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(
                Symbols.delete_rounded,
                color: history.hasHistory ? error : null,
              ),
              title: Text(
                '再生履歴をすべて削除',
                style: history.hasHistory ? TextStyle(color: error) : null,
              ),
              subtitle: const Text('最近再生した曲・続きから再生も削除します'),
              enabled: history.hasHistory,
              onTap: () => _clearAllHistory(context),
            ),
          ],
        );
      },
    );
  }
}

/// テーマ1件分の選択カード。左にそのテーマの配色の小さな見本、右に名前と説明。
class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.theme,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppThemeData theme;

  /// このテーマの、いまの表示モードでの配色(見本に使う)。
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette current = AppPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(current.radiusCard);

    return Container(
      decoration: BoxDecoration(
        color: current.surface,
        borderRadius: radius,
        border: Border.all(
          color: selected ? current.accent : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: current.raisedShadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _ThemePreview(palette: palette),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.label,
                        style: AppFonts.displayStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: current.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: current.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Symbols.radio_button_checked_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  color: selected ? current.accent : current.textFaint,
                  fill: selected ? 1 : 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// テーマの配色を使った小さな見本(地・面・再生ボタン・下タブ)。
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(palette.radiusArtLarge),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(palette.radiusChip / 2),
              boxShadow: palette.raisedShadows
                  .map((s) => s.scale(0.3))
                  .toList(),
            ),
            alignment: Alignment.centerRight,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: palette.playGradient,
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: Container(
              width: 30,
              height: 10,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: palette.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('自動'),
          icon: Icon(Symbols.brightness_auto_rounded, size: 18),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('ライト'),
          icon: Icon(Symbols.light_mode_rounded, size: 18),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('ダーク'),
          icon: Icon(Symbols.dark_mode_rounded, size: 18),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
