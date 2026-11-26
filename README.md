# スポットマップ

A new Flutter project.

## ブランチについて

- **`main`**：計測機能を追加する前の基本バージョン
- **`test_map_analytics`**：`main` をベースに、GA4・Firebase Analyticsによる利用状況の計測を追加したバージョン

### `test_map_analytics` の主な変更点

- マップ画面の表示、ピンのタップ、WebViewを開く操作、WebView内のページ表示を計測します。
- Firebase AnalyticsのApp Instance IDをWebView内のページに渡し、アプリとWebの計測をつなぎます。アプリが生成するInstallation IDも計測に使用します。
- ホームのログイン・新規登録をFirebase Authenticationに切り替えました。
- 計測の仕組みを説明するドキュメントと、イベント送信やID連携を確認するテストを追加しました。

### 関連ドキュメント

- [GA4計測マニュアル](docs/ga4_webview_tracking_manual.md) — iOSでのWebView計測の仕組みと確認手順
- [計測関連コード一覧](docs/analytics_code_inventory.md) — 関連ファイル、イベント、パラメータの一覧
- [操作別コードマニュアル（旧版）](docs/user_operation_code_manual.md) — 計測追加前のアプリ操作や実装を確認するための資料

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 開発環境

### Flutter / Dart

- Flutter：3.35.6
- Flutter Channel：stable
- Dart：3.9.2

### 開発ツール

- Xcode：26.4
- CocoaPods：1.16.2

### 対応プラットフォーム

- iOS
- Minimum Deployment Target：iOS 15.0

## 主要パッケージ

以下の主要パッケージを使用しています。

| パッケージ | 用途 |
|---|---|
| google_maps_flutter | Google Maps表示 |
| geolocator | 現在位置取得 |
| shared_preferences | 端末内データ保存 |
| webview_flutter | Webページ表示 |
| url_launcher | 外部URL起動 |
| http | API通信 |

## 動作条件

### Google Mapsの地図表示キー

リポジトリのルートに `MapsKeys.xcconfig` を作り、各行の `=` の右側に対象プラットフォームのキーを設定します。このファイルはGitの追跡対象外です。

```text
GOOGLE_MAPS_ANDROID_API_KEY =
GOOGLE_MAPS_IOS_API_KEY =
```

スポット検索用の `GOOGLE_PLACES_API_KEY` は、起動時に `--dart-define` で渡します。

### 実行環境

本アプリでは以下の環境・機能を必要とします。

- iOS端末
- iOS 15.0以上
- インターネット接続
- 位置情報サービス

※インターネット接続は地図表示や店舗検索に使用します。  
※位置情報サービスは現在地取得機能で使用します。
