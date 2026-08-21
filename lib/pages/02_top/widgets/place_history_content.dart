import 'package:flutter/material.dart';

import '../../../models/place.dart';
import '../../../repositories/place_history_repository.dart';

class PlaceHistoryContent extends StatefulWidget {
  const PlaceHistoryContent({
    super.key,
    required this.onOpenPlace,
    this.historyRepository = const PlaceHistoryRepository(),
    this.reloadToken = 0,
  });

  final ValueChanged<Place> onOpenPlace;
  final PlaceHistoryRepository historyRepository;
  final int reloadToken;

  @override
  State<PlaceHistoryContent> createState() => _PlaceHistoryContentState();
}

class _PlaceHistoryContentState extends State<PlaceHistoryContent> {
  late Future<List<Place>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _reloadHistory();
  }

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

  ({String label, Color color}) _openingStatus(Place place) {
    return switch (place.isOpenNow) {
      true => (label: '営業中', color: const Color(0xFF167A3D)),
      false => (label: '営業時間外', color: const Color(0xFFB3261E)),
      null => (label: '営業時間不明', color: const Color(0xFF6B6B70)),
    };
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F3F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 32,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'まだ見たスポットはありません',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'マップで場所を探してピンをタップすると、ここに履歴が表示されます',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF6B6B70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Place place) {
    final ({String label, Color color}) status = _openingStatus(place);
    return Card(
      key: ValueKey<String>('history-card-${place.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD8D8DC)),
      ),
      child: InkWell(
        onTap: () => widget.onOpenPlace(place),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status.color,
                      ),
                    ),
                  ),
                ],
              ),
              if (place.description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  place.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4A4A4F),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => widget.onOpenPlace(place),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('マップで開く'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: FutureBuilder<List<Place>>(
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
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            itemCount: history.length,
            itemBuilder: (BuildContext context, int index) {
              return _buildHistoryCard(history[index]);
            },
          );
        },
      ),
    );
  }
}
