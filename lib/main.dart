import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 30, 141, 33),
        ),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  
  LatLng? _targetLocation;       // Цель
  LatLng? _currentUserLocation;  // Текущая позиция
  
  StreamSubscription<Position>? _positionStreamSubscription;

  // Плеер для воспроизведения звука и флаг, чтобы будильник сработал 1 раз
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _alarmAlreadyPlayed = false;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
      });

      if (_targetLocation != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          _targetLocation!.latitude,
          _targetLocation!.longitude,
        );

        print("До цели осталось: ${distanceInMeters.toStringAsFixed(1)} метров");

        // Условие приближения (например, ближе 30 метров) И проверка, что будильник еще не орал
        if (distanceInMeters <= 30 && !_alarmAlreadyPlayed) {
          _alarmAlreadyPlayed = true; // Ставим флаг, чтобы не повторять бесконечно
          print("🎉 ВНИМАНИЕ: Пользователь добрался до точки!");

          // 1. Включаем вибрацию на 2 секунды
          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(duration: 2000);
          }

          // 2. Включаем звук по тестовой ссылке
          try {
            await _audioPlayer.play(UrlSource('https://www.soundjay.com/clock_c2026/sounds/alarm-clock-01.mp3'));
          } catch (e) {
            print("Ошибка воспроизведения звука: $e");
          }
        }
      }
    });
  }

  void _onMapTapped(TapPosition tapPosition, LatLng tappedPoint) {
    setState(() {
      _targetLocation = tappedPoint;
      _alarmAlreadyPlayed = false; // Сбрасываем флаг при выборе новой точки, если захочется проверить снова
    });
    print("Поставлена цель: ${tappedPoint.latitude}, ${tappedPoint.longitude}");
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    if (_currentUserLocation != null) {
      markers.add(
        Marker(
          point: _currentUserLocation!,
          width: 25,
          height: 25,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      );
    }

    if (_targetLocation != null) {
      markers.add(
        Marker(
          point: _targetLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
        ),
      );
    }

    return markers;
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _audioPlayer.dispose(); // Обязательно освобождаем память плеера при закрытии
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Транспортный будильник'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(42.8746, 74.5698),
          initialZoom: 14.0,
          onTap: _onMapTapped,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.untitled',
          ),
          MarkerLayer(markers: _buildMarkers()),
        ],
      ),
    );
  }
}