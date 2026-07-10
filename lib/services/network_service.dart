import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// 端末の現在のネットワーク種別。
///
/// ネイティブ側の `getNetworkType` メソッドが返す文字列
/// ("wifi" / "mobile" / "none" / "other") と対応する。
enum NetworkType { wifi, mobile, none, other }

/// ネイティブ側(MethodChannel)からネットワーク種別を取得するサービス。
class NetworkService {
  static const MethodChannel _channel = MethodChannel(
    'com.kuroinusan.localyt_music/youtubedl',
  );

  /// 現在のネットワーク種別を取得する。
  ///
  /// ネイティブ呼び出しで例外が発生した場合や、想定外の値が
  /// 返ってきた場合は安全側に倒して [NetworkType.other] を返す。
  Future<NetworkType> getNetworkType() async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'getNetworkType',
      );
      switch (result) {
        case 'wifi':
          return NetworkType.wifi;
        case 'mobile':
          return NetworkType.mobile;
        case 'none':
          return NetworkType.none;
        case 'other':
          return NetworkType.other;
        default:
          return NetworkType.other;
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to get network type',
        error: e,
        stackTrace: stackTrace,
      );
      return NetworkType.other;
    }
  }
}
