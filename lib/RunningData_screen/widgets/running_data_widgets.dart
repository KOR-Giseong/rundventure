import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import '../painters/running_data_painters.dart';

// ===================================================================
// 공통 포맷 유틸 함수
// ===================================================================

/// 페이스(분/km, double)를 "M'SS\"" 문자열로 변환
String formatRunningPace(double pace) {
  int minutes = pace.floor();
  int seconds = ((pace - minutes) * 60).round();
  return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
}

/// 초(int)를 "M:SS" 문자열로 변환
String formatRunningDuration(int seconds) {
  int minutes = seconds ~/ 60;
  int remainingSeconds = seconds % 60;
  return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
}

// ===================================================================
// 재사용 가능한 UI 위젯
// ===================================================================

/// 러닝 통계 컬럼 위젯 (공유 카드에서 사용)
class RunningStatColumn extends StatelessWidget {
  final String label;
  final String value;

  const RunningStatColumn(this.label, this.value, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 18,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

/// 러닝 상세 통계 카드 (목록 항목)
class RunningDetailStatCard extends StatelessWidget {
  final String label;
  final String value;

  const RunningDetailStatCard({Key? key, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepOrange.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: deviceWidth * 0.038,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: deviceWidth * 0.040,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 러닝 기록 공유용 카드 위젯 (스크린샷으로 캡처)
class RunningShareableCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<LatLng> latLngPoints;

  const RunningShareableCard({
    Key? key,
    required this.data,
    required this.latLngPoints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double safeKilometers = (data['kilometers'] as num? ?? 0.0).toDouble();
    final double safePace = (data['pace'] as num? ?? 0.0).toDouble();
    final int safeSeconds = (data['seconds'] as num? ?? 0).toInt();
    final double safeCalories = (data['calories'] as num? ?? 0.0).toDouble();

    if (latLngPoints.length < 2) {
      return Container(
        width: 450,
        height: 800,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 60.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                safeKilometers.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 90,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const Text(
                '킬로미터',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RunningStatColumn('평균 페이스', formatRunningPace(safePace)),
                  RunningStatColumn('시간', formatRunningDuration(safeSeconds)),
                  RunningStatColumn('칼로리', '${safeCalories.toStringAsFixed(0)} kcal'),
                ],
              ),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'RUNDVENTURE',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    double minLat = latLngPoints.map((p) => p.latitude).reduce(math.min);
    double maxLat = latLngPoints.map((p) => p.latitude).reduce(math.max);
    double minLng = latLngPoints.map((p) => p.longitude).reduce(math.min);
    double maxLng = latLngPoints.map((p) => p.longitude).reduce(math.max);
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    return Container(
      width: 450,
      height: 800,
      color: Colors.white,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(450, 800),
            painter: RunningRoutePainter(points: latLngPoints, bounds: bounds),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 60.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeKilometers.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 90,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Text(
                  '킬로미터',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RunningStatColumn('평균 페이스', formatRunningPace(safePace)),
                    RunningStatColumn('시간', formatRunningDuration(safeSeconds)),
                    RunningStatColumn('칼로리', '${safeCalories.toStringAsFixed(0)} kcal'),
                  ],
                ),
                const SizedBox(height: 40),
                const Center(
                  child: Text(
                    'RUNDVENTURE',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
