import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../main_screens/main_screen.dart';
import 'FirstGhostRun_Tracking.dart';
import 'GhostRunRulePage.dart';
import 'GhostRun_TrackingPage.dart';
import 'ghostrun_ready.dart';
import 'widgets/ghost_run_result_dialog.dart';
import 'widgets/route_map_dialog.dart';

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

  void _showUseWatchDialog(BuildContext context) async {
    if (widget.withWatch) {
      print("GhostRunPage: MainScreen으로부터 withWatch=true 받음. 즉시 시작.");
      _startRun(withWatch: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final bool withWatch = prefs.getBool('watchSyncEnabled') ?? false;

    _startRun(withWatch: withWatch);
  }

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

    if (!mounted) return;
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
                      onPressed: () => _showUseWatchDialog(context),
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

