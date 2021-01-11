import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gmaps_picker/src/animated_pin.dart';
import 'package:gmaps_picker/src/autocomplete_search.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// GMapsPicker is used to get the location from google maps. This widget is a
/// full page widget which you can open using a navigator.
///
/// Example:
/// ```
/// final pickedLocation = await Navigator.push<Location>(context, MaterialPageRoute(
///   builder: (context) => GMapsPicker(
///     initialLocation: LatLng(-33.8567844, 151.213108),
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
  }) : super(key: key);

  final LatLng initialLocation;

  @override
  _GMapsPickerState createState() => _GMapsPickerState();
}

class _GMapsPickerState extends State<GMapsPicker> {
  Location _locationPick;
  LatLng _currentMarker;
  bool _isMoving = false;

  /// Get the current position of the user.
  Future<Position> _getCurrentLocation() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      throw LocationServiceNotEnabledException();
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      // We cannot ask for any more permission, it has been permanently denied.
      throw LocationPermissionNotProvidedException();
    }

    if (permission == LocationPermission.denied) {
      // If it is denied, ask them for permission again.
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw LocationPermissionNotProvidedException();
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AutoCompleteSearch(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: <Widget>[
          _buildGoogleMap(context),
          Center(child: AnimatedPin(isAnimating: _isMoving)),
          if (_locationPick != null) _buildFloatingCard(),
          _buildMyLocationButton(context),
        ],
      ),
      extendBodyBehindAppBar: true,
    );
  }

  Widget _buildGoogleMap(BuildContext context) {
    return GoogleMap(
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      initialCameraPosition: CameraPosition(target: widget.initialLocation),
      mapType: MapType.normal,
      myLocationEnabled: true,
      zoomControlsEnabled: false,
      onMapCreated: (GoogleMapController controller) async {
        final currentPosition = await _getCurrentLocation();
        _currentMarker =
            LatLng(currentPosition.latitude, currentPosition.longitude);

        // Move the map to the current location of the user. Also, zoom to a
        // level where the map is discernable with respect to a city
        await controller
            .animateCamera(CameraUpdate.newLatLngZoom(_currentMarker, 15));
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
      },
    );
  }

  Widget _buildFloatingCard() {
    final size = MediaQuery.of(context).size;

    return Positioned(
      bottom: size.height * 0.05,
      left: size.width * 0.025,
      right: size.width * 0.025,
      child: Card(
        elevation: 4,
        child: Container(
          margin: EdgeInsets.all(10),
          child: Column(
            children: <Widget>[
              Text(
                _locationPick.address,
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
                  // Return the picked location when popping the nav.
                  Navigator.pop(context, _locationPick);
                },
              ),
            ],
          ),
        ),
      ),
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
    @required this.address,
    @required this.latlng,
  });

  final String address;
  final LatLng latlng;
}

/// Exception for when location services are not enabled.
class LocationServiceNotEnabledException implements Exception {}

/// Exception for when location permission is not accepted by user.
class LocationPermissionNotProvidedException implements Exception {}
