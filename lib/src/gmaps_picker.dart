import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gmaps_picker/src/animated_pin.dart';
import 'package:gmaps_picker/src/autocomplete_search.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

/// A function which returns a new marker position.
typedef ChangeMarkerPositionCallback = Future<MarkerPosition> Function();

/// GMapsPicker is used to get the location from google maps. This widget is a
/// full page widget which you can open using a navigator.
///
/// Example:
/// ```
/// final pickedLocation = await Navigator.push<Location>(context, MaterialPageRoute(
///   builder: (context) => GMapsPicker(
///     initialLocation: LatLng(-33.8567844, 151.213108),
///     googleMapsApiKey: 'your-api-key',
///   ),
/// ));
///
/// if (pickedLocation != null) {
///   // A location was picked, do something with.
/// }
/// ```
class GMapsPicker extends StatefulWidget {
  const GMapsPicker({
    Key key,
    @required this.initialLocation,
    @required this.googleMapsApiKey,
    this.onMapInitialization,
    this.options,
  }) : super(key: key);

  /// The initial location where the map is first shown. You may use the value
  /// returned by [getCurrentLocation] function here.
  final LatLng initialLocation;

  /// Whatever marker position this callback returns will update the map
  /// position after the map is initialized. It supports zooming of the map
  /// as well.
  final ChangeMarkerPositionCallback onMapInitialization;

  /// API key to access google maps services. This is required for autocomplete
  /// search.
  final String googleMapsApiKey;

  /// Options used to configure the autocomplete search results.
  final AutocompleteOptions options;

  @override
  _GMapsPickerState createState() => _GMapsPickerState();

  /// Gets the permission to access current location of the user. It throws
  /// exceptions if either the location service is not enabled or the permission
  /// to access location has been denied.
  static Future<void> getLocationPermission() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      throw LocationServiceNotEnabledException();
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      // We cannot ask for any more permission, it has been permanently denied.
      throw LocationPermissionDeniedForeverException();
    }

    if (permission == LocationPermission.denied) {
      // If it is denied, ask them for permission again.
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw LocationPermissionNotProvidedException();
      }
    }
  }

  /// Get the current location of the user. It throws exceptions if either the
  /// location service is not enabled or the permission to access location has
  /// been denied.
  static Future<LatLng> getCurrentLocation() async {
    await GMapsPicker.getLocationPermission();
    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }
}

class _GMapsPickerState extends State<GMapsPicker> {
  /// Controller to manage and navigate to places on the map.
  GoogleMapController _googleMapController;

  /// GooglePlace api client.
  GoogleMapsPlaces _googlePlace;

  /// The location that is pointed by the marker with additional geocoded
  /// location.
  Location _locationPick;

  /// The current location pointed by the marker shown in the center.
  LatLng _currentMarker;

  /// Whether the map is being moved.
  bool _isMoving = false;

  /// The zoom factor of the map.
  double _zoomFactor = 15;

  /// Memorizes the last autocomplete state to show and update location
  /// autocompletion dropdown.
  var _autocompleteState = AutocompleteState();

  @override
  void initState() {
    super.initState();

    _googlePlace = GoogleMapsPlaces(apiKey: widget.googleMapsApiKey);
    _currentMarker = LatLng(
      widget.initialLocation.latitude,
      widget.initialLocation.longitude,
    );
    // Reverse geocode the current marker.
    _reverseGeocode();
  }

  /// Reverse geocode from the location pointed by current marker.
  Future<void> _reverseGeocode() async {
    if (_currentMarker == null) {
      return;
    }

    final placemark = await placemarkFromCoordinates(
      _currentMarker.latitude,
      _currentMarker.longitude,
    );
    if (placemark.isNotEmpty) {
      final first = placemark[0];

      setState(() {
        _locationPick = Location(
          placemark: first,
          latlng: _currentMarker,
        );
      });
      return;
    }

    setState(() {
      // There was no address found, no need to retain an older address here.
      _locationPick = null;
    });
  }

  void _onSelectHere() {
    // Return the picked location when popping the nav.
    Navigator.pop(context, _locationPick);
  }

  void _onAutocompleteChange(AutocompleteState event) {
    setState(() {
      _autocompleteState = event;
    });
  }

  /// Remove focus from the autocomplete search input.
  void _unfocusAutocomplete() {
    setState(() {
      _autocompleteState = _autocompleteState.copyWith(isFocused: false);
    });
  }

  /// Callback for when a selection on the autocomplete is made.
  VoidCallback _onSelection(Prediction prediction) {
    return () async {
      // Hide the prediction list.
      setState(() {
        _autocompleteState = AutocompleteState();
      });

      // Only get the geometry for the details, we are going to use geocoding
      // to extract other details.
      final details = await _googlePlace.getDetailsByPlaceId(
        prediction.placeId,
        fields: ['geometry'],
        sessionToken: widget.options?.sessionToken,
      );

      if (!details.isOkay) {
        // If some error occurred, throw it with a reason.
        throw AutocompleteException(details.status, details.errorMessage);
      }

      setState(() {
        _currentMarker = LatLng(
          details.result.geometry.location.lat,
          details.result.geometry.location.lng,
        );
      });

      // Go to the selected place on the map.
      final _ = _reverseGeocode();
      await _googleMapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentMarker, _zoomFactor),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AutocompleteSearch(
          googleMapsApiKey: widget.googleMapsApiKey,
          options: widget.options,
          value: _autocompleteState,
          onChange: _onAutocompleteChange,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: <Widget>[
                    _buildGoogleMap(context),
                    Center(child: AnimatedPin(isAnimating: _isMoving)),
                    _buildMyLocationButton(context),
                  ],
                ),
              ),
              _buildCurrentLocationBar()
            ],
          ),
          if (_autocompleteState.isFocused &&
              _autocompleteState.input.isNotEmpty)
            _buildAutocompleteSuggestions()
        ],
      ),
      extendBodyBehindAppBar: true,
    );
  }

  Widget _buildAutocompleteSuggestions() {
    final statusHeight = MediaQuery.of(context).padding.top;

    return Container(
      margin: EdgeInsets.only(
        top: statusHeight + kToolbarHeight,
        left: 16,
        right: 14,
      ),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              opacity: _autocompleteState.isLoading ? 1 : 0,
              duration: Duration(milliseconds: 100),
              child: LinearProgressIndicator(),
            ),
            // Show the results if there are no error and predictions in
            // the list.
            if (!_autocompleteState.isError &&
                _autocompleteState.predictions.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _autocompleteState.predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _autocompleteState.predictions[index];

                  return ListTile(
                    key: Key(index.toString()),
                    title: Text(
                      prediction.structuredFormatting.mainText ?? '',
                    ),
                    subtitle: Text(
                      prediction.structuredFormatting.secondaryText ?? '',
                    ),
                    visualDensity: VisualDensity.compact,
                    onTap: _onSelection(prediction),
                  );
                },
              ),

            if (!_autocompleteState.isError &&
                _autocompleteState.predictions.isEmpty)
              ListTile(
                title: Text(
                  _autocompleteState.isLoading
                      ? 'Loading...'
                      : 'No matching address found',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            if (_autocompleteState.isError)
              ListTile(
                leading: Icon(Icons.error, color: Colors.red),
                title: Text(
                  'Failed to find a matching address',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationBar() {
    return GestureDetector(
      onTap: _unfocusAutocomplete,
      child: Material(
        elevation: 4,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _locationPick != null
                      ? [
                          Container(
                            margin: EdgeInsets.only(right: 12),
                            child: Text(
                              _locationPick.formattedAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _locationPick.placemark.country,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ]
                      : [],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _locationPick != null ? _onSelectHere : null,
                icon: Icon(
                  Icons.location_pin,
                  size: 20,
                ),
                label: Text('Select Here'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleMap(BuildContext context) {
    return GoogleMap(
      onTap: (_) => _unfocusAutocomplete(),
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      initialCameraPosition: CameraPosition(target: widget.initialLocation),
      mapType: MapType.normal,
      myLocationEnabled: true,
      zoomControlsEnabled: false,
      onMapCreated: (controller) async {
        _googleMapController = controller;

        // Change the map location once it is initialized.
        if (widget.onMapInitialization != null) {
          final newPos = await widget.onMapInitialization();
          setState(() {
            _currentMarker = newPos.latlng;
            _zoomFactor = newPos.zoom ?? _zoomFactor;
          });
          final _ = _reverseGeocode();

          await controller.animateCamera(
            CameraUpdate.newLatLngZoom(newPos.latlng, newPos.zoom),
          );
        }
      },
      onCameraMove: (CameraPosition position) {
        _currentMarker = position.target;
      },
      onCameraMoveStarted: () {
        setState(() {
          _isMoving = true;
        });
      },
      onCameraIdle: () {
        setState(() {
          _isMoving = false;
        });

        // Reverse geocode after the location settles in.
        final _ = _reverseGeocode();
      },
    );
  }

  Widget _buildMyLocationButton(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Positioned(
      top: statusBarHeight + kToolbarHeight + 16,
      right: 12,
      child: ElevatedButton(
        onPressed: () {},
        child: Icon(Icons.my_location),
        style: ButtonStyle(
          minimumSize: MaterialStateProperty.all(Size.zero),
          padding: MaterialStateProperty.all(
            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          shape: MaterialStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          )),
          backgroundColor: MaterialStateProperty.all(Colors.white),
          foregroundColor: MaterialStateProperty.all(Colors.black),
          overlayColor: MaterialStateProperty.all(Colors.grey.shade200),
        ),
      ),
    );
  }
}

/// A location that was picked from google maps.
class Location {
  Location({
    @required this.placemark,
    @required this.latlng,
  });

  final Placemark placemark;
  final LatLng latlng;

  /// Get the formatted address of this location.
  String get formattedAddress {
    var address = placemark.street ?? '';

    if (placemark.subLocality?.isNotEmpty == true) {
      if (placemark.street?.isNotEmpty == true) {
        address = address + ', ';
      }

      address = address + placemark.subLocality;
    }

    if (placemark.locality?.isNotEmpty == true) {
      if (placemark.street?.isNotEmpty == true ||
          placemark.subLocality?.isNotEmpty == true) {
        address = address + ', ';
      }

      address = address + placemark.locality;
    }

    return address;
  }
}

/// Exception for when location services are not enabled.
class LocationServiceNotEnabledException implements Exception {}

/// Exception for when location permission is not accepted by user.
class LocationPermissionNotProvidedException implements Exception {}

/// Exception for when location permission is denied forever by the user.
class LocationPermissionDeniedForeverException implements Exception {}

/// Exception for when autocomplete fails to get results successfully.
class AutocompleteException implements Exception {
  const AutocompleteException(this.kind, this.reason);

  final String kind;
  final String reason;

  @override
  String toString() {
    if (kind == null && reason == null) {
      return 'AutocompleteException';
    }
    return 'AutocompleteException due to $kind: $reason';
  }
}

/// MarkerPosition defined where the marker is located at on the map.
class MarkerPosition {
  MarkerPosition({
    @required this.latlng,
    @required this.zoom,
  });

  /// Latitude of the location.
  final LatLng latlng;

  /// Zoom factor on google maps.
  final double zoom;
}
