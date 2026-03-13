import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';

/// 고스트런 경로를 팝업 지도로 보여주는 다이얼로그입니다.
class RouteMapDialog extends StatelessWidget {
  final List<LatLng> userRoutePoints;
  final List<LatLng>? ghostRoutePoints;

  const RouteMapDialog({
    Key? key,
    required this.userRoutePoints,
    this.ghostRoutePoints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<LatLng> allPoints = <LatLng>[
      ...userRoutePoints,
      ...(ghostRoutePoints ?? [])
    ];
    if (allPoints.isEmpty) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('경로 오류', style: TextStyle(color: Colors.white)),
        content: const Text('표시할 경로 데이터가 없습니다.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'))
        ],
      );
    }

    final LatLngBounds bounds = _calculateBounds(allPoints);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('러닝 경로',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppleMap(
                  initialCameraPosition:
                      CameraPosition(target: allPoints.first, zoom: 15),
                  polylines: {
                    Polyline(
                      polylineId: PolylineId('user_route'),
                      points: userRoutePoints,
                      color: Colors.blueAccent,
                      width: 5,
                    ),
                    if (ghostRoutePoints != null &&
                        ghostRoutePoints!.isNotEmpty)
                      Polyline(
                        polylineId: PolylineId('ghost_route'),
                        points: ghostRoutePoints!,
                        color: Colors.purpleAccent.withOpacity(0.7),
                        width: 5,
                      ),
                  },
                  onMapCreated: (controller) {
                    Future.delayed(const Duration(milliseconds: 50), () {
                      controller.animateCamera(
                          CameraUpdate.newLatLngBounds(bounds, 60.0));
                    });
                  },
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
          southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));
    }
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }
}
