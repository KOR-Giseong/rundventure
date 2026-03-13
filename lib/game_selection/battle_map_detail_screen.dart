import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:rundventure/free_running/free_running_start.dart';

/// 친구 배틀 결과 화면에서 전체화면 지도를 보여주는 화면입니다.
class BattleMapDetailScreen extends StatefulWidget {
  final List<RouteDataPoint> myRoutePoints;
  final List<RouteDataPoint>? opponentRoutePoints;

  const BattleMapDetailScreen({
    Key? key,
    required this.myRoutePoints,
    this.opponentRoutePoints,
  }) : super(key: key);

  @override
  _BattleMapDetailScreenState createState() => _BattleMapDetailScreenState();
}

class _BattleMapDetailScreenState extends State<BattleMapDetailScreen> {
  AppleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Annotation> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMapDisplay();
  }

  void _updateMapDisplay() {
    _polylines.clear();
    _markers.clear();

    bool hasMyRoute = widget.myRoutePoints.isNotEmpty;
    bool hasOpponentRoute = widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty;

    if (hasMyRoute) {
      if (widget.myRoutePoints.length >= 2) {
        for (int i = 0; i < widget.myRoutePoints.length - 1; i++) {
          final start = widget.myRoutePoints[i];
          final end = widget.myRoutePoints[i + 1];
          _polylines.add(Polyline(
            polylineId: PolylineId('my_route_segment_$i'),
            points: [start.point, end.point],
            color: _getColorForSpeed(end.speed),
            width: 5,
          ));
        }
      }
      _markers.add(Annotation(
        annotationId: AnnotationId('my_start_position'),
        position: widget.myRoutePoints.first.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueGreen),
      ));
      _markers.add(Annotation(
        annotationId: AnnotationId('my_end_position'),
        position: widget.myRoutePoints.last.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueRed),
      ));
    }

    if (hasOpponentRoute) {
      final points = widget.opponentRoutePoints!;
      if (points.length >= 2) {
        for (int i = 0; i < points.length - 1; i++) {
          final start = points[i];
          final end = points[i + 1];
          _polylines.add(Polyline(
            polylineId: PolylineId('opponent_route_segment_$i'),
            points: [start.point, end.point],
            color: Colors.deepOrangeAccent,
            width: 5,
          ));
        }
      }
      _markers.add(Annotation(
        annotationId: AnnotationId('opponent_start_position'),
        position: points.first.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueYellow),
      ));
      _markers.add(Annotation(
        annotationId: AnnotationId('opponent_end_position'),
        position: points.last.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueViolet),
      ));
    }
  }

  void _onMapCreated(AppleMapController controller) {
    _mapController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapController == null) return;

      final List<LatLng> allPoints = [];
      if (widget.myRoutePoints.length >= 2) {
        allPoints.addAll(widget.myRoutePoints.map((dp) => dp.point));
      }
      if (widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty) {
        allPoints.addAll(widget.opponentRoutePoints!.map((dp) => dp.point));
      }

      if (allPoints.isEmpty) return;

      double minLat = allPoints.first.latitude, maxLat = allPoints.first.latitude;
      double minLng = allPoints.first.longitude, maxLng = allPoints.first.longitude;
      for (var point in allPoints) {
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
          ), 60.0,
        ),
      );
    });
  }

  Color _getColorForSpeed(double speed) {
    double speedKmh = speed * 3.6;
    if (speedKmh < 4) return Colors.blue.shade700;
    else if (speedKmh < 8) return Colors.green.shade600;
    else if (speedKmh < 12) return Colors.orange.shade700;
    else return Colors.red.shade600;
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('속도 (km/h)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 5),
            _buildLegendItem(Colors.blue.shade700, '< 4'),
            _buildLegendItem(Colors.green.shade600, '4 ~ 8'),
            _buildLegendItem(Colors.orange.shade700, '8 ~ 12'),
            _buildLegendItem(Colors.red.shade600, '> 12'),
            const SizedBox(height: 2),
            _buildLegendItem(Colors.deepOrangeAccent, '상대방'),
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
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasAnyRoute = widget.myRoutePoints.isNotEmpty ||
        (widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 상세 보기', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: hasAnyRoute
          ? Stack(
              children: [
                AppleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: widget.myRoutePoints.isNotEmpty
                        ? widget.myRoutePoints.first.point
                        : widget.opponentRoutePoints!.first.point,
                    zoom: 15.0,
                  ),
                  polylines: _polylines,
                  annotations: _markers,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: true,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                ),
                _buildLegend(),
              ],
            )
          : const Center(child: Text('표시할 경로 데이터가 없습니다.')),
    );
  }
}
