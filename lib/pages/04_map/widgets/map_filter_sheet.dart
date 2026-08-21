import 'package:flutter/material.dart';

import '../../../models/search_settings.dart';

class MapFilterSheet extends StatefulWidget {
  const MapFilterSheet({
    super.key,
    required this.initialSettings,
    required this.onChanged,
  });

  final SearchSettings initialSettings;
  final ValueChanged<SearchSettings> onChanged;

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  late SearchSettings _draft;

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

  void _updateMaxResultCount(int maxResultCount) {
    setState(() {
      _draft = _draft.copyWith(maxResultCount: maxResultCount);
    });
    widget.onChanged(_draft);
  }

  void _updateOpenNowOnly(bool openNowOnly) {
    setState(() {
      _draft = _draft.copyWith(openNowOnly: openNowOnly);
    });
    widget.onChanged(_draft);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '検索条件',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '距離',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<int>(value: 500, label: Text('500m')),
                ButtonSegment<int>(value: 1000, label: Text('1km')),
                ButtonSegment<int>(value: 3000, label: Text('3km')),
                ButtonSegment<int>(value: 5000, label: Text('5km')),
              ],
              selected: <int>{_draft.radiusMeters},
              onSelectionChanged: (Set<int> value) {
                _updateRadius(value.first);
              },
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 20),
            const Text(
              '件数',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<int>(value: 10, label: Text('10件')),
                ButtonSegment<int>(value: 20, label: Text('20件')),
              ],
              selected: <int>{_draft.maxResultCount},
              onSelectionChanged: (Set<int> value) {
                _updateMaxResultCount(value.first);
              },
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '営業中のみ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              value: _draft.openNowOnly,
              onChanged: _updateOpenNowOnly,
            ),
          ],
        ),
      ),
    );
  }
}
