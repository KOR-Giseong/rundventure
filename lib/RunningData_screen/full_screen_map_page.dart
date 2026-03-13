import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';

import 'package:rundventure/free_running/free_running_start.dart';

/// 러닝 경로를 전체 화면으로 표시하는 페이지입니다.
class FullScreenMapPage extends StatefulWidget {
  final List<RouteDataPoint> routeDataPoints;

  const FullScreenMapPage({Key? key, required this.routeDataPoints})
      : super(key: key);

  @override
  _FullScreenMapPageState createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  AppleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Annotation> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMapDisplay();
  }

  Color _getColorForSpeed(double speed) {
    double speedKmh = speed * 3.6;
    if (speedKmh < 4) return Colors.blue.shade700;
    if (speedKmh < 8) return Colors.green.shade600;
    if (speedKmh < 12) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  void _onMapCreated(AppleMapController controller) {
    _mapController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToBounds();
    });
  }

  void _updateMapDisplay() {
    if (widget.routeDataPoints.length < 2) return;

    for (int i = 0; i < widget.routeDataPoints.length - 1; i++) {
      final start = widget.routeDataPoints[i];
      final end = widget.routeDataPoints[i + 1];
      _polylines.add(Polyline(
        polylineId: PolylineId('route_segment_$i'),
        points: [start.point, end.point],
        color: _getColorForSpeed(end.speed),
        width: 5,
      ));
    }

    _markers.add(Annotation(
      annotationId: AnnotationId('start_position'),
      position: widget.routeDataPoints.first.point,
      icon: BitmapDescriptor.defaultAnnotationWithHue(
          BitmapDescriptor.hueGreen),
    ));

    _markers.add(Annotation(
      annotationId: AnnotationId('end_position'),
      position: widget.routeDataPoints.last.point,
      icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueRed),
    ));
    setState(() {});
  }

  void _moveCameraToBounds() async {
    if (widget.routeDataPoints.length < 2 || _mapController == null) return;

    final points = widget.routeDataPoints.map((dp) => dp.point).toList();
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60.0,
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('속도 (km/h)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87)),
            const SizedBox(height: 5),
            _buildLegendItem(Colors.blue.shade700, '< 4'),
            _buildLegendItem(Colors.green.shade600, '4 ~ 8'),
            _buildLegendItem(Colors.orange.shade700, '8 ~ 12'),
            _buildLegendItem(Colors.red.shade600, '> 12'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text,
              style:
                  const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '경로 상세보기',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png',
              width: 40, height: 40),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          AppleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: widget.routeDataPoints.isNotEmpty
                  ? widget.routeDataPoints.first.point
                  : const LatLng(37.4563, 126.7052),
              zoom: 15.0,
            ),
            polylines: _polylines,
            annotations: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
          ),
          _buildLegend(),
        ],
      ),
    );
  }
}
