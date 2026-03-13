import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';

/// 3D 원형 진행도 페인터 (러닝 데이터 화면의 목표 달성도 표시용)
class ThreeDProgressPainter extends CustomPainter {
  final double progress;

  ThreeDProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final double startAngle = -math.pi / 2;
    final double strokeWidth = size.width * 0.15;

    final Paint backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(rect, 0, 2 * math.pi, false, backgroundPaint);

    final bool isGoalReached = progress >= 1.0;

    final Paint basePaint = Paint()
      ..color = isGoalReached ? Colors.deepOrange[600]! : Colors.deepOrange
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double primaryProgress = math.min(progress, 1.0);
    final double primarySweep = primaryProgress * 2 * math.pi;

    if (primarySweep > 0) {
      canvas.drawArc(rect, startAngle, primarySweep, false, basePaint);
    }

    if (progress > 1.0) {
      final double extraProgress = progress - 1.0;
      final double extraSweep = extraProgress * 2 * math.pi;

      final Paint gradientPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: extraSweep,
          colors: [
            Colors.deepOrange[600]!,
            Colors.deepOrange[700]!,
            Colors.deepOrange[800]!,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(startAngle + primarySweep),
        ).createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
          rect, startAngle + primarySweep, extraSweep, false, gradientPaint);

      final Paint endCapPaint = Paint()
        ..color = Colors.deepOrange[800]!
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
          rect,
          startAngle + primarySweep + extraSweep - 0.001,
          0.001,
          false,
          endCapPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 러닝 경로를 단색으로 그리는 CustomPainter (러닝 데이터 화면 미리보기용)
class RunningRoutePainter extends CustomPainter {
  final List<LatLng> points;
  final LatLngBounds bounds;

  RunningRoutePainter({required this.points, required this.bounds});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      if (points.isNotEmpty) {
        final startPoint = _scalePoint(points.first, size);
        _drawCircle(canvas, startPoint, Colors.green);
      }
      return;
    }

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
      final scaledPoint = _scalePoint(points[i], size);
      path.lineTo(scaledPoint.dx, scaledPoint.dy);
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

    double normalizedX = (point.longitude - minLng) / (maxLng - minLng);
    double normalizedY = (point.latitude - minLat) / (maxLat - minLat);
    double lngRange = maxLng - minLng;
    double latRange = maxLat - minLat;

    if (lngRange.abs() < 0.00001) normalizedX = 0.5;
    if (latRange.abs() < 0.00001) normalizedY = 0.5;

    double paddingX = size.width * 0.15;
    double paddingY = size.height * 0.15;
    double drawWidth = size.width - 2 * paddingX;
    double drawHeight = size.height - 2 * paddingY;
    double scaledX = paddingX + normalizedX * drawWidth;
    double scaledY = paddingY + (1 - normalizedY) * drawHeight;

    return Offset(scaledX, scaledY);
  }

  void _drawCircle(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8.0, paint);
  }

  @override
  bool shouldRepaint(covariant RunningRoutePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.bounds != bounds;
  }
}
