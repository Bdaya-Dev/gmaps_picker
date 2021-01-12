import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gmaps_picker/gmaps_picker.dart';
import 'package:google_place/google_place.dart';

/// Autocomplete searches for matching addresses based on the given search
/// input.
class AutocompleteSearch extends StatefulWidget {
  const AutocompleteSearch({
    Key key,
    @required this.googleMapsApiKey,
    @required this.onChange,
    @required this.value,
    this.options,
  }) : super(key: key);

  /// API key to access google maps for autocomplete feature.
  final String googleMapsApiKey;

  /// Options used to configure the autocomplete search results.
  final AutocompleteOptions options;

  /// The current value of the autocomplete state.
  final AutocompleteState value;

  /// This is a callback which produces a new state with either loading state,
  /// error state or has matched autocompletions or combination.
  final ValueChanged<AutocompleteState> onChange;

  @override
  _AutocompleteSearchState createState() => _AutocompleteSearchState();
}

class _AutocompleteSearchState extends State<AutocompleteSearch> {
  FocusNode _focusNode;
  GooglePlace _googlePlace;
  final _controller = TextEditingController();
  Timer _debounceTimer;

  @override
  void initState() {
    super.initState();
    _googlePlace = GooglePlace(widget.googleMapsApiKey);
    _focusNode = FocusNode();
    _controller.addListener(_onSearchChange);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant AutocompleteSearch oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value.isFocused == oldWidget.value.isFocused) {
      return;
    }

    // Depending on whether `isFocused` value of the prop, remove or put focus.
    if (widget.value.isFocused) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  /// This is run whenever the input focus changes.
  void _onFocusChange() {
    widget.onChange(widget.value.copyWith(
      isFocused: _focusNode.hasPrimaryFocus,
    ));
  }

  /// Search for the locations from the given search text while debouncing.
  void _onSearchChange() {
    if (_debounceTimer?.isActive == true) {
      _debounceTimer.cancel();
    }

    if (!widget.value.isLoading) {
      widget.onChange(widget.value.copyWith(
        isLoading: true,
        input: _controller.text.trim(),
      ));
    }

    _debounceTimer = Timer(Duration(seconds: 1), () async {
      final trimmed = _controller.text.trim();
      if (trimmed.isEmpty) {
        widget.onChange(widget.value.copyWith(
          predictions: [],
          isLoading: false,
          exception: null,
          input: '',
        ));
        return;
      }

      try {
        final results = await _googlePlace.autocomplete.get(
          trimmed,
          components: widget.options?.components,
          language: widget.options?.language,
          location: _fromLatLng(widget.options?.location),
          origin: _fromLatLng(widget.options?.origin),
          offset: widget.options?.offset,
          radius: widget.options?.radius,
          sessionToken: widget.options?.sessionToken,
          types: widget.options?.types,
          strictbounds: widget.options?.strictbounds ?? false,
        );

        widget.onChange(widget.value.copyWith(
          predictions: results?.predictions ?? [],
          isLoading: false,
          exception: null,
          input: trimmed,
        ));
      } catch (exception) {
        // Pass the exception to the top.
        widget.onChange(widget.value.copyWith(
          isLoading: false,
          exception: exception,
          input: trimmed,
        ));

        // Rethrow this just incase the user up in the tree may want to log it
        // however they see fit.
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(4),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
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

/// Autocomplete options to configure autocomplete search results.
class AutocompleteOptions {
  /// A random string which identifies an autocomplete session for billing
  /// purposes. If this parameter is omitted from an autocomplete request,
  /// the request is billed independently. See the pricing sheet for details.
  final String sessionToken;

  /// The position, in the input term, of the last character that the service
  /// uses to match predictions. For example, if the input is 'Google' and the
  /// offset is 3, the service will match on 'Goo'. The string determined by
  /// the offset is matched against the first word in the input term only. For
  /// example, if the input term is 'Google abc' and the offset is 3, the
  /// service will attempt to match against 'Goo abc'. If no offset is supplied,
  /// the service will use the whole term. The offset should generally be set
  /// to the position of the text caret.
  final int offset;

  /// The origin point from which to calculate straight-line distance to the
  /// destination (returned as distance_meters). If this value is omitted,
  /// straight-line distance will not be returned.
  final LatLng origin;

  /// The point around which you wish to retrieve place information.
  final LatLng location;

  /// The distance (in meters) within which to return place results. Note that
  /// setting a radius biases results to the indicated area, but may not fully
  /// restrict results to the specified area. See Location Biasing and Location
  /// Restrict below.
  final int radius;

  /// The language code, indicating in which language the results should be
  /// returned, if possible. Searches are also biased to the selected language;
  /// results in the selected language may be given a higher ranking. See the
  /// list of supported languages and their codes. Note that we often update
  /// supported languages so this list may not be exhaustive. If language is not
  /// supplied, the Place Autocomplete service will attempt to use the native
  /// language of the domain from which the request is sent.
  final String language;

  /// The types of place results to return. If no type is specified, all types
  /// will be returned.
  final String types;

  /// A grouping of places to which you would like to restrict your results.
  /// Currently, you can use components to filter by up to 5 countries.
  /// Countries must be passed as a two character, ISO 3166-1 Alpha-2 compatible
  /// country code.
  final List<Component> components;

  /// Returns only those places that are strictly within the region defined by
  /// location and radius. This is a restriction, rather than a bias, meaning
  /// that results outside this region will not be returned even if they match
  /// the user input.
  final bool strictbounds;

  const AutocompleteOptions({
    this.sessionToken,
    this.offset,
    this.origin,
    this.location,
    this.radius,
    this.language,
    this.types,
    this.components,
    this.strictbounds = false,
  });
}

/// Convert LatLng to LatLon.
LatLon _fromLatLng(LatLng latLng) {
  if (latLng == null) {
    return null;
  }

  return LatLon(latLng.latitude, latLng.longitude);
}

/// A change event during an autocomplete action.
class AutocompleteState {
  /// Whether the autocomplete textfield is in focus.
  final bool isFocused;

  /// The list of predictions that were matched.
  final List<AutocompletePrediction> predictions;

  /// Whether the autocomplete is currently loading to fetch new results.
  final bool isLoading;

  /// Any exception that was thrown during autocompletion.
  final Exception exception;

  /// The search input. This field does not update as you type. The purpose of
  /// this field is to tweak the way the results are shown based on the input.
  final String input;

  const AutocompleteState({
    this.isFocused = false,
    this.predictions = const [],
    this.isLoading = false,
    this.input = '',
    this.exception,
  });

  AutocompleteState copyWith({
    bool isFocused,
    List<AutocompletePrediction> predictions,
    bool isLoading,
    String input,
    Exception exception,
  }) {
    return AutocompleteState(
      isFocused: isFocused ?? this.isFocused,
      predictions: predictions ?? this.predictions,
      isLoading: isLoading ?? this.isLoading,
      input: input ?? this.input,
      exception: exception ?? this.exception,
    );
  }
}
