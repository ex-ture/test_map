import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/place.dart';
import '../../models/place_suggestion.dart';
import '../../models/search_settings.dart';
import '../../repositories/google_places_repository.dart';
import '../../repositories/place_history_repository.dart';
import '../../repositories/place_repository.dart';
import 'map_camera_bounds.dart';
import 'widgets/map_filter_sheet.dart';
import 'widgets/map_search_bar.dart';
import 'widgets/place_bottom_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    this.searchSettings = const SearchSettings(),
    this.onSettingsChanged,
    this.initialPlace,
    this.initialPlaceRequestId = 0,
    this.isActive = true,
    this.repository,
    this.historyRepository = const PlaceHistoryRepository(),
    this.currentLocationLoader,
  });

  final SearchSettings searchSettings;
  final ValueChanged<SearchSettings>? onSettingsChanged;
  final Place? initialPlace;
  final int initialPlaceRequestId;
  final bool isActive;
  final PlaceRepository? repository;
  final PlaceHistoryRepository historyRepository;
  final Future<LatLng?> Function()? currentLocationLoader;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final PlaceRepository _repository;
  late final PlaceHistoryRepository _historyRepository;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _suggestionDebounce;

  List<Place> places = [];
  List<PlaceSuggestion> _suggestions = const <PlaceSuggestion>[];
  bool isLoading = true;
  bool isSearching = false;
  bool _isLoadingSuggestions = false;
  String? errorMessage;
  String? _lastSubmittedQuery;
  LatLng? currentLocation;
  bool _hasOpenedInitialPlace = false;
  bool _isShowingRestoredPlace = false;
  int _suggestionRequestId = 0;
  int _searchRequestId = 0;
  String? _activeSearchQuery;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.681236, 139.767125), // 東京駅付近
    zoom: 13.0,
  );

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? GooglePlacesRepository();
    _historyRepository = widget.historyRepository;
    _isShowingRestoredPlace = widget.initialPlace != null;
    _initializePage();
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive && !widget.isActive) {
      FocusManager.instance.primaryFocus?.unfocus();
      _closeSuggestions();
    }

    if (oldWidget.initialPlaceRequestId != widget.initialPlaceRequestId &&
        widget.initialPlace != null) {
      _restorePlace(widget.initialPlace!);
    }

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

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
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

  Future<void> _searchPlacesByText([String? submittedQuery]) async {
    if (isSearching) {
      return;
    }

    await _runTextSearch(submittedQuery);
  }

  Future<void> _replaceTextSearch(String query) async {
    await _runTextSearch(query);
  }

  Future<void> _runTextSearch([String? submittedQuery]) async {
    final String query = (submittedQuery ?? _searchController.text).trim();
    _closeSuggestions();
    if (query.isEmpty) {
      _showMessage('検索ワードを入力してください');
      return;
    }

    final LatLng? location = currentLocation;
    if (location == null) {
      _showMessage('現在地を取得できませんでした');
      return;
    }

    final double radiusMeters = widget.searchSettings.radiusMeters.toDouble();
    final int maxResultCount = widget.searchSettings.maxResultCount;
    final int requestId = ++_searchRequestId;

    FocusScope.of(context).unfocus();
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

      if (fetchedPlaces.isEmpty) {
        _showMessage('検索結果が見つかりませんでした');
        return;
      }

      final List<Place> visiblePlaces = widget.searchSettings.openNowOnly
          ? fetchedPlaces
                .where((Place place) => place.isOpenNow == true)
                .toList()
          : fetchedPlaces;
      if (visiblePlaces.isEmpty) {
        _showMessage('検索結果が見つかりませんでした');
        return;
      }

      await _fitCameraToPlaces(visiblePlaces);
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  void _dismissSearchOverlay() {
    FocusManager.instance.primaryFocus?.unfocus();
    _closeSuggestions();
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _searchController.text = suggestion.text;
    _searchController.selection = TextSelection.collapsed(
      offset: suggestion.text.length,
    );
    _closeSuggestions();
    await _searchPlacesByText(suggestion.text);
  }

  Widget _buildSuggestionPanel() {
    if (!_isLoadingSuggestions && _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, right: 56),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8D8DC)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: _isLoadingSuggestions && _suggestions.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 48),
              itemBuilder: (BuildContext context, int index) {
                final PlaceSuggestion suggestion = _suggestions[index];
                return ListTile(
                  key: ValueKey<String>('place-suggestion-$index'),
                  dense: true,
                  leading: Icon(
                    suggestion.type == PlaceSuggestionType.place
                        ? Icons.location_on_outlined
                        : Icons.search,
                  ),
                  title: Text(
                    suggestion.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
    );
  }

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
    final LatLng fetchedLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    if (!mounted) {
      return null;
    }
    setState(() {
      currentLocation = fetchedLocation;
    });

    await _moveCameraToCurrentLocation(fetchedLocation);
    return fetchedLocation;
  }

  Future<void> _moveCameraToCurrentLocation(LatLng location) async {
    final GoogleMapController? controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 15),
      ),
    );
  }

  Future<void> _moveCameraToPlace(Place place) async {
    final GoogleMapController? controller = _mapController;
    if (controller == null || !mounted) {
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(place.latitude, place.longitude),
          zoom: 16,
        ),
      ),
    );
  }

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

  Future<void> _openInitialPlace(Place place) async {
    try {
      await _moveCameraToPlace(place);
    } catch (error, stackTrace) {
      debugPrint('MapPage initial place camera error: $error');
      debugPrint('MapPage initial place camera stack: $stackTrace');
    }

    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_showPlaceBottomSheet(place));
      }
    });
    WidgetsBinding.instance.scheduleFrame();
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

    try {
      if (resultPlaces.length == 1 || hasSingleCoordinate) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(bounds.southwest, 16),
        );
        return;
      }

      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } catch (error, stackTrace) {
      debugPrint('MapPage fit camera error: $error');
      debugPrint('MapPage fit camera stack: $stackTrace');
    }
  }

  Future<void> _onPlaceMarkerTap(Place place) async {
    try {
      await _moveCameraToPlace(place);
    } catch (error, stackTrace) {
      debugPrint('MapPage marker camera error: $error');
      debugPrint('MapPage marker camera stack: $stackTrace');
    }

    if (mounted) {
      await _showPlaceBottomSheet(place);
    }
  }

  Future<void> _showPlaceBottomSheet(Place place) async {
    if (!mounted) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) =>
          PlaceBottomSheet(place: place, currentLocation: currentLocation),
    );

    try {
      await _historyRepository.add(place);
    } catch (error, stackTrace) {
      debugPrint('MapPage save place history error: $error');
      debugPrint('MapPage save place history stack: $stackTrace');
    }
  }

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

  List<Place> get filteredPlaces {
    return widget.searchSettings.openNowOnly && !_isShowingRestoredPlace
        ? places.where((Place place) => place.isOpenNow == true).toList()
        : places;
  }

  Set<Marker> _buildMarkers(List<Place> sourcePlaces) {
    return sourcePlaces.map((Place place) {
      return Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.latitude, place.longitude),
        infoWindow: InfoWindow(title: place.name, snippet: place.description),
        onTap: () async {
          debugPrint('MapPage marker tapped: ${place.name}');
          if (!mounted) {
            return;
          }
          await _onPlaceMarkerTap(place);
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final List<Place> currentFilteredPlaces = filteredPlaces;
    final Set<Marker> currentMarkers = _buildMarkers(currentFilteredPlaces);

    final Widget body;
    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (errorMessage != null) {
      body = Center(child: Text(errorMessage ?? ''));
    } else {
      body = Stack(
        children: [
          GoogleMap(
            initialCameraPosition: widget.initialPlace == null
                ? _initialPosition
                : CameraPosition(
                    target: LatLng(
                      widget.initialPlace!.latitude,
                      widget.initialPlace!.longitude,
                    ),
                    zoom: 16,
                  ),
            markers: currentMarkers,
            myLocationEnabled: currentLocation != null,
            myLocationButtonEnabled: true,
            onMapCreated: _onMapCreated,
            onTap: (_) => _dismissSearchOverlay(),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MapSearchBar(
                          controller: _searchController,
                          isSearching: isSearching,
                          showClearButton: places.isNotEmpty,
                          onChanged: _onSearchTextChanged,
                          onSearch: _searchPlacesByText,
                          onClear: _clearSearch,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.white,
                        elevation: 0,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _showFilterBottomSheet,
                          child: Container(
                            width: 48,
                            height: 52,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD8D8DC),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildSuggestionPanel(),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(body: body);
  }
}
