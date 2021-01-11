import 'package:flutter/material.dart';
import 'package:gmaps_picker/gmaps_picker.dart';

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
          onPressed: () async {
            final currentLocation = await GMapsPicker.getCurrentLocation();

            final pickedLocation = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GMapsPicker(
                  initialLocation: currentLocation,
                ),
              ),
            );

            if (pickedLocation != null) {
              print('You picked: ${pickedLocation.address}');
            }
          },
        ),
      ),
    );
  }
}
