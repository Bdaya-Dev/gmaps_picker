import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gmaps_picker/gmaps_picker.dart';
import 'package:gmaps_picker/src/place_provider.dart';
import 'package:gmaps_picker/src/animated_pin.dart';
import 'package:gmaps_picker/src/place_picker.dart';
import 'package:google_maps_webservice/geocoding.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

typedef SelectedPlaceWidgetBuilder = Widget Function(
  BuildContext context,
  PickResult selectedPlace,
  SearchingState state,
  bool isSearchBarFocused,
);

typedef PinBuilder = Widget Function(
  BuildContext context,
  PinState state,
);

class GoogleMapPlacePicker extends StatelessWidget {
  const GoogleMapPlacePicker({
    Key key,
    @required this.initialTarget,
    this.selectedPlaceWidgetBuilder,
    this.pinBuilder,
    this.onMoveStart,
    this.onMapCreated,
    this.onPlacePicked,
    this.language,
    this.onMyLocationTap,
  }) : super(key: key);

  final LatLng initialTarget;

  final SelectedPlaceWidgetBuilder selectedPlaceWidgetBuilder;
  final PinBuilder pinBuilder;

  final VoidCallback onMoveStart;
  final MapCreatedCallback onMapCreated;
  final ValueChanged<PickResult> onPlacePicked;
  final VoidCallback onMyLocationTap;

  final String language;

  Future<void> _searchByCameraLocation(PlaceProvider provider) async {
    provider.placeSearchingState = SearchingState.Searching;

    final response = await provider.geocoding.searchByLocation(
      Location(provider.cameraPosition.target.latitude,
          provider.cameraPosition.target.longitude),
      language: language,
    );

    if (response.errorMessage?.isNotEmpty == true ||
        response.status == 'REQUEST_DENIED') {
      provider.placeSearchingState = SearchingState.Idle;
      return;
    }

    provider.placeSearchingState = SearchingState.Idle;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        _buildGoogleMap(context),
        _buildPin(),
        _buildFloatingCard(),
        if (onMyLocationTap != null) _buildMyLocationButton(context),
      ],
    );
  }

  Widget _buildGoogleMap(BuildContext context) {
    return Selector<PlaceProvider, MapType>(
        selector: (_, provider) => provider.mapType,
        builder: (_, data, __) {
          final provider = PlaceProvider.of(context, listen: false);
          final initialCameraPosition =
              CameraPosition(target: initialTarget, zoom: 15);

          return GoogleMap(
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            initialCameraPosition: initialCameraPosition,
            mapType: data,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              provider.mapController = controller;
              provider.setCameraPosition(null);
              provider.pinState = PinState.Idle;

              // Set the initial camera position of the map.
              provider.setCameraPosition(initialCameraPosition);
              _searchByCameraLocation(provider);
            },
            onCameraIdle: () {
              if (provider.isAutoCompleteSearching) {
                provider.isAutoCompleteSearching = false;
                provider.pinState = PinState.Idle;
                return;
              }

              provider.pinState = PinState.Idle;
            },
            onCameraMoveStarted: () {
              provider.setPrevCameraPosition(provider.cameraPosition);

              // Cancel any other timer.
              provider.debounceTimer?.cancel();

              // Update state, dismiss keyboard and clear text.
              provider.pinState = PinState.Dragging;

              // Begins the search state if the hide details is enabled
              provider.placeSearchingState = SearchingState.Searching;

              onMoveStart();
            },
            onCameraMove: (CameraPosition position) {
              provider.setCameraPosition(position);
            },
            // gestureRecognizers make it possible to navigate the map when it's a
            // child in a scroll view e.g ListView, SingleChildScrollView...
            gestureRecognizers: {
              Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          );
        });
  }

  Widget _buildPin() {
    return Center(
      child: Selector<PlaceProvider, PinState>(
        selector: (_, provider) => provider.pinState,
        builder: (context, state, __) {
          if (pinBuilder == null) {
            return _defaultPinBuilder(context, state);
          } else {
            return Builder(
                builder: (builderContext) => pinBuilder(builderContext, state));
          }
        },
      ),
    );
  }

  Widget _defaultPinBuilder(BuildContext context, PinState state) {
    if (state == PinState.Preparing) {
      return Container();
    } else if (state == PinState.Idle) {
      return Stack(
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.place, size: 36, color: Colors.red),
                SizedBox(height: 42),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AnimatedPin(
                  child: Icon(
                    Icons.place,
                    size: 36,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 42),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildFloatingCard() {
    return Selector<PlaceProvider,
        Tuple4<PickResult, SearchingState, bool, PinState>>(
      selector: (_, provider) => Tuple4(
          provider.selectedPlace,
          provider.placeSearchingState,
          provider.isSearchBarFocused,
          provider.pinState),
      builder: (context, data, __) {
        if ((data.item1 == null && data.item2 == SearchingState.Idle) ||
            data.item3 == true ||
            data.item4 == PinState.Dragging) {
          return Container();
        } else {
          if (selectedPlaceWidgetBuilder == null) {
            return _defaultPlaceWidgetBuilder(context, data.item1, data.item2);
          } else {
            return Builder(
                builder: (builderContext) => selectedPlaceWidgetBuilder(
                    builderContext, data.item1, data.item2, data.item3));
          }
        }
      },
    );
  }

  Widget _defaultPlaceWidgetBuilder(
    BuildContext context,
    PickResult data,
    SearchingState state,
  ) {
    final size = MediaQuery.of(context).size;

    return Positioned(
      bottom: size.height * 0.05,
      left: size.width * 0.025,
      right: size.width * 0.025,
      child: Card(
        elevation: 4,
        child: state == SearchingState.Searching
            ? _buildLoadingIndicator()
            : _buildSelectionDetails(context, data),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      height: 48,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildSelectionDetails(BuildContext context, PickResult result) {
    return Container(
      margin: EdgeInsets.all(10),
      child: Column(
        children: <Widget>[
          Text(
            result.formattedAddress,
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          ElevatedButton(
            child: Text(
              'Select here',
              style: TextStyle(fontSize: 16),
            ),
            onPressed: () {
              onPlacePicked(result);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyLocationButton(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Positioned(
      top: statusBarHeight + 16,
      right: 15,
      child: Container(
        width: 35,
        height: 35,
        child: RawMaterialButton(
          shape: CircleBorder(),
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black54
              : Colors.white,
          elevation: 8,
          onPressed: onMyLocationTap,
          child: Icon(Icons.my_location),
        ),
      ),
    );
  }
}
