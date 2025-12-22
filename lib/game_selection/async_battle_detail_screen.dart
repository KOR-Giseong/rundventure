import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'async_battle_running_screen.dart';
import 'package:rundventure/free_running/free_running_start.dart';

class AsyncBattleDetailScreen extends StatefulWidget {
  final String battleId;

  const AsyncBattleDetailScreen({Key? key, required this.battleId}) : super(key: key);

  @override
  _AsyncBattleDetailScreenState createState() => _AsyncBattleDetailScreenState();
}

class _AsyncBattleDetailScreenState extends State<AsyncBattleDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  late Stream<DocumentSnapshot> _battleStream;
  String? _currentUserEmail;
  bool _isProcessing = false;

  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _currentUserEmail = _auth.currentUser?.email;
    _battleStream = _firestore.collection('asyncBattles').doc(widget.battleId).snapshots();
  }

  Future<void> _cancelBattle() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _showLoadingDialog("대결을 취소하는 중...");

    try {
      final callable = _functions.httpsCallable('cancelAsyncBattle');
      final result = await callable.call({'battleId': widget.battleId});

      if (!mounted) return;
      Navigator.pop(context);

      if (result.data['success'] == true) {
        _showCustomSnackBar("대결이 취소되었습니다.");
        Navigator.pop(context);
      } else {
        _showCustomSnackBar(result.data['message'] ?? "취소에 실패했습니다.", isError: true);
      }
    } catch (e) {
      print("cancelAsyncBattle 호출 오류: $e");
      if (mounted) {
        Navigator.pop(context);
        _showCustomSnackBar("대결 취소 중 오류가 발생했습니다.", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _startRun(double targetDistanceKm) {
    if (_isProcessing) return;
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AsyncBattleRunningScreen(
          targetDistanceKm: targetDistanceKm,
          battleId: widget.battleId,
        ),
      ),
    );
  }

  Future<void> _shareBattleResult() async {
    if (_isSharing) return;
    setState(() { _isSharing = true; });

    try {
      RenderRepaintBoundary boundary = _shareBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/async_battle_result.png').create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '런드벤처 오프라인 대결 결과! 🏃🔥');

    } catch (e) {
      print("공유 오류: $e");
      _showCustomSnackBar('이미지 생성 중 오류가 발생했습니다.', isError: true);
    } finally {
      if (mounted) setState(() { _isSharing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _battleStream,
      builder: (context, snapshot) {
        // 로딩/에러 처리
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: Colors.grey[100], body: Center(child: CircularProgressIndicator(color: Color(0xFFFF9F80))));
        }
        if (snapshot.hasError) {
          return Scaffold(backgroundColor: Colors.grey[100], body: Center(child: Text("오류: ${snapshot.error}")));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(backgroundColor: Colors.grey[100], body: Center(child: Text("대결 정보를 찾을 수 없습니다.")));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'] as String;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            leading: IconButton(
              icon: Image.asset('assets/images/Back-Navs.png', width: 66, height: 66),
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.only(left: 8),
            ),
            title: Text('대결 상세 정보'),
            backgroundColor: Colors.grey[100],
            elevation: 0,
            centerTitle: true,
            actions: [
              if (status == 'finished')
                _isSharing
                    ? Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                )
                    : IconButton(
                  icon: Icon(Icons.ios_share, color: Colors.black),
                  onPressed: _shareBattleResult,
                ),
            ],
          ),
          body: Stack(
            children: [
              _buildDetailsPage(data),

              Positioned(
                left: -2000,
                top: 0,
                child: RepaintBoundary(
                  key: _shareBoundaryKey,
                  child: _buildShareableCard(data),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 메인 화면 UI 빌드 ---
  Widget _buildDetailsPage(Map<String, dynamic> data) {
    // --- 1. 데이터 추출 ---
    final bool amIChallenger = data['challengerEmail'] == _currentUserEmail;
    final status = data['status'] as String;

    // "내 차례" 여부
    final bool isOpponentMyTurn = !amIChallenger && status == 'running' && data['opponentRunData'] == null;
    final bool isChallengerMyTurn = amIChallenger && status == 'pending';
    final bool isMyTurn = isOpponentMyTurn || isChallengerMyTurn;

    // 내 정보
    final myNickname = amIChallenger ? data['challengerNickname'] : data['opponentNickname'];
    final myProfileUrl = amIChallenger ? data['challengerProfileUrl'] : data['opponentProfileUrl'];
    final myRunData = (amIChallenger ? data['challengerRunData'] : data['opponentRunData']) as Map<String, dynamic>?;

    // 상대방 정보
    final opNickname = amIChallenger ? data['opponentNickname'] : data['challengerNickname'];
    final opProfileUrl = amIChallenger ? data['opponentProfileUrl'] : data['challengerProfileUrl'];
    final opRunData = (amIChallenger ? data['opponentRunData'] : data['challengerRunData']) as Map<String, dynamic>?;

    // 무승부 로직
    final bool isDraw = data['isDraw'] == true;

    // 승자 판별 (무승부가 아닐 때만)
    bool myIsWinner = false;
    bool opIsWinner = false;
    if (status == 'finished' && !isDraw) {
      if (data['winnerEmail'] == _currentUserEmail) {
        myIsWinner = true;
      } else if (data['winnerEmail'] != null) {
        opIsWinner = true;
      }
    }

    final targetKm = (data['targetDistanceKm'] as num).toInt();

    // --- 2. UI 빌드 ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2-1. 선수 비교 카드
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              child: Column(
                children: [
                  // 선수 프로필 (아바타, 닉네임, 승자/무승부)
                  _buildPlayerHeader(
                      myNickname, myProfileUrl, myIsWinner,
                      opNickname, opProfileUrl, opIsWinner, status, isDraw
                  ),
                  SizedBox(height: 20),
                  Divider(color: Colors.grey[200]),
                  SizedBox(height: 12),

                  // 비교 스탯 (기록)
                  _buildComparisonStatRow(
                    icon: Icons.timer_outlined,
                    label: "기록",
                    myValue: myRunData != null ? _formatTime(myRunData['seconds'] as num) : "--:--",
                    opValue: opRunData != null ? _formatTime(opRunData['seconds'] as num) : "--:--",
                    myColor: isDraw ? Colors.indigo : (myIsWinner ? Colors.green.shade700 : (opIsWinner ? Colors.redAccent.shade700 : Colors.black87)),
                    opColor: isDraw ? Colors.indigo : (opIsWinner ? Colors.green.shade700 : (myIsWinner ? Colors.redAccent.shade700 : Colors.black87)),
                  ),
                  SizedBox(height: 18),

                  // 비교 스탯 (페이스)
                  _buildComparisonStatRow(
                    icon: Icons.speed_outlined,
                    label: "평균 페이스",
                    myValue: myRunData != null ? _formatPace(myRunData['pace'] as num) : "--'--\"",
                    opValue: opRunData != null ? _formatPace(opRunData['pace'] as num) : "--'--\"",
                  ),
                  SizedBox(height: 18),

                  Divider(color: Colors.grey[200]),
                  SizedBox(height: 12),

                  // 공통 스탯 (목표 거리)
                  _buildSharedStatRow(
                    icon: Icons.map_outlined,
                    label: "목표 거리",
                    value: "$targetKm km",
                  ),
                  SizedBox(height: 18),

                  // 공통 스탯 (신청일)
                  _buildSharedStatRow(
                    icon: Icons.calendar_today_outlined,
                    label: "신청일",
                    value: DateFormat('yyyy.MM.dd').format((data['createdAt'] as Timestamp).toDate()),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),

          // 2-2. 액션 버튼
          _buildActionButtons(status, isMyTurn, isChallengerMyTurn, targetKm.toDouble()),
        ],
      ),
    );
  }

  Widget _buildShareableCard(Map<String, dynamic> data) {
    final bool amIChallenger = data['challengerEmail'] == _currentUserEmail;

    final myNickname = amIChallenger ? data['challengerNickname'] : data['opponentNickname'];
    final opNickname = amIChallenger ? data['opponentNickname'] : data['challengerNickname'];
    final myRunData = (amIChallenger ? data['challengerRunData'] : data['opponentRunData']) as Map<String, dynamic>?;
    final opRunData = (amIChallenger ? data['opponentRunData'] : data['challengerRunData']) as Map<String, dynamic>?;

    final bool isDraw = data['isDraw'] == true;
    bool iAmWinner = false;
    if (!isDraw && data['status'] == 'finished' && data['winnerEmail'] == _currentUserEmail) {
      iAmWinner = true;
    }

    final String myTimeStr = myRunData != null ? _formatTime(myRunData['seconds'] as num) : "--:--";
    final String opTimeStr = opRunData != null ? _formatTime(opRunData['seconds'] as num) : "--:--";

    final double distance = (data['targetDistanceKm'] as num).toDouble();
    List<LatLng> routePoints = [];
    if (myRunData != null && myRunData['routePoints'] != null) {
      routePoints = (myRunData['routePoints'] as List).map((p) {
        final lat = (p['latitude'] as num).toDouble();
        final lng = (p['longitude'] as num).toDouble();
        return LatLng(lat, lng);
      }).toList();
    } else if (opRunData != null && opRunData['routePoints'] != null) {
      routePoints = (opRunData['routePoints'] as List).map((p) {
        final lat = (p['latitude'] as num).toDouble();
        final lng = (p['longitude'] as num).toDouble();
        return LatLng(lat, lng);
      }).toList();
    }

    LatLngBounds bounds = LatLngBounds(southwest: LatLng(0,0), northeast: LatLng(0,0));
    if(routePoints.length >= 2) {
      double minLat = routePoints.map((p) => p.latitude).reduce(math.min);
      double maxLat = routePoints.map((p) => p.latitude).reduce(math.max);
      double minLng = routePoints.map((p) => p.longitude).reduce(math.min);
      double maxLng = routePoints.map((p) => p.longitude).reduce(math.max);
      bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    }

    return Container(
      width: 450,
      height: 800,
      color: Colors.white,
      child: Stack(
        children: [
          // 배경: 경로 그리기
          if (routePoints.length >= 2)
            CustomPaint(
              size: Size(450, 800),
              painter: RoutePainter(points: routePoints, bounds: bounds),
            ),

          // 하단 정보 오버레이
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '오프라인 대결 결과',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 2.0, decoration: TextDecoration.none),
                  ),
                  SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(myNickname, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent, decoration: TextDecoration.none), overflow: TextOverflow.ellipsis),
                            SizedBox(height: 4),
                            Text("나", style: TextStyle(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("VS", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.grey[300], decoration: TextDecoration.none)),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(opNickname, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent, decoration: TextDecoration.none), overflow: TextOverflow.ellipsis),
                            SizedBox(height: 4),
                            Text("상대방", style: TextStyle(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Divider(color: Colors.grey[300], thickness: 1),
                  SizedBox(height: 20),

                  Text(
                    isDraw ? "무승부" : (iAmWinner ? "승리!" : "패배"),
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      color: isDraw ? Colors.indigo : (iAmWinner ? Colors.blueAccent : Colors.redAccent),
                      decoration: TextDecoration.none,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(myTimeStr, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, decoration: TextDecoration.none)),
                            Text("시간", style: TextStyle(fontSize: 12, color: Colors.grey[500], decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          children: [
                            Text(opTimeStr, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, decoration: TextDecoration.none)),
                            Text("시간", style: TextStyle(fontSize: 12, color: Colors.grey[500], decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),

                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "${distance.toStringAsFixed(0)} km 오프라인 대결",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800], decoration: TextDecoration.none),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "RUNDVENTURE",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.0, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerHeader(
      String myNickname, String? myProfileUrl, bool myIsWinner,
      String opNickname, String? opProfileUrl, bool opIsWinner, String status, bool isDraw) {

    // 상태에 따라 VS 아이콘 변경
    Widget vsWidget;
    if (status == 'finished') {
      if (isDraw) {
        vsWidget = Icon(Icons.handshake, color: Colors.indigo, size: 28);
      } else {
        vsWidget = Icon(Icons.check_circle, color: myIsWinner ? Colors.green : Colors.redAccent, size: 28);
      }
    } else if (status == 'cancelled') {
      vsWidget = Icon(Icons.cancel, color: Colors.grey, size: 28);
    } else {
      vsWidget = Text("VS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[400]));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 내 정보
        Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: myProfileUrl != null
                    ? NetworkImage(myProfileUrl)
                    : AssetImage('assets/images/user.png') as ImageProvider,
                backgroundColor: Colors.grey[200],
              ),
              SizedBox(height: 8),
              Text(
                myNickname,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isDraw)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("🤝 Draw", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                )
              else if (myIsWinner)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("🏆 Winner", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                )
              else if (opIsWinner && status == 'finished')
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text("😥 Lose", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent.shade700)),
                  ),
            ],
          ),
        ),

        // VS 아이콘
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: vsWidget,
        ),

        // 상대방 정보
        Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: opProfileUrl != null
                    ? NetworkImage(opProfileUrl)
                    : AssetImage('assets/images/user.png') as ImageProvider,
                backgroundColor: Colors.grey[200],
              ),
              SizedBox(height: 8),
              Text(
                opNickname,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isDraw)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("🤝 Draw", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                )
              else if (opIsWinner)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("🏆 Winner", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                )
              else if (myIsWinner && status == 'finished')
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text("😥 Lose", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent.shade700)),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonStatRow({
    required IconData icon,
    required String label,
    required String myValue,
    required String opValue,
    Color myColor = Colors.black87,
    Color opColor = Colors.black87,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            myValue,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: myColor),
            textAlign: TextAlign.left,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            children: [
              Icon(icon, color: Colors.grey[500], size: 20),
              SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            opValue,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: opColor),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildSharedStatRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[500], size: 20),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(String status, bool isMyTurn, bool isChallengerMyTurn, double targetKm) {
    if (_isProcessing) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFFF9F80)));
    }

    if (isMyTurn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.directions_run_rounded),
            label: Text("러닝 시작하기"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _startRun(targetKm),
          ),
          if (isChallengerMyTurn)
            TextButton(
              child: Text("대결 취소하기", style: TextStyle(color: Colors.redAccent)),
              onPressed: _cancelBattle,
            ),
        ],
      );
    }

    if (status == 'pending' || status == 'running') {
      return Center(
        child: Text(
          status == 'pending' ? "⏳ 도전자가 뛸 때까지 대기 중입니다." : "🏃 상대방이 뛸 때까지 대기 중입니다.",
          style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w500),
        ),
      );
    }

    return SizedBox.shrink();
  }

  String _formatTime(num seconds) {
    final double totalSeconds = seconds.toDouble();
    final int totalSecInt = totalSeconds.floor();
    final int centi = ((totalSeconds - totalSecInt) * 100).round();

    final int hours = totalSecInt ~/ 3600;
    final int minutes = (totalSecInt % 3600) ~/ 60;
    final int secs = totalSecInt % 60;

    String timeStr = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${centi.toString().padLeft(2, '0')}';
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$timeStr';
    }
    return timeStr;
  }

  String _formatPace(num pace) {
    if (pace.isInfinite || pace.isNaN || pace == 0) return "--'--\"";
    int min = pace.floor();
    int sec = ((pace - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFFFF9F80)),
              SizedBox(width: 20),
              Text(message, style: TextStyle(fontSize: 16)),
            ],
          ),
        );
      },
    );
  }
}

class RoutePainter extends CustomPainter {
  final List<LatLng> points;
  final LatLngBounds bounds;

  RoutePainter({required this.points, required this.bounds});

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
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.bounds != bounds;
  }
}