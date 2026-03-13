import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';

/// 고스트런 결과 공유 이미지에 러닝 경로를 그리는 CustomPainter입니다.
class RoutePainter extends CustomPainter {
  final List<LatLng> userPoints;
  final List<LatLng> ghostPoints;
  final LatLngBounds bounds;
  final bool isFirstRun;

  RoutePainter({
    required this.userPoints,
    required this.ghostPoints,
    required this.bounds,
    required this.isFirstRun,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void drawPath(List<LatLng> points, Color color) {
      if (points.length < 2) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      final firstScaledPoint = _scalePoint(points.first, size);
      path.moveTo(firstScaledPoint.dx, firstScaledPoint.dy);
      for (int i = 1; i < points.length; i++) {
        final scaledPoint = _scalePoint(points[i], size);
        path.lineTo(scaledPoint.dx, scaledPoint.dy);
      }
      canvas.drawPath(path, paint);
    }

    void drawCircle(Canvas canvas, Offset center, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 8.0, paint);

      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, 8.0, borderPaint);
    }

    if (!isFirstRun && ghostPoints.isNotEmpty) {
      drawPath(ghostPoints, Colors.purpleAccent);
      drawCircle(
          canvas, _scalePoint(ghostPoints.first, size), Colors.purple.shade200);
      drawCircle(
          canvas, _scalePoint(ghostPoints.last, size), Colors.purple.shade200);
    }

    if (userPoints.isNotEmpty) {
      final userPathColor = isFirstRun ? Colors.white : Colors.blueAccent;
      drawPath(userPoints, userPathColor);
      drawCircle(
          canvas, _scalePoint(userPoints.first, size), Colors.greenAccent);
      drawCircle(canvas, _scalePoint(userPoints.last, size), Colors.redAccent);
    }
  }

  Offset _scalePoint(LatLng point, Size size) {
    double minLat = bounds.southwest.latitude;
    double maxLat = bounds.northeast.latitude;
    double minLng = bounds.southwest.longitude;
    double maxLng = bounds.northeast.longitude;

    double lngRange = maxLng - minLng;
    double latRange = maxLat - minLat;

    double normalizedX =
        lngRange.abs() < 1e-9 ? 0.5 : (point.longitude - minLng) / lngRange;
    double normalizedY =
        latRange.abs() < 1e-9 ? 0.5 : (point.latitude - minLat) / latRange;

    double paddingX = size.width * 0.1;
    double paddingY = size.height * 0.1;
    double drawWidth = size.width - 2 * paddingX;
    double drawHeight = size.height - 2 * paddingY;

    double scaledX = paddingX + normalizedX * drawWidth;
    double scaledY = paddingY + (1 - normalizedY) * drawHeight;

    return Offset(scaledX, scaledY);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.userPoints != userPoints ||
        oldDelegate.ghostPoints != ghostPoints ||
        oldDelegate.bounds != bounds ||
        oldDelegate.isFirstRun != isFirstRun;
  }
}
