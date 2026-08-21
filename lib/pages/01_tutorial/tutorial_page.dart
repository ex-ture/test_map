import 'package:flutter/material.dart';

import '../00_root/root_page.dart';
import '../../routes/app_routes.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToMap() {
    _markTutorialCompletedAndGoToMap();
  }

  void _nextPage() {
    if (_currentPageIndex < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
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

  Widget _buildDot(int index) {
    final bool isSelected = index == _currentPageIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isSelected ? 18 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isSelected ? Colors.black87 : Colors.black26,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildSlide({
    required String title,
    required String description,
    required Widget preview,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          preview,
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int index) {
                  setState(() {
                    _currentPageIndex = index;
                  });
                },
                children: [
                  _buildSlide(
                    title: '場所を検索',
                    description: 'キーワードで周辺の場所を検索できます',
                    preview: const _MiniMapPreview(),
                  ),
                  _buildSlide(
                    title: 'ピンから詳細を見る',
                    description: 'ピンをタップすると詳細情報を確認できます',
                    preview: const _MiniDetailPreview(),
                  ),
                  _buildSlide(
                    title: 'WEBページを開く',
                    description: '外部サイトや詳細ページをアプリ内で確認できます',
                    preview: const _MiniWebPreview(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(3, _buildDot),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _goToMap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Color(0xFFD8D8DC)),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('スキップ'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _currentPageIndex == 2
                                ? _goToMap
                                : _nextPage,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Text(_currentPageIndex == 2 ? 'はじめる' : '次へ'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMapPreview extends StatelessWidget {
  const _MiniMapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8D8DC)),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F8),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            top: 10,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD8D8DC)),
              ),
            ),
          ),
          const Positioned(
            left: 20,
            top: 72,
            child: _RoadLine(width: 92, angle: -0.18),
          ),
          const Positioned(
            right: 24,
            top: 64,
            child: _RoadLine(width: 84, angle: 0.42),
          ),
          const Positioned(
            left: 36,
            bottom: 32,
            child: _RoadLine(width: 122, angle: 0.12),
          ),
          const Positioned(
            left: 74,
            top: 84,
            child: _PinDot(color: Color(0xFF1F1F22)),
          ),
          const Positioned(
            right: 62,
            top: 88,
            child: _PinDot(color: Color(0xFFD84A43)),
          ),
          const Positioned(
            left: 110,
            bottom: 48,
            child: _PinDot(color: Color(0xFF1F1F22)),
          ),
          Positioned(
            right: 12,
            bottom: 10,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD8D8DC)),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                size: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDetailPreview extends StatelessWidget {
  const _MiniDetailPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8D8DC)),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F8),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Positioned(
            left: 18,
            top: 52,
            child: _RoadLine(width: 76, angle: 0.24),
          ),
          const Positioned(
            right: 26,
            top: 58,
            child: _RoadLine(width: 92, angle: -0.18),
          ),
          const Positioned(
            left: 120,
            top: 70,
            child: _PinDot(color: Color(0xFFD84A43)),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD8D8DC)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spot C',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '気になるスポットの詳細を確認',
                    style: TextStyle(fontSize: 8, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Container(height: 1, color: const Color(0xFFD8D8DC)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '他のアプリで開く',
                            style: TextStyle(fontSize: 8.5),
                          ),
                        ),
                        Icon(
                          Icons.north_east_rounded,
                          size: 10,
                          color: Color(0xFF8E8E93),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: const Color(0xFFD8D8DC)),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'アプリ内で開く',
                            style: TextStyle(fontSize: 8.5),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniWebPreview extends StatelessWidget {
  const _MiniWebPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8D8DC)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8D8DC)),
        ),
        child: Column(
          children: [
            Container(
              height: 28,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7F9),
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'WEB表示',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'スポット詳細ページ',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD8D8DC)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: double.infinity,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD8D8DC)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD8D8DC)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _RoadLine extends StatelessWidget {
  const _RoadLine({required this.width, required this.angle});

  final double width;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFE3E3E7),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Container(width: 1, height: 6, color: color.withValues(alpha: 0.7)),
      ],
    );
  }
}
