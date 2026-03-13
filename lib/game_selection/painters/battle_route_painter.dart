import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';

/// 배틀 결과 화면의 공유 카드에 사용되는 경로 CustomPainter입니다.
class BattleRoutePainter extends CustomPainter {
  final List<LatLng> points;
  final LatLngBounds bounds;

  BattleRoutePainter({required this.points, required this.bounds});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final firstScaledPoint = _scalePoint(points.first, size);
    path.moveTo(firstScaledPoint.dx, firstScaledPoint.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(_scalePoint(points[i], size).dx, _scalePoint(points[i], size).dy);
    }
    canvas.drawPath(path, paint);
    _drawCircle(canvas, _scalePoint(points.first, size), Colors.green);
    _drawCircle(canvas, _scalePoint(points.last, size), Colors.red);
  }

  Offset _scalePoint(LatLng point, Size size) {
    double minLat = bounds.southwest.latitude;
    double maxLat = bounds.northeast.latitude;
    double minLng = bounds.southwest.longitude;
    double maxLng = bounds.northeast.longitude;
    double lngRange = maxLng - minLng;
    double latRange = maxLat - minLat;
    double normalizedX = (lngRange.abs() < 0.00001) ? 0.5 : (point.longitude - minLng) / lngRange;
    double normalizedY = (latRange.abs() < 0.00001) ? 0.5 : (point.latitude - minLat) / latRange;
    double paddingX = size.width * 0.15;
    double paddingY = size.height * 0.15;
    double drawWidth = size.width - 2 * paddingX;
    double drawHeight = size.height - 2 * paddingY;
    double scaledX = paddingX + normalizedX * drawWidth;
    double scaledY = paddingY + (1 - normalizedY) * drawHeight;
    return Offset(scaledX, scaledY);
  }

  void _drawCircle(Canvas canvas, Offset center, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8.0, paint);
  }

  @override
  bool shouldRepaint(covariant BattleRoutePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.bounds != bounds;
  }
}
