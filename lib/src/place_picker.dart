import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gmaps_picker/gmaps_picker.dart';
import 'package:gmaps_picker/src/autocomplete_search.dart';
import 'package:gmaps_picker/src/google_map_place_picker.dart';
import 'package:gmaps_picker/src/place_provider.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

enum PinState { Preparing, Idle, Dragging }
enum SearchingState { Idle, Searching }

class PlacePicker extends StatefulWidget {
  PlacePicker({
    Key key,
    @required this.apiKey,
    this.onPlacePicked,
    @required this.initialPosition,
    this.useCurrentLocation,
    this.desiredLocationAccuracy = LocationAccuracy.high,
    this.onMapCreated,
    this.hintText,
    this.searchingText,
    this.onAutoCompleteFailed,
    this.onGeocodingSearchFailed,
    this.autoCompleteDebounceInMilliseconds = 500,
    this.cameraMoveDebounceInMilliseconds = 750,
    this.initialMapType = MapType.normal,
    this.enableMapTypeButton = true,
    this.enableMyLocationButton = true,
    this.myLocationButtonCooldown = 10,
    this.usePinPointingSearch = true,
    this.usePlaceDetailSearch = false,
    this.autocompleteOffset,
    this.autocompleteRadius,
    this.autocompleteLanguage,
    this.autocompleteComponents,
    this.autocompleteTypes,
    this.strictbounds,
    this.region,
  }) : super(key: key);

  final String apiKey;

  final LatLng initialPosition;
  final bool useCurrentLocation;
  final LocationAccuracy desiredLocationAccuracy;

  final MapCreatedCallback onMapCreated;

  final String hintText;
  final String searchingText;

  final ValueChanged<String> onAutoCompleteFailed;
  final ValueChanged<String> onGeocodingSearchFailed;
  final int autoCompleteDebounceInMilliseconds;
  final int cameraMoveDebounceInMilliseconds;

  final MapType initialMapType;
  final bool enableMapTypeButton;
  final bool enableMyLocationButton;
  final int myLocationButtonCooldown;

  final bool usePinPointingSearch;
  final bool usePlaceDetailSearch;

  final num autocompleteOffset;
  final num autocompleteRadius;
  final String autocompleteLanguage;
  final List<String> autocompleteTypes;
  final List<Component> autocompleteComponents;
  final bool strictbounds;
  final String region;

  /// By using default setting of Place Picker, it will result result when user hits the select here button.
  ///
  /// If you managed to use your own [selectedPlaceWidgetBuilder], then this WILL NOT be invoked, and you need use data which is
  /// being sent with [selectedPlaceWidgetBuilder].
  final ValueChanged<PickResult> onPlacePicked;

  @override
  _PlacePickerState createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  final _autocompleteKey = GlobalKey<AutoCompleteSearchState>();
  Future<PlaceProvider> _futureProvider;
  PlaceProvider provider;

  @override
  void initState() {
    super.initState();

    _futureProvider = _initPlaceProvider();
  }

  Future<PlaceProvider> _initPlaceProvider() async {
    final headers = await GoogleApiHeaders().getHeaders();
    final provider = PlaceProvider(widget.apiKey, headers);
    provider.sessionToken = _uuid.v4();
    provider.desiredAccuracy = widget.desiredLocationAccuracy;
    provider.setMapType(widget.initialMapType);

    return provider;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        _autocompleteKey.currentState.clearOverlay();
        return Future.value(true);
      },
      child: FutureBuilder(
        future: _futureProvider,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            provider = snapshot.data;

            return ChangeNotifierProvider.value(
              value: provider,
              child: Builder(
                builder: (context) {
                  return Scaffold(
                    extendBodyBehindAppBar: true,
                    appBar: AppBar(
                      automaticallyImplyLeading: false,
                      iconTheme: Theme.of(context).iconTheme,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      titleSpacing: 0.0,
                      title: _buildSearchBar(),
                    ),
                    body: _buildMapWithLocation(),
                  );
                },
              ),
            );
          } else {
            final children = <Widget>[];
            if (snapshot.hasError) {
              children.addAll([
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).errorColor,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('Error: ${snapshot.error}'),
                )
              ]);
            } else {
              children.add(CircularProgressIndicator());
            }

            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: children,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
          ),
          padding: EdgeInsets.zero,
        ),
        Expanded(
          child: AutoCompleteSearch(
            key: _autocompleteKey,
            sessionToken: provider.sessionToken,
            hintText: widget.hintText,
            searchingText: widget.searchingText,
            debounceMilliseconds: widget.autoCompleteDebounceInMilliseconds,
            onPicked: (prediction) {
              _pickPrediction(prediction);
            },
            onSearchFailed: (status) {
              if (widget.onAutoCompleteFailed != null) {
                widget.onAutoCompleteFailed(status);
              }
            },
            autocompleteOffset: widget.autocompleteOffset,
            autocompleteRadius: widget.autocompleteRadius,
            autocompleteLanguage: widget.autocompleteLanguage,
            autocompleteComponents: widget.autocompleteComponents,
            autocompleteTypes: widget.autocompleteTypes,
            strictbounds: widget.strictbounds,
            region: widget.region,
          ),
        ),
        SizedBox(width: 5),
      ],
    );
  }

  Future<void> _pickPrediction(Prediction prediction) async {
    provider.placeSearchingState = SearchingState.Searching;

    final response = await provider.places.getDetailsByPlaceId(
      prediction.placeId,
      sessionToken: provider.sessionToken,
      language: widget.autocompleteLanguage,
    );

    if (response.errorMessage?.isNotEmpty == true ||
        response.status == 'REQUEST_DENIED') {
      if (widget.onAutoCompleteFailed != null) {
        widget.onAutoCompleteFailed(response.status);
      }
      return;
    }

    provider.selectedPlace = PickResult.fromPlaceDetailResult(response.result);

    // Prevents searching again by camera movement.
    provider.isAutoCompleteSearching = true;

    await _moveTo(provider.selectedPlace.geometry.location.lat,
        provider.selectedPlace.geometry.location.lng);

    provider.placeSearchingState = SearchingState.Idle;
  }

  Future<void> _moveTo(double latitude, double longitude) async {
    final controller = provider.mapController;
    if (controller == null) return;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 16,
        ),
      ),
    );
  }

  Future<void> _moveToCurrentPosition() async {
    if (provider.currentPosition != null) {
      await _moveTo(provider.currentPosition.latitude,
          provider.currentPosition.longitude);
    }
  }

  Widget _buildMapWithLocation() {
    if (widget.useCurrentLocation) {
      return FutureBuilder(
          future: provider.updateCurrentLocation(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else {
              if (provider.currentPosition == null) {
                return _buildMap(widget.initialPosition);
              } else {
                return _buildMap(LatLng(provider.currentPosition.latitude,
                    provider.currentPosition.longitude));
              }
            }
          });
    } else {
      return FutureBuilder(
        future: Future.delayed(Duration(milliseconds: 1)),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return _buildMap(widget.initialPosition);
          }
        },
      );
    }
  }

  Widget _buildMap(LatLng initialTarget) {
    return GoogleMapPlacePicker(
      initialTarget: initialTarget,
      onMapCreated: widget.onMapCreated,
      language: widget.autocompleteLanguage,
      onMyLocationTap: () async {
        // Prevent to click many times in short period.
        if (provider.isOnUpdateLocationCooldown == false) {
          provider.isOnUpdateLocationCooldown = true;
          Timer(Duration(seconds: widget.myLocationButtonCooldown), () {
            provider.isOnUpdateLocationCooldown = false;
          });
          await provider.updateCurrentLocation();
          await _moveToCurrentPosition();
        }
      },
      onMoveStart: () {
        _autocompleteKey.currentState.resetSearchBar();
      },
      onPlacePicked: widget.onPlacePicked,
    );
  }
}
