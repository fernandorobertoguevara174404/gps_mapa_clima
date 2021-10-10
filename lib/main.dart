import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

Future<Map<String,dynamic>> fetchPronostico(double lat, double lon) async {
  final response = await http
      .get(Uri.parse('https://www.7timer.info/bin/civillight.php?lon=${lon}&lat=${lat}&ac=0&unit=metric&output=json&tzshift=0'));

  if(response.statusCode == 200){
    return jsonDecode(response.body);
  }
  else{
    throw Exception('Fallo en cargar Album');
  }
}

Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

void main() {
  runApp(
    MaterialApp(
      title: 'Named Routes Demo',
      // Start the app with the "/" named route. In this case, the app starts
      // on the FirstScreen widget.
      initialRoute: '/',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        '/': (context) => const FirstScreen(),
        // When navigating to the "/second" route, build the SecondScreen widget.
        '/second': (context) => const SecondScreen(),
      },
    ),
  );
}

class FirstScreen extends StatefulWidget {
  const FirstScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _FirstScreenState();
}

class _FirstScreenState extends State<FirstScreen> {
  Future<Map<String,dynamic>>? futurePronostico;

  List<Widget> createDateWidgets(List<dynamic> seriededatos) {
    List<Widget> lst = List.generate(7, (index) => Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(child: Text("Fecha: " + seriededatos[index]["date"].toString())),
          Expanded(child: Text(seriededatos[index]["weather"])),
          Expanded(child: Text("Max: " + seriededatos[index]["temp2m"]["max"].toString() + "°C")),
          Expanded(child: Text("Min: " + seriededatos[index]["temp2m"]["min"].toString() + "°C")),
        ],
      ),
    ));
    return lst;
  }

  void _navigateAndDisplay(BuildContext context) async{
    _determinePosition().then((value) async {
      LatLng navegador = await Navigator.pushNamed(context, '/second', arguments: value) as LatLng;
      print(navegador);
      setState(() {
        futurePronostico = fetchPronostico(navegador.latitude, navegador.longitude);
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    _determinePosition().then((value) {
      futurePronostico = fetchPronostico(value.latitude, value.longitude);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('First Screen'),
      ),
      body: Center(
        child: Column(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FutureBuilder<Map<String,dynamic>>(
                  future: futurePronostico,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Column(
                        children: createDateWidgets(snapshot.data!["dataseries"]),
                      );
                    } else if (snapshot.hasError) {
                      return Text('${snapshot.error}');
                    }

                    // By default, show a loading spinner.
                    return const CircularProgressIndicator();
                  },
                ),
              ],
            ),
            ElevatedButton(
              // Within the `FirstScreen` widget
              onPressed: () {
                // Navigate to the second screen using a named route.
                _navigateAndDisplay(context);
              },
              child: const Text('Launch screen'),
            ),
          ],
        ),
      ),
    );
  }

}

class SecondScreen extends StatelessWidget {
  const SecondScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Position;
    var coordenadas = LatLng(args.latitude, args.longitude);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Screen'),
      ),
      body: Center(
        child: FlutterMap(
          options: MapOptions(
            onTap: (tapPosition, point) {
              // print(point.toString());
              Navigator.pop(context, point);
            },
            center: coordenadas,
            zoom: 13.0,
          ),
          layers: [
            TileLayerOptions(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: ['a', 'b', 'c'],
              attributionBuilder: (_) {
                return Text("© OpenStreetMap contributors");
              },
            ),
            MarkerLayerOptions(
              markers: [
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: coordenadas,
                  builder: (ctx) =>
                      Container(
                        child: FlutterLogo(),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}