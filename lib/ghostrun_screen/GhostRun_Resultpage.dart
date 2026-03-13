import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'ghostrun_ready.dart';
import 'widgets/route_map_dialog.dart';
import 'widgets/ghost_share_preview_overlay.dart';


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

    if (!context.mounted) return;
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

  final _watch = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;

  @override
  void initState() {
    super.initState();
    _loadAllUserRecords();
    _initializeWatchConnectivity();
  }

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
