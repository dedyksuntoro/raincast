import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:raincast/models/rainviewer_model.dart';
import 'package:raincast/screens/home_screen.dart';
import 'package:raincast/services/weather_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RainCast',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final WeatherService _weatherService = WeatherService();
  LatLng? _userLocation;
  RainViewerData? _rainViewerData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      Position position = await _getUserLocation(context);
      final lat = position.latitude;
      final lon = position.longitude;

      final rainData = await _weatherService.getRainViewerData();

      setState(() {
        _userLocation = LatLng(lat, lon);
        _rainViewerData = rainData;
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<Position> _getUserLocation(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationSettingsDialog(
          context,
          'Layanan lokasi dimatikan. Aktifkan layanan lokasi di pengaturan.',
          Permission.location,
        );
        throw Exception('Layanan lokasi dimatikan');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationSettingsDialog(
            context,
            'Izin lokasi ditolak. Buka pengaturan aplikasi untuk memberikan izin lokasi.',
            Permission.location,
          );
          throw Exception('Izin lokasi ditolak');
        }
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting location: ${e.toString()}');
      throw e;
    }
  }

  Future<void> _showLocationSettingsDialog(
    BuildContext context,
    String message,
    Permission permission,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Lokasi'),
          content: SingleChildScrollView(
            child: ListBody(children: <Widget>[Text(message)]),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Pengaturan'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
                exit(0);
              },
            ),
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
                exit(0);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_rainViewerData == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomeScreen(
      userLocation: _userLocation,
      rainViewerData: _rainViewerData,
    );
  }
}
