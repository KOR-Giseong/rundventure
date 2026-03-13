import 'package:apple_maps_flutter/apple_maps_flutter.dart';

/// 러닝 경로의 각 지점(위치 + 속도)을 나타내는 모델입니다.
class RouteDataPoint {
  final LatLng point;
  final double speed;

  RouteDataPoint({required this.point, required this.speed});

  Map<String, dynamic> toMap() {
    return {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'speed': speed,
    };
  }

  factory RouteDataPoint.fromMap(Map<String, dynamic> map) {
    return RouteDataPoint(
      point: LatLng(
        (map['latitude'] as num).toDouble(),
        (map['longitude'] as num).toDouble(),
      ),
      speed: (map['speed'] as num).toDouble(),
    );
  }
}
