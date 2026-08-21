import 'package:flutter/material.dart';

import '../../models/place.dart';
import '../../models/search_settings.dart';
import '../../repositories/place_history_repository.dart';
import '../02_top/widgets/place_history_content.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onOpenPlace,
    this.historyRepository = const PlaceHistoryRepository(),
    this.reloadToken = 0,
  });

  final SearchSettings settings;
  final ValueChanged<SearchSettings> onChanged;
  final ValueChanged<Place> onOpenPlace;
  final PlaceHistoryRepository historyRepository;
  final int reloadToken;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: SafeArea(
        child: PlaceHistoryContent(
          historyRepository: historyRepository,
          onOpenPlace: onOpenPlace,
          reloadToken: reloadToken,
        ),
      ),
    );
  }
}
