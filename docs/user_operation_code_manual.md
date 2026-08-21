# スポットマップ 操作別コードマニュアル

この文書は、アプリ利用者が画面で行う操作を起点に、裏側でどの Flutter/Dart コードが動くかを説明する技術マニュアルです。利用方法だけでなく、状態管理、ローカル保存、Google Places API、画面遷移の流れも追えるようにしています。

コード抜粋は、処理の流れを理解しやすいように一部だけを掲載しています。実際の最新コードは、各節の「関連コード」に記載したファイルを参照してください。

「関連コード」は、まず関連するファイルを列挙し、その下に主な関数・変数を処理の流れに沿って列挙します。ファイルパスと関数名・変数名は同じ階層に混ぜません。

## 目次

- [1. アプリ全体の構成](#1-アプリ全体の構成)
- [2. ファイルごとの役割](#2-ファイルごとの役割)
- [3. 起動時の画面判定](#3-起動時の画面判定)
- [4. チュートリアル](#4-チュートリアル)
  - [4.1 「次へ」ボタン](#41-次へボタン)
  - [4.2 「スキップ」「はじめる」ボタン](#42-スキップはじめるボタン)
- [5. ホームとローカル認証](#5-ホームとローカル認証)
  - [5.1 ホーム表示](#51-ホーム表示)
  - [5.2 新規登録](#52-新規登録)
  - [5.3 ログイン](#53-ログイン)
  - [5.4 ログアウト](#54-ログアウト)
  - [5.5 パスワード表示切替](#55-パスワード表示切替)
- [6. タブ操作](#6-タブ操作)
- [7. マップ画面](#7-マップ画面)
  - [7.1 マップ初期表示と現在地取得](#71-マップ初期表示と現在地取得)
  - [7.2 検索欄に文字を入力する](#72-検索欄に文字を入力する)
  - [7.3 検索を実行する](#73-検索を実行する)
  - [7.4 候補をタップする](#74-候補をタップする)
  - [7.5 クリアボタン](#75-クリアボタン)
  - [7.6 フィルターボタン](#76-フィルターボタン)
  - [7.7 地図上のピンをタップする](#77-地図上のピンをタップする)
  - [7.8 地図の空き場所をタップする](#78-地図の空き場所をタップする)
- [8. スポット詳細ボトムシート](#8-スポット詳細ボトムシート)
  - [8.1 「他のアプリで開く」](#81-他のアプリで開く)
  - [8.2 「アプリ内で開く」](#82-アプリ内で開く)
  - [8.3 「ルートを見る」](#83-ルートを見る)
- [9. 履歴画面](#9-履歴画面)
  - [9.1 履歴を開く](#91-履歴を開く)
  - [9.2 履歴カードまたは「マップで開く」を押す](#92-履歴カードまたはマップで開くを押す)
- [10. データ保存仕様](#10-データ保存仕様)
  - [10.1 ローカル認証](#101-ローカル認証)
  - [10.2 チュートリアル完了状態](#102-チュートリアル完了状態)
  - [10.3 スポット閲覧履歴](#103-スポット閲覧履歴)
- [11. Google Places API との連携](#11-google-places-api-との連携)
  - [11.1 APIキーの準備と取り扱い](#111-apiキーの準備と取り扱い)
- [12. 主要な操作とコードの対応表](#12-主要な操作とコードの対応表)
- [13. テストで確認されている主な動作](#13-テストで確認されている主な動作)
- [14. 運用上の注意](#14-運用上の注意)
- [15. コード最適化の記録](#15-コード最適化の記録)
  - [15.1 Google Places API通信処理の共通化](#151-google-places-api通信処理の共通化)
  - [15.2 マップ検索の非同期リクエスト管理強化](#152-マップ検索の非同期リクエスト管理強化)
  - [15.3 マップのフィルターUIを専用Widgetへ分離](#153-マップのフィルターuiを専用widgetへ分離)
  - [15.4 履歴カードの営業状態表示の整理](#154-履歴カードの営業状態表示の整理)

## 1. アプリ全体の構成

アプリの入口は `lib/main.dart` の `MyApp` です。`MaterialApp` がルート名を受け取り、`onGenerateRoute` で表示する画面を決めます。

主なルートは次の通りです。

| ルート | 画面 | 主なファイル |
| --- | --- | --- |
| `/` | 初回起動判定 | `lib/pages/00_root/root_page.dart` |
| `/tutorial` | チュートリアル | `lib/pages/01_tutorial/tutorial_page.dart` |
| `/main-shell` | ホーム、マップ、履歴のタブ画面 | `lib/pages/03_main_shell/main_shell.dart` |
| `/map` | マップタブを開いた状態のメイン画面 | `lib/main.dart`, `MainShell` |
| `/webview` | アプリ内 Web 表示 | `lib/pages/05_webview/webview_page.dart` |

`MainShell` は `IndexedStack` で次の3タブを保持します。

| タブ | 画面 | 主な責務 |
| --- | --- | --- |
| ホーム | `HomePage` | ローカル認証の登録、ログイン、ログアウト |
| マップ | `MapPage` | 現在地取得、検索、候補表示、ピン表示、詳細表示 |
| 履歴 | `SettingsPage` + `PlaceHistoryContent` | 閲覧済みスポットの一覧、マップで再表示 |

該当コードの抜粋（lib/main.dart）:

```dart
return MaterialApp(
  title: 'スポットマップ',
  initialRoute: AppRoutes.root,
  onGenerateRoute: (RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const RootPage(),
        );
      case AppRoutes.mainShell:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MainShell(),
        );
    }
  },
);
```

変数と関数の意味:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `MaterialApp` | Widget | アプリ全体のテーマ、ルート、画面遷移を管理する Flutter の基本 Widget です。 |
| `title` | `String` | アプリ名です。OS やタスクスイッチャーなどで参照されます。 |
| `initialRoute` | `String` | 起動時に最初に開くルート名です。ここでは `/` を示す `AppRoutes.root` です。 |
| `onGenerateRoute` | 関数 | ルート名に応じて、実際に表示する画面を作る関数です。 |
| `settings.name` | `String?` | 遷移先として指定されたルート名です。 |
| `MaterialPageRoute` | Flutter API | 1画面分の遷移ルートを作るクラスです。 |
| `builder` | 関数 | ルートが表示する Widget を生成します。 |
| `RootPage` | Widget | 起動時にチュートリアルへ行くかメイン画面へ行くかを判定する画面です。 |
| `MainShell` | Widget | ホーム、マップ、履歴の3タブを持つメイン画面です。 |

## 2. ファイルごとの役割

この章では、以降の操作説明で出てくる主要ファイルの役割を先に整理します。画面、状態管理、保存、外部API連携のどこを担当しているかを把握しておくと、各操作の処理の流れを追いやすくなります。

| ファイル | 役割 |
| --- | --- |
| `lib/main.dart` | アプリ起動点です。`MaterialApp`、テーマ、ルート定義、画面遷移先の生成を担当します。 |
| `lib/routes/app_routes.dart` | ルート名の定数を集約します。`/`, `/tutorial`, `/main-shell`, `/map`, `/webview` をここで定義します。 |
| `lib/pages/00_root/root_page.dart` | 初回起動時の振り分け画面です。チュートリアル完了状態を読み、チュートリアルまたはメイン画面へ遷移します。 |
| `lib/pages/01_tutorial/tutorial_page.dart` | チュートリアル画面です。ページ送り、スキップ、開始、チュートリアル完了保存を担当します。 |
| `lib/pages/03_main_shell/main_shell.dart` | メイン画面のタブ管理です。ホーム、マップ、履歴の切り替え、検索条件の共有、履歴からマップを開く処理を担当します。 |
| `lib/pages/03_main_shell/home_page.dart` | ホーム画面とローカル認証UIです。登録、ログイン、ログアウト、パスワード表示切替、認証状態表示を担当します。 |
| `lib/repositories/mock_auth_repository.dart` | ローカルモック認証の保存層です。アカウント一覧、ログイン状態、ログイン中メールアドレスを `SharedPreferences` に読み書きします。 |
| `lib/pages/04_map/map_page.dart` | マップ画面の中心です。現在地取得、検索実行、候補取得、フィルター、Marker生成、詳細ボトムシート表示、履歴保存呼び出しを担当します。 |
| `lib/pages/04_map/widgets/map_search_bar.dart` | マップ上部の検索欄です。検索送信、クリア、検索中表示、入力変更通知を担当します。 |
| `lib/pages/04_map/widgets/map_filter_sheet.dart` | マップのフィルターシートです。距離、最大件数、営業中のみの表示、一時設定の保持、変更した設定の通知を担当します。 |
| `lib/pages/04_map/widgets/place_bottom_sheet.dart` | スポット詳細ボトムシートです。外部アプリで開く、アプリ内WebViewで開く、ルート表示を担当します。 |
| `lib/pages/04_map/map_camera_bounds.dart` | 複数スポットを地図内に収めるための `LatLngBounds` 計算を担当します。 |
| `lib/pages/05_webview/webview_page.dart` | アプリ内WebView画面です。URL読み込み、読み込み中表示、遷移制御、読み込みエラー表示を担当します。 |
| `lib/pages/06_settings/settings_page.dart` | 履歴画面の外枠です。現在は設定画面ではなく、`PlaceHistoryContent` を表示する履歴タブとして使われています。 |
| `lib/pages/02_top/widgets/place_history_content.dart` | 履歴一覧の中身です。履歴読み込み、履歴がない場合の画面、履歴カード表示、マップで開く操作を担当します。 |
| `lib/repositories/place_history_repository.dart` | スポット閲覧履歴の保存層です。`Place` をJSON文字列化し、`SharedPreferences` の `place_view_history` に最大20件保存します。 |
| `lib/repositories/place_repository.dart` | 場所検索リポジトリのインターフェースです。マップ画面はこの抽象型を通して検索処理を呼びます。 |
| `lib/repositories/google_places_repository.dart` | Google Places API連携です。Text Search、Autocomplete、レスポンスの `Place` / `PlaceSuggestion` 変換を担当します。 |
| `lib/models/place.dart` | スポット情報のモデルです。ID、名称、説明、緯度経度、URL、営業中状態を持ちます。 |
| `lib/models/place_suggestion.dart` | 検索候補のモデルです。候補文字列、候補種別、Place IDを持ちます。 |
| `lib/models/search_settings.dart` | 検索条件のモデルです。検索距離、最大件数、営業中のみの設定を持ちます。 |
| `lib/constants/place_urls.dart` | スポットURLの定数を置くファイルです。現在はプレースホルダーURLを提供します。 |

lib以外で、アプリ機能に関係する手動設定ファイルは次の通りです。自動生成ファイル、テスト、表示名だけの変更は含めません。

| ファイル | 役割 |
| --- | --- |
| `pubspec.yaml` | 地図表示、現在地取得、ローカル保存、HTTP通信、外部アプリ起動、アプリ内WebViewに必要なパッケージ依存関係を定義します。 |
| `ios/Runner/Info.plist` | iOSで現在地取得を行うための利用目的文言を定義します。`geolocator` が位置情報権限を要求するとき、この文言がOSの許可ダイアログに使われます。 |
| `android/app/src/main/AndroidManifest.xml` | Androidで現在地取得に必要な位置情報権限と、Google Maps SDKに渡すAPIキー設定を定義します。 |
| `.vscode/launch.json` | VS Codeからアプリを起動するときの実行設定です。Google Places APIキーを `--dart-define=GOOGLE_PLACES_API_KEY=...` でアプリへ渡します。 |

## 3. 起動時の画面判定

### ユーザー操作

アプリを起動します。

### 表示される動き

初回起動ではチュートリアルが表示されます。チュートリアル完了後は、次回以降ホームを含むメイン画面が表示されます。

### 裏側のコード

処理の流れ:

1. `MaterialApp` の `initialRoute` により、最初に `RootPage` が生成されます。
2. `RootPage.initState()` は画面構築直後に一度だけ実行されます。
3. `addPostFrameCallback` を使い、初回描画が終わった後に `_routeToFirstScreen()` を実行します。画面構築中に `Navigator` を動かすと不安定になるため、このタイミングに遅らせています。
4. `_routeToFirstScreen()` は `SharedPreferences` を開き、`tutorial_completed` を読み込みます。
5. 保存値がない場合は `false` とみなし、初回起動として扱います。
6. `tutorial_completed` が `true` なら遷移先を `AppRoutes.mainShell`、`false` なら `AppRoutes.tutorial` に決めます。
7. 非同期読み込み中に `RootPage` が破棄されていた場合は、`mounted` 判定で何もせず終了します。
8. `RootPage` がまだ有効なら `pushReplacementNamed()` を呼び、現在の `/` ルートを判定後のルートへ置き換えます。
9. 置き換え遷移なので、起動判定だけの `RootPage` は戻り履歴に残りません。

該当コードの抜粋（lib/pages/00_root/root_page.dart）:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _routeToFirstScreen();
  });
}

Future<void> _routeToFirstScreen() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final bool isTutorialCompleted =
      preferences.getBool(tutorialCompletedPreferenceKey) ?? false;

  if (!mounted) {
    return;
  }

  Navigator.of(context).pushReplacementNamed(
    isTutorialCompleted ? AppRoutes.mainShell : AppRoutes.tutorial,
  );
}
```

変数と関数の意味:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `initState()` | ライフサイクル関数 | `RootPage` が作られた直後に一度だけ呼ばれます。起動時のルート判定を始める入口です。 |
| `WidgetsBinding.instance.addPostFrameCallback` | Flutter API | 初回描画後に処理を実行するための仕組みです。画面構築中に `Navigator` を直接動かさないために使います。 |
| `_routeToFirstScreen()` | 非同期関数 | チュートリアル完了状態を読み、最初に表示する画面を決めます。 |
| `preferences` | `SharedPreferences` | 端末内の簡易保存領域へアクセスするオブジェクトです。 |
| `isTutorialCompleted` | `bool` | `tutorial_completed` が保存済みかどうかです。`null` の場合は `false` として扱います。 |
| `tutorialCompletedPreferenceKey` | `String` 定数 | `SharedPreferences` に保存するキー名です。値は `tutorial_completed` です。 |
| `pushReplacementNamed()` | 画面遷移メソッド | 現在のルートを置き換えて、指定したルートへ移動します。 |

関連コード:

ファイル:

- `lib/pages/00_root/root_page.dart`

主な関数・変数:

- `tutorialCompletedPreferenceKey`
- `_routeToFirstScreen()`
- `markTutorialCompleted()`

### 保存されるデータ

`markTutorialCompleted()` は `SharedPreferences` に次の値を保存します。

| キー | 値 |
| --- | --- |
| `tutorial_completed` | `true` |

## 4. チュートリアル

### 4.1 「次へ」ボタン

#### ユーザー操作

チュートリアル画面で「次へ」を押します。

#### 表示される動き

チュートリアルの次のページへスライドします。ページ下部のドット表示も現在ページに合わせて変わります。

#### 裏側のコード

処理の流れ:

1. `TutorialPage` は `PageController` と `_currentPageIndex` を保持した状態で表示されます。
2. 「次へ」ボタンの `onPressed` が `_nextPage()` を呼びます。
3. `_nextPage()` は現在ページ番号 `_currentPageIndex` を確認します。
4. `_currentPageIndex < 2` の場合だけ `PageController.nextPage()` を呼び、次ページへ遷移します。
5. すでに最後のページの場合、「次へ」ではなく「はじめる」ボタンの処理に切り替わるため、`nextPage()` は呼ばれません。
6. ページ移動が完了すると `PageView.onPageChanged` が新しい `index` を受け取ります。
7. `setState()` で `_currentPageIndex` を更新し、ページ番号に依存するUIを再描画します。
8. 下部ボタンは `_currentPageIndex` を見て、途中ページでは「次へ」、最後のページでは「はじめる」を表示します。
9. `_buildDot(index)` は `_currentPageIndex` と各ドットの `index` を比較し、現在ページだけ幅と色を変えます。

該当コードの抜粋（lib/pages/01_tutorial/tutorial_page.dart）:

```dart
void _nextPage() {
  if (_currentPageIndex < 2) {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

PageView(
  controller: _pageController,
  onPageChanged: (int index) {
    setState(() {
      _currentPageIndex = index;
    });
  },
  children: [...]
)
```

変数と関数の意味:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `_nextPage()` | 関数 | 「次へ」ボタンから呼ばれ、次のチュートリアルページへ進めます。 |
| `_currentPageIndex` | `int` | 現在表示しているチュートリアルページ番号です。0から始まります。 |
| `_pageController` | `PageController` | `PageView` をプログラム側から動かすためのコントローラです。 |
| `nextPage()` | メソッド | 次ページへアニメーション付きで移動します。 |
| `duration` | `Duration` | ページ移動アニメーションの時間です。ここでは250ミリ秒です。 |
| `curve` | `Curve` | アニメーションの速度変化です。`Curves.easeOut` により終わりに近づくほど緩やかになります。 |
| `onPageChanged` | コールバック | ユーザーのスワイプやボタン操作でページが変わった時に呼ばれます。 |

関連コード:

ファイル:

- `lib/pages/01_tutorial/tutorial_page.dart`

主な関数・変数:

- `_TutorialPageState._nextPage()`
- `PageView.onPageChanged`
- `_TutorialPageState._buildDot()`

### 4.2 「スキップ」「はじめる」ボタン

#### ユーザー操作

「スキップ」を押す、または最後のページで「はじめる」を押します。

#### 表示される動き

チュートリアルが完了扱いになり、メイン画面へ移動します。

#### 裏側のコード

処理の流れ:

1. 「スキップ」または最後のページの「はじめる」の `onPressed` が `_goToMap()` を呼びます。
2. `_goToMap()` はチュートリアル完了処理本体の `_markTutorialCompletedAndGoToMap()` に処理を渡します。
3. `_markTutorialCompletedAndGoToMap()` は `markTutorialCompleted()` を `await` し、保存処理が終わるまで遷移を待ちます。
4. `markTutorialCompleted()` は `SharedPreferences` を開き、`tutorial_completed = true` を保存します。
5. 保存完了後、非同期処理中に `TutorialPage` が破棄されていないか `mounted` で確認します。
6. 破棄済みなら `Navigator` を呼ばずに終了します。
7. 画面が有効なら `pushNamedAndRemoveUntil()` で `AppRoutes.mainShell` へ遷移します。
8. 第2引数の `(Route<dynamic> route) => false` により、既存の戻り履歴はすべて削除されます。
9. これにより、チュートリアル完了後に戻る操作でチュートリアルへ戻らず、次回起動時も `RootPage` がメイン画面へ振り分けます。

該当コードの抜粋（lib/pages/01_tutorial/tutorial_page.dart）:

```dart
void _goToMap() {
  _markTutorialCompletedAndGoToMap();
}

Future<void> _markTutorialCompletedAndGoToMap() async {
  await markTutorialCompleted();

  if (!mounted) {
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil(
    AppRoutes.mainShell,
    (Route<dynamic> route) => false,
  );
}
```

変数と関数の意味:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `_goToMap()` | 関数 | チュートリアル終了操作を受け取る入口です。ボタン側から直接呼ばれます。 |
| `_markTutorialCompletedAndGoToMap()` | 非同期関数 | チュートリアル完了状態の保存とメイン画面への遷移をまとめて行います。 |
| `markTutorialCompleted()` | 非同期関数 | `SharedPreferences` に `tutorial_completed = true` を保存します。次回起動時にチュートリアルを飛ばすための処理です。 |
| `mounted` | `State` のプロパティ | この画面の `State` がまだ画面ツリー上に存在するかを示します。非同期処理の後に画面が破棄されていた場合、`Navigator` を呼ばないために確認します。 |
| `AppRoutes.mainShell` | ルート名の定数 | メイン画面を表す文字列です。実体は `/main-shell` です。 |
| `(Route<dynamic> route) => false` | 戻り履歴の判定関数 | 既存の画面履歴を残すか判断する関数です。常に `false` を返すため、過去の画面をすべて削除します。 |

関連コード:

ファイル:

- `lib/pages/01_tutorial/tutorial_page.dart`
- `lib/pages/00_root/root_page.dart`

主な関数・変数:

- `_goToMap()`
- `_markTutorialCompletedAndGoToMap()`
- `markTutorialCompleted()`

## 5. ホームとローカル認証

このアプリの認証は、サーバー認証ではなく端末内のローカルモック認証です。登録情報、ログイン状態は `SharedPreferences` に保存されます。

### 5.1 ホーム表示

#### ユーザー操作

ホームタブを開きます。

#### 表示される動き

ログアウト状態なら「ゲスト」とログイン/新規登録ボタンが表示されます。ログイン状態なら「ログイン中」、表示名、ログアウトボタンが表示されます。

#### 裏側のコード

処理の流れ:

1. ホームタブの `HomePage` が生成されると、`initState()` が一度だけ `_loadSession()` を実行します。
2. `_loadSession()` は `MockAuthRepository.fetchSession()` を呼び、端末内のログイン状態を読み込みます。
3. `fetchSession()` は `SharedPreferences` から `mock_auth_is_logged_in` と `mock_auth_logged_in_email` を取得します。
4. `mock_auth_is_logged_in` が `true` かつメールアドレスがある場合だけ、ログイン中の `MockAuthSession` を返します。
5. どちらかが欠けている場合は、未ログインの `MockAuthSession` として扱います。
6. 読み込み完了時点で `HomePage` が破棄されていれば、`mounted` 判定で画面更新せず終了します。
7. 画面が有効なら `setState()` で `_session` を更新します。
8. `build()` は `_session.isLoggedIn` を見て、ログイン中表示かゲスト表示かを切り替えます。
9. 画面右上のステータス表示と本文の表示名は、同じ `_session.displayName` を参照します。
10. `displayName` はログイン中ならメールアドレスの `@` より前、未ログインなら `ゲスト` を返します。

該当コードの抜粋（lib/pages/03_main_shell/home_page.dart）:

```dart
@override
void initState() {
  super.initState();
  _loadSession();
}

Future<void> _loadSession() async {
  final MockAuthSession session = await _authRepository.fetchSession();
  if (!mounted) {
    return;
  }

  setState(() {
    _session = session;
  });
}
```

変数と関数の意味:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `_authRepository` | `MockAuthRepository` | ローカル認証データを読み書きするリポジトリです。 |
| `_loadSession()` | 非同期関数 | 保存済みログイン状態を取得し、ホーム画面の表示状態を更新します。 |
| `fetchSession()` | 非同期関数 | `SharedPreferences` からログイン中フラグとメールアドレスを読みます。 |
| `session` | `MockAuthSession` | ログイン中かどうか、ログイン中メールアドレスをまとめた状態オブジェクトです。 |
| `_session` | `MockAuthSession` | `HomePage` が現在表示に使っている認証状態です。 |
| `setState()` | Flutter API | `_session` の変更を画面に反映するために再描画を依頼します。 |

関連コード:

ファイル:

- `lib/pages/03_main_shell/home_page.dart`
- `lib/repositories/mock_auth_repository.dart`

主な関数・変数:

- `_HomePageState._loadSession()`
- `_HomePageState._buildLoggedOutContent()`
- `_HomePageState._buildLoggedInContent()`
- `MockAuthRepository.fetchSession()`
- `MockAuthSession.displayName`

### 5.2 新規登録

#### ユーザー操作

「新規登録」を押し、メールアドレス、パスワード、パスワード確認を入力して「登録する」を押します。

#### 表示される動き

入力が正しければアカウントが端末内に保存され、そのままログイン状態になります。同じメールアドレスがすでに登録済みの場合は「すでにアカウントが登録されています」と表示されます。

#### 裏側のコード

処理の流れ:

1. ホームの「新規登録」ボタンが `_showAuthSheet(_AuthFormMode.register)` を呼びます。
2. `_showAuthSheet()` は `showModalBottomSheet` で `_AuthFormSheet` を表示し、登録モードを `mode` として渡します。
3. `_AuthFormSheetState.initState()` は `widget.mode` を `_mode` に保持し、確認用パスワード欄を含む登録用フォームを表示します。
4. 「登録する」を押すと `_submit()` が入力欄の `TextEditingController` からメールアドレス、パスワード、確認用パスワードを読みます。
5. メールアドレスは `trim()` で前後空白を除去し、パスワードは入力値をそのまま扱います。
6. `_validateEmail()` は空欄と `@` 区切りを検証します。
7. `_validatePassword(..., requireMinLength: true)` は空欄と4文字以上を検証します。
8. 登録モードでは、パスワードと確認用パスワードの一致も検証します。
9. 検証結果は `_emailErrorText`、`_passwordErrorText`、`_passwordConfirmationErrorText`、`_formErrorText` に反映されます。
10. 入力検証でエラーがある場合は、`MockAuthRepository` を呼ばずに終了し、入力欄のエラー表示だけを更新します。
11. 入力が有効な場合は `_isSubmitting = true` にして送信ボタンの二重押しを防ぎます。
12. `isEmailRegistered()` で同じメールアドレスが登録済みか確認します。
13. 非同期確認中にシートが閉じられていた場合は、`mounted` 判定で以降の画面更新を行わず終了します。
14. 登録済みなら `_formErrorText` に「すでにアカウントが登録されています」を入れ、`_isSubmitting = false` に戻して終了します。
15. 未登録なら `registerAndLogin()` を呼び、アカウント一覧への保存、ログイン状態の保存、ログイン中メールアドレスの保存をまとめて行います。
16. 保存後、`widget.onSessionChanged()` 経由でホーム側の `_loadSession()` を再実行し、ホーム表示をログイン状態へ更新します。
17. 再読み込み後にシートがまだ有効なら、`Navigator.pop()` で登録用ボトムシートを閉じます。

該当コードの抜粋（lib/pages/03_main_shell/home_page.dart）:

```dart
Future<void> _submit() async {
  final String email = _emailController.text.trim();
  final String password = _passwordController.text;
  final String passwordConfirmation = _passwordConfirmationController.text;
  final bool isRegister = _mode == _AuthFormMode.register;

  final String? emailError = _validateEmail(email);
  final String? passwordError = _validatePassword(
    password,
    requireMinLength: isRegister,
  );
  final String? passwordConfirmationError =
      isRegister && password != passwordConfirmation ? 'パスワードが一致しません' : null;
}
```

ここで作られる変数の意味:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `email` | `String` | メールアドレス入力欄の値です。前後の空白は `trim()` で取り除きます。 |
| `password` | `String` | パスワード入力欄の値です。パスワードは空白も入力値として扱うため `trim()` していません。 |
| `passwordConfirmation` | `String` | 新規登録時だけ表示される確認用パスワード欄の値です。 |
| `isRegister` | `bool` | 現在のシートが新規登録モードかどうかです。`true` なら登録、`false` ならログインとして処理します。 |
| `emailError` | `String?` | メールアドレスの検証エラーメッセージです。問題なければ `null` です。 |
| `passwordError` | `String?` | パスワードの検証エラーメッセージです。登録時は4文字以上もチェックします。 |
| `passwordConfirmationError` | `String?` | 登録時にパスワード確認が一致しない場合のエラーです。 |

該当コードの抜粋（lib/pages/03_main_shell/home_page.dart）:

```dart
if (isRegister) {
  final bool isEmailRegistered = await widget.authRepository
      .isEmailRegistered(email: email);

  if (isEmailRegistered) {
    setState(() {
      _formErrorText = 'すでにアカウントが登録されています';
      _isSubmitting = false;
    });
    return;
  }

  await widget.authRepository.registerAndLogin(
    email: email,
    password: password,
  );
}
```

ここで重要な変数とオブジェクト:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `widget.authRepository` | `MockAuthRepository` | 登録情報やログイン状態を `SharedPreferences` に読み書きするリポジトリです。 |
| `isEmailRegistered` | `bool` | 入力されたメールアドレスがすでに登録済みかどうかです。 |
| `_formErrorText` | `String?` | 入力欄単位ではなく、フォーム全体に表示するエラーメッセージです。 |
| `_isSubmitting` | `bool` | 送信中かどうかです。`true` の間はボタンを無効化し、二重送信を防ぎます。 |
| `registerAndLogin()` | 非同期関数 | アカウント保存とログイン状態への切り替えを同時に行います。 |

関連コード:

ファイル:

- `lib/pages/03_main_shell/home_page.dart`
- `lib/repositories/mock_auth_repository.dart`

主な関数・変数:

- `_HomePageState._showAuthSheet()`
- `_AuthFormSheetState._submit()`
- `_validateEmail()`
- `_validatePassword()`
- `MockAuthRepository.isEmailRegistered()`
- `MockAuthRepository.registerAndLogin()`

### 5.3 ログイン

#### ユーザー操作

「ログイン」を押し、登録済みメールアドレスとパスワードを入力して「ログインする」を押します。

#### 表示される動き

メールアドレスとパスワードが保存済みデータと一致すればログイン状態になります。一致しない場合は「メールアドレスまたはパスワードが違います」と表示されます。

#### 裏側のコード

処理の流れ:

1. ホームの「ログイン」ボタンが `_showAuthSheet(_AuthFormMode.login)` を呼びます。
2. `_showAuthSheet()` は `_AuthFormSheet` にログインモードを渡してボトムシートを表示します。
3. ログインモードでは確認用パスワード欄を表示せず、送信ボタンのラベルを「ログインする」にします。
4. 「ログインする」を押すか、パスワード欄で送信すると `_submit()` が実行されます。
5. `_submit()` はメールアドレスとパスワードを読み込みます。メールアドレスだけ `trim()` します。
6. `_validateEmail()` でメールアドレスの空欄と形式を検証します。
7. `_validatePassword(..., requireMinLength: false)` でパスワードの空欄だけを検証します。
8. 検証エラーがあればエラー文を入力欄へ反映し、`MockAuthRepository.login()` へ進まず終了します。
9. 入力が有効なら `_isSubmitting = true` にし、送信中の二重押しを防ぎます。
10. `MockAuthRepository.login()` が `mock_auth_accounts` を読み、正規化済みメールアドレスで保存済みパスワードを探します。
11. パスワードが一致しない場合、`login()` は `false` を返します。
12. 照合失敗時は `_formErrorText` に「メールアドレスまたはパスワードが違います」を入れ、`_isSubmitting = false` に戻して終了します。
13. 照合成功時は `mock_auth_is_logged_in = true` と `mock_auth_logged_in_email = email` が保存されます。
14. `widget.onSessionChanged()` でホーム側の `_loadSession()` を再実行し、ホーム表示をログイン状態へ更新します。
15. 再読み込み後にシートがまだ有効なら、`Navigator.pop()` でログイン用ボトムシートを閉じます。

該当コードの抜粋（lib/pages/03_main_shell/home_page.dart）:

```dart
final bool isLoggedIn = await widget.authRepository.login(
  email: email,
  password: password,
);

if (!isLoggedIn) {
  setState(() {
    _formErrorText = 'メールアドレスまたはパスワードが違います';
    _isSubmitting = false;
  });
  return;
}
```

変数と関数の意味:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `login()` | 非同期関数 | 入力メールアドレスとパスワードが保存済みアカウントと一致するか確認します。 |
| `isLoggedIn` | `bool` | ログインに成功したかどうかです。成功なら `true`、失敗なら `false` です。 |
| `_formErrorText` | `String?` | ログイン失敗時にフォーム上へ表示するエラー文です。 |
| `_isSubmitting` | `bool` | 送信中フラグです。失敗時は `false` に戻して再入力できるようにします。 |

関連コード:

ファイル:

- `lib/pages/03_main_shell/home_page.dart`
- `lib/repositories/mock_auth_repository.dart`

主な関数・変数:

- `_AuthFormSheetState._submit()`
- `MockAuthRepository.login()`

### 5.4 ログアウト

#### ユーザー操作

ログイン中のホームで「ログアウト」を押します。

#### 表示される動き

ホームがゲスト表示に戻ります。登録済みアカウント情報は削除されません。

#### 裏側のコード

処理の流れ:

1. ログイン中表示の「ログアウト」ボタンが `_logout()` を呼びます。
2. `_logout()` は `MockAuthRepository.logout()` を `await` し、保存済みログイン状態の更新完了を待ちます。
3. `logout()` は `mock_auth_is_logged_in` を `false` にします。
4. `logout()` は現在ログイン中メールアドレス `mock_auth_logged_in_email` を削除します。
5. 登録済みアカウント一覧 `mock_auth_accounts` は削除しないため、再ログイン用のアカウント情報は残ります。
6. 保存完了後、`_logout()` は `_loadSession()` を再実行します。
7. `_loadSession()` は `fetchSession()` で未ログイン状態を読み、`setState()` で `_session` を更新します。
8. `build()` が再実行され、ホーム画面はステータス表示、本文、ボタンをゲスト表示へ戻します。

該当コードの抜粋（lib/pages/03_main_shell/home_page.dart, lib/repositories/mock_auth_repository.dart）:

```dart
Future<void> _logout() async {
  await _authRepository.logout();
  await _loadSession();
}

Future<void> logout() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setBool(isLoggedInKey, false);
  await preferences.remove(loggedInEmailKey);
}
```

関連コード:

ファイル:

- `lib/pages/03_main_shell/home_page.dart`
- `lib/repositories/mock_auth_repository.dart`

主な関数・変数:

- `_HomePageState._logout()`
- `MockAuthRepository.logout()`

### 5.5 パスワード表示切替

#### ユーザー操作

パスワード欄右側の目アイコンを押します。

#### 表示される動き

パスワードの伏せ字表示と通常表示が切り替わります。

#### 裏側のコード

処理の流れ:

1. パスワード入力欄の `suffixIcon` として `_buildVisibilityButton()` が配置されます。
2. 登録モードでは、確認用パスワード欄にも同じ仕組みの表示切替ボタンが配置されます。
3. ボタンには現在の伏せ字状態 `isObscured` と、押下時に実行する `onPressed` が渡されます。
4. 目アイコンを押すと、渡された `onPressed` が実行されます。
5. 通常のパスワード欄では `setState()` の中で `_obscurePassword` を反転します。
6. 確認用パスワード欄では `_obscurePasswordConfirmation` を反転します。
7. `TextField.obscureText` が更新後の値を参照し、伏せ字表示と通常表示が切り替わります。
8. 表示切替は入力文字列、検証結果、送信状態を変更せず、画面上の見え方だけを変更します。

該当コードの抜粋（lib/pages/03_main_shell/home_page.dart）:

```dart
Widget _buildVisibilityButton({
  required Key key,
  required bool isObscured,
  required VoidCallback onPressed,
}) {
  return IconButton(
    key: key,
    onPressed: onPressed,
    icon: Icon(
      isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
    ),
  );
}

TextField(
  controller: _passwordController,
  obscureText: _obscurePassword,
  decoration: _inputDecoration(
    labelText: 'パスワード',
    errorText: _passwordErrorText,
    suffixIcon: _buildVisibilityButton(
      key: const ValueKey<String>('mock-auth-password-visibility-button'),
      isObscured: _obscurePassword,
      onPressed: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
    ),
  ),
)

TextField(
  controller: _passwordConfirmationController,
  obscureText: _obscurePasswordConfirmation,
  decoration: _inputDecoration(
    labelText: 'パスワード確認',
    errorText: _passwordConfirmationErrorText,
    suffixIcon: _buildVisibilityButton(
      key: const ValueKey<String>(
        'mock-auth-password-confirmation-visibility-button',
      ),
      isObscured: _obscurePasswordConfirmation,
      onPressed: () {
        setState(() {
          _obscurePasswordConfirmation = !_obscurePasswordConfirmation;
        });
      },
    ),
  ),
)
```

関連コード:

ファイル:

- `lib/pages/03_main_shell/home_page.dart`

主な関数・変数:

- `_AuthFormSheetState._buildVisibilityButton()`

## 6. タブ操作

### ユーザー操作

下部ナビゲーションの「ホーム」「マップ」「履歴」を押します。

### 表示される動き

選択したタブが表示されます。マップタブは初めて開くまで `MapPage` を作らず、初回表示時に現在地取得を始めます。履歴タブを開くと、履歴再読み込み用の `reloadToken` が更新されます。

### 裏側のコード

処理の流れ:

1. 下部ナビゲーションの項目を押すと、選択されたタブ番号が `_selectTab(index)` に渡されます。
2. `_selectTab()` はまず `FocusManager.instance.primaryFocus?.unfocus()` を呼び、検索欄などに残っている入力フォーカスを解除します。
3. `setState()` の中でタブ状態を更新します。
4. マップタブが選ばれた場合は `_hasVisitedMap = true` にし、`IndexedStack` 内で `MapPage` を生成できる状態にします。
5. `_currentIndex` を押されたタブ番号へ更新し、`IndexedStack.index` と `NavigationBar.selectedIndex` の両方に反映させます。
6. 履歴タブが選ばれた場合は `_historyReloadToken++` し、履歴画面側へ再読み込みタイミングを通知します。
7. `IndexedStack` は非表示タブも破棄しないため、生成済みのホーム、マップ、履歴の状態は基本的に保持されます。
8. `MapPage` には `isActive: _currentIndex == 1` が渡されるため、マップタブから離れたときは `didUpdateWidget()` 側で検索フォーカスと候補パネルを閉じます。

該当コードの抜粋（lib/pages/03_main_shell/main_shell.dart）:

```dart
void _selectTab(int index) {
  FocusManager.instance.primaryFocus?.unfocus();
  setState(() {
    if (index == 1) {
      _hasVisitedMap = true;
    }
    _currentIndex = index;
    if (index == 2) {
      _historyReloadToken++;
    }
  });
}
```

該当コードの抜粋（lib/pages/03_main_shell/main_shell.dart）:

```dart
body: IndexedStack(
  index: _currentIndex,
  children: [
    const HomePage(),
    if (_hasVisitedMap)
      MapPage(
        searchSettings: _settings,
        initialPlace: _selectedPlace,
        initialPlaceRequestId: _placeOpenRequestId,
        isActive: _currentIndex == 1,
        onSettingsChanged: (SearchSettings value) {
          setState(() {
            _settings = value;
          });
        },
      )
    else
      const SizedBox.expand(),
  ],
)
```

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
@override
void didUpdateWidget(covariant MapPage oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (oldWidget.isActive && !widget.isActive) {
    FocusManager.instance.primaryFocus?.unfocus();
    _closeSuggestions();
  }
}
```

変数と関数の意味:

| 名前 | 種類 | 意味 |
| --- | --- | --- |
| `_currentIndex` | `int` | 現在表示しているタブ番号です。0がホーム、1がマップ、2が履歴です。 |
| `_hasVisitedMap` | `bool` | マップを一度でも開いたかどうかです。初回まで `MapPage` の生成を遅らせます。 |
| `_historyReloadToken` | `int` | 履歴タブを開いたタイミングで履歴を再読み込みするための値です。 |

関連コード:

ファイル:

- `lib/pages/03_main_shell/main_shell.dart`

主な関数・変数:

- `NavigationBar.onDestinationSelected`
- `_MainShellState._selectTab()`

## 7. マップ画面

### 7.1 マップ初期表示と現在地取得

#### ユーザー操作

マップタブを開きます。

#### 表示される動き

現在地取得中はローディングインジケータが表示されます。取得に成功すると `GoogleMap` が表示され、現在地レイヤーと現在地ボタンが有効になります。取得できない場合はエラーメッセージや `SnackBar` が表示されます。

#### 裏側のコード

処理の流れ:

1. `MainShell` でマップタブが初めて選ばれると `_hasVisitedMap` が `true` になり、`IndexedStack` 内に `MapPage` が生成されます。
2. `MapPage.initState()` は検索リポジトリ、履歴リポジトリ、初期スポット復元フラグを初期化します。
3. `initialPlace` が渡されている場合は、`_isShowingRestoredPlace = true` にして履歴復元中の1件表示として扱います。
4. `_initializePage()` は現在地取得処理を開始します。テスト時など `currentLocationLoader` が渡されている場合は、それを優先して使います。
5. 通常時の `_loadCurrentLocation()` は、位置情報サービスが有効か確認します。
6. 位置情報サービスが無効なら `SnackBar` を表示し、現在地なしとして `null` を返します。
7. サービスが有効なら、位置情報権限を確認し、未確認の場合は `requestPermission()` で権限を要求します。
8. 権限が `deniedForever` または `denied` の場合は `SnackBar` を表示し、現在地なしとして `null` を返します。
9. 権限がある場合は `getCurrentPosition()` で高精度の現在地を取得し、`LatLng` に変換します。
10. 非同期取得中に画面が破棄されていれば、`mounted` 判定で状態更新せず `null` を返します。
11. 画面が有効なら `currentLocation` に現在地を保存し、`GoogleMapController` が利用可能な場合は `_moveCameraToCurrentLocation()` で地図の表示範囲を現在地中心へ更新します。
12. `_initializePage()` は現在地が取れなかった場合、`initialPlace` がなければ `places = []`、`errorMessage = '現在地の取得に失敗しました'`、`isLoading = false` にします。
13. 現在地が取れなかった場合でも `initialPlace` があれば、そのスポット1件を `places` に入れ、エラー表示ではなく復元表示を優先します。
14. 現在地が取れた場合は、`places` に `initialPlace` 1件または空配列を入れ、`errorMessage = null`、`isLoading = false` にします。
15. `GoogleMap` 作成後に `_onMapCreated()` が呼ばれ、初期スポットがある場合は `_openInitialPlace()`、ない場合は地図の表示範囲を現在地中心へ更新します。

該当コードの抜粋（lib/pages/03_main_shell/main_shell.dart）:

```dart
void _selectTab(int index) {
  FocusManager.instance.primaryFocus?.unfocus();
  setState(() {
    if (index == 1) {
      _hasVisitedMap = true;
    }
    _currentIndex = index;
  });
}

if (_hasVisitedMap)
  MapPage(
    searchSettings: _settings,
    initialPlace: _selectedPlace,
    initialPlaceRequestId: _placeOpenRequestId,
    isActive: _currentIndex == 1,
  )
else
  const SizedBox.expand()
```

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
@override
void initState() {
  super.initState();
  _repository = widget.repository ?? GooglePlacesRepository();
  _historyRepository = widget.historyRepository;
  _isShowingRestoredPlace = widget.initialPlace != null;
  _initializePage();
}

Future<void> _initializePage() async {
  final LatLng? location = widget.currentLocationLoader == null
      ? await _loadCurrentLocation()
      : await widget.currentLocationLoader!();
  if (widget.currentLocationLoader != null && mounted && location != null) {
    setState(() {
      currentLocation = location;
    });
  }

  if (location == null) {
    if (!mounted) {
      return;
    }
    setState(() {
      places = widget.initialPlace == null
          ? const <Place>[]
          : <Place>[widget.initialPlace!];
      errorMessage = widget.initialPlace == null ? '現在地の取得に失敗しました' : null;
      isLoading = false;
    });
    return;
  }

  setState(() {
    places = widget.initialPlace == null
        ? const <Place>[]
        : <Place>[widget.initialPlace!];
    errorMessage = null;
    isLoading = false;
  });
}
```

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
Future<LatLng?> _loadCurrentLocation() async {
  final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    if (!mounted) {
      return null;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('位置情報サービスが無効です')));
    return null;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    if (!mounted) {
      return null;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('位置情報の権限が拒否されています')));
    return null;
  }

  if (permission == LocationPermission.denied) {
    if (!mounted) {
      return null;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('位置情報の権限が許可されていません')));
    return null;
  }

  final Position position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
  final LatLng fetchedLocation = LatLng(position.latitude, position.longitude);

  if (!mounted) {
    return null;
  }
  setState(() {
    currentLocation = fetchedLocation;
  });

  await _moveCameraToCurrentLocation(fetchedLocation);
  return fetchedLocation;
}
```

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
void _onMapCreated(GoogleMapController controller) {
  _mapController = controller;

  final Place? initialPlace = widget.initialPlace;
  if (initialPlace != null) {
    if (!_hasOpenedInitialPlace) {
      _hasOpenedInitialPlace = true;
      unawaited(_openInitialPlace(initialPlace));
    }
    return;
  }

  final LatLng? location = currentLocation;
  if (location != null) {
    unawaited(_moveCameraToCurrentLocation(location));
  }
}
```

関連コード:

ファイル:

- `lib/pages/04_map/map_page.dart`

主な関数・変数:

- `_MapPageState._initializePage()`
- `_MapPageState._loadCurrentLocation()`
- `_MapPageState._moveCameraToCurrentLocation()`

### 7.2 検索欄に文字を入力する

#### ユーザー操作

マップ上部の検索欄に文字を入力します。

#### 表示される動き

入力から少し待つと、検索候補が検索欄の下に表示されます。入力が空の場合や現在地がない場合、候補は表示されません。

#### 裏側のコード

処理の流れ:

1. 検索欄の文字が変わるたびに `MapSearchBar.onChanged` が呼び出され、`MapPage._onSearchTextChanged()` に入力文字列を渡します。
2. `_onSearchTextChanged()` は直前の `_suggestionDebounce` をキャンセルし、古い入力に対する候補取得タイマーを止めます。
3. `_suggestionRequestId` を増やし、後で返る非同期レスポンスが現在の入力に対応しているか判定できるようにします。
4. 入力文字列は `trim()` され、空白だけの入力は空文字として扱われます。
5. 入力が空なら `_suggestions = []`、`_isLoadingSuggestions = false` にし、候補パネルを閉じて終了します。
6. 入力がある場合でも、いったん候補リストと読み込み表示を初期化します。
7. `currentLocation` がまだない場合は、Google Places Autocomplete を呼ばずに終了します。
8. 入力があり現在地もある場合、400ミリ秒の `Timer` を作り、入力が止まってから `_loadSuggestions(input, location, requestId)` を実行します。
9. `_loadSuggestions()` は開始時に `mounted` と `requestId` を確認し、画面破棄済みまたは古いリクエストなら何もせず終了します。
10. 有効なリクエストなら `_isLoadingSuggestions = true` にし、候補パネルに読み込み表示を出します。
11. `fetchAutocompleteSuggestions()` に入力文字、現在地、検索半径を渡し、Google Places Autocomplete の候補を取得します。
12. 取得後も `mounted` と `requestId` を再確認し、入力変更後に遅れて返った結果は破棄します。
13. 有効な結果だけ最大5件に絞って `_suggestions` に保存し、候補パネルへ表示します。
14. API例外が発生した場合はデバッグログに残し、現在のリクエストが有効なら候補を空にします。
15. 成功・失敗に関係なく、現在のリクエストが有効なら最後に `_isLoadingSuggestions = false` に戻します。

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
void _onSearchTextChanged(String value) {
  _suggestionDebounce?.cancel();
  final int requestId = ++_suggestionRequestId;
  final String input = value.trim();
  if (input.isEmpty) {
    setState(() {
      _suggestions = const <PlaceSuggestion>[];
      _isLoadingSuggestions = false;
    });
    return;
  }

  setState(() {
    _suggestions = const <PlaceSuggestion>[];
    _isLoadingSuggestions = false;
  });

  final LatLng? location = currentLocation;
  if (location == null) {
    return;
  }

  _suggestionDebounce = Timer(const Duration(milliseconds: 400), () {
    unawaited(_loadSuggestions(input, location, requestId));
  });
}

Future<void> _loadSuggestions(
  String input,
  LatLng location,
  int requestId,
) async {
  if (!mounted || requestId != _suggestionRequestId) {
    return;
  }
  setState(() {
    _isLoadingSuggestions = true;
  });

  try {
    final List<PlaceSuggestion> suggestions = await _repository
        .fetchAutocompleteSuggestions(
          input: input,
          latitude: location.latitude,
          longitude: location.longitude,
          radiusMeters: widget.searchSettings.radiusMeters.toDouble(),
        );
    if (!mounted || requestId != _suggestionRequestId) {
      return;
    }
    setState(() {
      _suggestions = suggestions.take(5).toList();
    });
  } catch (error, stackTrace) {
    debugPrint('MapPage autocomplete error: $error');
    debugPrint('MapPage autocomplete stack: $stackTrace');
    if (mounted && requestId == _suggestionRequestId) {
      setState(() {
        _suggestions = const <PlaceSuggestion>[];
      });
    }
  } finally {
    if (mounted && requestId == _suggestionRequestId) {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }
}
```

関連コード:

ファイル:

- `lib/pages/04_map/widgets/map_search_bar.dart`
- `lib/pages/04_map/map_page.dart`

主な関数・変数:

- `MapSearchBar.onChanged`
- `_MapPageState._onSearchTextChanged()`
- `_MapPageState._loadSuggestions()`
- `GooglePlacesRepository.fetchAutocompleteSuggestions()`

### 7.3 検索を実行する

#### ユーザー操作

検索アイコンを押す、またはキーボードの検索を実行します。

#### 表示される動き

検索結果が見つかると地図上に `Marker` が表示され、マップの表示範囲が検索結果全体を収めるように更新されます。検索語が空、現在地がない、結果がない、API で失敗した場合は `SnackBar` が表示されます。

#### 裏側のコード

処理の流れ:

1. 検索アイコン、キーボードの検索、候補タップのいずれかから `_searchPlacesByText()` が呼ばれます。
2. `isSearching` が `true` の間はすぐに処理を終了し、検索の二重実行を防ぎます。
3. 検索語は引数 `submittedQuery` があればそれを使い、なければ検索欄の `TextEditingController` から読みます。
4. 検索語は `trim()` され、空白だけの入力は空文字として扱われます。
5. `_closeSuggestions()` で候補取得タイマー、候補リスト、候補読み込み状態を閉じます。
6. 検索語が空なら `SnackBar` で「検索ワードを入力してください」と表示して終了します。
7. `currentLocation` がない場合も API を呼ばず、`SnackBar` で「現在地を取得できませんでした」と表示して終了します。
8. `_searchPlacesByText()` は通常の二重送信を拒否した後、実検索を担当する `_runTextSearch()` を呼びます。
9. `_runTextSearch()` は開始時点の検索語、現在地、検索半径、最大件数をローカル変数へ固定します。
10. `_searchRequestId` を増やして今回の `requestId` とし、`_activeSearchQuery` に進行中の検索語を保持します。
11. 入力フォーカスを外し、`isSearching = true` にして検索欄を送信中状態にします。
12. `PlaceRepository.searchPlacesByText()` に検索開始時に確定した検索語、現在地、検索半径、最大件数を渡します。
13. リポジトリから結果が返った後、`mounted` と `requestId == _searchRequestId` を確認します。
14. 古いリクエストの場合は、`places`、`_lastSubmittedQuery`、`_isShowingRestoredPlace`、SnackBar、カメラを更新せず終了します。
15. 最新リクエストの場合だけ、取得結果を `places` に保存し、`_isShowingRestoredPlace` を `false` に戻し、正常に反映した検索語を `_lastSubmittedQuery` に保持します。
16. 取得結果が空なら `SnackBar` で「検索結果が見つかりませんでした」と表示して終了します。
17. 営業中のみフィルターが有効な場合は、`isOpenNow == true` のスポットだけを表示対象にします。
18. 表示対象が空なら同じ「検索結果が見つかりませんでした」という `SnackBar` を表示し、表示対象があれば `_fitCameraToPlaces()` で地図の表示範囲を更新します。
19. 例外時も最新リクエストの場合だけログと検索失敗の `SnackBar` を出します。
20. `finally` でも最新リクエストか確認し、最新の場合だけ `isSearching = false` と `_activeSearchQuery = null` に戻します。古い検索の完了では、新しい検索の送信中状態を解除しません。

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
Future<void> _searchPlacesByText([String? submittedQuery]) async {
  if (isSearching) {
    return;
  }

  await _runTextSearch(submittedQuery);
}

Future<void> _runTextSearch([String? submittedQuery]) async {
  final String query = (submittedQuery ?? _searchController.text).trim();
  final LatLng? location = currentLocation;
  final double radiusMeters = widget.searchSettings.radiusMeters.toDouble();
  final int maxResultCount = widget.searchSettings.maxResultCount;
  final int requestId = ++_searchRequestId;

  setState(() {
    isSearching = true;
    _activeSearchQuery = query;
  });

  try {
    final List<Place> fetchedPlaces = await _repository.searchPlacesByText(
      query: query,
      latitude: location.latitude,
      longitude: location.longitude,
      radiusMeters: radiusMeters,
      maxResultCount: maxResultCount,
    );
    if (!mounted || requestId != _searchRequestId) {
      return;
    }

    setState(() {
      places = fetchedPlaces;
      _isShowingRestoredPlace = false;
      _lastSubmittedQuery = query;
    });
  } catch (error, stackTrace) {
    if (!mounted || requestId != _searchRequestId) {
      return;
    }
    debugPrint('MapPage text search error: $error');
    debugPrint('MapPage text search stack: $stackTrace');
    _showMessage('検索に失敗しました');
  } finally {
    if (mounted && requestId == _searchRequestId) {
      setState(() {
        isSearching = false;
        _activeSearchQuery = null;
      });
    }
  }
}
```

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
Future<void> _fitCameraToPlaces(List<Place> resultPlaces) async {
  final GoogleMapController? controller = _mapController;
  if (controller == null || !mounted || resultPlaces.isEmpty) {
    return;
  }

  final LatLngBounds? bounds = buildBoundsForPlaces(resultPlaces);
  if (bounds == null) {
    return;
  }

  final bool hasSingleCoordinate =
      bounds.southwest.latitude == bounds.northeast.latitude &&
      bounds.southwest.longitude == bounds.northeast.longitude;

  if (resultPlaces.length == 1 || hasSingleCoordinate) {
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(bounds.southwest, 16),
    );
    return;
  }

  await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
}
```

関連コード:

ファイル:

- `lib/pages/04_map/widgets/map_search_bar.dart`
- `lib/pages/04_map/map_page.dart`
- `lib/repositories/google_places_repository.dart`

主な関数・変数:

- `MapSearchBar._submitSearch()`
- `_MapPageState._searchPlacesByText()`
- `_MapPageState._runTextSearch()`
- `_MapPageState._fitCameraToPlaces()`
- `_MapPageState._searchRequestId`
- `_MapPageState._activeSearchQuery`
- `_MapPageState._lastSubmittedQuery`
- `GooglePlacesRepository.searchPlacesByText()`

### 7.4 候補をタップする

#### ユーザー操作

検索候補リストの項目をタップします。

#### 表示される動き

検索欄に候補文字列が入り、その文字列で検索が実行されます。

#### 裏側のコード

処理の流れ:

1. `_buildSuggestionPanel()` は `_isLoadingSuggestions` と `_suggestions` を見て、候補パネルを表示するか判断します。
2. 読み込み中で候補がまだない場合は、パネル内に `CircularProgressIndicator` を表示します。
3. 候補がある場合は、`_suggestions` の各要素から `ListTile` を生成します。
4. 候補種別が `place` なら位置アイコン、それ以外なら検索アイコンを表示します。
5. 候補をタップすると `ListTile.onTap` から `_selectSuggestion(suggestion)` が呼ばれます。
6. `_selectSuggestion()` は `_searchController.text` に候補文字列を設定し、検索欄の表示と内部状態を一致させます。
7. `TextSelection.collapsed` でカーソルを候補文字列の末尾に移動します。
8. `_closeSuggestions()` で候補取得タイマーを止め、`_suggestionRequestId` を更新し、候補パネルを閉じます。
9. `_searchPlacesByText(suggestion.text)` を `await` し、候補文字列をそのまま検索語として検索します。
10. 以降は通常検索と同じく、空文字、現在地未取得、API失敗、結果なし、フィルター、地図の表示範囲の更新という順に処理されます。

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
Widget _buildSuggestionPanel() {
  if (!_isLoadingSuggestions && _suggestions.isEmpty) {
    return const SizedBox.shrink();
  }

  return _isLoadingSuggestions && _suggestions.isEmpty
      ? const CircularProgressIndicator()
      : ListView.separated(
          itemCount: _suggestions.length,
          itemBuilder: (BuildContext context, int index) {
            final PlaceSuggestion suggestion = _suggestions[index];
            return ListTile(
              key: ValueKey<String>('place-suggestion-$index'),
              leading: Icon(
                suggestion.type == PlaceSuggestionType.place
                    ? Icons.location_on_outlined
                    : Icons.search,
              ),
              title: Text(suggestion.text),
              onTap: () => _selectSuggestion(suggestion),
            );
          },
        );
}

Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
  _searchController.text = suggestion.text;
  _searchController.selection = TextSelection.collapsed(
    offset: suggestion.text.length,
  );
  _closeSuggestions();
  await _searchPlacesByText(suggestion.text);
}

```

関連コード:

ファイル:

- `lib/pages/04_map/map_page.dart`

主な関数・変数:

- `_MapPageState._buildSuggestionPanel()`
- `_MapPageState._selectSuggestion()`

### 7.5 クリアボタン

#### ユーザー操作

検索欄右側のクリアボタンを押します。

#### 表示される動き

検索欄、候補、検索結果のピンが消えます。

#### 裏側のコード

処理の流れ:

1. クリアアイコンは、検索欄に文字がある場合、または検索結果が表示されている場合に表示されます。
2. クリアアイコンを押すと `MapSearchBar._clear()` が実行されます。
3. `_clear()` は検索欄の `TextEditingController.clear()` を呼び、入力文字列を空にします。
4. 続けて `widget.onClear()` を呼び、親の `MapPage._clearSearch()` に検索状態の初期化を依頼します。
5. `_clearSearch()` は入力フォーカスを外し、ソフトキーボードを閉じます。
6. 表示中の `SnackBar` を `hideCurrentSnackBar()` で閉じます。
7. `_closeSuggestions()` で候補取得タイマー、候補リスト、候補読み込み状態を閉じます。
8. `_searchRequestId` を増やし、完了していないテキスト検索を論理的に無効化します。
9. `setState()` で `places = []` にし、地図上の検索結果 `Marker` を消します。
10. `_isShowingRestoredPlace = false` に戻し、履歴から復元した1件表示状態も解除します。
11. `_lastSubmittedQuery` と `_activeSearchQuery` を `null` に戻し、フィルター変更時に以前の検索語が再利用されないようにします。
12. `isSearching = false` に戻します。無効化された検索が後から完了しても、検索番号の判定によりクリア後の状態を上書きしません。
13. `errorMessage = null` にし、現在地取得エラー表示ではなく通常の地図表示へ戻せる状態にします。

該当コードの抜粋（lib/pages/04_map/widgets/map_search_bar.dart, lib/pages/04_map/map_page.dart）:

```dart
void _clear() {
  _controller.clear();
  widget.onClear();
}

void _clearSearch() {
  FocusScope.of(context).unfocus();
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  _closeSuggestions();
  _searchRequestId++;
  setState(() {
    places = const <Place>[];
    _isShowingRestoredPlace = false;
    _lastSubmittedQuery = null;
    _activeSearchQuery = null;
    isSearching = false;
    errorMessage = null;
  });
}
```

関連コード:

ファイル:

- `lib/pages/04_map/widgets/map_search_bar.dart`
- `lib/pages/04_map/map_page.dart`

主な関数・変数:

- `MapSearchBar._clear()`
- `_MapPageState._clearSearch()`
- `_MapPageState._searchRequestId`
- `_MapPageState._activeSearchQuery`

### 7.6 フィルターボタン

#### ユーザー操作

検索欄右側のフィルターボタンを押します。

#### 表示される動き

検索条件の `ModalBottomSheet` が開きます。距離、件数、営業中のみを変更できます。

#### 裏側のコード

処理の流れ:

1. フィルターボタンを押すと `_showFilterBottomSheet()` が呼ばれます。
2. `MapPage` は背景色と上端の角丸を指定して `showModalBottomSheet()` を呼びます。
3. builderは `MapFilterSheet` を生成し、現在の `widget.searchSettings` を `initialSettings` として渡します。
4. `MapFilterSheet.initState()` は初期設定を `_draft` に保存し、シートが開いている間の一時設定として扱います。
5. 距離の `SegmentedButton` を変更すると、`_draft.copyWith(radiusMeters: value)` で新しい `SearchSettings` を作ります。
6. 最大件数の `SegmentedButton` を変更すると、`_draft.copyWith(maxResultCount: value)` で新しい設定を作ります。
7. 営業中のみの `SwitchListTile` を変更すると、`_draft.copyWith(openNowOnly: value)` で設定を更新します。
8. 各変更は `MapFilterSheet` 自身の `setState()` でシート内部へ反映され、更新直後に `onChanged(_draft)` で通知されます。
9. `MapPage` は `MapFilterSheet.onChanged` を `widget.onSettingsChanged` へ橋渡しします。
10. `MainShell` は受け取った値を `_settings` に保存し、同じ設定を `MapPage` と履歴画面へ渡します。
11. `MapPage.didUpdateWidget()` は、古い設定と新しい設定の距離・件数を比較します。
12. 距離または件数が変わり、検索中の場合は `_activeSearchQuery`、検索中でない場合は `_lastSubmittedQuery` を再検索語として選びます。
13. 現在地と再検索語がある場合は `_replaceTextSearch(query)` を呼び、新しい条件で検索し直します。
14. 以前の検索は `_searchRequestId` が一致しなくなるため、後から完了しても結果、SnackBar、カメラ、送信中状態を更新しません。
15. 距離または件数が変わっても、現在地または検索語がなければAPI再検索は行いません。
16. 営業中のみの変更は API 再検索ではなく、`filteredPlaces` で現在の `places` の表示対象を絞り込みます。
17. シートを閉じる確定処理はなく、再度開くと親が保持する最新設定から新しい `_draft` を作ります。
18. 履歴から復元したスポットは `_isShowingRestoredPlace` により営業中フィルターの対象外として扱い、営業状態が不明でも1件表示を維持します。

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
void _showFilterBottomSheet() {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return MapFilterSheet(
        initialSettings: widget.searchSettings,
        onChanged: (SearchSettings settings) {
          widget.onSettingsChanged?.call(settings);
        },
      );
    },
  );
}
```

該当コードの抜粋（lib/pages/04_map/widgets/map_filter_sheet.dart）:

```dart
@override
void initState() {
  super.initState();
  _draft = widget.initialSettings;
}

void _updateRadius(int radiusMeters) {
  setState(() {
    _draft = _draft.copyWith(radiusMeters: radiusMeters);
  });
  widget.onChanged(_draft);
}
```

該当コードの抜粋（lib/pages/03_main_shell/main_shell.dart）:

```dart
MapPage(
  searchSettings: _settings,
  onSettingsChanged: (SearchSettings value) {
    setState(() {
      _settings = value;
    });
  },
)

SettingsPage(
  settings: _settings,
  onChanged: (SearchSettings value) {
    setState(() {
      _settings = value;
    });
  },
)
```

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
@override
void didUpdateWidget(covariant MapPage oldWidget) {
  super.didUpdateWidget(oldWidget);

  final bool hasApiSearchConditionChanged =
      oldWidget.searchSettings.radiusMeters !=
          widget.searchSettings.radiusMeters ||
      oldWidget.searchSettings.maxResultCount !=
          widget.searchSettings.maxResultCount;

  if (!hasApiSearchConditionChanged) {
    return;
  }

  final LatLng? location = currentLocation;
  final String? query = isSearching
      ? _activeSearchQuery
      : _lastSubmittedQuery;
  if (location != null && query != null) {
    unawaited(_replaceTextSearch(query));
  }
}

List<Place> get filteredPlaces {
  return widget.searchSettings.openNowOnly && !_isShowingRestoredPlace
      ? places.where((Place place) => place.isOpenNow == true).toList()
      : places;
}
```

関連コード:

ファイル:

- `lib/pages/04_map/map_page.dart`
- `lib/pages/04_map/widgets/map_filter_sheet.dart`
- `lib/models/search_settings.dart`
- `lib/pages/03_main_shell/main_shell.dart`

主な関数・変数:

- `_MapPageState._showFilterBottomSheet()`
- `MapFilterSheet`
- `_MapFilterSheetState._draft`
- `_MapFilterSheetState._updateRadius()`
- `_MapFilterSheetState._updateMaxResultCount()`
- `_MapFilterSheetState._updateOpenNowOnly()`
- `SearchSettings.copyWith()`
- `MainShell.onSettingsChanged`
- `_MapPageState.didUpdateWidget()`
- `_MapPageState._replaceTextSearch()`
- `_MapPageState._activeSearchQuery`
- `_MapPageState._searchRequestId`
- `_MapPageState.filteredPlaces`

### 7.7 地図上のピンをタップする

#### ユーザー操作

地図上のスポットピンをタップします。

#### 表示される動き

地図の表示範囲がその場所を中心にするよう更新され、スポット詳細ボトムシートが表示されます。表示したスポットは履歴に保存されます。

#### 裏側のコード

処理の流れ:

1. `filteredPlaces` は、検索結果 `places` に現在の営業中フィルターを適用した表示対象リストです。
2. `_buildMarkers(filteredPlaces)` が表示対象から `Marker` セットを生成します。
3. 各 `Marker` には `place.id` を使った `MarkerId`、緯度経度、情報ウィンドウ、`onTap` が設定されます。
4. ピンをタップすると `Marker.onTap` が呼び出され、対象の `Place` を `_onPlaceMarkerTap(place)` へ渡します。
5. `_onPlaceMarkerTap()` はまず `_moveCameraToPlace(place)` を `await` し、地図の表示範囲を対象スポット中心へ更新します。
6. `_moveCameraToPlace()` は `GoogleMapController` がない場合、または画面が破棄済みの場合は何もせず戻ります。
7. 地図の表示範囲の更新中に例外が出ても、ログ出力だけにとどめ、詳細表示処理は続行できるようにしています。
8. `mounted` を確認したうえで `_showPlaceBottomSheet(place)` を呼びます。
9. `_showPlaceBottomSheet()` は `showModalBottomSheet()` で `PlaceBottomSheet` を表示します。
10. `PlaceBottomSheet` にはタップした `place` と、現在地が取得済みなら `currentLocation` を渡します。
11. 同じ関数内で `PlaceHistoryRepository.add(place)` を呼び、詳細表示したスポットを閲覧履歴へ保存します。
12. 履歴保存に失敗した場合は画面表示を止めず、デバッグログへ記録して処理を終えます。

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
Set<Marker> _buildMarkers(List<Place> sourcePlaces) {
  return sourcePlaces.map((Place place) {
    return Marker(
      markerId: MarkerId(place.id),
      position: LatLng(place.latitude, place.longitude),
      infoWindow: InfoWindow(title: place.name, snippet: place.description),
      onTap: () async {
        await _onPlaceMarkerTap(place);
      },
    );
  }).toSet();
}

Future<void> _onPlaceMarkerTap(Place place) async {
  await _moveCameraToPlace(place);
  if (mounted) {
    await _showPlaceBottomSheet(place);
  }
}

Future<void> _showPlaceBottomSheet(Place place) async {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    builder: (_) =>
        PlaceBottomSheet(place: place, currentLocation: currentLocation),
  );

  await _historyRepository.add(place);
}
```

関連コード:

ファイル:

- `lib/pages/04_map/map_page.dart`
- `lib/repositories/place_history_repository.dart`

主な関数・変数:

- `_MapPageState._buildMarkers()`
- `_MapPageState._onPlaceMarkerTap()`
- `_MapPageState._showPlaceBottomSheet()`
- `PlaceHistoryRepository.add()`

### 7.8 地図の空き場所をタップする

#### ユーザー操作

地図上のピン以外の場所をタップします。

#### 表示される動き

検索欄のフォーカスが解除され、候補パネルが閉じます。

#### 裏側のコード

処理の流れ:

1. `GoogleMap` のピン以外の場所をタップすると `onTap` が呼び出されます。
2. `onTap` は `_dismissSearchOverlay()` を呼びます。
3. `_dismissSearchOverlay()` は `FocusManager.instance.primaryFocus?.unfocus()` を実行し、検索欄などの入力フォーカスを解除します。
4. 入力フォーカス解除により、表示中のソフトキーボードも閉じます。
5. 続けて `_closeSuggestions()` を呼び、候補取得用の debounce タイマーをキャンセルします。
6. `_closeSuggestions()` は `_suggestionRequestId` を増やし、遅れて返ってきた古い候補レスポンスを無効化します。
7. 候補または候補読み込み状態が残っていれば、`setState()` で `_suggestions = []`、`_isLoadingSuggestions = false` に戻します。
8. 検索欄の文字列、検索結果 `places`、選択中の検索条件は変更しません。

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
void _dismissSearchOverlay() {
  FocusManager.instance.primaryFocus?.unfocus();
  _closeSuggestions();
}

void _closeSuggestions() {
  _suggestionDebounce?.cancel();
  _suggestionRequestId++;
  if (mounted && (_suggestions.isNotEmpty || _isLoadingSuggestions)) {
    setState(() {
      _suggestions = const <PlaceSuggestion>[];
      _isLoadingSuggestions = false;
    });
  }
}

GoogleMap(
  onTap: (_) => _dismissSearchOverlay(),
)
```

関連コード:

ファイル:

- `lib/pages/04_map/map_page.dart`

主な関数・変数:

- `_MapPageState._dismissSearchOverlay()`
- `_MapPageState._closeSuggestions()`

## 8. スポット詳細ボトムシート

スポット詳細ボトムシートは `PlaceBottomSheet` で作られます。スポット名、説明、URL と、外部アプリ、アプリ内WebView、ルート表示の操作が並びます。

### 8.1 「他のアプリで開く」

#### ユーザー操作

「他のアプリで開く」を押します。

#### 表示される動き

外部ブラウザまたは対応アプリでスポット URL が開きます。開けない場合は「URLを開けませんでした」と表示されます。

#### 裏側のコード

処理の流れ:

1. `PlaceBottomSheet` の「他のアプリで開く」の行をタップすると `_openExternalBrowser(context)` が呼ばれます。
2. `_openExternalBrowser()` は `place.webUrl` から `Uri` を作ります。
3. `launchUrl(uri, mode: LaunchMode.externalApplication)` を呼び、URLをOS側の外部ブラウザまたは対応アプリへ渡します。
4. 外部アプリ側で開けた場合、アプリ内では追加の状態更新を行わず処理を終えます。
5. `launchUrl` が `false` を返した場合は、URL を開けなかったと判断します。
6. 失敗時も、非同期処理中に `BuildContext` が無効化されていないか `context.mounted` を確認します。
7. `context` が有効なら `SnackBar` で「URLを開けませんでした」と表示します。

該当コードの抜粋（lib/pages/04_map/widgets/place_bottom_sheet.dart）:

```dart
Future<void> _openExternalBrowser(BuildContext context) async {
  final Uri uri = Uri.parse(place.webUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
    }
  }
}
```

関連コード:

ファイル:

- `lib/pages/04_map/widgets/place_bottom_sheet.dart`

主な関数・変数:

- `PlaceBottomSheet._openExternalBrowser()`

### 8.2 「アプリ内で開く」

#### ユーザー操作

「アプリ内で開く」を押します。

#### 表示される動き

アプリ内WebView画面へ遷移し、スポット URL が表示されます。ページ読み込み中は上部に進捗バーが表示されます。

#### 裏側のコード

処理の流れ:

1. 「アプリ内で開く」をタップすると `_openInAppWebView(context)` が呼ばれます。
2. `_openInAppWebView()` は `Navigator.of(context).pushNamed()` を呼びます。
3. 遷移先ルートには `AppRoutes.webview`、引数には `place.webUrl` を渡します。
4. `main.dart` の `onGenerateRoute` が `/webview` を受け取り、`settings.arguments` からURL文字列を取り出します。
5. URL引数が有効なら `WebViewPage(url: url)` を生成します。
6. `WebViewPage.initState()` は `WebViewController` を生成し、JavaScript と遷移制御を設定します。
7. `NavigationDelegate.onNavigationRequest` は `http` と `https` のみ許可し、アプリ外 deep link などは `prevent` します。
8. `loadRequest(Uri.parse(widget.url))` でページ読み込みを開始します。
9. 読み込み開始時は `_isLoading = true` になり、上部の `LinearProgressIndicator` を表示します。
10. 読み込み完了時は `_isLoading = false` になり、プログレス表示を消します。
11. メインフレームの読み込みに失敗した場合は `_errorMessage` をセットし、WebView の代わりにエラー文を表示します。
12. ユーザーが戻る操作をすると、通常の `Navigator` スタックに従ってスポット詳細側へ戻ります。

該当コードの抜粋（lib/pages/04_map/widgets/place_bottom_sheet.dart, lib/pages/05_webview/webview_page.dart）:

```dart
void _openInAppWebView(BuildContext context) {
  Navigator.of(context).pushNamed(AppRoutes.webview, arguments: place.webUrl);
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key, this.url = 'https://example.com'});

  final String url;
}
```

該当コードの抜粋（lib/pages/05_webview/webview_page.dart）:

```dart
@override
void initState() {
  super.initState();
  _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          final Uri? uri = Uri.tryParse(request.url);
          final String scheme = uri?.scheme.toLowerCase() ?? '';
          if (scheme == 'http' || scheme == 'https') {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ),
    )
    ..loadRequest(Uri.parse(widget.url));
}
```

関連コード:

ファイル:

- `lib/pages/04_map/widgets/place_bottom_sheet.dart`
- `lib/pages/05_webview/webview_page.dart`

主な関数・変数:

- `PlaceBottomSheet._openInAppWebView()`
- `WebViewPage`
- `WebViewController.loadRequest()`

### 8.3 「ルートを見る」

#### ユーザー操作

「ルートを見る」を押します。

#### 表示される動き

Google Maps などの外部地図アプリで目的地までのルートが開きます。開けない場合は「URLを開けませんでした」と表示されます。

#### 裏側のコード

処理の流れ:

1. 「ルートを見る」をタップすると `_openRouteInExternalApp(context)` が呼ばれます。
2. `_openRouteInExternalApp()` は `_buildGoogleMapsRouteUrl()` で Google Maps の経路URLを組み立てます。
3. 目的地は常に `place.latitude,place.longitude` から `destination` として作ります。
4. `currentLocation` がある場合は、現在地の緯度経度を `origin` とし、スポット座標を `destination` としてURLに含めます。
5. `currentLocation` がない場合は、`destination` のみを含む経路URLにします。
6. 作成したURL文字列を `Uri.parse()` で `Uri` に変換します。
7. `launchUrl(uri, mode: LaunchMode.externalApplication)` で外部地図アプリまたはブラウザへ渡します。
8. 起動できた場合、アプリ内の状態は変更せず処理を終えます。
9. 起動に失敗した場合は `context.mounted` を確認し、有効なら `SnackBar` で「URLを開けませんでした」と表示します。

該当コードの抜粋（lib/pages/04_map/widgets/place_bottom_sheet.dart）:

```dart
String _buildGoogleMapsRouteUrl() {
  final String destination = '${place.latitude},${place.longitude}';
  final LatLng? location = currentLocation;

  if (location == null) {
    return 'https://www.google.com/maps/dir/?api=1&destination=$destination';
  }

  final String origin = '${location.latitude},${location.longitude}';
  return 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination';
}

Future<void> _openRouteInExternalApp(BuildContext context) async {
  final String routeUrl = _buildGoogleMapsRouteUrl();
  final Uri uri = Uri.parse(routeUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
    }
  }
}
```

関連コード:

ファイル:

- `lib/pages/04_map/widgets/place_bottom_sheet.dart`

主な関数・変数:

- `PlaceBottomSheet._buildGoogleMapsRouteUrl()`
- `PlaceBottomSheet._openRouteInExternalApp()`

## 9. 履歴画面

### 9.1 履歴を開く

#### ユーザー操作

下部ナビゲーションの「履歴」を押します。

#### 表示される動き

閲覧済みスポットがあればカード一覧が表示されます。履歴がない場合は「まだ見たスポットはありません」と表示されます。

#### 裏側のコード

処理の流れ:

1. 下部ナビゲーションで履歴タブを押すと、`MainShell._selectTab(2)` が呼ばれます。
2. `_selectTab()` は入力フォーカスを外したうえで `setState()` を実行します。
3. `_currentIndex = 2` にして、`IndexedStack` の表示対象を履歴タブへ切り替えます。
4. 同時に `_historyReloadToken++` し、履歴画面に「再読み込みすべきタイミング」を伝えます。
5. `SettingsPage` は `reloadToken`、履歴リポジトリ、`onOpenPlace` を `PlaceHistoryContent` に渡します。
6. `PlaceHistoryContent` の初回生成時は `initState()` で `_reloadHistory()` が呼ばれます。
7. 生成済みの履歴タブを再表示した場合は、`didUpdateWidget()` が前回の `reloadToken` と比較します。
8. `reloadToken` または履歴リポジトリが変わっていれば、`setState(_reloadHistory)` で読み込み対象の `Future` を差し替えます。
9. `_reloadHistory()` は `PlaceHistoryRepository.fetchHistory()` の `Future` を `_historyFuture` に入れます。
10. `FutureBuilder` が `_historyFuture` を監視し、読み込み中は `CircularProgressIndicator` を表示します。
11. 読み込み完了後、履歴が空なら履歴がない場合の画面を表示します。
12. 履歴がある場合は `ListView.builder` で履歴カードを生成します。
13. 履歴データは `SharedPreferences` の `place_view_history` から読み出され、保存順のまま最大20件まで表示されます。

該当コードの抜粋（lib/pages/03_main_shell/main_shell.dart）:

```dart
void _selectTab(int index) {
  FocusManager.instance.primaryFocus?.unfocus();
  setState(() {
    if (index == 1) {
      _hasVisitedMap = true;
    }
    _currentIndex = index;
    if (index == 2) {
      _historyReloadToken++;
    }
  });
}
```

該当コードの抜粋（lib/pages/02_top/widgets/place_history_content.dart）:

```dart
@override
void didUpdateWidget(covariant PlaceHistoryContent oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.historyRepository != widget.historyRepository ||
      oldWidget.reloadToken != widget.reloadToken) {
    setState(_reloadHistory);
  }
}

void _reloadHistory() {
  _historyFuture = widget.historyRepository.fetchHistory();
}
```

該当コードの抜粋（lib/pages/02_top/widgets/place_history_content.dart）:

```dart
FutureBuilder<List<Place>>(
  future: _historyFuture,
  builder: (BuildContext context, AsyncSnapshot<List<Place>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<Place> history = snapshot.data ?? const <Place>[];
    if (history.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildHistoryCard(history[index]);
      },
    );
  },
)
```

関連コード:

ファイル:

- `lib/pages/03_main_shell/main_shell.dart`
- `lib/pages/06_settings/settings_page.dart`
- `lib/pages/02_top/widgets/place_history_content.dart`
- `lib/repositories/place_history_repository.dart`

主な関数・変数:

- `MainShell._selectTab(2)`
- `SettingsPage`
- `PlaceHistoryContent.didUpdateWidget()`
- `PlaceHistoryContent._reloadHistory()`
- `PlaceHistoryRepository.fetchHistory()`

### 9.2 履歴カードまたは「マップで開く」を押す

#### ユーザー操作

履歴カード、またはカード内の「マップで開く」を押します。

#### 表示される動き

マップタブへ移動し、そのスポットの `Marker` と詳細ボトムシートが表示されます。

#### 裏側のコード

処理の流れ:

1. 履歴カード全体、または「マップで開く」ボタンを押すと `PlaceHistoryContent` の `widget.onOpenPlace(place)` が呼ばれます。
2. `SettingsPage` から渡された `onOpenPlace` は、最終的に `MainShell._openPlace(place)` へつながります。
3. `_openPlace()` は `setState()` の中で `_selectedPlace` に対象スポットを保存します。
4. `_placeOpenRequestId` を増やし、同じスポットを連続で開いた場合でも `MapPage.didUpdateWidget()` が変更を検知できるようにします。
5. `_hasVisitedMap = true` にして、まだマップタブを開いたことがない場合でも `MapPage` が生成される状態にします。
6. `_currentIndex = 1` にして、表示タブをマップへ切り替えます。
7. `MainShell.build()` は `MapPage` に `initialPlace` と `initialPlaceRequestId` を渡します。
8. 既存の `MapPage` がある場合、`MapPage.didUpdateWidget()` が `initialPlaceRequestId` の変化と `initialPlace` の存在を確認します。
9. 条件に一致すると `_restorePlace(place)` を呼びます。
10. `_restorePlace()` は候補取得タイマーを止め、`_suggestionRequestId` と `_searchRequestId` を更新し、候補取得と進行中のテキスト検索を論理的に無効化します。
11. 検索欄を空にし、`setState()` で `places` を対象スポット1件だけにします。
12. `_isShowingRestoredPlace = true`、候補なし、`_lastSubmittedQuery = null`、`_activeSearchQuery = null`、`isSearching = false`、エラーなしの状態にします。
13. 無効化された検索が後から成功または失敗しても、検索番号の判定により履歴スポット、SnackBar、カメラ、検索状態を上書きしません。
14. `GoogleMapController` がすでにある場合は `_openInitialPlace(place)` を呼び、対象位置に合わせた地図の表示範囲の更新と詳細ボトムシート表示を行います。
15. まだ地図が作成されていない場合は、`_onMapCreated()` 後に `_openInitialPlace()` が実行されます。
16. `_openInitialPlace()` は地図の表示範囲を対象スポットに合わせて更新し、次フレームで詳細ボトムシートを開きます。

該当コードの抜粋（lib/pages/03_main_shell/main_shell.dart）:

```dart
void _openPlace(Place place) {
  setState(() {
    _selectedPlace = place;
    _placeOpenRequestId++;
    _hasVisitedMap = true;
    _currentIndex = 1;
  });
}
```

該当コードの抜粋（lib/pages/02_top/widgets/place_history_content.dart）:

```dart
Card(
  key: ValueKey<String>('history-card-${place.id}'),
  child: InkWell(
    onTap: () => widget.onOpenPlace(place),
    child: TextButton.icon(
      onPressed: () => widget.onOpenPlace(place),
      icon: const Icon(Icons.map_outlined, size: 18),
      label: const Text('マップで開く'),
    ),
  ),
)
```

該当コードの抜粋（lib/pages/04_map/map_page.dart）:

```dart
@override
void didUpdateWidget(covariant MapPage oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (oldWidget.initialPlaceRequestId != widget.initialPlaceRequestId &&
      widget.initialPlace != null) {
    _restorePlace(widget.initialPlace!);
  }
}

void _restorePlace(Place place) {
  _suggestionDebounce?.cancel();
  _suggestionRequestId++;
  _searchRequestId++;
  _searchController.clear();
  setState(() {
    places = <Place>[place];
    _isShowingRestoredPlace = true;
    _suggestions = const <PlaceSuggestion>[];
    _isLoadingSuggestions = false;
    _lastSubmittedQuery = null;
    _activeSearchQuery = null;
    isSearching = false;
    errorMessage = null;
  });

  if (_mapController != null) {
    unawaited(_openInitialPlace(place));
  }
}
```

関連コード:

ファイル:

- `lib/pages/02_top/widgets/place_history_content.dart`
- `lib/pages/03_main_shell/main_shell.dart`
- `lib/pages/04_map/map_page.dart`

主な関数・変数:

- `PlaceHistoryContent.onOpenPlace`
- `MainShell._openPlace()`
- `MapPage.didUpdateWidget()`
- `_MapPageState._restorePlace()`
- `_MapPageState._openInitialPlace()`
- `_MapPageState._searchRequestId`
- `_MapPageState._activeSearchQuery`

## 10. データ保存仕様

### 10.1 ローカル認証

ローカル認証は `SharedPreferences` に保存されます。

| キー | 内容 |
| --- | --- |
| `mock_auth_accounts` | メールアドレスをキー、パスワードを値にしたJSON |
| `mock_auth_registered_email` | 互換用の最新登録メール |
| `mock_auth_registered_password` | 互換用の最新登録パスワード |
| `mock_auth_is_logged_in` | ログイン中かどうか |
| `mock_auth_logged_in_email` | 現在ログイン中のメールアドレス |

### 10.2 チュートリアル完了状態

チュートリアル完了状態は `SharedPreferences` に保存されます。

| キー | 内容 |
| --- | --- |
| `tutorial_completed` | チュートリアル完了済みなら `true` |

### 10.3 スポット閲覧履歴

スポット閲覧履歴は `PlaceHistoryRepository` が `SharedPreferences` に保存します。

| 項目 | 内容 |
| --- | --- |
| 保存キー | `place_view_history` |
| 最大件数 | 20件 |
| 重複処理 | 同じ `place.id` の既存履歴を除外し、最新を先頭へ入れる |
| 保存形式 | `Place` をJSON文字列にして `StringList` 保存 |

処理の流れ:

1. スポット詳細ボトムシートを表示すると、`MapPage._showPlaceBottomSheet()` から `PlaceHistoryRepository.add(place)` が呼ばれます。
2. `add()` は `SharedPreferences` から `place_view_history` の `StringList` を読み込みます。
3. 保存済み文字列を `_decodePlace()` で `Place` に戻します。
4. JSONとして壊れている履歴、または `Place` に復元できない履歴は `whereType<Place>()` で除外します。
5. 同じ `place.id` の履歴を一度取り除きます。これにより重複表示ではなく「最新閲覧として先頭へ移動」になります。
6. 新しく表示した `place` をリストの先頭へ追加します。
7. 最大件数 `_maxHistoryCount` を超えないように `take(_maxHistoryCount)` で20件までに切り詰めます。
8. `_encodePlace()` で各 `Place` をJSON文字列化します。
9. `setStringList()` で `place_view_history` に保存します。
10. 履歴画面は `fetchHistory()` で同じキーを読み、保存順のまま一覧表示します。
11. 保存時に例外が発生した場合、呼び出し元の `MapPage._showPlaceBottomSheet()` はデバッグログへ記録し、ボトムシート表示自体は継続します。

該当コードの抜粋（lib/repositories/place_history_repository.dart）:

```dart
Future<List<Place>> fetchHistory() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final List<String> storedPlaces =
      preferences.getStringList(_storageKey) ?? const <String>[];

  return storedPlaces
      .map(_decodePlace)
      .whereType<Place>()
      .take(_maxHistoryCount)
      .toList();
}

Future<void> add(Place place) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final List<String> storedPlaces =
      preferences.getStringList(_storageKey) ?? const <String>[];
  final List<Place> history = storedPlaces
      .map(_decodePlace)
      .whereType<Place>()
      .where((Place storedPlace) => storedPlace.id != place.id)
      .toList();

  history.insert(0, place);
  await preferences.setStringList(
    _storageKey,
    history.take(_maxHistoryCount).map(_encodePlace).toList(),
  );
}
```

## 11. Google Places API との連携

`GooglePlacesRepository` は Google Places API を呼び、レスポンスをアプリ内の `Place` や `PlaceSuggestion` に変換します。

検索実行時は `places:searchText`、候補表示時は `places:autocomplete` を使います。

### 11.1 APIキーの準備と取り扱い

このプロジェクトを手元で実行するには、Google Maps API と Google Places API を使用するためのAPIキーが必要です。実行する人が各自でGoogle Cloudを使って、自分のAPIキーを発行してください。プロジェクト作成者のAPIキーをそのまま使用してはいけません。

発行したAPIキーは、このプロジェクトで使用しているJSON設定ファイルに設定してからアプリを実行します。

APIキーを設定した後は、次の点に注意してください。

1. APIキーを設定したJSONファイルを、そのままGitHubなどへプッシュ（送信）しないでください。
2. APIキーを含むJSONファイルを `.gitignore` に追加し、Gitの管理対象から外してください。
3. すでにGitの管理対象になっているファイルは、`.gitignore` に追加するだけでは管理対象から外れない場合があります。プッシュする前に、そのファイルがGitの管理対象になっていないことを確認してください。
4. APIキーを含んだ状態ですでにプッシュした場合、ファイルを削除してもGitの履歴にAPIキーが残る可能性があります。この場合は、Google Cloud側でそのAPIキーを無効化し、新しいAPIキーを発行してください。

主な設定:

| 項目 | 内容 |
| --- | --- |
| APIキー | `String.fromEnvironment('GOOGLE_PLACES_API_KEY')` |
| 言語 | `ja` |
| 地域 | `JP` |
| 検索範囲 | 現在地と `SearchSettings.radiusMeters` から計算 |
| 最大件数 | `SearchSettings.maxResultCount` |

`GooglePlacesRepository._validatedApiKey` はAPIキーが空、または `'あなたのキー'` の場合に例外を投げます。マップ側ではこの例外を捕捉し、ユーザーには「検索に失敗しました」と表示します。

APIレスポンスから `Place` への主な対応:

| API 側 | アプリ側 |
| --- | --- |
| `places[].id` | `Place.id` |
| `places[].displayName.text` | `Place.name` |
| `places[].formattedAddress` | `Place.description` |
| `places[].location.latitude` | `Place.latitude` |
| `places[].location.longitude` | `Place.longitude` |
| `places[].currentOpeningHours.openNow` | `Place.isOpenNow` |

処理の流れ:

1. `MapPage._searchPlacesByText()` から `PlaceRepository.searchPlacesByText()` が呼ばれます。
2. 実体が `GooglePlacesRepository` の場合、`searchPlacesByText()` が Google Places Text Search API のリクエストを組み立てます。
3. 検索語は `trim()` され、空なら `ArgumentError` を投げてAPI呼び出しへ進みません。
4. 検索半径が0以下の場合も `ArgumentError` を投げ、API呼び出しへ進みません。
5. 共通通信関数 `_postJsonObject()` が `_validatedApiKey` で `GOOGLE_PLACES_API_KEY` が設定済みか確認します。未設定またはプレースホルダー値なら例外を投げます。
6. `maxResultCount` は Google Places API の上限に合わせて 1 から 20 の範囲に丸めます。
7. `_buildSearchBounds()` が現在地と検索半径から矩形の `locationRestriction` を作ります。
8. `searchPlacesByText()` がエンドポイント、Field Mask、リクエスト本文を `_postJsonObject()` に渡します。
9. リクエストには `textQuery`、`pageSize`、`languageCode: ja`、`regionCode: JP`、矩形の `locationRestriction` を含めます。
10. `_postJsonObject()` がAPIキーを含む共通ヘッダーを生成し、リクエスト本文をJSONへエンコードして `http.Client.post()` を実行します。
11. `_postJsonObject()` がHTTPステータスを検証し、2xx以外ならレスポンス本文付きで例外を投げます。
12. `_postJsonObject()` がレスポンスをJSONとしてデコードし、トップレベルが `Map<String, dynamic>` でなければ `FormatException` を投げます。
13. `_parsePlacesResponse()` がレスポンス内の `places` 配列を取り出し、各要素を `_toPlace()` でアプリ内モデル `Place` に変換します。
14. 変換できない要素は `whereType<Place>()` で除外します。
15. API の矩形検索結果に対し、念のため `_distanceMeters()` で指定半径内のスポットだけに絞ります。
16. 変換済みの `List<Place>` が `MapPage` に戻り、`places`、`filteredPlaces`、`Marker` 表示に使われます。
17. Autocomplete は `fetchAutocompleteSuggestions()` が入力文字を検証し、空なら空配列を返します。
18. 入力がある場合は `places:autocomplete` に `input`、現在地ベースの `locationBias`、`languageCode: ja`、`regionCode: JP` を送信します。
19. Autocomplete も `_postJsonObject()` で同じ通信・検証処理を通り、レスポンス固有の処理で `PlaceSuggestion` に変換して検索候補として返します。

該当コードの抜粋（lib/repositories/google_places_repository.dart）:

```dart
Future<List<Place>> searchPlacesByText({
  required String query,
  required double latitude,
  required double longitude,
  required double radiusMeters,
  int maxResultCount = 20,
}) async {
  final int pageSize = maxResultCount.clamp(1, 20);
  final _SearchBounds bounds = _buildSearchBounds(
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
  );

  final Map<String, dynamic> response = await _postJsonObject(
    endpoint: _textSearchEndpoint,
    fieldMask: _fieldMask,
    body: <String, Object>{
      'textQuery': query.trim(),
      'pageSize': pageSize,
      'languageCode': 'ja',
      'regionCode': 'JP',
      'locationRestriction': <String, Object>{
        'rectangle': <String, Object>{
          'low': <String, double>{
            'latitude': bounds.south,
            'longitude': bounds.west,
          },
          'high': <String, double>{
            'latitude': bounds.north,
            'longitude': bounds.east,
          },
        },
      },
    },
  );

  return _parsePlacesResponse(response);
}
```

該当コードの抜粋（lib/repositories/google_places_repository.dart）:

```dart
Future<Map<String, dynamic>> _postJsonObject({
  required String endpoint,
  required String fieldMask,
  required Map<String, Object> body,
}) async {
  final String apiKey = _validatedApiKey;
  final http.Response response = await _client.post(
    Uri.parse(endpoint),
    headers: <String, String>{
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': fieldMask,
    },
    body: jsonEncode(body),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    if (endpoint == _autocompleteEndpoint) {
      throw Exception(
        'Google Places Autocomplete request failed: '
        'status=${response.statusCode}, body=${response.body}',
      );
    }
    developer.log(
      'Google Places API failed status=${response.statusCode} body=${response.body}',
      name: 'GooglePlacesRepository',
    );
    throw Exception(
      'Google Places API request failed: '
      'status=${response.statusCode}, body=${response.body}',
    );
  }

  final Object? decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    if (endpoint == _autocompleteEndpoint) {
      throw const FormatException(
        'Google Places Autocomplete returned invalid JSON.',
      );
    }
    throw const FormatException(
      'Google Places API returned invalid JSON.',
    );
  }
  return decoded;
}
```

該当コードの抜粋（lib/repositories/google_places_repository.dart）:

```dart
Place? _toPlace(Map<String, dynamic> json) {
  final Map<String, dynamic> displayName =
      (json['displayName'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
  final Map<String, dynamic> location =
      (json['location'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
  final Map<String, dynamic> currentOpeningHours =
      (json['currentOpeningHours'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};

  final String name = (displayName['text'] as String?)?.trim() ?? '';
  final num? latitudeNum = location['latitude'] as num?;
  final num? longitudeNum = location['longitude'] as num?;

  if (name.isEmpty || latitudeNum == null || longitudeNum == null) {
    return null;
  }

  return Place(
    id: (json['id'] as String?) ??
        'place_${location['latitude']}_${location['longitude']}',
    name: name,
    description: (json['formattedAddress'] as String?)?.trim() ?? '',
    latitude: latitudeNum.toDouble(),
    longitude: longitudeNum.toDouble(),
    webUrl: placeholderPlaceWebUrl,
    isOpenNow: currentOpeningHours['openNow'] as bool?,
  );
}
```

関連コード:

ファイル:

- `lib/repositories/google_places_repository.dart`
- `lib/repositories/place_repository.dart`
- `lib/models/place.dart`
- `lib/models/place_suggestion.dart`

主な関数・変数:

- `PlaceRepository.searchPlacesByText()`
- `GooglePlacesRepository.fetchPlaces()`
- `GooglePlacesRepository.searchPlacesByText()`
- `GooglePlacesRepository.fetchAutocompleteSuggestions()`
- `GooglePlacesRepository._postJsonObject()`
- `GooglePlacesRepository._parsePlacesResponse()`
- `GooglePlacesRepository._toPlace()`
- `Place`
- `PlaceSuggestion`

## 12. 主要な操作とコードの対応表

| 操作 | 主なコード | 結果 |
| --- | --- | --- |
| アプリ起動 | `RootPage._routeToFirstScreen()` | チュートリアルまたはメイン画面へ遷移 |
| チュートリアルで「次へ」 | `_TutorialPageState._nextPage()` | 次ページへ移動 |
| チュートリアル完了 | `_markTutorialCompletedAndGoToMap()` | 完了状態を保存してメイン画面へ遷移 |
| ホーム表示 | `_HomePageState._loadSession()` | ログイン状態を表示 |
| 新規登録 | `_AuthFormSheetState._submit()` | アカウント保存、ログイン状態へ変更 |
| ログイン | `MockAuthRepository.login()` | 保存済みアカウントと照合 |
| ログアウト | `MockAuthRepository.logout()` | ログイン状態を解除 |
| タブ切替 | `MainShell._selectTab()` | 選択タブを表示 |
| マップ初期表示 | `MapPage._initializePage()` | 現在地取得、地図表示 |
| 検索入力 | `MapPage._onSearchTextChanged()` | 候補取得 |
| 検索実行 | `MapPage._searchPlacesByText()`, `_runTextSearch()` | 最新の検索結果をピンで表示 |
| 候補選択 | `MapPage._selectSuggestion()` | 候補文字列で検索 |
| 検索クリア | `MapPage._clearSearch()` | 進行中検索を無効化して検索状態を初期化 |
| フィルター変更 | `MapPage._showFilterBottomSheet()`, `MapFilterSheet`, `didUpdateWidget()` | シートから変更した検索条件をすぐに通知し、距離・件数変更時は最新の検索条件で再検索 |
| ピンタップ | `MapPage._onPlaceMarkerTap()` | 詳細ボトムシート表示、履歴保存 |
| 外部で開く | `PlaceBottomSheet._openExternalBrowser()` | 外部アプリで URL を開く |
| アプリ内で開く | `PlaceBottomSheet._openInAppWebView()` | WebView画面へ遷移 |
| ルートを見る | `PlaceBottomSheet._openRouteInExternalApp()` | 外部地図アプリで経路を開く |
| 履歴を開く | `PlaceHistoryContent._reloadHistory()` | 履歴一覧を読み込む |
| 履歴から開く | `MainShell._openPlace()`, `MapPage._restorePlace()` | 進行中検索を無効化してスポットを再表示 |

## 13. テストで確認されている主な動作

関連するテストファイル:

- `test/home_page_test.dart`
- `test/main_shell_test.dart`
- `test/map_page_initial_place_test.dart`
- `test/map_filter_sheet_test.dart`
- `test/map_search_bar_test.dart`
- `test/map_camera_bounds_test.dart`
- `test/place_history_repository_test.dart`
- `test/google_places_repository_test.dart`
- `test/search_settings_test.dart`

主な確認観点:

| 観点 | テスト対象 |
| --- | --- |
| ホーム認証 | 登録、ログイン、ログアウト、表示名、エラー表示 |
| タブ連携 | 履歴からマップへ戻る、初期スポットを開く |
| マップ検索UI | 検索欄、クリア、検索中状態、通常の二重送信拒否 |
| マップフィルターUI | 文言、選択肢、初期選択、設定変更通知、連続変更、同じ値の再選択抑止 |
| フィルターとMapPageの連携 | BottomSheet表示、即時通知、距離・件数の再検索、営業中のみの非再検索、再表示時の設定復元 |
| マップ検索の非同期競合 | 距離・最大件数変更による検索置換、古い結果・空結果・エラー・`finally`の無効化 |
| 検索と画面状態の連携 | 履歴復元・クリアによる検索無効化、タブ離脱中の検索継続、営業中のみ変更時のAPI再検索抑止 |
| 地図表示範囲 | 複数地点、単一点、空リスト |
| 履歴保存 | 最大20件、重複時の先頭移動、破損データ無視 |
| Google Places | API リクエスト、レスポンス変換、エラー処理 |
| 検索設定 | `SearchSettings.copyWith()` |

## 14. 運用上の注意

- `GOOGLE_PLACES_API_KEY` が未設定だと Google Places API 呼び出しは失敗します。
- 認証はモック実装です。パスワードは端末内に暗号化されていない状態で保存されるため、本番認証としては使えません。
- 履歴の `webUrl` は現在 `placeholderPlaceWebUrl` を使っています。実スポット URL を扱う場合はAPIレスポンスから取得する設計変更が必要です。
- `SettingsPage` というファイル名ですが、現在の画面内容は履歴表示です。
- `PlaceRepository.fetchPlaces()` はインターフェース上残っていますが、現在の検索UIでは主に `searchPlacesByText()` と `fetchAutocompleteSuggestions()` を使用します。

## 15. コード最適化の記録

### 15.1 Google Places API通信処理の共通化

#### 最適化の目的

Nearby Search、Text Search、Autocompleteで重複していたGoogle Places APIの通信処理を一元化し、API通信の設定や検証処理を変更するときの修正漏れと処理差異を防ぐために実施しました。

#### 変更前の構造と問題点

変更前の `lib/repositories/google_places_repository.dart` にある `GooglePlacesRepository` では、現在地周辺のスポットを取得する `fetchPlaces()`、入力された検索語からスポットを探す `searchPlacesByText()`、検索欄への入力に応じて候補を取得する `fetchAutocompleteSuggestions()` が、それぞれAPI通信に必要な処理を個別に持っていました。これらの関数は、取得したデータをマップ上の検索結果や検索候補として表示するために使われます。

- `GooglePlacesRepository` が持つ `_validatedApiKey` による、設定済みAPIキーの取得と未設定値の検証
- `http.Client.post()` の呼び出し
- `Content-Type`、`X-Goog-Api-Key`、`X-Goog-FieldMask`のヘッダー生成
- `jsonEncode()` によるリクエスト本文のJSON化
- HTTPステータスが2xxであることの検証
- `jsonDecode()` によるレスポンスのデコード
- JSONのトップレベルが `Map<String, dynamic>` であることの検証

同じ通信手順が3か所に分散していたため、共通仕様を変更する場合に複数箇所の修正が必要で、修正漏れや実装差異が発生しやすい状態でした。また、同じファイルの `GooglePlacesRepository._parsePlacesResponse()` は、APIレスポンスの妥当性を確認する処理と、レスポンス内のスポット情報を画面表示用の `Place` に変換する処理の両方を担当していました。

#### 変更内容

`lib/repositories/google_places_repository.dart` の `GooglePlacesRepository` に、Google Places APIへPOSTリクエストを送り、共通のレスポンス検証まで行うプライベート関数 `_postJsonObject()` を追加しました。この関数へ、APIキー取得、共通ヘッダー生成、JSONエンコード、HTTPステータス判定、JSONデコード、トップレベルのJSONオブジェクト検証を集約しました。

`GooglePlacesRepository.fetchPlaces()`、`GooglePlacesRepository.searchPlacesByText()`、`GooglePlacesRepository.fetchAutocompleteSuggestions()` は、それぞれの検索方法に固有のエンドポイント、Field Mask、リクエスト本文だけを組み立て、共通通信を `_postJsonObject()` に任せる構造へ変更しました。返されたJSONオブジェクトは、各関数がスポットまたは検索候補へ変換します。

`GooglePlacesRepository._parsePlacesResponse()` は `http.Response` ではなく検証済みの `Map<String, dynamic>` を受け取り、`places` 配列をマップ表示用の `Place` へ変換する処理だけを担当するようにしました。

Nearby SearchおよびText SearchとAutocompleteで異なっていた例外メッセージとログ出力は、共通化後も維持しています。

#### 変更したファイル

- `lib/repositories/google_places_repository.dart`
- `test/google_places_repository_test.dart`
- `docs/user_operation_code_manual.md`

#### 変更した主なコード

- `lib/repositories/google_places_repository.dart` の `GooglePlacesRepository`: Google Places APIへの通信と、レスポンスからアプリ内モデルへの変換を担当するクラスです。
- `GooglePlacesRepository.fetchPlaces()`: 現在地周辺のスポットを取得します。Nearby Search固有の入力値、リクエスト本文、Field Mask、レスポンス変換だけを担当する形に整理しました。
- `GooglePlacesRepository.searchPlacesByText()`: 検索語と現在地を使ってスポットを取得します。Text Search固有のリクエスト生成、指定半径による絞り込み、レスポンス変換だけを担当する形に整理しました。
- `GooglePlacesRepository.fetchAutocompleteSuggestions()`: 検索欄の入力に対する候補を取得します。Autocomplete固有のリクエスト生成と `PlaceSuggestion` への変換だけを担当する形に整理しました。
- `GooglePlacesRepository._postJsonObject()`: 3つの公開関数から呼ばれ、APIキー、POST通信、共通ヘッダー、JSON変換、ステータスとレスポンス形式の検証を一括して担当するよう追加しました。
- `GooglePlacesRepository._parsePlacesResponse()`: 検証済みJSONの `places` 配列を `Place` へ変換します。通信結果の検証を `_postJsonObject()` へ移し、モデル変換だけを担当するよう変更しました。
- `GooglePlacesRepository` の `_nearbySearchEndpoint`、`_textSearchEndpoint`、`_autocompleteEndpoint`: 各検索方法の送信先を保持します。値は変更せず、各公開関数から共通通信関数へ渡します。
- `GooglePlacesRepository` の `_fieldMask` と `_autocompleteFieldMask`: APIから取得する項目を指定します。内容は変更せず、スポット検索用と検索候補用の指定を共通通信関数へ渡します。

#### 変更後の処理の流れ

1. `GooglePlacesRepository` の各公開関数が従来どおり入力値を検証します。
2. 各公開関数が従来と同じエンドポイント、Field Mask、リクエスト本文を指定します。
3. `GooglePlacesRepository._postJsonObject()` が、同じクラスの `_validatedApiKey` から検証済みAPIキーを取得します。
4. `_postJsonObject()` が共通ヘッダーを生成し、リクエスト本文を `jsonEncode()` でJSON化します。
5. `_postJsonObject()` が `http.Client.post()` でリクエストを送信します。
6. `_postJsonObject()` がHTTPステータスを検証し、2xx以外の場合は従来と同じ条件で例外を投げます。
7. `_postJsonObject()` がレスポンス本文を `jsonDecode()` でデコードします。
8. トップレベルが `Map<String, dynamic>` でない場合は、従来と同じ条件で `FormatException` を投げます。
9. `GooglePlacesRepository.fetchPlaces()` と `GooglePlacesRepository.searchPlacesByText()` は、同じクラスの `_parsePlacesResponse()` と `_toPlace()` でAPIレスポンスをマップ表示用の `Place` へ変換します。
10. `GooglePlacesRepository.searchPlacesByText()` は従来どおり指定半径による絞り込みを行います。
11. `GooglePlacesRepository.fetchAutocompleteSuggestions()` は、同じクラスの `_toSuggestion()` でAPIレスポンスを検索欄へ表示する `PlaceSuggestion` へ変換します。

#### ユーザー操作への影響

画面上の動作や操作への変更なし。

エンドポイント、HTTPメソッド、リクエスト本文、Field Mask、検索範囲、最大件数、距離による絞り込み、モデル変換、例外条件は変更していません。

#### 技術的な効果

- 重複削減: 3つの公開関数に分散していた共通通信処理を `_postJsonObject()` に集約しました。
- 可読性向上: 公開関数から通信の定型処理がなくなり、APIごとの入力、リクエスト、変換処理を追いやすくしました。
- 責務分離: `_postJsonObject()` が通信とレスポンス検証、`_parsePlacesResponse()` が `Place`変換を担当します。
- テスト容易性向上: 3つの公開APIから同じ通信処理を通る構造となり、公開APIを増やさず共通動作を検証できます。
- 保守性向上: 共通ヘッダーやレスポンス検証の変更箇所が一か所になりました。
- バグ発生リスクの低下: API通信仕様の修正漏れや、3処理間で検証内容がずれるリスクを下げました。

#### 確認結果

- `flutter analyze`: 成功（問題なし）
- 関連テスト `flutter test test/google_places_repository_test.dart`: 9件すべて成功
- 全テスト `flutter test`: 50件すべて成功
- iOSシミュレータ向けビルド `flutter build ios --simulator`: 成功（`build/ios/iphonesimulator/Runner.app`を生成）

追加したテストでは、Nearby Searchのエンドポイント、POSTメソッド、共通ヘッダー、APIキー、Field Mask、リクエスト本文、`Place`変換、不正なJSON、トップレベルがオブジェクトでないJSONを確認しました。既存のText SearchとAutocompleteのテストでは、Field Maskを完全一致で検証するように強化しました。

#### 残っている課題

なし。

### 15.2 マップ検索の非同期リクエスト管理強化

#### 最適化の目的

テキスト検索の実行中に距離・最大件数の変更、履歴スポットの復元、検索状態のクリアが行われた場合に、古い検索結果が新しい画面状態を上書きしないようにするために実施しました。

#### 変更前の構造と問題点

変更前の `lib/pages/04_map/map_page.dart` にある `_MapPageState._searchPlacesByText()` は、検索欄から送信された検索語を受け取り、スポット検索を開始する関数です。`_MapPageState` が持つ `isSearching` は、スポット検索を実行中かどうかを保持し、検索欄の読み取り専用表示と進捗表示を切り替え、通常の二重送信を防ぐために使われます。しかし、先に開始した検索と後から開始した検索のどちらから結果が返されたかを判定する状態はありませんでした。

そのため、検索中に距離または最大件数を変更すると、親Widgetから新しい検索設定を受け取る `_MapPageState.didUpdateWidget()` が再検索を試みても `isSearching` に拒否され、変更前の条件で開始した結果が画面へ反映される可能性がありました。`_MapPageState` が持つ `places` は、取得したスポットを保持し、地図上のMarker生成に使われる一覧です。

また、検索中に履歴スポットを復元した場合や内部的に検索状態をクリアした場合も、古い検索の完了後に次の処理が実行される可能性がありました。

- 地図へ表示する `places` と、正常に反映された最後の検索語を保持する `_lastSubmittedQuery` の上書き
- 履歴スポットを表示中かどうかを保持し、「営業中のみ」の絞り込みを履歴スポットへ適用しないために使う `_isShowingRestoredPlace` の解除
- 検索結果がない場合、または検索に失敗した場合のSnackBar表示
- 古い検索結果へのカメラ移動
- 検索の成否にかかわらず終了処理を行う `finally` が、古い検索の完了時に送信中状態を解除すること

`mounted` 判定はWidget破棄後の更新を防ぎますが、Widgetが生存したまま別の表示状態へ移行したことは判別できませんでした。

#### 変更内容

`lib/pages/04_map/map_page.dart` の `_MapPageState` に、検索を開始するたびに更新する番号 `_searchRequestId` を追加しました。検索完了時に開始時の番号と現在の番号を比較することで、その結果が現在有効な検索から返されたものか、後から別の検索が開始されたため無効になったものかを判定します。

同じ `_MapPageState` に、現在実行中の検索語を保持する `_activeSearchQuery` も追加しました。正常に画面へ反映された最後の検索語を保持する既存の `_lastSubmittedQuery` とは役割を分け、検索中に距離または最大件数が変更された場合でも、実行中の検索語と新しい条件を使って検索し直せるようにしました。

通常のユーザー検索を受ける `_MapPageState._searchPlacesByText()` は、従来どおり `isSearching` で二重送信を拒否します。実際にリポジトリへ検索を依頼し、返された結果が現在有効か確認する処理は `_MapPageState._runTextSearch()` へ分けました。フィルター変更による内部再検索は `_MapPageState._replaceTextSearch()` が受け取り、通常の二重送信制御とは別に、新しい条件で検索を開始します。

`_MapPageState._runTextSearch()` は検索開始時点の検索語、現在地、検索半径、最大件数を固定し、検索ごとに `_searchRequestId` の番号を記録します。Repositoryから結果または例外が返ったときと、検索終了時の `finally` で、Widgetが表示中であることと番号が現在も一致することを確認します。これにより、古い処理の結果、SnackBar、カメラ移動、進捗状態を画面へ反映しないようにしました。

検索欄を初期状態へ戻す `_MapPageState._clearSearch()` と、履歴から選んだ1件をマップへ表示する `_MapPageState._restorePlace()` は、 `_searchRequestId` を更新し、`_activeSearchQuery` を空にして `isSearching = false` に戻します。これにより、それ以前に開始されていた検索が後から完了しても、クリア後の画面や履歴スポットを上書きしません。

タブを離れただけの場合は `_searchRequestId` を変更していません。`IndexedStack` 内で検索を継続し、マップへ戻ったときに完了済み結果を表示できる従来の動作を維持しています。

#### 変更したファイル

- `lib/pages/04_map/map_page.dart`
- `test/map_page_initial_place_test.dart`
- `docs/user_operation_code_manual.md`

`test/main_shell_test.dart` は変更していません。関連する既存テストとして実行しました。

#### 変更した主なコード

- `lib/pages/04_map/map_page.dart` の `_MapPageState._searchRequestId`: 検索開始ごとに更新する番号です。開始時と完了時の番号を比較し、古い検索結果を画面へ反映しないために追加しました。
- `_MapPageState._activeSearchQuery`: 現在実行中の検索語を保持します。検索中にフィルターが変わったとき、新しい条件で検索し直すために追加しました。
- `_MapPageState._lastSubmittedQuery`: 正常に画面へ反映された最後の検索語を保持します。実行中の検索語を別変数へ分けることで、この変数の既存の意味を維持しました。
- `_MapPageState._searchPlacesByText()`: 検索欄からの通常検索を受け、検索中の二重送信を拒否します。リポジトリ通信と結果判定を `_runTextSearch()` へ分けました。
- `_MapPageState._replaceTextSearch()`: 距離または最大件数が変わったときの内部再検索を受けます。通常検索の二重送信制御とは別に、新しい条件で検索を開始できるよう追加しました。
- `_MapPageState._runTextSearch()`: リポジトリへの検索依頼、結果が現在有効かどうかの判定、画面状態・SnackBar・カメラの更新を担当します。番号が一致する検索だけを反映するよう変更しました。
- `_MapPageState.didUpdateWidget()`: 親Widgetから新しい検索設定や履歴スポットを受け取ったときに呼ばれます。距離・最大件数の変更時に、現在の検索語を使って検索を置き換えるよう変更しました。
- `_MapPageState._clearSearch()`: 検索結果と検索欄の関連状態を初期化します。進行中の検索も無効にし、クリア後に古い結果が戻らないよう変更しました。
- `_MapPageState._restorePlace()`: 履歴から選んだスポットをマップへ復元します。進行中の検索を無効にし、履歴スポットの表示を優先するよう変更しました。
- `test/map_page_initial_place_test.dart` の `_DelayedPlaceRepository` と `_PendingSearch`: テスト内でRepositoryの完了順を制御する補助クラスです。先に開始した検索と後から開始した検索を任意の順番で完了させるために追加しました。

#### 変更後の処理の流れ

1. 通常の検索操作は `_searchPlacesByText()` が受け、`isSearching == true` の場合は従来どおり拒否します。
2. 実検索を開始する場合は `_runTextSearch()` が検索語、現在地、検索半径、最大件数を開始時点の値として固定します。
3. `_MapPageState._searchRequestId` を増やし、どの検索処理から返された結果かを後で判定できるよう、開始時の番号をローカル変数へ保持します。
4. `_activeSearchQuery` に進行中の検索語を保存し、`isSearching = true` にします。
5. Repositoryの検索完了後、Widgetが表示中かを示す `mounted` と、開始時に記録した検索番号が現在の `_searchRequestId` と一致するかを確認します。
6. 古い検索は、結果、内部状態、SnackBar、カメラを更新せず終了します。
7. 最新の検索だけが `places`、`_isShowingRestoredPlace`、`_lastSubmittedQuery` を更新し、結果に応じてSnackBarまたはカメラ移動を実行します。
8. 例外時も最新の検索だけが検索失敗のログとSnackBarを出します。
9. `finally` でも検索番号を確認し、現在有効な検索だけが `isSearching = false` と `_activeSearchQuery = null` に戻します。
10. 距離または最大件数の変更時は、検索中なら `_activeSearchQuery`、検索中でなければ `_lastSubmittedQuery` を使って新条件の検索を開始します。
11. 営業中のみの変更ではAPI再検索を行わず、既存の `filteredPlaces` によるローカル絞り込みを維持します。
12. 履歴復元またはクリア時は `_searchRequestId` を更新し、それ以前に開始した検索の結果を画面へ反映しないようにします。
13. タブを離れただけでは検索を無効化せず、検索完了後の結果を保持します。

#### ユーザー操作への影響

検索欄、フィルター、検索結果、Marker、カメラ移動、SnackBar文言などの通常操作とUIに変更はありません。

検索中の検索欄は従来どおり読み取り専用となり、検索アイコンは進捗表示へ変わり、通常の二重送信は拒否されます。

競合時のみ、最新の検索条件、履歴復元、クリア後の状態が優先され、古い非同期検索による意図しない上書きが発生しなくなりました。

#### 技術的な効果

- 非同期処理の安全性向上: 現在有効な検索から返された結果だけが画面状態を更新します。
- バグ発生リスクの低下: 古い結果、例外、`finally` による新しい状態の上書きを防ぎます。
- 責務分離: 通常送信の二重実行防止、フィルター変更による内部再検索、リポジトリ通信と結果判定を分けました。
- 保守性向上: `_lastSubmittedQuery` と進行中検索語の意味を分離しました。
- テスト容易性向上: `Completer<List<Place>>` で検索完了順を制御し、競合を再現できるようにしました。

#### 追加・変更したテスト

`test/map_page_initial_place_test.dart` に、検索結果を返すタイミングをテスト側で制御する `_DelayedPlaceRepository` と、未完了の検索条件と結果を保持する `_PendingSearch` を追加し、次を確認しました。

- 検索中の距離変更で新しい半径の検索が開始される
- 新しい検索を先に完了し、古い検索を後から完了しても最新結果だけが表示される
- 検索中の最大件数変更で新しい件数の検索が開始される
- 古い結果ではMarkerとカメラが更新されない
- 古い空結果と古い検索エラーではSnackBarが表示されない
- 古い検索の `finally` では最新の検索の進捗表示が解除されない
- 最新の検索が完了した後に進捗表示が解除される
- 検索中の履歴復元後に古い結果を完了しても履歴スポットが維持される
- 履歴復元後は検索欄が空になり、進捗表示が解除される
- 履歴復元後のフィルター変更で古い検索語が再利用されない
- クリア後に古い検索結果が反映されない
- タブを離れただけの場合は検索が継続し、結果が保持される
- 通常の二重送信が引き続き拒否される
- 営業中のみの変更では追加API検索が発生しない

既存テストは削除していません。

#### 確認結果

- `flutter analyze`: 成功（問題なし）
- 関連テスト `flutter test test/map_page_initial_place_test.dart`: 14件すべて成功
- 関連テスト `flutter test test/main_shell_test.dart`: 5件すべて成功
- 全テスト `flutter test`: 57件すべて成功
- iOSシミュレータ向けビルド `flutter build ios --simulator`: 成功（`build/ios/iphonesimulator/Runner.app`を生成）

#### 残っている課題

なし。

### 15.3 マップのフィルターUIを専用Widgetへ分離

#### 最適化の目的

`lib/pages/04_map/map_page.dart` の `MapPage` に埋め込まれていたフィルターシートの表示内容と一時状態管理を専用Widgetへ分離し、マップ・検索状態管理とフィルターUIの責務を明確にするために実施しました。`MapPage` は、Google Map、スポット検索、Marker、カメラ、検索フィルター、履歴スポットの復元をまとめて管理するマップ画面です。

#### 変更前の構造と問題点

変更前の `lib/pages/04_map/map_page.dart` にある `_MapPageState._showFilterBottomSheet()` は、ユーザーがマップ画面のフィルターボタンを押したときにBottomSheetを開く関数です。この関数は `showModalBottomSheet()` の呼び出しに加えて、約100行のシートUIと状態管理を持っていました。

- 選択中の距離、最大件数、営業中のみの値を一時的に保持する `SearchSettings draft` の初期化と更新
- BottomSheet内だけを再描画する `StatefulBuilder` と `setModalState()`
- SafeArea、余白、見出し、Divider
- 距離と最大件数の `SegmentedButton`
- 営業中のみの `SwitchListTile`
- 変更していない条件を維持しながら新しい設定を作る `SearchSettings.copyWith()`
- 変更した設定の即時通知

そのため、現在地取得、検索、非同期検索管理、Marker、カメラ、履歴などを担当する `MapPage` に、独立してテスト可能なフィルターフォームの責務も集中していました。

#### 変更内容

`lib/pages/04_map/widgets/map_filter_sheet.dart` を新規作成し、距離、最大件数、営業中のみの選択UIを表示する `MapFilterSheet` と、その選択状態を管理する `_MapFilterSheetState` を追加しました。これにより、フィルターUIと一時状態を `MapPage` から専用Widgetへ移しました。

`MapFilterSheet` が受け取る `initialSettings` は、シートを開いた時点の検索設定です。`_MapFilterSheetState.initState()` がこの値を `_draft` に保存します。`_draft` はシート内で選択中の距離、最大件数、営業中のみの値を保持し、各選択肢の表示へ反映する状態です。ユーザーが設定を変更すると、シート自身の `setState()` 内で `_draft.copyWith()` を実行し、更新後の設定を `onChanged(_draft)` で直ちに親へ通知します。

`_MapPageState._showFilterBottomSheet()` から `StatefulBuilder` とシート内部のUIを削除し、モーダル表示、背景色、角丸、初期設定の受け渡し、`MapPage.onSettingsChanged` への橋渡しだけを残しました。`onSettingsChanged` は、変更された検索設定を設定共有元の `MainShell` へ通知し、マップの再検索や表示対象の絞り込みへ反映するコールバックです。

文言、選択肢、余白、文字スタイル、Divider、`showSelectedIcon: false`、背景色、角丸、即時反映、閉じ方は変更していません。

#### 変更したファイル

- `lib/pages/04_map/map_page.dart`
- `lib/pages/04_map/widgets/map_filter_sheet.dart`
- `test/map_filter_sheet_test.dart`
- `test/map_page_initial_place_test.dart`
- `docs/user_operation_code_manual.md`

#### 変更した主なコード

- `lib/pages/04_map/widgets/map_filter_sheet.dart` の `MapFilterSheet`: 距離、最大件数、営業中のみの選択UIを表示し、変更後の `SearchSettings` を親へ通知する専用Widgetとして追加しました。
- `_MapFilterSheetState`: `MapFilterSheet` の選択状態と再描画を管理します。フィルターUIの状態管理を `MapPage` から移しました。
- `_MapFilterSheetState._draft`: シート内で選択中の検索条件を保持し、各ボタンとスイッチの選択表示へ反映します。以前の `_showFilterBottomSheet()` のローカル変数から、専用Widgetの状態へ移しました。
- `_MapFilterSheetState._updateRadius()`: ユーザーが距離を選んだとき、ほかの条件を維持した新しい設定を作り、表示更新と親への通知を行うために追加しました。
- `_MapFilterSheetState._updateMaxResultCount()`: ユーザーが最大件数を選んだとき、ほかの条件を維持した新しい設定を作り、表示更新と親への通知を行うために追加しました。
- `_MapFilterSheetState._updateOpenNowOnly()`: ユーザーが「営業中のみ」を切り替えたとき、ほかの条件を維持した新しい設定を作り、表示更新と親への通知を行うために追加しました。
- `lib/pages/04_map/map_page.dart` の `_MapPageState._showFilterBottomSheet()`: フィルターボタンからシートを開く処理です。シート内部のUIと状態管理を取り除き、`MapFilterSheet` の表示と設定通知の橋渡しだけを担当するよう変更しました。
- `lib/models/search_settings.dart` の `SearchSettings.copyWith()`: 変更対象以外の検索条件を保った新しい `SearchSettings` を作ります。呼び出し元を専用Widgetへ移しましたが、関数自体の仕様は変更していません。

#### 変更後の処理の流れ

1. マップ画面のフィルターボタンから `_MapPageState._showFilterBottomSheet()` を呼びます。
2. `MapPage` が従来と同じ背景色と上端の角丸で `showModalBottomSheet()` を表示します。
3. builderが `MapFilterSheet` を生成し、親の最新 `searchSettings` を `initialSettings` として渡します。
4. `_MapFilterSheetState.initState()` が初期設定を `_draft` へ保存します。
5. ユーザーが距離、最大件数、営業中のみを変更すると、`setState()` 内で `_draft` を更新します。
6. 更新直後に `MapFilterSheet.onChanged(_draft)` を呼びます。
7. `_MapPageState` が通知を `MapPage.onSettingsChanged` へ橋渡しします。
8. `lib/pages/03_main_shell/main_shell.dart` の `_MainShellState` が、マップ画面と履歴画面で共有する検索設定 `_settings` を更新し、最新設定を `MapPage` へ渡します。
9. 距離または最大件数が変わった場合は、`_MapPageState.didUpdateWidget()` が必要に応じて最新条件で再検索します。
10. 営業中のみの変更ではAPI再検索せず、`_MapPageState.filteredPlaces` が `places` から画面へ表示するスポットだけをローカルで絞り込みます。
11. シートを閉じる確定処理はありません。再度開くと、親が保持する最新設定から新しい `_draft` を作ります。

#### MapPageとMapFilterSheetの責務分担

`lib/pages/04_map/map_page.dart` の `MapPage` に残した責務:

- フィルターボタンの配置と押下処理
- `showModalBottomSheet()` の呼び出し
- 背景色と上端の角丸
- 初期設定の受け渡し
- `MapPage.onSettingsChanged` への橋渡し
- `_MapPageState.didUpdateWidget()` と再検索
- `_MapPageState.filteredPlaces` による表示対象の絞り込み
- 検索、Marker、カメラ、履歴などのマップ状態管理

`lib/pages/04_map/widgets/map_filter_sheet.dart` の `MapFilterSheet` へ移した責務:

- シート内部のSafeArea、余白、見出し、レイアウト
- 距離と最大件数の `SegmentedButton`
- 営業中のみの `SwitchListTile`
- 選択中の設定を保持する `_MapFilterSheetState._draft`
- `SearchSettings.copyWith()` を使った設定更新
- シート内部の `setState()`
- 変更した設定の即時通知

`MapFilterSheet` はリポジトリ、検索語、検索リクエスト、Marker、カメラを参照しません。

#### ユーザー操作への影響

画面上の見た目、文言、選択肢、操作、即時反映、再検索、BottomSheetの閉じ方に変更なし。

距離または最大件数変更時の再検索、進行中検索の置き換え、営業中のみ変更時のローカル絞り込みも従来どおりです。

#### 技術的な効果

- 責務分離: フィルターUIと一時状態をマップ・検索状態管理から分離しました。
- 可読性向上: `_showFilterBottomSheet()` をモーダル表示と橋渡しだけに縮小しました。
- テスト容易性向上: Google MapやリポジトリなしでフィルターUIを単体テストできます。
- 保守性向上: 文言、選択肢、レイアウト、通知処理を専用ファイルで管理できます。
- バグ発生リスクの低下: 連続変更時の設定維持や通知内容をWidget単体テストで固定しました。

#### 追加・変更したテスト

新規の `test/map_filter_sheet_test.dart` では次を確認しました。

- 既存の見出し、文言、距離・件数の全選択肢
- 初期距離、初期最大件数、初期営業中のみの選択状態
- 距離変更時に件数と営業状態を維持した通知
- 最大件数変更時に距離と営業状態を維持した通知
- 営業中のみ変更時に距離と最大件数を維持した通知
- 連続変更時に変更値を累積した順序どおりの通知
- 選択済み距離・件数の再選択で不要な通知が発生しないこと

`test/map_page_initial_place_test.dart` には、実際のフィルターボタンからシートを開く連携テストを追加しました。

- `MapFilterSheet` がBottomSheetとして表示される
- 距離、最大件数、営業中のみが `MapPage.onSettingsChanged` へ即時通知される
- 距離変更で新しい半径の検索が開始される
- 最大件数変更で新しい件数の検索が開始される
- 営業中のみの変更では追加API検索が発生しない
- シートを閉じて再度開くと親が保持する最新設定が選択状態へ反映される

既存の非同期検索テストは削除・弱体化していません。

#### 確認結果

- `flutter analyze`: 成功（問題なし）
- Widget単体テスト `flutter test test/map_filter_sheet_test.dart`: 6件すべて成功
- MapPage関連テスト `flutter test test/map_page_initial_place_test.dart`: 15件すべて成功
- 全テスト `flutter test`: 64件すべて成功
- iOSシミュレータ向けビルド `flutter build ios --simulator`: 成功（`build/ios/iphonesimulator/Runner.app`を生成）

#### 残っている課題

なし。

### 15.4 履歴カードの営業状態表示の整理

#### 変更前の重複

`lib/pages/02_top/widgets/place_history_content.dart` の `PlaceHistoryContent` は、保存済みのスポットを履歴カードとして一覧表示するWidgetです。変更前は、各カードが受け取る `Place.isOpenNow` に対し、表示文字列を `_PlaceHistoryContentState._openingStatus()`、文字色と背景色の基準になる色を `_PlaceHistoryContentState._openingStatusColor()` で別々に判定していました。`Place.isOpenNow` は、スポットが営業中なら `true`、営業時間外なら `false`、情報がない場合は `null` を保持し、履歴カード右上の営業状態表示に使われます。同じ3状態の分岐が2か所にあったため、表示文字列と色の対応がずれる可能性がありました。

#### 変更内容

`lib/pages/02_top/widgets/place_history_content.dart` の `_PlaceHistoryContentState._openingStatus()` が、表示文字列 `label` と表示色 `color` をまとめた `({String label, Color color})` のrecordを返す構造へ変更しました。営業状態ごとの文字列と色を1回のswitch式で決定し、重複していた `_openingStatusColor()` は削除しました。

同じクラスの `_buildHistoryCard()` は、1件の `Place` から履歴カードを組み立てる関数です。最適化後は `_openingStatus()` から取得したrecordの `label` を営業状態の文言として表示し、`color` を文字色と従来どおりの背景色計算に使用します。

表示内容は変更していません。

- `true`: 「営業中」、`Color(0xFF167A3D)`
- `false`: 「営業時間外」、`Color(0xFFB3261E)`
- `null`: 「営業時間不明」、`Color(0xFF6B6B70)`

#### 技術的な効果

- 重複削減: 営業状態のswitch判定を2か所から1か所へ集約しました。
- 可読性向上: 文字列と色の対応を同じ分岐で確認できます。
- 保守性向上: 営業状態表示を変更するときの修正漏れを防ぎやすくしました。
- バグ発生リスクの低下: 文字列と色の組み合わせがずれる可能性を下げました。

#### ユーザー操作への影響

履歴カードの見た目、文言、色、レイアウト、タップ操作に変更なし。

#### テスト結果

- `true`、`false`、`null` の3状態で、既存の表示文字列と文字色を確認するWidgetテストを追加
- `flutter analyze`: 成功（問題なし）
- `flutter test`: 65件すべて成功
- `flutter build ios --simulator`: 成功

#### 残っている課題

なし。
