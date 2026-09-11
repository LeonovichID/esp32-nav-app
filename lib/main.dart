import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ESP32NavApp(),
  ));
}

class ESP32NavApp extends StatefulWidget {
  const ESP32NavApp({super.key});

  @override
  State<ESP32NavApp> createState() => _ESP32NavAppState();
}

class _ESP32NavAppState extends State<ESP32NavApp> {
  // Posisi Awal (Contoh: Karanganyar / Solo)
  LatLng currentLocation = const LatLng(-7.5962, 110.9525);
  List<LatLng> routePoints = [];
  List<List<LatLng>> buildingPolygons = [];
  bool isLoading = false;

  // 1. Ambil Rute Jalan Gratis dari OSRM
  Future<void> fetchOSRMRoute(LatLng destination) async {
    setState(() => isLoading = true);
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${currentLocation.longitude},${currentLocation.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        
        setState(() {
          routePoints = coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();
        });

        // Ambil data poligon bangunan sekitar
        await fetchBuildingsNearby(currentLocation);
      }
    } catch (e) {
      debugPrint("Error OSRM: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 2. Ambil Poligon Bangunan Sekitar dari Overpass API (OSM)
  Future<void> fetchBuildingsNearby(LatLng center) async {
    double delta = 0.0025; // Radius area sekitar ~250m
    String bbox = "${center.latitude - delta},${center.longitude - delta},"
                 "${center.latitude + delta},${center.longitude + delta}";
    
    final query = '[out:json];way["building"]($bbox);out geom;';
    final url = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<List<LatLng>> polygons = [];
        
        for (var element in data['elements']) {
          if (element['geometry'] != null) {
            List<LatLng> poly = [];
            for (var pt in element['geometry']) {
              poly.add(LatLng(pt['lat'].toDouble(), pt['lon'].toDouble()));
            }
            polygons.add(poly);
          }
        }
        setState(() {
          buildingPolygons = polygons;
        });
      }
    } catch (e) {
      debugPrint("Error Overpass: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP32 Nav Simulator"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
        ],
      ),
      body: Column(
        children: [
          // PETA UTAMA (Atas)
          Expanded(
            flex: 3,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: currentLocation,
                initialZoom: 16.0,
                onTap: (tapPosition, point) => fetchOSRMRoute(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.esp32_nav_app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation,
                      child: const Icon(Icons.navigation, color: Colors.red, size: 30),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SIMULATOR LAYAR ESP32 (Bawah)
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF1E1E1E),
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "PREVIEW TAMPILAN ESP32 (60 FPS VECTOR)",
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E7DF), // Layar LCD Sharp / E-Paper
                      border: Border.all(color: Colors.black, width: 4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CustomPaint(
                        painter: ESP32DisplayPainter(
                          routePoints: routePoints,
                          buildings: buildingPolygons,
                          currentPos: currentLocation,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Ketuk lokasi di peta atas untuk buat rute",
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter untuk Render Vektor Monokrom
class ESP32DisplayPainter extends CustomPainter {
  final List<LatLng> routePoints;
  final List<List<LatLng>> buildings;
  final LatLng currentPos;

  ESP32DisplayPainter({
    required this.routePoints,
    required this.buildings,
    required this.currentPos,
  });

  Offset _latLngToOffset(LatLng point, Size size) {
    double scale = 140000.0;
    double centerX = size.width / 2;
    double centerY = size.height / 2;

    double x = centerX + (point.longitude - currentPos.longitude) * scale;
    double y = centerY - (point.latitude - currentPos.latitude) * scale;

    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final routePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Render Bangunan (Garis Tipis)
    for (var building in buildings) {
      if (building.isEmpty) continue;
      Path path = Path();
      Offset first = _latLngToOffset(building.first, size);
      path.moveTo(first.dx, first.dy);

      for (int i = 1; i < building.length; i++) {
        Offset pt = _latLngToOffset(building[i], size);
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, buildingPaint);
    }

    // Render Rute Jalan (Garis Tebal)
    if (routePoints.length > 1) {
      Path routePath = Path();
      Offset start = _latLngToOffset(routePoints.first, size);
      routePath.moveTo(start.dx, start.dy);

      for (int i = 1; i < routePoints.length; i++) {
        Offset pt = _latLngToOffset(routePoints[i], size);
        routePath.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(routePath, routePaint);
    }

    // Render Panah Posisi Kendaraan
    final arrowPaint = Paint()..color = Colors.black;
    Path arrow = Path();
    double cx = size.width / 2;
    double cy = size.height / 2;

    arrow.moveTo(cx, cy - 8);
    arrow.lineTo(cx - 6, cy + 7);
    arrow.lineTo(cx + 6, cy + 7);
    arrow.close();

    canvas.drawPath(arrow, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
