import 'package:flutter/material.dart';
import 'package:localyt_music/services/storage_permission_service.dart';

/// 全ファイルアクセスが未許可の場合に、許可を促すダイアログを表示して
/// システム設定画面へ誘導する。
///
/// 既に許可済みなら何もせず即座に true を返す。戻り値は「許可されている
/// (=処理を続行してよい)」かどうか。設定画面から戻った後に再確認する。
Future<bool> ensureAllFilesAccess(BuildContext context) async {
  final StoragePermissionService service = StoragePermissionService();

  if (await service.hasAllFilesAccess()) return true;
  if (!context.mounted) return false;

  final bool? openSettings = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('ファイルアクセスの許可'),
        content: const Text(
          'ダウンロード済みファイルの削除やプレイリスト名の変更を行うには、'
          '「すべてのファイルへのアクセス」の許可が必要です。\n\n'
          '設定画面で本アプリの許可をオンにしてください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('あとで'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('設定を開く'),
          ),
        ],
      );
    },
  );

  if (openSettings == true) {
    await service.requestAllFilesAccess();
  }

  // 設定画面から戻ってきた時点での許可状態を返す(まだ許可していなければ false)。
  return service.hasAllFilesAccess();
}
