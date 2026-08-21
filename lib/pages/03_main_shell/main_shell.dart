import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/place.dart';
import '../../models/search_settings.dart';
import '../../repositories/place_history_repository.dart';
import '../../repositories/place_repository.dart';
import '../04_map/map_page.dart';
import '../06_settings/settings_page.dart';
import 'home_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialTabIndex = 0,
    this.initialSettings = const SearchSettings(),
    this.initialPlace,
    this.historyRepository = const PlaceHistoryRepository(),
    this.mapRepository,
    this.currentLocationLoader,
  });

  final int initialTabIndex;
  final SearchSettings initialSettings;
  final Place? initialPlace;
  final PlaceHistoryRepository historyRepository;
  final PlaceRepository? mapRepository;
  final Future<LatLng?> Function()? currentLocationLoader;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  late SearchSettings _settings;
  Place? _selectedPlace;
  int _placeOpenRequestId = 0;
  int _historyReloadToken = 0;
  late bool _hasVisitedMap;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _settings = widget.initialSettings;
    _selectedPlace = widget.initialPlace;
    _hasVisitedMap = widget.initialTabIndex == 1 || widget.initialPlace != null;
    if (widget.initialPlace != null) {
      _placeOpenRequestId = 1;
    }
  }

  void _openPlace(Place place) {
    setState(() {
      _selectedPlace = place;
      _placeOpenRequestId++;
      _hasVisitedMap = true;
      _currentIndex = 1;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              repository: widget.mapRepository,
              historyRepository: widget.historyRepository,
              currentLocationLoader: widget.currentLocationLoader,
              onSettingsChanged: (SearchSettings value) {
                setState(() {
                  _settings = value;
                });
              },
            )
          else
            const SizedBox.expand(),
          SettingsPage(
            settings: _settings,
            onChanged: (SearchSettings value) {
              setState(() {
                _settings = value;
              });
            },
            historyRepository: widget.historyRepository,
            onOpenPlace: _openPlace,
            reloadToken: _historyReloadToken,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'マップ'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: '履歴'),
        ],
      ),
    );
  }
}
