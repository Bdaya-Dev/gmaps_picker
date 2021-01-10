import 'package:flutter/material.dart';
import 'package:gmaps_picker/gmaps_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const apiKey = 'put-your-api-key-here';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Map Place Picker Demo',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Map Place Picker Demo'),
      ),
      body: Center(
        child: ElevatedButton(
          child: Text('Load Google Map'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlacePicker(
                  apiKey: apiKey,
                  initialPosition: LatLng(-33.8567844, 151.213108),
                  useCurrentLocation: true,
                  selectInitialPosition: true,
                  onPlacePicked: (result) {
                    print('You picked: ${result.formattedAddress}');
                    Navigator.of(context).pop();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
