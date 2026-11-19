import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'constants/place_urls.dart';
import 'firebase_options.dart';
import 'models/place.dart';
import 'pages/00_root/root_page.dart';
import 'pages/01_tutorial/tutorial_page.dart';
import 'pages/03_main_shell/main_shell.dart';
import 'pages/05_webview/webview_page.dart';
import 'repositories/firebase_auth_repository.dart';
import 'routes/app_routes.dart';
import 'services/analytics_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.authRepository = const FirebaseAuthRepository(),
    this.analyticsService = const FirebaseAnalyticsService(),
  });

  final AuthRepository authRepository;
  final AnalyticsService analyticsService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'スポットマップ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
          outline: Color(0xFFD8D8DC),
        ),
        dividerColor: const Color(0xFFD8D8DC),
        splashColor: const Color(0x11000000),
        highlightColor: const Color(0x08000000),
      ),
      initialRoute: AppRoutes.root,
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case AppRoutes.root:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const RootPage(),
            );
          case AppRoutes.tutorial:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const TutorialPage(),
            );
          case AppRoutes.mainShell:
            final Place? initialPlace = settings.arguments is Place
                ? settings.arguments as Place
                : null;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => MainShell(
                initialTabIndex: initialPlace == null ? 0 : 1,
                initialPlace: initialPlace,
                authRepository: authRepository,
                analyticsService: analyticsService,
              ),
            );
          case AppRoutes.map:
            final Place? initialPlace = settings.arguments is Place
                ? settings.arguments as Place
                : null;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => MainShell(
                initialTabIndex: 1,
                initialPlace: initialPlace,
                authRepository: authRepository,
                analyticsService: analyticsService,
              ),
            );
          case AppRoutes.webview:
            final Object? arguments = settings.arguments;
            final String url = arguments is String && arguments.isNotEmpty
                ? arguments
                : firebaseHostingWebUrl;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  WebViewPage(url: url, analyticsService: analyticsService),
            );
          default:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const RootPage(),
            );
        }
      },
    );
  }
}
