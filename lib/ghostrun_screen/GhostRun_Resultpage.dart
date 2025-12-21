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
import 'ghostrun_ready.dart'; // GhostRunReadyPage가 있는 파일
// ✅ [추가] 워치 커넥티비티 임포트
import 'package:watch_connectivity/watch_connectivity.dart';
// ✅ [추가] GhostRunPage 임포트 (기록 다이얼로그에서 사용)
import 'ghostrunpage.dart';


// ================== 지도 다이얼로그 (수정 없음) ==================
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
    final List<LatLng> allPoints = <LatLng>[...userRoutePoints, ...(ghostRoutePoints ?? [])];

    if (allPoints.isEmpty) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('경로 오류', style: TextStyle(color: Colors.white)),
        content: const Text('표시할 경로 데이터가 없습니다.', style: TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기'))],
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
              child: Text('러닝 경로', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppleMap(
                  initialCameraPosition: CameraPosition(target: allPoints.first, zoom: 15),
                  polylines: {
                    Polyline(
                      polylineId:   PolylineId('user_route'),
                      points: userRoutePoints,
                      color: Colors.blueAccent,
                      width: 5,
                    ),
                    if (ghostRoutePoints != null && ghostRoutePoints!.isNotEmpty)
                      Polyline(
                        polylineId:   PolylineId('ghost_route'),
                        points: ghostRoutePoints!,
                        color: Colors.purpleAccent.withOpacity(0.7),
                        width: 5,
                      ),
                  },
                  onMapCreated: (controller) {
                    Future.delayed(const Duration(milliseconds: 50), () {
                      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
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
      return LatLngBounds(southwest: const LatLng(0, 0), northeast: const LatLng(0, 0));
    }
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }
}

// ================== 기록 목록 다이얼로그 (수정 없음, GhostRunPage에 있던 것) ==================
class GhostRunHistoryDialog extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final FirebaseFirestore firestore;
  final String currentUserEmail;

  const GhostRunHistoryDialog({
    Key? key,
    required this.records,
    required this.firestore,
    required this.currentUserEmail,
  }) : super(key: key);

  void _showRouteMap(BuildContext context, Map<String, dynamic> record) async {
    List<LatLng> _pointsToLatLng(List<dynamic> pointsData) {
      return pointsData.map((p) {
        if (p is GeoPoint) {
          return LatLng(p.latitude, p.longitude);
        } else if (p is Map) {
          return LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
        }
        return const LatLng(0, 0);
      }).where((point) => point.latitude != 0 || point.longitude != 0).toList();
    }

    final userPointsData = record['locationPoints'] as List<dynamic>?;
    if (userPointsData == null || userPointsData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 기록에는 경로 데이터가 없습니다.')));
      return;
    }

    final List<LatLng> userRoutePoints = _pointsToLatLng(userPointsData);
    List<LatLng>? ghostRoutePoints;

    if (record['isFirstRecord'] == false && record['ghostRecordId'] != null) {
      try {
        final ghostDoc = await firestore.collection('ghostRunRecords').doc(currentUserEmail).collection('records').doc(record['ghostRecordId']).get();
        if (ghostDoc.exists) {
          final ghostPointsData = ghostDoc.data()?['locationPoints'] as List<dynamic>?;
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
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/ghostlogo.png', width: 24, height: 24, color: Colors.purpleAccent),
                      const SizedBox(width: 8),
                      const Text('고스트런 기록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                    final DateTime recordDate = (record['date'] as Timestamp).toDate();
                    dateText = index == 0
                        ? "오늘 기록 ${DateFormat('yy.MM.dd').format(recordDate)}" // 첫 번째 기록은 "오늘"
                        : "지난 기록 ${DateFormat('yy.MM.dd').format(recordDate)}";
                  }
                  String timeText = "--:--";
                  if (record['time'] != null) {
                    final int timeInSeconds = (record['time'] as num).toInt();
                    final int minutes = timeInSeconds ~/ 60;
                    final int seconds = timeInSeconds % 60;
                    timeText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
                  }
                  String distanceText = "--";
                  if (record['distance'] != null) {
                    distanceText = "${(record['distance'] as num).toStringAsFixed(2)}km";
                  }
                  String paceText = "--:--";
                  if (record['pace'] != null && (record['pace'] as num).isFinite && (record['pace'] as num) > 0) {
                    final double pace = (record['pace'] as num).toDouble();
                    final paceMinutes = pace.floor();
                    final paceSeconds = ((pace - paceMinutes) * 60).round();
                    paceText = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
                  }
                  String resultText = "";
                  Color resultColor = Colors.grey;
                  if (record['isFirstRecord'] == false && record['raceResult'] != null) {
                    final String result = record['raceResult'] as String;
                    if (result == 'win') {
                      resultText = " (승리)";
                      resultColor = Colors.green;
                    } else if (result == 'lose') {
                      resultText = " (패배)";
                      resultColor = Colors.red;
                    } else {
                      resultText = " (무승부)";
                      resultColor = Colors.orange;
                    }
                  } else if (record['isFirstRecord'] == true) {
                    resultText = " (첫 기록)";
                    resultColor = Colors.grey;
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "$dateText$resultText",
                              style: TextStyle(color: resultColor, fontSize: 13),
                            ),
                            // 경로 데이터가 있을 때만 지도 아이콘 표시
                            if (record['locationPoints'] != null && (record['locationPoints'] as List).isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.map_outlined, color: Colors.white70, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showRouteMap(context, record), // 탭하면 경로 맵 표시
                              )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRecordCard(timeText, 'Time'),
                            _buildRecordCard(distanceText, 'Km'),
                            _buildRecordCard(paceText, 'min/km'),
                          ],
                        ),
                        if (index < records.length - 1) // 마지막 항목 아니면 구분선 추가
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Divider(color: Colors.grey[800]),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 닫기 버튼
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  minimumSize: const Size(120, 40),
                ),
                child: const Text("닫기", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 기록 카드 위젯 (GhostRunPage의 것과 동일)
  Widget _buildRecordCard(String value, String label) {
    return Container(
      width: 90,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== 결과 화면 State ==================
class GhostRunResultScreen extends StatefulWidget {
  final Map<String, dynamic> userResult;
  final Map<String, dynamic> ghostResult;
  final bool isWin;

  const GhostRunResultScreen({
    Key? key,
    required this.userResult,
    required this.ghostResult,
    required this.isWin,
  }) : super(key: key);

  @override
  State<GhostRunResultScreen> createState() => _GhostRunResultScreenState();
}

class _GhostRunResultScreenState extends State<GhostRunResultScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _allRecords = [];
  bool _isLoading = true;

  // ✅ [추가] 워치 커넥티비티 변수
  final _watch = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;

  @override
  void initState() {
    super.initState();
    _loadAllUserRecords();
    // ✅ [추가] 워치 리스너 초기화 호출
    _initializeWatchConnectivity();
  }

  // ✅ [추가] 워치 리스너 초기화 함수
  void _initializeWatchConnectivity() {
    _watchMessageSubscription?.cancel();
    _watchMessageSubscription = _watch.messageStream.listen((message) {
      if (message.containsKey('command')) {
        final command = message['command'] as String;
        print("🎯 [DART-GhostResult] Command received: $command");

        if (command == 'showHistory') {
          // 워치에서 '기록' 버튼 누름 -> 기록 다이얼로그 표시
          if(mounted) _showRecordsDialog();
        } else if (command == 'resetToMainMenu') {
          // 워치에서 '확인' 버튼 누름 -> GhostRunReadyPage로 이동
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const GhostRunReadyPage()),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    // ✅ [추가] 워치 구독 취소
    _watchMessageSubscription?.cancel();
    super.dispose();
  }


  Future<void> _loadAllUserRecords() async {
    setState(() { _isLoading = true; });
    try {
      final String userEmail = _auth.currentUser?.email ?? '';
      if (userEmail.isEmpty) {
        setState(() { _isLoading = false; });
        return;
      }
      // Firestore에서 최근 20개 기록 로드
      final recordsSnapshot = await _firestore
          .collection('ghostRunRecords')
          .doc(userEmail)
          .collection('records')
          .orderBy('date', descending: true)
          .limit(20)
          .get();
      if (recordsSnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> records = [];
        for (var doc in recordsSnapshot.docs) {
          var data = doc.data();
          data['id'] = doc.id; // 문서 ID 추가
          records.add(data);
        }
        setState(() {
          _allRecords = records; // 상태 업데이트
        });
      }
    } catch (e) {
      print('모든 레코드 로딩 중 오류 발생: $e');
    } finally {
      if (mounted) {
        setState(() { // 로딩 완료
          _isLoading = false;
        });
      }
    }
  }

  // 기록 목록 다이얼로그 표시 함수
  void _showRecordsDialog() {
    if (_allRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('불러올 기록이 없습니다.')));
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) => GhostRunHistoryDialog(
        records: _allRecords,
        firestore: _firestore,
        currentUserEmail: _auth.currentUser?.email ?? '',
      ),
    );
  }

  // 경로 맵 다이얼로그 표시 함수
  void _showRouteMap() {
    // 유저 경로 데이터 추출 및 LatLng 리스트로 변환
    final userPointsData = widget.userResult['locationPoints'] as List<dynamic>?;
    final List<LatLng> userRoutePoints = (userPointsData?.map((p) {
      if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
      if (p is Map) return LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
      return const LatLng(0, 0); // 유효하지 않으면 (0,0)
    }).where((e) => e.latitude != 0 || e.longitude != 0).toList()) ?? []; // (0,0) 제외

    // 고스트 경로 데이터 추출 및 LatLng 리스트로 변환
    final ghostPointsData = widget.ghostResult['locationPoints'] as List<dynamic>?;
    final List<LatLng> ghostRoutePoints = (ghostPointsData?.map((p) {
      if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
      if (p is Map) return LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
      return const LatLng(0, 0);
    }).where((e) => e.latitude != 0 || e.longitude != 0).toList()) ?? [];

    // 경로 데이터 없으면 메시지 표시 후 종료
    if (userRoutePoints.isEmpty && ghostRoutePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('표시할 경로 데이터가 없습니다.')));
      return;
    }

    // 경로 맵 다이얼로그 표시
    showDialog(
      context: context,
      builder: (_) => RouteMapDialog(
        userRoutePoints: userRoutePoints,
        ghostRoutePoints: ghostRoutePoints,
      ),
    );
  }

  // 결과 공유 함수
  void _shareResult() {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    // 공유 미리보기 오버레이 생성 및 표시
    overlayEntry = OverlayEntry(
        builder: (context) => GhostSharePreviewOverlay(
          userResult: widget.userResult,
          ghostResult: widget.ghostResult,
          isWin: widget.isWin,
          onShareComplete: () => overlayEntry.remove(), // 공유 완료 시 오버레이 제거
        ));
    overlay.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    // 결과 데이터 포맷팅
    final String userTime = _formatTime((widget.userResult['time'] as num? ?? 0).toInt());
    final String userDistance = _formatDistance((widget.userResult['distance'] as num? ?? 0.0).toDouble());
    final String userPace = _formatPace((widget.userResult['pace'] as num? ?? 0.0).toDouble());

    final String ghostTime = _formatTime((widget.ghostResult['time'] as num? ?? 0).toInt());
    final String ghostDistance = _formatDistance((widget.ghostResult['distance'] as num? ?? 0.0).toDouble());
    final String ghostPace = _formatPace((widget.ghostResult['pace'] as num? ?? 0.0).toDouble());

    // 승패 메시지 설정
    String resultMessage = widget.isWin ? "수고하셨습니다!\n과거의 나를 뛰어넘었습니다!" : "아쉽지만\n과거의 나에게 패배했습니다.";
    String comparisonMessage = widget.isWin ? "과거의 나에게 승리!" : "과거의 나에게 패배";

    return Scaffold(
      backgroundColor:Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false, // 기본 뒤로가기 버튼 숨김
        leading: GestureDetector( // 커스텀 뒤로가기 버튼
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const GhostRunReadyPage())), // 탭하면 GhostRunReadyPage로 이동
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Image.asset('assets/images/Back-Navs-Black.png', width: 40, height: 40),
          ),
        ),
        centerTitle: true,
        title: const Text('고스트런 결과', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          // 경로 보기 버튼
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Colors.white),
            onPressed: _showRouteMap,
          ),
          // 공유 버튼
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: _shareResult,
          )
        ],
      ),
      body: Stack( // 배경 이미지와 내용을 겹치기 위해 Stack 사용
        children: [
          // 배경 이미지 (화면 하단에 배치)
          Positioned.fill(bottom: 0, child: Image.asset('assets/images/ghostrunconfirmation.png', fit: BoxFit.cover)),
          Positioned(bottom: 10, right: 10, child: Image.asset('assets/images/ghostrunconfirmation2.png', width: 120, height: 120)),
          // 내용 영역 (SafeArea 적용)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // 결과 메시지 (승/패)
                  Text(resultMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  // 승/패 요약 텍스트 (색상 구분)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(comparisonMessage, style: TextStyle(color: widget.isWin ? Colors.greenAccent : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 40),
                  // 유저 결과 카드
                  _buildResultCard("Me", userTime, userDistance, userPace, Colors.blueAccent),
                  const SizedBox(height: 25),
                  // 고스트 결과 카드
                  _buildResultCard("Ghost", ghostTime, ghostDistance, ghostPace, Colors.purpleAccent),
                  const Spacer(), // 남은 공간 모두 차지
                  // 지난 기록 더보기 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _showRecordsDialog, // 로딩 중이면 비활성화
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      child: _isLoading // 로딩 상태 표시
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('지난기록 더보기', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 확인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const GhostRunReadyPage())), // 탭하면 GhostRunReadyPage로 이동
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('확인', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20), // 하단 여백
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 결과 카드 위젯 빌더
  Widget _buildResultCard(String title, String time, String distance, String pace, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(15)), // 반투명 검정 배경, 둥근 모서리
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀 (아이콘 + 텍스트)
          Row(
            children: [
              if (title == "Me") // 유저 아이콘
                Icon(Icons.person, color: iconColor, size: 20)
              else // 고스트 아이콘
                Image.asset('assets/images/ghostlogo.png', width: 20, height: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: iconColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          // 측정 항목 (시간, 거리, 페이스)
          Row(
            children: [
              _buildMetricBox(time, "Time"),
              const SizedBox(width: 10),
              _buildMetricBox(distance, "Km"),
              const SizedBox(width: 10),
              _buildMetricBox(pace, "min/km"),
            ],
          ),
        ],
      ),
    );
  }

  // 측정 항목 표시용 작은 박스 위젯 빌더
  Widget _buildMetricBox(String value, String label) {
    return Expanded( // Row 안에서 공간을 균등하게 차지하도록 Expanded 사용
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: Colors.black, // 검정 배경
          borderRadius: BorderRadius.circular(10), // 둥근 모서리
          border: Border.all(color: Colors.grey.shade800, width: 1), // 회색 테두리
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), // 값 (흰색, 굵게)
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)), // 레이블 (밝은 회색)
          ],
        ),
      ),
    );
  }

  // 초를 MM:SS 형식으로 변환
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  // 거리를 "0.00km" 형식으로 변환
  String _formatDistance(double distance) {
    return "${distance.toStringAsFixed(2)}km";
  }

  // 페이스(분/km)를 "M:SS" 형식으로 변환
  String _formatPace(double pace) {
    if(!pace.isFinite || pace <= 0) return "--:--"; // 유효하지 않으면 "--:--"
    final paceMinutes = pace.floor();
    final paceSeconds = ((pace - paceMinutes) * 60).floor(); // floor 사용
    return "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
  }
}


// ================== 공유 미리보기 오버레이 (수정 없음, GhostRunPage에 있던 것) ==================
class GhostSharePreviewOverlay extends StatefulWidget {
  final Map<String, dynamic> userResult;
  final Map<String, dynamic>? ghostResult; // 첫 기록일 수 있으므로 Nullable
  final bool isWin;
  final Function() onShareComplete;

  const GhostSharePreviewOverlay({Key? key, required this.userResult, this.ghostResult, required this.isWin, required this.onShareComplete}) : super(key: key);

  @override
  _GhostSharePreviewOverlayState createState() => _GhostSharePreviewOverlayState();
}

class _GhostSharePreviewOverlayState extends State<GhostSharePreviewOverlay> {
  final GlobalKey _shareBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 위젯 렌더링 후 캡처 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        captureAndShare();
      }
    });
  }

  // 이미지 캡처 및 공유 함수
  Future<void> captureAndShare() async {
    await Future.delayed(const Duration(milliseconds: 300)); // 렌더링 안정화 시간
    try {
      // RepaintBoundary 찾아서 이미지로 변환
      RenderRepaintBoundary boundary = _shareBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // 고해상도 캡처
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("ByteData could not be generated.");
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 임시 파일로 저장
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/ghost_run_result.png').create();
      await file.writeAsBytes(pngBytes);

      // share_plus 패키지로 공유
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '런드벤처 고스트런 결과! 👻');
    } catch (e) {
      print('Share error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("공유 이미지 생성 실패: $e")));
    } finally {
      widget.onShareComplete(); // 완료 콜백 호출 (오버레이 제거 등)
    }
  }

  // 시간 포맷 함수
  String _formatTime(dynamic totalSeconds) {
    final int secondsInt = (totalSeconds as num? ?? 0).toInt();
    final int minutes = secondsInt ~/ 60;
    final int seconds = secondsInt % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  // 경로 경계 계산 함수
  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) return LatLngBounds(southwest: const LatLng(0,0), northeast: const LatLng(0,0));
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  // Firestore 데이터(GeoPoint 또는 Map)를 LatLng 리스트로 변환
  List<LatLng> _pointsToLatLng(List<dynamic>? pointsData) {
    if (pointsData == null) return [];
    return pointsData.map((p) {
      if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
      if (p is Map) return LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
      return const LatLng(0, 0);
    }).where((point) => point.latitude != 0 || point.longitude != 0).toList(); // (0,0) 좌표 제외
  }


  @override
  Widget build(BuildContext context) {
    final bool isFirstRun = widget.ghostResult == null; // 고스트 결과 없으면 첫 기록

    // 결과 텍스트 및 색상 설정
    final String resultText;
    final Color resultColor;
    if (isFirstRun) {
      resultText = 'FIRST\nRUN'; // 줄바꿈 포함
      resultColor = Colors.blueAccent;
    } else {
      resultText = widget.isWin ? 'WIN' : 'LOSE';
      resultColor = widget.isWin ? Colors.greenAccent : Colors.redAccent;
    }

    // 경로 데이터 변환
    final List<LatLng> userRoutePoints = _pointsToLatLng(widget.userResult['locationPoints']);
    final List<LatLng> ghostRoutePoints = isFirstRun ? [] : _pointsToLatLng(widget.ghostResult?['locationPoints']);

    // 전체 경로 경계 계산
    final List<LatLng> allPoints = [...userRoutePoints, ...ghostRoutePoints];
    final bounds = allPoints.isNotEmpty ? _calculateBounds(allPoints) : null;

    // 공유될 카드 UI
    return Material(
      color: Colors.black.withOpacity(0.8), // 반투명 배경
      child: Center(
        child: RepaintBoundary( // 이 위젯을 이미지로 캡처
          key: _shareBoundaryKey,
          child: SizedBox( // 고정된 크기 (캡처용)
            width: 450,
            height: 800,
            child: Stack(
              children: [
                Container(color: Colors.black), // 기본 검정 배경

                // 경로 그리기 (CustomPaint 사용)
                if (allPoints.isNotEmpty && bounds != null)
                  CustomPaint(
                    size: const Size(450, 800),
                    painter: RoutePainter( // 아래 정의된 RoutePainter 사용
                      userPoints: userRoutePoints,
                      ghostPoints: ghostRoutePoints,
                      bounds: bounds,
                      isFirstRun: isFirstRun, // 첫 기록인지 여부 전달
                    ),
                  ),

                Container(color: Colors.black.withOpacity(0.6)), // 경로 위에 반투명 검정 레이어

                // 범례 표시
                if (allPoints.isNotEmpty && !isFirstRun) // 경주 모드일 때
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
                if (allPoints.isNotEmpty && isFirstRun) // 첫 기록 모드일 때
                  Positioned(
                    top: 100,
                    right: 30,
                    child: _buildLegendItem(Colors.white, 'MY FIRST RUN'),
                  ),

                // 텍스트 정보 표시 영역
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, // 가로로 꽉 채움
                    children: [
                      Text('GHOST RUN', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, decoration: TextDecoration.none)),
                      const SizedBox(height: 8),
                      // 결과 텍스트 (WIN/LOSE/FIRST RUN)
                      Text(resultText, style: TextStyle(color: resultColor, fontSize: resultText.length > 3 ? 60 : 100, fontWeight: FontWeight.w900, height: 1.1, decoration: TextDecoration.none)),
                      const Spacer(), // 하단 정보 위로 밀기
                      // 기록 표시
                      _buildResultRow("MY RECORD", _formatTime(widget.userResult['time'])),
                      const SizedBox(height: 8),
                      if (!isFirstRun) // 첫 기록 아닐 때만 고스트 기록 표시
                        _buildResultRow("GHOST RECORD", _formatTime(widget.ghostResult!['time'])),
                      const SizedBox(height: 24),
                      // 거리 표시
                      Center(child: Text("${(widget.userResult['distance'] as num? ?? 0.0).toStringAsFixed(2)} Km", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, decoration: TextDecoration.none))),
                      const SizedBox(height: 40),
                      // 앱 이름
                      Center(child: Text('RUNDVENTURE', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none))),
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

  // 범례 항목 위젯 빌더
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle), // 색상 원
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none), // 흰색 텍스트
        ),
      ],
    );
  }

  // 기록 행 위젯 빌더 (레이블 + 값)
  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // 양쪽 끝 정렬
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 20, decoration: TextDecoration.none)), // 레이블
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, decoration: TextDecoration.none)), // 값
      ],
    );
  }
}

// ================== 경로 그리기 CustomPainter (수정 없음, GhostRunPage에 있던 것) ==================
class RoutePainter extends CustomPainter {
  final List<LatLng> userPoints;
  final List<LatLng> ghostPoints;
  final LatLngBounds bounds;
  final bool isFirstRun; // 첫 기록인지 여부

  RoutePainter({
    required this.userPoints,
    required this.ghostPoints,
    required this.bounds,
    required this.isFirstRun,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 경로 라인 그리기 함수
    void drawPath(List<LatLng> points, Color color) {
      if (points.length < 2) return; // 점 2개 이상 필요
      final paint = Paint()
        ..color = color
        ..strokeWidth = 6.0 // 선 두께
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round // 끝 모양 둥글게
        ..strokeJoin = StrokeJoin.round; // 꺾이는 부분 둥글게
      final path = Path();
      final firstScaledPoint = _scalePoint(points.first, size); // 첫 점 좌표 변환
      path.moveTo(firstScaledPoint.dx, firstScaledPoint.dy); // 경로 시작점 이동
      // 나머지 점들 연결
      for (int i = 1; i < points.length; i++) {
        final scaledPoint = _scalePoint(points[i], size);
        path.lineTo(scaledPoint.dx, scaledPoint.dy);
      }
      canvas.drawPath(path, paint); // 경로 그리기
    }

    // 시작/종료 지점 원 그리기 함수
    void drawCircle(Canvas canvas, Offset center, Color color) {
      final paint = Paint() // 채우기 색상
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 8.0, paint); // 원 그리기

      final borderPaint = Paint() // 테두리 색상
        ..color = Colors.black.withOpacity(0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, 8.0, borderPaint); // 테두리 그리기
    }

    // 고스트 경로 그리기 (첫 기록 아닐 때만)
    if (!isFirstRun && ghostPoints.isNotEmpty) {
      drawPath(ghostPoints, Colors.purpleAccent); // 보라색 경로
      drawCircle(canvas, _scalePoint(ghostPoints.first, size), Colors.purple.shade200); // 연보라 시작점
      drawCircle(canvas, _scalePoint(ghostPoints.last, size), Colors.purple.shade200);  // 연보라 종료점
    }

    // 사용자 경로 그리기
    if (userPoints.isNotEmpty) {
      // 첫 기록이면 흰색, 아니면 파란색 경로
      final userPathColor = isFirstRun ? Colors.white : Colors.blueAccent;
      drawPath(userPoints, userPathColor);
      drawCircle(canvas, _scalePoint(userPoints.first, size), Colors.greenAccent); // 녹색 시작점
      drawCircle(canvas, _scalePoint(userPoints.last, size), Colors.redAccent);    // 빨간색 종료점
    }
  }

  // LatLng 좌표를 Canvas 좌표로 변환하는 함수
  Offset _scalePoint(LatLng point, Size size) {
    double minLat = bounds.southwest.latitude;
    double maxLat = bounds.northeast.latitude;
    double minLng = bounds.southwest.longitude;
    double maxLng = bounds.northeast.longitude;

    // 위도/경도 범위 계산
    double lngRange = maxLng - minLng;
    double latRange = maxLat - minLat;

    // 정규화 (0.0 ~ 1.0 범위로 변환)
    // 범위가 0에 가까우면 (점이 하나거나 수직/수평선) 중앙값(0.5) 사용
    double normalizedX = lngRange.abs() < 1e-9 ? 0.5 : (point.longitude - minLng) / lngRange;
    double normalizedY = latRange.abs() < 1e-9 ? 0.5 : (point.latitude - minLat) / latRange;

    // 패딩 설정 및 그리기 영역 계산
    double paddingX = size.width * 0.1; // 좌우 10% 패딩
    double paddingY = size.height * 0.1; // 상하 10% 패딩
    double drawWidth = size.width - 2 * paddingX;
    double drawHeight = size.height - 2 * paddingY;

    // Canvas 좌표 계산 (Y축은 위가 0이므로 반전)
    double scaledX = paddingX + normalizedX * drawWidth;
    double scaledY = paddingY + (1 - normalizedY) * drawHeight; // Y축 반전

    return Offset(scaledX, scaledY);
  }

  // 다시 그릴 필요가 있는지 확인하는 함수
  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    // 이전 값과 비교하여 변경되었으면 다시 그림
    return oldDelegate.userPoints != userPoints ||
        oldDelegate.ghostPoints != ghostPoints ||
        oldDelegate.bounds != bounds ||
        oldDelegate.isFirstRun != isFirstRun;
  }
}