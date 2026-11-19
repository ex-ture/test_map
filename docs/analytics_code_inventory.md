# Analytics関連コード・ファイル一覧

更新日: 2026-10-30。現在のローカルコードを基準に整理。生成済みSDK・Podsの内部コードは対象外です。GTM管理画面の設定や本番配信内容を取得した一覧ではありません。

## 1. 実装ファイル

ファイル一覧は相対パスです。処理の開始行へ移動するリンクは[GA4計測マニュアル・第3章](ga4_webview_tracking_manual.md#section-3)にまとめています。

| ファイル | 主なコード | 役割 |
| --- | --- | --- |
| [analytics_service.dart](../lib/services/analytics_service.dart) | `AnalyticsService`、`FirebaseAnalyticsService`、`FirebaseAnalyticsGateway`、`DefaultFirebaseAnalyticsGateway` | イベント名・パラメータを組み立て、Firebase Analytics SDKへ渡す中心部分 |
| [webview_screen_view.dart](../lib/services/webview_screen_view.dart) | `WebViewScreenView.tryParse`、`screenName`、`parameters` | 新SVのURL検証・正規化、web:pathとwv_page_*の生成 |
| [app_instance_id_service.dart](../lib/services/app_instance_id_service.dart) | `getAppInstanceId` | SDK管理のApp Instance IDを取得 |
| [webview_page.dart](../lib/pages/05_webview/webview_page.dart) | `initState`、`_parseAnalyticsMessage`、`_validPagePath`、`_onAnalyticsMessage` | Channel登録、JSON解析、DOM状態・URL・文書世代の検証、文書につき1回のWebページSVと既存イベント送信 |
| 同上 | `_notifyAppIdentity`、`_loadPage`、遷移コールバック | WebへのID通知、URL生成、読み込み・受付状態の管理 |
| [installation_id_service.dart](../lib/services/installation_id_service.dart) | `InstallationIdService.getInstallationId` | UUID v4を生成しSharedPreferencesに保存。メモリキャッシュと同時取得の共有あり |
| [webview_url_builder.dart](../lib/services/webview_url_builder.dart) | `buildWebViewUrl` | 許可された表示先URLに`installation_id`・ログイン中の`auth_uid`を付加 |
| [place_urls.dart](../lib/constants/place_urls.dart) | `firebaseHostingWebUrl` | 初期表示先`https://corp.ex-ture.com/`。URLへのID付加とWebへのID通知にも使用 |
| [main.dart](../lib/main.dart) | `main`、`MyApp`、`onGenerateRoute` | Firebase初期化、AnalyticsServiceの生成・各画面への注入 |
| [main_shell.dart](../lib/pages/03_main_shell/main_shell.dart) | `analyticsService` | マップ画面へServiceを引き渡す |
| [map_page.dart](../lib/pages/04_map/map_page.dart) | `logScreenView(AnalyticsScreen.map)`、`logAction(AnalyticsAction.pinTap)` | マップ初回・タブ再アクティブ・ピンタップを記録。詳細表示にもServiceを渡す |
| [place_bottom_sheet.dart](../lib/pages/04_map/widgets/place_bottom_sheet.dart) | `_openInAppWebView` | 開く操作を記録し、WebView終了待ち後にmap SVを1回記録 |
| [public/index.html](../public/index.html) | GTM読み込み、`window.pushAppIdentity` | URLのIDを読み、`app_identity_ready`をdataLayerへpushするローカルのWeb実装 |

## 2. イベントとパラメータ

アプリが明示的に記録するイベントの一覧です。SDKの自動収集イベントは含めません。

| イベント | 呼び出し | 明示的に渡す値 |
| --- | --- | --- |
| `screen_view`（Map） | `logScreenView(AnalyticsScreen.map)` | screenName=`map`、`installation_id`、ログイン中のみ`auth_uid`。初回・タブ再アクティブ・WebView終了後 |
| `screen_view`（Webページ） | `logWebViewScreenView(page)` | screenName=`web:/case`等、screenClass=`WebViewPage`、`wv_page_location`・`wv_page_title`・`wv_page_referrer`と共通パラメータ |
| `action_event` | `logAction(AnalyticsAction.pinTap / webviewOpen)` | `action_name`=`pin_tap`または`webview_open`、`installation_id`、ログイン中のみ`auth_uid` |
| `webview_bridge_test` | `logWebViewBridgeTest()` | `installation_id`、ログイン中のみ`auth_uid` |
| `wv_page_view` | `logWebViewPageView(pagePath: ...)` | `page_path` |

`_commonParameters()`は`installation_id`をSDKのデフォルトイベントパラメータにも設定します。したがって、`wv_page_view`の呼び出しで明示的に渡す値は`page_path`だけですが、先に設定されたデフォルトの`installation_id`が適用される可能性があります。`wv_page_view`自身は`_commonParameters()`を呼びません。

`app_identity_ready`はWebのdataLayerイベントです。この名前でFlutterがFirebase Analyticsへ直接送信する実装ではありません。

## 3. WebView → GA4の流れ

WebView生成時の箱SVは削除済みです。新しい`wv_screen_view`通知は`logWebViewScreenView` → Gatewayの`logScreenView` → `FirebaseAnalytics.instance.logScreenView`へ進みます。`AnalyticsScreen.webview`のenum定義が残っていても、生成時に呼び出す処理はありません。

以下は維持した`wv_page_view`の経路です。

```text
GTM / WebのJavaScript
  → window.AppAnalytics.postMessage(文字列)
  → onMessageReceived（受信ログ）
  → _parseAnalyticsMessage（形式検証）
  → _onAnalyticsMessage（状態・URL・DOM・page_path検証）
  → AnalyticsService.logWebViewPageView(pagePath: ...)
  → FirebaseAnalyticsService
  → DefaultFirebaseAnalyticsGateway.logEvent
  → FirebaseAnalytics.instance.logEvent
  → GA4
```

Channelは初回ロード前に登録します。既存`wv_page_view`は同じ文書内でも複数回処理し、重複抑止はありません。新しい`wv_screen_view`だけは`_documentVersion`ごとに1回受理します。拒否したメッセージを保留・再送する仕組みはありません。

### 新SVの受信形式

```javascript
window.AppAnalytics.postMessage(JSON.stringify({
  event: 'wv_screen_view',
  page_location: window.location.href,
  page_title: document.title,
  page_referrer: document.referrer
}));
```

- JSON全体2048 UTF-16コード単位以内、上記4フィールドのみ。3項目は文字列必須。
- locationはHTTPSの許可originかつ現在URIと一致する必要がある。比較は正規化前。
- titleは空を許容。referrerも空を許容し、非空ならuserinfoなしの有効なHTTP／HTTPS URLが必要。不正値は通知ごと拒否。
- 保存URLはorigin＋pathで再構成し全query・fragmentを除く。各値は最大100 Unicodeコードポイント。pathは保持する。
- 送信名は`web:`＋path。保存キーは`wv_page_location`・`wv_page_title`・`wv_page_referrer`。
- 受理済み世代を非同期送信前に予約し、並行通知を抑止。`onPageStarted`で世代が増えるため、同URLの新文書や`/a → /b → /a`も送れる。URL単位の永続抑止ではない。
- 新旧イベントは独立しており、片方の受信からもう片方を追加生成しない。SPA専用通知・閲覧IDは未導入。

### 既存PVの受信形式

JSON形式:

```javascript
window.AppAnalytics.postMessage(JSON.stringify({
  event: 'wv_page_view',
  page_path: '/case'
}));
```

現在のWebView URLのpathが`/case`である場合に処理します。

互換形式:

```javascript
window.AppAnalytics.postMessage('wv_page_view');
window.AppAnalytics.postMessage('bridge_test');
```

旧`wv_page_view`は現在URLのpathを使用します。空pathは`/`とし、query・fragmentは含めません。`bridge_test`は従来どおり`webview_bridge_test`を記録します。

### 既存wv_page_viewのJSON・page_pathの検証

- JSON解析前の文字列上限は2,048（Dartの`String.length`）。壊れたJSONは拒否。
- JSONはオブジェクトで、`event`と`page_path`の2フィールドのみ。追加フィールドも拒否。
- JSONの`event`は`wv_page_view`のみ。JSON形式の`bridge_test`は許可しない。
- `page_path`は文字列で、長さ1〜100（DartのUTF-16コード単位数）。切り詰めず拒否する。
- `/`で始まり、`//`で始まらない。空白・制御文字・`?`・`#`・バックスラッシュを拒否。
- 現在URLから取得したpath（空なら`/`）との完全一致が必要。末尾スラッシュや表記差を独自に補正しない。
- 検証済みの値だけを渡し、受信JSON全体をAnalyticsパラメータに展開しない。

### 安全条件とDOM受付状態

`mounted`、表示中のroute、エラーなし、許可メッセージ、現在URL取得、許可オリジン、userInfoなし、`_documentVersion`一致、`_pageReady`を確認します。

許可オリジンは`WebViewScreenView.allowedOrigins`で定義し、`webview_page.dart`の`_analyticsAllowedOrigins`も同じ定義を参照します。

- `https://corp.ex-ture.com`
- `https://ex-ture.com`

scheme・host・実効portが同じ許可エントリに一致する必要があります。HTTP、未許可サブドメイン、別port、userInfo付きURLは拒否します。HTTPSの明示的な443は許可されます。

`onPageStarted`で文書番号を増やし、`_pageReady=false`に戻します。許可メッセージ受信時にまだfalseなら、URL等を検証してから`runJavaScriptReturningResult('document.readyState')`を実行します。`interactive`または`complete`なら受付可能にし、その受信イベントを処理します。`loading`は拒否します。

非同期処理後も状態・文書番号を再確認するため、確認中に始まった次の文書へ古い処理を持ち越しません。`onPageFinished`は読み込み表示終了・ID通知と、エラーがない場合の受付開始のフォールバックです。

## 4. ID連携の範囲

`installation_id`は`InstallationIdService`が保存・再利用し、`auth_uid`はFirebase Authの現在ユーザーから取得します。Analyticsの共通パラメータでは、UIDがnullまたは空文字なら付けません。

ここはWebViewブリッジの2オリジン許可と範囲が異なります。

| 処理 | 現在の対象 |
| --- | --- |
| ブリッジ受信 | `corp.ex-ture.com`と`ex-ture.com` |
| `buildWebViewUrl`によるID付加 | `firebaseHostingWebUrl`とscheme・host・portが一致しuserInfoがないURL（現在は`corp.ex-ture.com`） |
| `_notifyAppIdentity`による`pushAppIdentity`実行 | `firebaseHostingWebUrl`のoriginと既存の2許可origin。Webに受け取り関数があること |

`buildWebViewUrl`は既存queryを維持しつつIDを設定し、古い`auth_uid`は除去します。リダイレクト後のID保持は、この関数だけでは保証されません。

`public/index.html`はHosting用サンプルです。WebViewでは`app_identity_request`を送り、FlutterのSDK ID通知後に`app_identity_ready`をpushします。Flutterは`_identitySent`・`_identityInFlight`で文書内の通知を抑止し、同じ保持文書への復帰でも成功済みなら再通知しません。このID通知状態は新SVの重複抑止とは別です。本番Web/GTMの現行状態はこのローカルサンプルからは断定しません。

## 5. Firebase・依存関係の関連ファイル

| ファイル | 役割 |
| --- | --- |
| [firebase_options.dart](../lib/firebase_options.dart) | Firebase初期化のプラットフォーム別設定 |
| [pubspec.yaml](../pubspec.yaml)、[pubspec.lock](../pubspec.lock) | Firebase Analytics・WebView等の依存宣言と解決済みバージョン |
| [Runner.xcscheme](../ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme) | iOS起動引数`-FIRDebugEnabled`の設定箇所 |

Firebaseプラグイン登録ファイルは生成物です。通常、イベント追加の編集対象にはしません。

## 6. 関連テスト

| ファイル | 主な確認対象 |
| --- | --- |
| [analytics_service_test.dart](../test/analytics_service_test.dart) | イベント名、ページSVの画面名・クラス・正規化パラメータ、既存PV、共通ID |
| [webview_page_test.dart](../test/webview_page_test.dart) | 新旧JSON、URL整合性、origin、DOM、文書世代、新SVの並行重複・同URL再読み込み、既存PV・ID通知 |
| [map_page_initial_place_test.dart](../test/map_page_initial_place_test.dart) | Map初回・タブ再アクティブ・WebView終了後のSV回数、無効化された呼び出し元、既存操作計測 |
| [installation_id_service_test.dart](../test/installation_id_service_test.dart) | ID生成・保存・再利用 |
| [webview_url_builder_test.dart](../test/webview_url_builder_test.dart) | URLへのID付加、UID除去、対象外URL |
| [web_identity_test.cjs](../test/web_identity_test.cjs) | WebのdataLayerへのID通知と重複抑止 |

```sh
flutter test --no-pub test/analytics_service_test.dart test/webview_page_test.dart test/map_page_initial_place_test.dart test/main_shell_test.dart test/app_instance_id_service_test.dart test/webview_url_builder_test.dart
node --test test/web_identity_test.cjs
flutter analyze --no-pub
```

今回のMarkdown更新ではテストを再実行していません。直前のWebページSV実装時は上記Flutter関連97件・Web Identity 4件成功、analyze指摘なしでした。Fakeを含むため、実機のGA4配送確認とは別です。

## 7. 実機で見るログ

| ログ | 読み取り方 |
| --- | --- |
| `AppAnalytics received` | FlutterのChannel受信まで到達 |
| `rejected before URL lookup` | メッセージ形式・mounted・route・エラー状態で拒否 |
| `currentUrl lookup started / completed` | URL取得の前後 |
| `DOM readiness checked` | DOM判定結果と受付状態 |
| `rejected after URL lookup` | オリジン・DOM・文書変更などの安全条件で拒否 |
| `rejected page_path` | path不正または現在URLとの不一致 |
| `checks passed` → `sending wv_page_view` | 検証を通過しService呼び出しへ。送信ログに`page_path`を表示 |
| `calling FirebaseAnalytics.instance.logEvent` | SDK呼び出し直前 |
| `gateway logEvent completed` | SDK呼び出し完了。GA4到達の確認ではない |

表示中のpathを使う確認例:

```javascript
window.AppAnalytics.postMessage(JSON.stringify({
  event: 'wv_page_view',
  page_path: window.location.pathname
}));
```

許可されたHTTPSオリジン・DOM利用可能・検証に通るpathで実行し、GA4 DebugViewでは`wv_page_view`の`page_path`を確認します。この既存PV形式への`page_title`追加は拒否します。ページ情報3項目は新しい`wv_screen_view`形式で受信します。新SVでは`checks passed`後にもURL一致・重複確認があるため、このログだけでSV送信成功とは判断できません。
