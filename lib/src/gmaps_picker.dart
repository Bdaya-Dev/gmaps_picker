import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gmaps_picker/src/animated_pin.dart';
import 'package:gmaps_picker/src/autocomplete_search.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GMapsPicker extends StatefulWidget {
  const GMapsPicker({
    Key key,
    @required this.initialLocation,
    this.onPlacePicked,
  }) : super(key: key);

  final ValueChanged<Location> onPlacePicked;
  final LatLng initialLocation;

  @override
  _GMapsPickerState createState() => _GMapsPickerState();
}

class _GMapsPickerState extends State<GMapsPicker> {
  Location _locationPick;

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
          AnimatedPin(isAnimating: false),
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
      onMapCreated: (GoogleMapController controller) {},
      onCameraIdle: () {},
      onCameraMoveStarted: () {},
      onCameraMove: (CameraPosition position) {},
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
                  widget.onPlacePicked(_locationPick);
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
