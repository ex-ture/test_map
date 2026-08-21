import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routes/app_routes.dart';

const String tutorialCompletedPreferenceKey = 'tutorial_completed';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

Future<void> markTutorialCompleted() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setBool(tutorialCompletedPreferenceKey, true);
}
