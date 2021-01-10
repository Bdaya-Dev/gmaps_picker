import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gmaps_picker/gmaps_picker.dart';
import 'package:gmaps_picker/src/place_provider.dart';
import 'package:gmaps_picker/src/prediction_tile.dart';
import 'package:google_maps_webservice/places.dart';

class AutoCompleteSearch extends StatefulWidget {
  const AutoCompleteSearch({
    Key key,
    @required this.sessionToken,
    @required this.onPicked,
    this.hintText,
    this.searchingText = 'Searching...',
    this.height = 40,
    this.debounceMilliseconds,
    this.onSearchFailed,
    this.autocompleteOffset,
    this.autocompleteRadius,
    this.autocompleteLanguage,
    this.autocompleteComponents,
    this.autocompleteTypes,
    this.strictbounds,
    this.region,
    this.initialSearchString,
    this.searchForInitialValue,
    this.autocompleteOnTrailingWhitespace,
  }) : super(key: key);

  final String sessionToken;
  final String hintText;
  final String searchingText;
  final double height;
  final int debounceMilliseconds;
  final ValueChanged<Prediction> onPicked;
  final ValueChanged<String> onSearchFailed;
  final num autocompleteOffset;
  final num autocompleteRadius;
  final String autocompleteLanguage;
  final List<String> autocompleteTypes;
  final List<Component> autocompleteComponents;
  final bool strictbounds;
  final String region;
  final String initialSearchString;
  final bool searchForInitialValue;
  final bool autocompleteOnTrailingWhitespace;

  @override
  AutoCompleteSearchState createState() => AutoCompleteSearchState();
}

class AutoCompleteSearchState extends State<AutoCompleteSearch> {
  TextEditingController controller = TextEditingController();
  FocusNode focus = FocusNode();
  OverlayEntry overlayEntry;
  String _searchTerm = '';
  String _previousSearchTerm = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchString != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.text = widget.initialSearchString;
        if (widget.searchForInitialValue) {
          _onSearchInputChange();
        }
      });
    }
    controller.addListener(_onSearchInputChange);
    focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onSearchInputChange);
    controller.dispose();

    focus.removeListener(_onFocusChanged);
    focus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 16, right: 8),
      alignment: Alignment.center,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(4),
        child: TextField(
          controller: controller,
          focusNode: focus,
          decoration: InputDecoration(
            hintText: widget.hintText,
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
            suffixIcon: _searchTerm.isNotEmpty
                ? Container(
                    margin: EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      child: Icon(
                        Icons.clear,
                        size: 24,
                        color: Colors.black,
                      ),
                      onTap: clearText,
                    ),
                  )
                : null,
            suffixIconConstraints: BoxConstraints.loose(Size.fromHeight(32)),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
      ),
    );
  }

  void _onSearchInputChange() {
    if (!mounted) {
      return;
    }
    setState(() {
      _searchTerm = controller.text;
    });

    final provider = PlaceProvider.of(context, listen: false);

    if (controller.text.isEmpty) {
      provider.debounceTimer?.cancel();
      _searchPlace(controller.text);
      return;
    }

    if (controller.text.trim() == _previousSearchTerm.trim()) {
      provider.debounceTimer?.cancel();
      return;
    }

    if (!widget.autocompleteOnTrailingWhitespace &&
        controller.text.substring(controller.text.length - 1) == ' ') {
      provider.debounceTimer?.cancel();
      return;
    }

    if (provider.debounceTimer?.isActive ?? false) {
      provider.debounceTimer.cancel();
    }

    provider.debounceTimer =
        Timer(Duration(milliseconds: widget.debounceMilliseconds), () {
      _searchPlace(controller.text.trim());
    });
  }

  void _onFocusChanged() {
    final provider = PlaceProvider.of(context, listen: false);
    provider.isSearchBarFocused = focus.hasFocus;
    provider.debounceTimer?.cancel();
    provider.placeSearchingState = SearchingState.Idle;
  }

  void _searchPlace(String searchTerm) {
    setState(() {
      _previousSearchTerm = searchTerm;
    });

    if (context == null) {
      return;
    }

    _clearOverlay();

    if (searchTerm.isEmpty) {
      return;
    }

    _displayOverlay(_buildSearchingOverlay());
    _performAutoCompleteSearch(searchTerm);
  }

  void _clearOverlay() {
    if (overlayEntry != null) {
      overlayEntry.remove();
      overlayEntry = null;
    }
  }

  void _displayOverlay(Widget overlayChild) {
    _clearOverlay();

    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: screenWidth * 0.025,
        right: screenWidth * 0.025,
        top: kToolbarHeight + mq.padding.top,
        child: Material(
          elevation: 3,
          child: overlayChild,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  Widget _buildSearchingOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        children: <Widget>[
          SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 24),
          Expanded(
            child: Text(
              widget.searchingText ?? 'Searching...',
              style: TextStyle(fontSize: 16),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPredictionOverlay(List<Prediction> predictions) {
    return ListBody(
      children: predictions
          .asMap()
          .entries
          .map(
            (pred) => PredictionTile(
              key: Key(pred.key.toString()),
              prediction: pred.value,
              onTap: (selectedPrediction) {
                resetSearchBar();
                widget.onPicked(selectedPrediction);
              },
            ),
          )
          .toList(),
    );
  }

  Future<void> _performAutoCompleteSearch(String searchTerm) async {
    final provider = PlaceProvider.of(context, listen: false);

    if (searchTerm.isNotEmpty) {
      final response = await provider.places.autocomplete(
        searchTerm,
        sessionToken: widget.sessionToken,
        location: provider.currentPosition == null
            ? null
            : Location(provider.currentPosition.latitude,
                provider.currentPosition.longitude),
        offset: widget.autocompleteOffset,
        radius: widget.autocompleteRadius,
        language: widget.autocompleteLanguage,
        types: widget.autocompleteTypes,
        components: widget.autocompleteComponents,
        strictbounds: widget.strictbounds,
        region: widget.region,
      );

      if (response.errorMessage?.isNotEmpty == true ||
          response.status == 'REQUEST_DENIED') {
        if (widget.onSearchFailed != null) {
          widget.onSearchFailed(response.status);
        }
        return;
      }

      _displayOverlay(_buildPredictionOverlay(response.predictions));
    }
  }

  void clearText() {
    _searchTerm = '';
    controller.clear();
  }

  void resetSearchBar() {
    clearText();
    focus.unfocus();
  }

  void clearOverlay() {
    _clearOverlay();
  }
}
