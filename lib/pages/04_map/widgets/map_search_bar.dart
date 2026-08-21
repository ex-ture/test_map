import 'package:flutter/material.dart';

class MapSearchBar extends StatefulWidget {
  const MapSearchBar({
    super.key,
    required this.onSearch,
    required this.onClear,
    this.onChanged,
    this.controller,
    this.isSearching = false,
    this.showClearButton = false,
  });

  final VoidCallback onSearch;
  final VoidCallback onClear;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool isSearching;
  final bool showClearButton;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  late final TextEditingController _internalController;

  TextEditingController get _controller =>
      widget.controller ?? _internalController;

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant MapSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _internalController).removeListener(
        _handleTextChanged,
      );
      _controller.addListener(_handleTextChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _internalController.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onClear();
  }

  void _submitSearch() {
    if (!widget.isSearching) {
      widget.onSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        controller: _controller,
        cursorColor: Colors.black,
        readOnly: widget.isSearching,
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
        onSubmitted: (_) => _submitSearch(),
        decoration: InputDecoration(
          hintText: '場所やジャンルで検索',
          hintStyle: const TextStyle(color: Color(0xFF6B6B70)),
          prefixIcon: widget.isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  onPressed: _submitSearch,
                  tooltip: '検索',
                  icon: const Icon(Icons.search, color: Color(0xFF6B6B70)),
                ),
          suffixIcon: _controller.text.isEmpty && !widget.showClearButton
              ? null
              : IconButton(
                  onPressed: widget.isSearching ? null : _clear,
                  tooltip: 'クリア',
                  icon: const Icon(Icons.clear, color: Color(0xFF6B6B70)),
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8D8DC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8D8DC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBEBEC4)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
