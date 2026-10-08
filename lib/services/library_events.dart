import 'package:flutter/foundation.dart';

/// プレイリストの追加・削除・名前変更・更新・並べ替えを、表示中の画面へ知らせる。
///
/// ホームとライブラリはタブとして生き続けるため、別の画面で起きた変更を
/// ここで受け取って読み込み直す。
class LibraryEvents extends ChangeNotifier {
  LibraryEvents._();

  static final LibraryEvents instance = LibraryEvents._();

  void notifyChanged() => notifyListeners();
}
