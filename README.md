# localyt_music

YouTubeのプレイリストをダウンロードし、ローカル環境で音楽として再生するためのFlutterアプリです。
Flutter（Dart）によるUIと、ネイティブAndroid（Kotlin）によるYouTube-DL／FFmpeg連携で構成されています。

## 主な機能

- youtube-dl-android を利用したYouTubeプレイリストのダウンロード
- FFmpegによる動画ファイルからMP3への変換
- just_audio によるバックグラウンド再生対応の音楽プレイヤー
- プレイリストのローカル管理（保存・一覧表示）

## 構成
- 主な依存ライブラリ
  - `youtube-dl-android` v0.18.1: 動画ダウンロード
  - `ffmpeg-kit` v6.1.1: 音声変換
  - `smart-exception-java`: 例外処理

## セットアップ

```bash
flutter pub get
```

## 開発・実行

```bash
flutter analyze
flutter run
flutter run --release
```

## テスト

```bash
flutter test
```

ダウンロード機能のテストは `TestDownloadScreen` を利用します（`main.dart` でコメントアウトを解除）。

## ストレージとパーミッション

- 保存先: `/storage/emulated/0/Download/localyt_music/{playlist_name}/`
- プレイリストURLはSharedPreferencesに保存（キー = プレイリスト名）
- 必要な権限（AndroidManifest.xml）
  - `INTERNET`: コンテンツのダウンロード
  - `WRITE_EXTERNAL_STORAGE`: ファイルの保存
  - `WAKE_LOCK`, `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`: バックグラウンド再生
  - `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: 音声再生サービス

## 著作権に関する注意

本アプリはYouTube動画のダウンロード・MP3変換機能を含みますが、これは**個人の私的利用を目的としたもの**です。

- ダウンロードしたコンテンツの著作権は、各コンテンツの権利者に帰属します。
- 著作権者の許諾を得ていない音楽・動画のダウンロードや、ダウンロードしたコンテンツの複製・配布・公開・商用利用は、著作権法その他の法令に違反する可能性があります。
- YouTubeの利用規約（Terms of Service）では、明示的に許可された場合を除き、動画・音楽のダウンロードを禁止しています。本アプリの利用にあたっては、利用者ご自身がYouTubeの利用規約を確認し、遵守してください。
- 本アプリの利用により生じたいかなる法的責任についても、開発者は一切の責任を負いません。利用は自己責任で行ってください。
- 本アプリは個人の学習・検証目的で開発されたものであり、Google LLCおよびYouTubeとは無関係です。「YouTube」は Google LLC の商標です。

## 注意
youtubeからのダウンロードはyoutube-dl-androidに依存しています。今後ダウンロード機能が動作しなくなる可能性があります