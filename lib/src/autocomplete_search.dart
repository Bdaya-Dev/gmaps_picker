import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_place/google_place.dart';

/// Autocomplete searches for matching addresses based on the given search
/// input.
class AutocompleteSearch extends StatefulWidget {
  const AutocompleteSearch({Key key, @required this.googleMapsApiKey})
      : super(key: key);

  /// API key to access google maps for autocomplete feature.
  final String googleMapsApiKey;

  @override
  _AutocompleteSearchState createState() => _AutocompleteSearchState();
}

class _AutocompleteSearchState extends State<AutocompleteSearch> {
  GooglePlace _googlePlace;
  final _controller = TextEditingController();
  Timer _debounceTimer;

  @override
  void initState() {
    super.initState();
    _googlePlace = GooglePlace(widget.googleMapsApiKey);
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

    _debounceTimer = Timer(Duration(seconds: 1), () async {});
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
