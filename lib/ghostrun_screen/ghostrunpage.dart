import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main_screens/main_screen.dart';
import 'FirstGhostRun_Tracking.dart';
import 'GhostRunRulePage.dart';
import 'GhostRun_TrackingPage.dart';
import 'ghostrun_ready.dart';

// ⛔️ [삭제됨] import 'package:watch_connectivity/watch_connectivity.dart';

// ▼▼▼▼▼ [ ✨ 1. 신규 추가 ✨ ] ▼▼▼▼▼
import 'package:shared_preferences/shared_preferences.dart'; // 👈 SharedPreferences 임포트
// ▲▲▲▲▲ [ ✨ 1. 신규 추가 ✨ ] ▲▲▲▲▲

// ================== 공유 미리보기 오버레이 ==================
// (수정 없음)
class GhostSharePreviewOverlay extends StatefulWidget {
  final Map<String, dynamic> userResult;
  final Map<String, dynamic>? ghostResult;
  final bool isWin;
  final Function() onShareComplete;

  const GhostSharePreviewOverlay(
      {Key? key,
        required this.userResult,
        this.ghostResult,
        required this.isWin,
        required this.onShareComplete})
      : super(key: key);

  @override
  _GhostSharePreviewOverlayState createState() =>
      _GhostSharePreviewOverlayState();
}

// (수정 없음)
class _GhostSharePreviewOverlayState extends State<GhostSharePreviewOverlay> {
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
      final file = await File('${tempDir.path}/ghost_run_result.png').create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '런드벤처 고스트런 결과! 👻');
    } catch (e) {
      print('Share error: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("공유 이미지 생성 실패: $e")));
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
        return LatLng(
            (p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
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

// ================== 지도 다이얼로그 ==================
// (수정 없음)
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
        content:
        const Text('표시할 경로 데이터가 없습니다.', style: TextStyle(color: Colors.white70)),
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
                    if (ghostRoutePoints != null && ghostRoutePoints!.isNotEmpty)
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

// ================== 기록 선택 다이얼로그 ==================
// (수정 없음)
class GhostRunResultDialog extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Function(Map<String, dynamic>) onRecordSelected;
  final FirebaseFirestore firestore;
  final String currentUserEmail;

  const GhostRunResultDialog({
    super.key,
    required this.records,
    required this.onRecordSelected,
    required this.firestore,
    required this.currentUserEmail,
  });

  Future<void> _shareRecordAsImage(
      BuildContext context, Map<String, dynamic> userRecord) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
      const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    Map<String, dynamic>? ghostRecord;
    if (userRecord['isFirstRecord'] == false &&
        userRecord['ghostRecordId'] != null) {
      try {
        final ghostDoc = await firestore
            .collection('ghostRunRecords')
            .doc(currentUserEmail)
            .collection('records')
            .doc(userRecord['ghostRecordId'])
            .get();
        if (ghostDoc.exists) {
          ghostRecord = ghostDoc.data();
        }
      } catch (e) {
        print("공유를 위한 고스트 기록 로딩 실패: $e");
      }
    }

    Navigator.pop(context); // 로딩 인디케이터 닫기

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => GhostSharePreviewOverlay(
        userResult: userRecord,
        ghostResult: ghostRecord,
        isWin: userRecord['raceResult'] == 'win',
        onShareComplete: () => overlayEntry.remove(),
      ),
    );
    overlay.insert(overlayEntry);
  }

  void _showOptionsDialog(BuildContext context, Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('작업 선택', style: TextStyle(color: Colors.white)),
        content: const Text('이 기록을 불러오거나 공유하시겠습니까?',
            style: TextStyle(color: Colors.white70)),
        actions: <Widget>[
          TextButton(
            child:
            const Text('공유하기', style: TextStyle(color: Colors.cyanAccent)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _shareRecordAsImage(context, record);
            },
          ),
          TextButton(
            child: const Text('불러오기', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRecordSelected(record); // 선택된 기록 콜백 호출
              Navigator.of(context).pop(); // 기록 선택 다이얼로그 닫기
            },
          ),
          TextButton(
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  void _showRouteMap(BuildContext context, Map<String, dynamic> record) async {
    List<LatLng> _pointsToLatLng(List<dynamic> pointsData) {
      return pointsData.map((p) {
        if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
        if (p is Map)
          return LatLng((p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble());
        return const LatLng(0, 0);
      }).where((point) => point.latitude != 0 || point.longitude != 0).toList();
    }

    final userPointsData = record['locationPoints'] as List<dynamic>?;
    if (userPointsData == null || userPointsData.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('경로 데이터가 없습니다.')));
      return;
    }

    final List<LatLng> userRoutePoints = _pointsToLatLng(userPointsData);
    List<LatLng>? ghostRoutePoints;

    if (record['isFirstRecord'] == false && record['ghostRecordId'] != null) {
      try {
        final ghostDoc = await firestore
            .collection('ghostRunRecords')
            .doc(currentUserEmail)
            .collection('records')
            .doc(record['ghostRecordId'])
            .get();
        if (ghostDoc.exists) {
          final ghostPointsData =
          ghostDoc.data()?['locationPoints'] as List<dynamic>?;
          if (ghostPointsData != null && ghostPointsData.isNotEmpty) {
            ghostRoutePoints = _pointsToLatLng(ghostPointsData);
          }
        }
      } catch (e) {
        print("고스트 경로 로딩 실패: $e");
      }
    }

    showDialog(
      context: context,
      builder: (_) => RouteMapDialog(
        userRoutePoints: userRoutePoints,
        ghostRoutePoints: ghostRoutePoints,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('고스트런 기록 선택',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[800]),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  String dateText = "기록 없음";
                  if (record['date'] is Timestamp) {
                    dateText =
                    "지난기록 ${DateFormat('yy.MM.dd').format((record['date'] as Timestamp).toDate())}";
                  }
                  String timeText = "--:--";
                  if (record['time'] != null) {
                    final int timeInSeconds = (record['time'] as num).toInt();
                    timeText =
                    "${(timeInSeconds ~/ 60).toString().padLeft(2, '0')}:${(timeInSeconds % 60).toString().padLeft(2, '0')}";
                  }
                  String distanceText = "--";
                  if (record['distance'] != null) {
                    distanceText =
                    "${(record['distance'] as num).toStringAsFixed(2)}km";
                  }
                  String paceText = "--:--";
                  if (record['pace'] != null &&
                      (record['pace'] as num).isFinite &&
                      (record['pace'] as num) > 0) {
                    final double pace = (record['pace'] as num).toDouble();
                    final int paceMinutes = pace.floor();
                    final int paceSeconds = ((pace - paceMinutes) * 60).round();
                    paceText =
                    "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
                  }

                  String resultText = "";
                  if (record['isFirstRecord'] == true) {
                    resultText = ' (첫 기록)';
                  } else if (record['raceResult'] != null) {
                    resultText = (record['raceResult'] == 'win'
                        ? ' (승리)'
                        : (record['raceResult'] == 'lose' ? ' (패배)' : ' (무승부)'));
                  }

                  return InkWell(
                    onTap: () {
                      _showOptionsDialog(context, record);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$dateText$resultText",
                                style: TextStyle(
                                  color: record['raceResult'] == 'win'
                                      ? Colors.green[400]
                                      : (record['raceResult'] == 'lose'
                                      ? Colors.red[400]
                                      : Colors.grey[400]),
                                  fontSize: 13,
                                ),
                              ),
                              if (record['locationPoints'] != null &&
                                  (record['locationPoints'] as List).isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.map_outlined,
                                      color: Colors.white70, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showRouteMap(context, record),
                                )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              buildRecordCard(timeText, 'Time'),
                              buildRecordCard(distanceText, 'Km'),
                              buildRecordCard(paceText, 'min/km'),
                            ],
                          ),
                          if (index < records.length - 1)
                            Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Divider(color: Colors.grey[800])),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildRecordCard(String value, String label) {
    return Container(
      width: 90,
      height: 60,
      decoration: BoxDecoration(
          color: Colors.black, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

// ================== 메인 페이지 State ==================
class GhostRunPage extends StatefulWidget {
  final Map<String, dynamic>? ghostRecord;
  final bool withWatch;

  const GhostRunPage({
    super.key,
    this.ghostRecord,
    this.withWatch = false,
  });
  @override
  State<GhostRunPage> createState() => _GhostRunPageState();
}

class _GhostRunPageState extends State<GhostRunPage> {
  // UI 표시용 변수
  String _displayTime = "--:--";
  String _distanceDisplay = "--";
  String _paceDisplay = "--:--";
  String _currentDate = "--.--.--";
  String _challengeMessage = "도전을 시도해보세요!";
  bool _hasRecord = false; // 기록 존재 여부
  bool _isLoading = true; // 로딩 상태
  String _raceResultText = ""; // 최근 결과 텍스트
  Color _raceResultColor = Colors.white; // 최근 결과 색상

  // Firestore & Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 데이터 변수
  Map<String, dynamic>? _latestRecord; // 화면에 표시될 최신/선택된 기록
  List<Map<String, dynamic>> _allRecords = []; // '지난기록 더보기'용 리스트

  @override
  void initState() {
    super.initState();
    _loadUserRecord();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ▼▼▼▼▼ [ ✨ 2. 수정된 함수 ✨ ] ▼▼▼▼▼
  /// (수정) Apple Watch 연동 다이얼로그 대신 SharedPreferences에서 설정값을 읽어옵니다.
  void _showUseWatchDialog(BuildContext context) async { // 👈 async로 변경
    // 1. MainScreen의 워치 명령으로 진입한 경우 (withWatch: true), 즉시 시작
    if (widget.withWatch) {
      print("GhostRunPage: MainScreen으로부터 withWatch=true 받음. 즉시 시작.");
      _startRun(withWatch: true);
      return;
    }

    // 2. 워치 명령이 아닌, 사용자가 직접 버튼을 누른 경우
    final prefs = await SharedPreferences.getInstance();
    // 'watchSyncEnabled' 키로 저장된 값을 읽어오며, 없으면 false(끄기)를 기본값으로 합니다.
    final bool withWatch = prefs.getBool('watchSyncEnabled') ?? false;

    // 설정값(withWatch)에 따라 바로 _startRun 함수를 호출합니다.
    _startRun(withWatch: withWatch);
  }
  // ▲▲▲▲▲ [ ✨ 2. 수정된 함수 ✨ ] ▲▲▲▲▲

  // (수정 없음)
  void _startRun({required bool withWatch}) {
    if (_hasRecord) {
      _navigateToGhostRunTracking(withWatch: withWatch);
    } else {
      _navigateToFirstRunTracking(withWatch: withWatch);
    }
  }

  // (수정 없음)
  Future<void> _showDarkModeRecommendationDialog(
      BuildContext context, VoidCallback onConfirm) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.grey[800]!)),
          icon:
          const Icon(Icons.dark_mode_outlined, color: Colors.white, size: 32),
          title: const Text(
            '고스트를 맞이할 준비',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '고스트는 어둠 속에서 더 강합니다.\n다크 모드로 전환하고 러닝에 몰입하세요 !',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '[ 설정 > 디스플레이 및 밝기 > 다크 모드 ]',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('확인',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  // (수정 없음)
  void _updateUIFromRecord(Map<String, dynamic> record) {
    setState(() {
      _latestRecord = record;
      _hasRecord = true;
      if (record['date'] is Timestamp) {
        final DateTime recordDate = (record['date'] as Timestamp).toDate();
        _currentDate = DateFormat('yy.MM.dd').format(recordDate);
      }
      if (record['distance'] != null) {
        _distanceDisplay = (record['distance'] as num).toStringAsFixed(2);
      }
      if (record['pace'] != null &&
          (record['pace'] as num).isFinite &&
          (record['pace'] as num) > 0) {
        final double pace = (record['pace'] as num).toDouble();
        final int paceMinutes = pace.floor();
        final int paceSeconds = ((pace - paceMinutes) * 60).round();
        _paceDisplay = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
      } else {
        _paceDisplay = "--:--";
      }
      if (record['time'] != null) {
        final int timeInSeconds = (record['time'] as num).toInt();
        _displayTime =
        "${(timeInSeconds ~/ 60).toString().padLeft(2, '0')}:${(timeInSeconds % 60).toString().padLeft(2, '0')}";
      }
      _raceResultText = "";
      _raceResultColor = Colors.white;

      if (record['isFirstRecord'] == true) {
        _raceResultText = " (첫 기록)";
        _raceResultColor = Colors.grey;
        _challengeMessage = "과거의 나에게 도전해보세요!";
      } else if (record['raceResult'] != null) {
        final String result = record['raceResult'] as String;
        if (result == 'win') {
          _raceResultText = " (승리)";
          _raceResultColor = Colors.green;
        } else if (result == 'lose') {
          _raceResultText = " (패배)";
          _raceResultColor = Colors.red;
        } else {
          _raceResultText = " (무승부)";
          _raceResultColor = Colors.orange;
        }
        _challengeMessage = "과거 나에게 도전이 있습니다!";
      } else {
        _challengeMessage = "과거의 나에게 도전해보세요!";
        _raceResultColor = Colors.grey;
      }
    });
  }

  // (수정 없음)
  Future<void> _loadUserRecord() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final String userEmail = _auth.currentUser?.email ?? '';
      if (userEmail.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasRecord = false;
          _challengeMessage = "첫 도전 시작하기!";
        });
        return;
      }
      final userDoc =
      await _firestore.collection('ghostRunRecords').doc(userEmail).get();
      if (userDoc.exists && userDoc.data()!.containsKey('latestRecordId')) {
        String latestRecordId = userDoc.data()!['latestRecordId'];
        final recordDoc = await _firestore
            .collection('ghostRunRecords')
            .doc(userEmail)
            .collection('records')
            .doc(latestRecordId)
            .get();
        if (recordDoc.exists) {
          final data = recordDoc.data()!;
          data['id'] = recordDoc.id;
          _updateUIFromRecord(data);
          await _loadAllUserRecords();
          return;
        }
      }
      final recordsSnapshot = await _firestore
          .collection('ghostRunRecords')
          .doc(userEmail)
          .collection('records')
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (recordsSnapshot.docs.isNotEmpty) {
        final data = recordsSnapshot.docs.first.data();
        data['id'] = recordsSnapshot.docs.first.id;
        _updateUIFromRecord(data);
        await _firestore
            .collection('ghostRunRecords')
            .doc(userEmail)
            .set({
          'latestRecordId': recordsSnapshot.docs.first.id,
          'latestRecordDate': data['date'],
        }, SetOptions(merge: true));
        await _loadAllUserRecords();
      } else {
        setState(() {
          _isLoading = false;
          _hasRecord = false;
          _challengeMessage = "첫 도전 시작하기!";
        });
      }
    } catch (e) {
      print('레코드 로딩 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
        _hasRecord = false;
        _challengeMessage = "오류 발생: 기록 로드 실패";
      });
    }
  }

  // (수정 없음)
  Future<void> _loadAllUserRecords() async {
    try {
      final String userEmail = _auth.currentUser?.email ?? '';
      if (userEmail.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final recordsSnapshot = await _firestore
          .collection('ghostRunRecords')
          .doc(userEmail)
          .collection('records')
          .orderBy('date', descending: true)
          .limit(20)
          .get();
      if (recordsSnapshot.docs.isNotEmpty) {
        _allRecords = recordsSnapshot.docs
            .map((doc) => doc.data()..['id'] = doc.id)
            .toList();
      }
    } catch (e) {
      print('모든 레코드 로딩 중 오류 발생: $e');
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  // (수정 없음)
  void _showRecordsDialog() {
    if (_allRecords.isEmpty) return;
    showDialog(
      context: context,
      builder: (BuildContext context) => GhostRunResultDialog(
        records: _allRecords,
        onRecordSelected: (selectedRecord) {
          _updateUIFromRecord(selectedRecord);
        },
        firestore: _firestore,
        currentUserEmail: _auth.currentUser?.email ?? '',
      ),
    );
  }

  // (수정 없음)
  void _showLatestRecordMap() async {
    if (_latestRecord == null) return;

    List<LatLng> _pointsToLatLng(List<dynamic> pointsData) {
      return pointsData.map((p) {
        if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
        if (p is Map)
          return LatLng((p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble());
        return const LatLng(0, 0);
      }).where((point) => point.latitude != 0 || point.longitude != 0).toList();
    }

    final userPointsData = _latestRecord!['locationPoints'] as List<dynamic>?;
    if (userPointsData == null || userPointsData.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('경로 데이터가 없습니다.')));
      return;
    }
    final List<LatLng> userRoutePoints = _pointsToLatLng(userPointsData);

    List<LatLng>? ghostRoutePoints;
    if (_latestRecord!['isFirstRecord'] == false &&
        _latestRecord!['ghostRecordId'] != null) {
      try {
        final ghostDoc = await _firestore
            .collection('ghostRunRecords')
            .doc(_auth.currentUser!.email)
            .collection('records')
            .doc(_latestRecord!['ghostRecordId'])
            .get();
        if (ghostDoc.exists) {
          final ghostPointsData =
          ghostDoc.data()!['locationPoints'] as List<dynamic>?;
          if (ghostPointsData != null && ghostPointsData.isNotEmpty) {
            ghostRoutePoints = _pointsToLatLng(ghostPointsData);
          }
        }
      } catch (e) {
        print("고스트 경로 로딩 실패: $e");
      }
    }

    showDialog(
        context: context,
        builder: (_) => RouteMapDialog(
          userRoutePoints: userRoutePoints,
          ghostRoutePoints: ghostRoutePoints,
        ));
  }

  // (수정 없음)
  void _navigateToFirstRunTracking({bool withWatch = false}) {
    _showDarkModeRecommendationDialog(context, () {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  FirstGhostRunTrackingPage(withWatch: withWatch)));
    });
  }

  // (수정 없음)
  void _navigateToGhostRunTracking({bool withWatch = false}) {
    if (_latestRecord != null) {
      final double distanceInKm =
          (_latestRecord!['distance'] as num?)?.toDouble() ?? 0.0;
      if (distanceInKm < 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('도전 불가', style: TextStyle(color: Colors.white)),
            content: const Text('기록이 1km 미만이라 대결할 수 없습니다.\n기록 초기화 후 다시 측정해주세요.',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인', style: TextStyle(color: Colors.blue)))
            ],
          ),
        );
        return;
      }

      _showDarkModeRecommendationDialog(context, () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => GhostRunTrackingPage(
                    ghostRunData: _latestRecord!, withWatch: withWatch)));
      });
    }
  }

  // (수정 없음)
  Future<void> _resetGhostRunData() async {
    try {
      final String userEmail = _auth.currentUser?.email ?? '';
      if (userEmail.isEmpty) return;
      final CollectionReference userRecordsRef = _firestore
          .collection('ghostRunRecords')
          .doc(userEmail)
          .collection('records');
      final DocumentReference userDocRef =
      _firestore.collection('ghostRunRecords').doc(userEmail);
      final QuerySnapshot snapshot = await userRecordsRef.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      await userDocRef.delete();
      setState(() {
        _hasRecord = false;
        _latestRecord = null;
        _allRecords.clear();
        _displayTime = "--:--";
        _distanceDisplay = "--";
        _paceDisplay = "--:--";
        _currentDate = "--.--.--";
        _raceResultText = "";
        _challengeMessage = "첫 도전 시작하기!";
      });
      if (mounted) _showCustomSnackBar('기록이 초기화되었습니다.');
    } catch (e) {
      print('데이터 초기화 중 오류 발생: $e');
      if (mounted) _showCustomSnackBar('기록 초기화 실패', isError: true);
    }
  }

  // (수정 없음)
  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('기록 초기화', style: TextStyle(color: Colors.white)),
        content: const Text('모든 고스트런 기록을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('아니요', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGhostRunData();
            },
            child: const Text('예, 삭제합니다', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // (수정 없음)
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor:
        isError ? Colors.redAccent.shade400 : Colors.purpleAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const GhostRunReadyPage()));
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const GhostRunReadyPage())),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Image.asset('assets/images/Back-Navs-Black.png',
                  width: 40, height: 40),
            ),
          ),
          centerTitle: true,
          title: const Text('고스트런',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined, color: Colors.white),
              tooltip: '메인 화면',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.red),
              tooltip: '도움말',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const GhostRunRulePage())),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Stack(
          children: [
            Positioned(
                bottom: -150,
                left: 0,
                right: 0,
                child: Image.asset('assets/images/ghostrunconfirmation.png',
                    fit: BoxFit.cover)),
            Positioned(
                bottom: 0,
                right: 20,
                child: Image.asset(
                    'assets/images/ghostrunconfirmation2.png',
                    width: 80,
                    height: 80)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '지난기록 $_currentDate$_raceResultText',
                      style: TextStyle(
                          color: _raceResultText.isEmpty
                              ? Colors.grey[400]
                              : _raceResultColor,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 130,
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('RUNNING',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            if (_hasRecord) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _showLatestRecordMap,
                                child: const Icon(Icons.map_outlined,
                                    color: Colors.white70, size: 22),
                              )
                            ]
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(_displayTime,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 60,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(30)),
                    child: Text(_challengeMessage,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 130,
                          decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_distanceDisplay,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              const Text('Km',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 130,
                          decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_paceDisplay,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              const Text('Min/Km',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                            _hasRecord ? _showRecordsDialog : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              disabledBackgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(30)),
                            ),
                            child: Text(
                                _hasRecord ? '지난기록 더보기' : '기록이 없습니다',
                                style: TextStyle(
                                    color: _hasRecord
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      if (_hasRecord)
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _showResetConfirmDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(30)),
                              ),
                              child: const Text('새로 기록하기',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _showUseWatchDialog(context), // 👈 ✨ [수정] 수정된 함수 호출
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                          _hasRecord ? '도전하기' : '첫 도전 시작하기',
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== 경로 그리기 CustomPainter ==================
// (수정 없음)
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