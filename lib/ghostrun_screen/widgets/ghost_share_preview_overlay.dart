import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../painters/route_painter.dart';

/// 고스트런 결과를 이미지로 캡처해 공유하는 오버레이 위젯입니다.
class GhostSharePreviewOverlay extends StatefulWidget {
  final Map<String, dynamic> userResult;
  final Map<String, dynamic>? ghostResult;
  final bool isWin;
  final Function() onShareComplete;

  const GhostSharePreviewOverlay({
    Key? key,
    required this.userResult,
    this.ghostResult,
    required this.isWin,
    required this.onShareComplete,
  }) : super(key: key);

  @override
  _GhostSharePreviewOverlayState createState() =>
      _GhostSharePreviewOverlayState();
}

class _GhostSharePreviewOverlayState
    extends State<GhostSharePreviewOverlay> {
  final GlobalKey _shareBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        captureAndShare();
      }
    });
  }

  Future<void> captureAndShare() async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      RenderRepaintBoundary boundary = _shareBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("ByteData could not be generated.");
      Uint8List pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file =
          await File('${tempDir.path}/ghost_run_result.png').create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '런드벤처 고스트런 결과! 👻');
    } catch (e) {
      print('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("공유 이미지 생성 실패: $e")));
      }
    } finally {
      widget.onShareComplete();
    }
  }

  String _formatTime(dynamic totalSeconds) {
    final int secondsInt = (totalSeconds as num? ?? 0).toInt();
    final int minutes = secondsInt ~/ 60;
    final int seconds = secondsInt % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty)
      return LatLngBounds(
          southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));
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

  List<LatLng> _pointsToLatLng(List<dynamic>? pointsData) {
    if (pointsData == null) return [];
    return pointsData.map((p) {
      if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
      if (p is Map)
        return LatLng((p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble());
      return const LatLng(0, 0);
    }).where((point) => point.latitude != 0 || point.longitude != 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirstRun = widget.ghostResult == null;

    final String resultText;
    final Color resultColor;
    if (isFirstRun) {
      resultText = 'FIRST\nRUN';
      resultColor = Colors.blueAccent;
    } else {
      resultText = widget.isWin ? 'WIN' : 'LOSE';
      resultColor = widget.isWin ? Colors.greenAccent : Colors.redAccent;
    }

    final List<LatLng> userRoutePoints =
        _pointsToLatLng(widget.userResult['locationPoints']);
    final List<LatLng> ghostRoutePoints =
        isFirstRun ? [] : _pointsToLatLng(widget.ghostResult?['locationPoints']);

    final List<LatLng> allPoints = [...userRoutePoints, ...ghostRoutePoints];
    final bounds = allPoints.isNotEmpty ? _calculateBounds(allPoints) : null;

    return Material(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: RepaintBoundary(
          key: _shareBoundaryKey,
          child: SizedBox(
            width: 450,
            height: 800,
            child: Stack(
              children: [
                Container(color: Colors.black),
                if (allPoints.isNotEmpty && bounds != null)
                  CustomPaint(
                    size: const Size(450, 800),
                    painter: RoutePainter(
                      userPoints: userRoutePoints,
                      ghostPoints: ghostRoutePoints,
                      bounds: bounds,
                      isFirstRun: isFirstRun,
                    ),
                  ),
                Container(color: Colors.black.withOpacity(0.6)),
                if (allPoints.isNotEmpty && !isFirstRun)
                  Positioned(
                    top: 100,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(Colors.blueAccent, 'MY RUN'),
                        const SizedBox(height: 8),
                        _buildLegendItem(Colors.purpleAccent, 'GHOST RUN'),
                      ],
                    ),
                  ),
                if (allPoints.isNotEmpty && isFirstRun)
                  Positioned(
                    top: 100,
                    right: 30,
                    child: _buildLegendItem(Colors.white, 'MY FIRST RUN'),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('GHOST RUN',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              decoration: TextDecoration.none)),
                      const SizedBox(height: 8),
                      Text(resultText,
                          style: TextStyle(
                              color: resultColor,
                              fontSize: resultText.length > 3 ? 60 : 100,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              decoration: TextDecoration.none)),
                      const Spacer(),
                      _buildResultRow(
                          "MY RECORD", _formatTime(widget.userResult['time'])),
                      const SizedBox(height: 8),
                      if (!isFirstRun)
                        _buildResultRow("GHOST RECORD",
                            _formatTime(widget.ghostResult!['time'])),
                      const SizedBox(height: 24),
                      Center(
                          child: Text(
                              "${(widget.userResult['distance'] as num? ?? 0.0).toStringAsFixed(2)} Km",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none))),
                      const SizedBox(height: 40),
                      Center(
                          child: Text('RUNDVENTURE',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            )),
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 20,
                decoration: TextDecoration.none)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none)),
      ],
    );
  }
}
