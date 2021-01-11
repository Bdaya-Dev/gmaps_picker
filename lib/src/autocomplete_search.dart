import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

/// Autocomplete searches for matching addresses based on the given search
/// input.
class AutoCompleteSearch extends StatefulWidget {
  @override
  _AutoCompleteSearchState createState() => _AutoCompleteSearchState();
}

class _AutoCompleteSearchState extends State<AutoCompleteSearch> {
  final _controller = TextEditingController();
  Timer _debounceTimer;
  List<Location> _searchedLocations = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Search for the locations from the given search text while debouncing.
  void _onSearchChange() {
    if (_debounceTimer?.isActive == true) {
      _debounceTimer.cancel();
    }

    _debounceTimer = Timer(Duration(seconds: 1), () async {
      final searchText = _controller.text.trim();
      if (searchText.isEmpty) {
        setState(() {
          _searchedLocations = [];
        });
        return;
      }

      final locations = await locationFromAddress(searchText);
      setState(() {
        _searchedLocations = locations;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(4),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search for a locality, landmark or city',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(4),
          ),
          prefixIcon: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search, size: 24),
          ),
          prefixIconConstraints: BoxConstraints.loose(Size.fromHeight(32)),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }
}
