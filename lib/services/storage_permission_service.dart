import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// 全ファイルアクセス(MANAGE_EXTERNAL_STORAGE)の状態確認と要求を行うサービス。
///
/// ダウンロード済みファイルは公開Downloadフォルダに直接書き込まれ、MediaStore上の
/// 所有者がNULLになるため、スコープドストレージ(Android 11+)では自アプリでも
/// 削除・リネームができない。全ファイルアクセスを付与することでFile API経由の
/// 削除・リネームが確実に動作するようになる。
class StoragePermissionService {
  static const MethodChannel _channel = MethodChannel(
    'com.kuroinusan.localyt_music/youtubedl',
  );

  /// 全ファイルアクセスが付与されているか。Android 10以下は常にtrue。
  Future<bool> hasAllFilesAccess() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>(
        'hasAllFilesAccess',
      );
      return granted ?? false;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to check all-files access',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// 全ファイルアクセスの許可画面(システム設定)を開く。
  Future<void> requestAllFilesAccess() async {
    try {
      await _channel.invokeMethod('requestAllFilesAccess');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to request all-files access',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
