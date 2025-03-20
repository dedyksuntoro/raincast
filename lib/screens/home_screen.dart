import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/rainviewer_model.dart';
import '../services/weather_service.dart';

class HomeScreen extends StatefulWidget {
  final LatLng? userLocation;
  final RainViewerData? rainViewerData;

  const HomeScreen({super.key, this.userLocation, this.rainViewerData});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  int _currentFrameIndex = 0;
  late List<RadarFrame> _allFrames;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _isLoading = false;
  LatLng? _currentUserLocation; // Lokasi pengguna saat ini
  final WeatherService _weatherService = WeatherService();
  bool _showResetButton = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    final tween = Tween<double>(begin: 0, end: 1);
    final curvedAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          double targetPosition = maxScroll * tween.evaluate(curvedAnimation);
          _scrollController.animateTo(
            targetPosition,
            duration: const Duration(milliseconds: 50),
            curve: Curves.linear,
          );
        }
      }
    });

    _animationController.repeat(reverse: true);
    _currentUserLocation = widget.userLocation;
    _loadFrames();
  }

  void _loadFrames() {
    if (widget.rainViewerData == null) {
      _allFrames = [];
    } else {
      _allFrames = [
        ...widget.rainViewerData!.past,
        ...widget.rainViewerData!.nowcast,
      ];
      _setInitialFrameIndex();
    }
    setState(() {});
  }

  void _setInitialFrameIndex() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int closestIndex = 0;
    int minDiff = (now - _allFrames.first.time).abs();

    for (int i = 1; i < _allFrames.length; i++) {
      int diff = (now - _allFrames[i].time).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    _currentFrameIndex = closestIndex;
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  Future<void> _resetRotateMap() async {
    _mapController.rotate(0); // Reset rotasi kompas
    // Tambahkan delay kecil agar animasi rotasi selesai dulu
    Future.delayed(Duration(milliseconds: 100), () {
      setState(() {
        _showResetButton = false; // Sembunyikan tombol reset
      });
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final rainData = await _weatherService.getRainViewerData();
      setState(() {
        _allFrames = [...rainData.past, ...rainData.nowcast];
        _setInitialFrameIndex();
      });
    } catch (e) {
      print('Error refreshing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _centerToUserLocation() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Position position = await _getUserLocation(context);
      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentUserLocation = newLocation;
        _mapController.move(newLocation, _mapController.camera.zoom);
      });
    } catch (e) {
      print('Error centering to location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildLegendContent() {
    return Row(
      children: [
        Container(width: 16, height: 16, color: Colors.blue),
        const SizedBox(width: 4),
        const Text('Hujan Ringan', style: TextStyle(color: Colors.white)),
        const SizedBox(width: 8),
        Container(width: 16, height: 16, color: Colors.yellow),
        const SizedBox(width: 4),
        const Text('Hujan Sedang', style: TextStyle(color: Colors.white)),
        const SizedBox(width: 8),
        Container(width: 16, height: 16, color: Colors.red),
        const SizedBox(width: 4),
        const Text('Hujan Lebat', style: TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildCurrentLocationIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue, // Warna isi lingkaran
        border: Border.all(
          color: Colors.white, // Warna outline
          width: 2.0, // Ketebalan outline
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.black.withAlpha(150),
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        // appBar: AppBar(
        //   toolbarHeight: 0,
        //   systemOverlayStyle: SystemUiOverlayStyle(
        //     // Status bar color
        //     statusBarColor: Colors.red,
        //     // Status bar brightness (optional)
        //     // statusBarIconBrightness: Brightness.dark, // For Android (dark icons)
        //     // statusBarBrightness: Brightness.light, // For iOS (dark icons)
        //   ),
        // ),
        body:
            widget.userLocation == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentUserLocation!,
                        initialZoom: 10.0,
                        maxZoom: 19,
                        minZoom: 3,
                        interactionOptions: InteractionOptions(
                          enableMultiFingerGestureRace: true,
                        ),
                        onMapEvent: (event) {
                          if (event is MapEventRotate) {
                            setState(() {
                              _showResetButton =
                                  true; // Tampilkan tombol reset jika peta berubah
                            });
                          }
                        },
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            LatLng(
                              -85.0,
                              -180.0,
                            ), // Batas bawah kiri (sekitar kutub selatan)
                            LatLng(
                              85.0,
                              180.0,
                            ), // Batas atas kanan (sekitar kutub utara)
                          ),
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        if (_allFrames.isNotEmpty)
                          TileLayer(
                            urlTemplate:
                                'https://tilecache.rainviewer.com${_allFrames[_currentFrameIndex].path}/256/{z}/{x}/{y}/2/1_1.png',
                            tileBuilder: (context, tileWidget, tile) {
                              return Opacity(opacity: 0.7, child: tileWidget);
                            },
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              rotate: true,
                              alignment: Alignment.center,
                              point: _currentUserLocation!,
                              // width: 50, // Ukuran tetap marker (icon)
                              // height: 50, // Ukuran tetap marker (icon)
                              child: Align(
                                alignment: Alignment.center,
                                child: _buildCurrentLocationIcon(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withAlpha(150),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'RainCast',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Row(
                                  children: [
                                    _buildLegendContent(),
                                    const SizedBox(width: 10),
                                    _buildLegendContent(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 80,
                      child: Column(
                        children: [
                          if (_showResetButton) // Hanya tampil jika ada perubahan posisi/rotasi
                            FloatingActionButton(
                              mini: true,
                              onPressed: _resetRotateMap,
                              backgroundColor: Colors.black.withAlpha(150),
                              child: Icon(Icons.explore, color: Colors.white),
                            ),
                          SizedBox(height: 8),
                          FloatingActionButton(
                            mini: true,
                            onPressed: _refreshData,
                            backgroundColor: Colors.black.withAlpha(150),
                            child: Icon(Icons.refresh, color: Colors.white),
                          ),
                          SizedBox(height: 8),
                          FloatingActionButton(
                            mini: true,
                            onPressed: _centerToUserLocation,
                            backgroundColor: Colors.black.withAlpha(150),
                            child: Icon(Icons.my_location, color: Colors.white),
                          ),
                          SizedBox(height: 8),
                          FloatingActionButton(
                            mini: true,
                            onPressed: _zoomIn,
                            backgroundColor: Colors.black.withAlpha(150),
                            child: Icon(Icons.zoom_in, color: Colors.white),
                          ),
                          SizedBox(height: 8),
                          FloatingActionButton(
                            mini: true,
                            onPressed: _zoomOut,
                            backgroundColor: Colors.black.withAlpha(150),
                            child: Icon(Icons.zoom_out, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    if (_allFrames.isNotEmpty)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Slider(
                            thumbColor: Colors.blue,
                            activeColor: Colors.blueAccent,
                            value: _currentFrameIndex.toDouble(),
                            min: 0,
                            max: (_allFrames.length - 1).toDouble(),
                            divisions: _allFrames.length - 1,
                            label:
                                "${DateFormat('dd MMM yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_allFrames[_currentFrameIndex].time * 1000))}",
                            onChanged: (value) {
                              setState(() {
                                _currentFrameIndex = value.toInt();
                                _isLoading = true;
                              });
                            },
                            onChangeEnd: (value) {
                              setState(() {
                                _isLoading = false;
                              });
                            },
                          ),
                        ),
                      ),
                    if (_isLoading)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}
