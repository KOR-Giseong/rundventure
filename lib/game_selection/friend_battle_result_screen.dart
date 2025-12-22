import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rundventure/free_running/free_running_start.dart';
import 'package:rundventure/main_screens/main_screen.dart';

import 'friend_battle_list_screen.dart';


class FriendBattleResultScreen extends StatefulWidget {
  final String battleId;
  final Map<String, dynamic> finalBattleData;
  final List<RouteDataPoint> myRoutePoints;
  final int myFinalSeconds;
  final int myStepCount;
  final double myElevation;
  final double myAverageSpeed;
  final double myCalories;

  // 밀리초 데이터
  final int? myFinalTimeMs;

  // 상대방 경로 (선택적)
  final List<RouteDataPoint>? opponentRoutePoints;
  // 히스토리 탭에서 진입 여부
  final bool isFromHistory;


  const FriendBattleResultScreen({
    Key? key,
    required this.battleId,
    required this.finalBattleData,
    required this.myRoutePoints,
    required this.myFinalSeconds,
    required this.myStepCount,
    required this.myElevation,
    required this.myAverageSpeed,
    required this.myCalories,
    this.myFinalTimeMs,
    this.opponentRoutePoints,
    this.isFromHistory = false,
  }) : super(key: key);

  @override
  _FriendBattleResultScreenState createState() => _FriendBattleResultScreenState();
}

class _FriendBattleResultScreenState extends State<FriendBattleResultScreen> {
  final String? _myEmail = FirebaseAuth.instance.currentUser?.email;
  final GlobalKey _shareBoundaryKey = GlobalKey();

  // 상태 변수
  bool _isSaving = false;
  bool _isSharing = false;
  bool _isWinner = false; // 내가 이겼는지
  bool _isDraw = false;
  bool _isMeChallenger = false;

  bool _isCancelled = false;
  bool _didIQuit = false;

  // 내 정보
  late Map<String, dynamic> _myInfo;
  // 상대방 정보
  late Map<String, dynamic> _opponentInfo;

  // 지도 변수
  AppleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Annotation> _markers = {};

  @override
  void initState() {
    super.initState();
    _myInfo = {};
    _processBattleData();
    _updateMapDisplay();
  }

  void _processBattleData() {
    if (_myEmail == null) return;

    final data = widget.finalBattleData;
    _isMeChallenger = (data['challengerEmail'] == _myEmail);

    final targetDistanceKm = (data['targetDistanceKm'] as num).toDouble();

    final String status = data['status'] ?? 'finished';
    if (status == 'cancelled') {
      _isCancelled = true;
      final String? canceller = data['cancellerEmail'];
      _didIQuit = (canceller == _myEmail);
      _isWinner = !_didIQuit;
      _isDraw = false;
    }

    // 1. 내 밀리초
    int myMs = widget.myFinalTimeMs ??
        ((_isMeChallenger ? data['challengerFinalTimeMs'] : data['opponentFinalTimeMs']) as int?) ??
        (widget.myFinalSeconds * 1000);

    // 2. 상대방 밀리초
    int opMs = ((_isMeChallenger ? data['opponentFinalTimeMs'] : data['challengerFinalTimeMs']) as int?) ?? 0;

    // 상대방 기록 역산 (구버전 호환)
    if (opMs == 0) {
      final opPace = (_isMeChallenger ? data['opponentPace'] : data['challengerPace'] as num).toDouble();
      if (opPace > 0) {
        opMs = (opPace * targetDistanceKm * 60.0 * 1000).round();
      }
    }

    // 내 정보 설정
    _myInfo = {
      'nickname': _isMeChallenger ? data['challengerNickname'] : data['opponentNickname'],
      'profileUrl': _isMeChallenger ? data['challengerProfileUrl'] : data['opponentProfileUrl'],
      'distance': targetDistanceKm,
      'seconds': widget.myFinalSeconds,
      'timeMs': myMs,
      'pace': (widget.myFinalSeconds / 60.0) / (targetDistanceKm > 0 ? targetDistanceKm : 1), // 0 나누기 방지
      'stepCount': widget.myStepCount,
      'elevation': widget.myElevation,
      'avgSpeed': widget.myAverageSpeed,
      'calories': widget.myCalories,
    };

    // 상대방 정보 설정
    _opponentInfo = {
      'email': _isMeChallenger ? data['opponentEmail'] : data['challengerEmail'],
      'nickname': _isMeChallenger ? data['opponentNickname'] : data['challengerNickname'],
      'profileUrl': _isMeChallenger ? data['opponentProfileUrl'] : data['challengerProfileUrl'],
      'distance': targetDistanceKm,
      'seconds': opMs ~/ 1000,
      'timeMs': opMs,
      'pace': (_isMeChallenger ? data['opponentPace'] : data['challengerPace'] as num).toDouble(),
    };

    // 승패 판정 (취소되지 않았을 때만 시간으로 계산)
    if (!_isCancelled) {
      setState(() {
        if (opMs == 0) {
          _isWinner = true;
          _isDraw = false;
        } else if (myMs == opMs) {
          _isDraw = true;
          _isWinner = false;
        } else {
          _isDraw = false;
          _isWinner = myMs < opMs;
        }
      });
    }
  }

  /// 2. 지도 경로 표시 (변경 없음)
  void _updateMapDisplay() {
    _polylines.clear();
    _markers.clear();

    bool hasMyRoute = widget.myRoutePoints.isNotEmpty;
    bool hasOpponentRoute = widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty;

    // 내 경로
    if (hasMyRoute) {
      if (widget.myRoutePoints.length >= 2) {
        for (int i = 0; i < widget.myRoutePoints.length - 1; i++) {
          final start = widget.myRoutePoints[i];
          final end = widget.myRoutePoints[i + 1];
          _polylines.add(Polyline(
            polylineId: PolylineId('my_route_segment_$i'),
            points: [start.point, end.point],
            color: _getColorForSpeed(end.speed),
            width: 5,
          ));
        }
      }
      _markers.add(Annotation(
        annotationId: AnnotationId('my_start_position'),
        position: widget.myRoutePoints.first.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueGreen),
      ));
      _markers.add(Annotation(
        annotationId: AnnotationId('my_end_position'),
        position: widget.myRoutePoints.last.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // 상대방 경로
    if (hasOpponentRoute) {
      final points = widget.opponentRoutePoints!;
      if (points.length >= 2) {
        for (int i = 0; i < points.length - 1; i++) {
          final start = points[i];
          final end = points[i + 1];
          _polylines.add(Polyline(
            polylineId: PolylineId('opponent_route_segment_$i'),
            points: [start.point, end.point],
            color: Colors.deepOrangeAccent,
            width: 5,
          ));
        }
      }
      _markers.add(Annotation(
        annotationId: AnnotationId('opponent_start_position'),
        position: points.first.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueYellow),
      ));
      _markers.add(Annotation(
        annotationId: AnnotationId('opponent_end_position'),
        position: points.last.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueViolet),
      ));
    }
  }

  /// 3. 지도 카메라 (변경 없음)
  void _onMapCreated(AppleMapController controller) {
    _mapController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapController == null) return;

      final List<LatLng> allPoints = [];
      if (widget.myRoutePoints.length >= 2) {
        allPoints.addAll(widget.myRoutePoints.map((dp) => dp.point));
      }
      if (widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty) {
        allPoints.addAll(widget.opponentRoutePoints!.map((dp) => dp.point));
      }

      if (allPoints.isEmpty) return;

      double minLat = allPoints.first.latitude, maxLat = allPoints.first.latitude;
      double minLng = allPoints.first.longitude, maxLng = allPoints.first.longitude;
      for (var point in allPoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ), 60.0,
        ),
      );
    });
  }

  /// 4. 스낵바 (변경 없음)
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 5. 공유 기능
  Future<void> _shareRunResult() async {
    if (_isSharing) return;
    if (widget.myRoutePoints.isEmpty) {
      _showCustomSnackBar('경로가 없어 공유할 수 없습니다.', isError: true);
      return;
    }
    setState(() { _isSharing = true; });
    try {
      RenderRepaintBoundary boundary = _shareBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/rundventure_battle_result.png').create();
      await file.writeAsBytes(pngBytes);
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '런드벤처에서 친구와의 대결 완료! 🏃💨');
    } catch (e) {
      _showCustomSnackBar('공유 중 오류가 발생했습니다.', isError: true);
    } finally {
      if (mounted) setState(() { _isSharing = false; });
    }
  }

  /// 6. 기록 저장 기능
  Future<void> _saveRunningData() async {
    if (!mounted || _myEmail == null) return;
    setState(() { _isSaving = true; });

    final _firestore = FirebaseFirestore.instance;
    final String email = _myEmail!;
    final Timestamp runTimestamp = Timestamp.now();

    try {
      WriteBatch batch = _firestore.batch();

      // 1. 'records' 서브컬렉션 갱신
      final battleRecordDocRef = _firestore
          .collection('friendBattles')
          .doc(widget.battleId)
          .collection('records')
          .doc(email);

      batch.update(battleRecordDocRef, {
        'isWinner': _isWinner,
        'isDraw': _isDraw,
      });

      // 2. 전적 업데이트
      final userRef = _firestore.collection('users').doc(email);

      if (_isDraw) {
        batch.update(userRef, { 'battleDraws': FieldValue.increment(1) });
      } else {
        batch.update(userRef, {
          'battleWins': FieldValue.increment(_isWinner ? 1 : 0),
          'battleLosses': FieldValue.increment(_isWinner ? 0 : 1),
        });
      }

      // 3. 메인 문서 최종 업데이트 (중단된 경우가 아니면 status 'finished'로 확정)
      // 중단된 경우('cancelled')에는 이미 status가 'cancelled'이므로 건드리지 않음
      if (!_isCancelled) {
        final battleDocRef = _firestore.collection('friendBattles').doc(widget.battleId);
        batch.update(battleDocRef, {
          'status': 'finished',
          'updatedAt': runTimestamp,
          'isDraw': _isDraw,
        });
      }

      await batch.commit();
      _showCustomSnackBar('대결 기록이 저장되었습니다!');

      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => FriendBattleListScreen())
      );

    } catch (e) {
      _showCustomSnackBar('저장 중 오류가 발생했습니다: ${e.toString()}', isError: true);
    } finally {
      if (mounted) { setState(() { _isSaving = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_myEmail == null || !_myInfo.containsKey('nickname')) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    bool hasAnyRoute = widget.myRoutePoints.isNotEmpty || (widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty);

    return Stack(
      children: [
        // 공유용 위젯 (화면 밖)
        Positioned(
          top: -2000,
          left: 0,
          child: RepaintBoundary(
            key: _shareBoundaryKey,
            child: _buildShareableCard(widget.myRoutePoints.map((dp) => dp.point).toList()),
          ),
        ),

        // 메인 UI
        WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              automaticallyImplyLeading: false,
              title: Text(_isCancelled ? '중단된 대결' : '대결 결과', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              actions: [
                _isSharing
                    ? Padding(padding: const EdgeInsets.all(14.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(icon: Icon(Icons.ios_share, color: Colors.black), onPressed: _shareRunResult),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // 승/패/기권 헤더
                  _buildResultHeader(),
                  SizedBox(height: 16),

                  // 지도
                  if (hasAnyRoute)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => BattleMapDetailScreen(
                                myRoutePoints: widget.myRoutePoints,
                                opponentRoutePoints: widget.opponentRoutePoints,
                              ),
                            ));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 4))],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  AppleMap(
                                    onMapCreated: _onMapCreated,
                                    initialCameraPosition: CameraPosition(
                                        target: (widget.myRoutePoints.isNotEmpty
                                            ? widget.myRoutePoints.first.point
                                            : widget.opponentRoutePoints!.first.point),
                                        zoom: 15.0
                                    ),
                                    polylines: _polylines,
                                    annotations: _markers,
                                    myLocationEnabled: false,
                                    myLocationButtonEnabled: false,
                                    zoomGesturesEnabled: true,
                                    scrollGesturesEnabled: true,
                                  ),
                                  _buildLegend(),
                                  Center(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('탭하여 자세히 보기', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('기록된 경로 데이터가 없습니다.\n(기권 또는 초기 종료)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600]))),
                        ),
                      ),
                    ),

                  // 기록 비교
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildStatsComparison(),
                  ),

                  // 내 상세 기록
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('내 상세 기록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        SizedBox(height: 16),
                        _buildDetailStatGrid(),
                      ],
                    ),
                  )
                ],
              ),
            ),

            // 하단 버튼
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 기권 상태이거나 히스토리에서 왔으면 '뒤로가기'만 표시
                  if (_isCancelled || widget.isFromHistory)
                    TextButton(
                      onPressed: () { Navigator.pop(context); },
                      child: Text('뒤로가기', style: TextStyle(color: Colors.grey[700], fontSize: 15)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveRunningData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2))
                          : Text('기록 저장하고 목록으로', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultHeader() {
    // 1. 취소(중단)된 경우 UI
    if (_isCancelled) {
      final String title = _didIQuit ? "기권패" : "기권승";
      final String subtitle = _didIQuit ? "대결을 중단했습니다." : "상대방이 대결을 중단했습니다.";
      final Color color = _didIQuit ? Colors.redAccent : Colors.green;
      final IconData icon = _didIQuit ? Icons.cancel_presentation : Icons.check_circle_outline;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 48),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color, letterSpacing: 2.0),
            ),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 16, color: Colors.black54)),
          ],
        ),
      );
    }

    // 2. 정상 종료된 경우 UI
    int diffMs = (_myInfo['timeMs'] - _opponentInfo['timeMs']).abs() as int;
    String diffStr = (diffMs / 1000).toStringAsFixed(2);
    String reason = "";

    if (_opponentInfo['timeMs'] == 0) {
      reason = "상대방 기록 없음";
    } else if (_isDraw) {
      reason = "완벽한 동점!";
    } else {
      reason = "$diffStr초 차이로 ${_isWinner ? '승리!' : '패배.'}";
    }

    if (_isDraw) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Icon(Icons.handshake, color: Colors.indigo, size: 48),
            SizedBox(height: 12),
            Text('무승부', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo, letterSpacing: 2.0)),
            SizedBox(height: 4),
            Text('놀랍습니다! $reason', style: TextStyle(fontSize: 16, color: Colors.black54)),
          ],
        ),
      );
    }

    final bool isWinner = _isWinner;
    final Color color = isWinner ? Colors.blueAccent : Colors.redAccent;
    final IconData icon = isWinner ? Icons.emoji_events_outlined : Icons.heart_broken_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          SizedBox(height: 12),
          Text(
            isWinner ? '승리!' : '패배',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color, letterSpacing: 2.0),
          ),
          SizedBox(height: 4),
          Text(reason, style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// (UI) 기록 비교 위젯
  Widget _buildStatsComparison() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4)) ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatarColumn(_myInfo['nickname'], _myInfo['profileUrl'], _isDraw ? Colors.indigo : Colors.blueAccent),
              Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[400])),
              _buildAvatarColumn(_opponentInfo['nickname'], _opponentInfo['profileUrl'], Colors.grey[600]),
            ],
          ),
          SizedBox(height: 16),
          Divider(),
          SizedBox(height: 8),

          _buildComparisonRow(
              '시간',
              formatTimeWithMs(_myInfo['timeMs']),
              formatTimeWithMs(_opponentInfo['timeMs']),
              _isCancelled ? null : (_isDraw ? null : _myInfo['timeMs'] <= _opponentInfo['timeMs'])
          ),

          _buildComparisonRow(
              '평균 페이스',
              formatPace(_myInfo['pace']),
              formatPace(_opponentInfo['pace']),
              _isCancelled ? null : (_isDraw ? null : _myInfo['pace'] <= _opponentInfo['pace'])
          ),
          _buildComparisonRow(
            '거리',
            '${_myInfo['distance'].toStringAsFixed(2)} km',
            '${_opponentInfo['distance'].toStringAsFixed(2)} km',
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarColumn(String nickname, String? profileUrl, Color? color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          backgroundImage: (profileUrl != null && profileUrl.isNotEmpty) ? NetworkImage(profileUrl) : null,
          child: (profileUrl == null || profileUrl.isEmpty) ? Icon(Icons.person, size: 30, color: Colors.grey[600]) : null,
        ),
        SizedBox(height: 8),
        Text(nickname, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildComparisonRow(String label, String myValue, String opValue, bool? isMyWinner) {
    Color myColor, opColor;
    if (isMyWinner == null) {
      myColor = Colors.black87;
      opColor = Colors.black87;
    } else if (isMyWinner) {
      myColor = Colors.blueAccent;
      opColor = Colors.grey[600]!;
    } else {
      myColor = Colors.black87;
      opColor = Colors.redAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14))),
          Expanded(flex: 3, child: Text(myValue, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: myColor))),
          Expanded(flex: 3, child: Text(opValue, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: opColor))),
        ],
      ),
    );
  }

  Widget _buildDetailStatGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildStatGridItem('칼로리', '${_myInfo['calories'].toStringAsFixed(0)} kcal'),
        _buildStatGridItem('걸음수', '${_myInfo['stepCount']}'),
        _buildStatGridItem('고도', '${_myInfo['elevation'].toStringAsFixed(0)} m'),
        _buildStatGridItem('평균 속도', '${_myInfo['avgSpeed'].toStringAsFixed(1)} km/h'),
      ],
    );
  }

  Widget _buildStatGridItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2)) ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildShareableCard(List<LatLng> latLngPoints) {
    final double distance = _myInfo['distance'];
    final String myTimeStr = formatTimeWithMs(_myInfo['timeMs']);
    final String opTimeStr = formatTimeWithMs(_opponentInfo['timeMs']);

    String resultText = "";
    Color resultColor = Colors.black;

    if (_isCancelled) {
      resultText = _didIQuit ? "기권패" : "기권승";
      resultColor = _didIQuit ? Colors.redAccent : Colors.green;
    } else if (_isDraw) {
      resultText = "무승부";
      resultColor = Colors.indigo;
    } else {
      resultText = _isWinner ? "승리!" : "패배";
      resultColor = _isWinner ? Colors.blueAccent : Colors.redAccent;
    }

    LatLngBounds bounds = LatLngBounds(southwest: LatLng(0,0), northeast: LatLng(0,0));
    if(latLngPoints.length >= 2) {
      double minLat = latLngPoints.map((p) => p.latitude).reduce(math.min);
      double maxLat = latLngPoints.map((p) => p.latitude).reduce(math.max);
      double minLng = latLngPoints.map((p) => p.longitude).reduce(math.min);
      double maxLng = latLngPoints.map((p) => p.longitude).reduce(math.max);
      bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    }

    return Container(
      width: 450,
      height: 800,
      color: Colors.white,
      child: Stack(
        children: [
          if (latLngPoints.length >= 2)
            CustomPaint(
              size: Size(450, 800),
              painter: RoutePainter(points: latLngPoints, bounds: bounds),
            ),

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
                    '친구 대결 결과',
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
                            Text(_myInfo['nickname'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent, decoration: TextDecoration.none), overflow: TextOverflow.ellipsis),
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
                            Text(_opponentInfo['nickname'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent, decoration: TextDecoration.none), overflow: TextOverflow.ellipsis),
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
                    resultText,
                    style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: resultColor, decoration: TextDecoration.none, letterSpacing: 1.5),
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
                    child: Text("${distance.toStringAsFixed(2)} km 러닝", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800], decoration: TextDecoration.none)),
                  ),
                  SizedBox(height: 20),
                  Text("RUNDVENTURE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.0, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('속도 (km/h)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
            SizedBox(height: 5),
            _buildLegendItem(Colors.blue.shade700, '< 4'),
            _buildLegendItem(Colors.green.shade600, '4 ~ 8'),
            _buildLegendItem(Colors.orange.shade700, '8 ~ 12'),
            _buildLegendItem(Colors.red.shade600, '> 12'),
            SizedBox(height: 2),
            _buildLegendItem(Colors.deepOrangeAccent, '상대방'),
          ],
        ),
      ),
    );
  }
  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  // --- 헬퍼 함수 ---

  String formatPace(double pace) {
    if (pace <= 0.0 || !pace.isFinite) return "--'--''";
    int minutes = pace.floor();
    int seconds = ((pace - minutes) * 60).round();
    if (seconds == 60) { minutes++; seconds = 0; }
    return '${minutes}\'${seconds.toString().padLeft(2, '0')}\'\'';
  }

  String formatTimeWithMs(int totalMs) {
    if (totalMs == 0) return "--:--.--";
    final int totalSeconds = totalMs ~/ 1000;
    final int ms = (totalMs % 1000) ~/ 10; // 2자리 (0~99)
    final int minutes = (totalSeconds ~/ 60) % 60;
    final int hours = totalSeconds ~/ 3600;
    final int seconds = totalSeconds % 60;

    String msStr = ms.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$msStr';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$msStr';
    }
  }

  Color _getColorForSpeed(double speed) {
    double speedKmh = speed * 3.6;
    if (speedKmh < 4) return Colors.blue.shade700;
    else if (speedKmh < 8) return Colors.green.shade600;
    else if (speedKmh < 12) return Colors.orange.shade700;
    else return Colors.red.shade600;
  }
}


// --- 헬퍼 클래스 (RoutePainter) --- (변경 없음)
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

// 상세 지도 보기 화면 (변경 없음)
class BattleMapDetailScreen extends StatefulWidget {
  final List<RouteDataPoint> myRoutePoints;
  final List<RouteDataPoint>? opponentRoutePoints;

  const BattleMapDetailScreen({
    Key? key,
    required this.myRoutePoints,
    this.opponentRoutePoints,
  }) : super(key: key);

  @override
  _BattleMapDetailScreenState createState() => _BattleMapDetailScreenState();
}

class _BattleMapDetailScreenState extends State<BattleMapDetailScreen> {
  AppleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Annotation> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMapDisplay();
  }

  void _updateMapDisplay() {
    _polylines.clear();
    _markers.clear();

    bool hasMyRoute = widget.myRoutePoints.isNotEmpty;
    bool hasOpponentRoute = widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty;

    if (hasMyRoute) {
      if (widget.myRoutePoints.length >= 2) {
        for (int i = 0; i < widget.myRoutePoints.length - 1; i++) {
          final start = widget.myRoutePoints[i];
          final end = widget.myRoutePoints[i + 1];
          _polylines.add(Polyline(
            polylineId: PolylineId('my_route_segment_$i'),
            points: [start.point, end.point],
            color: _getColorForSpeed(end.speed),
            width: 5,
          ));
        }
      }
      _markers.add(Annotation(
        annotationId: AnnotationId('my_start_position'),
        position: widget.myRoutePoints.first.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueGreen),
      ));
      _markers.add(Annotation(
        annotationId: AnnotationId('my_end_position'),
        position: widget.myRoutePoints.last.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueRed),
      ));
    }

    if (hasOpponentRoute) {
      final points = widget.opponentRoutePoints!;
      if (points.length >= 2) {
        for (int i = 0; i < points.length - 1; i++) {
          final start = points[i];
          final end = points[i + 1];
          _polylines.add(Polyline(
            polylineId: PolylineId('opponent_route_segment_$i'),
            points: [start.point, end.point],
            color: Colors.deepOrangeAccent,
            width: 5,
          ));
        }
      }
      _markers.add(Annotation(
        annotationId: AnnotationId('opponent_start_position'),
        position: points.first.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueYellow),
      ));
      _markers.add(Annotation(
        annotationId: AnnotationId('opponent_end_position'),
        position: points.last.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueViolet),
      ));
    }
  }

  void _onMapCreated(AppleMapController controller) {
    _mapController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapController == null) return;

      final List<LatLng> allPoints = [];
      if (widget.myRoutePoints.length >= 2) {
        allPoints.addAll(widget.myRoutePoints.map((dp) => dp.point));
      }
      if (widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty) {
        allPoints.addAll(widget.opponentRoutePoints!.map((dp) => dp.point));
      }

      if (allPoints.isEmpty) return;

      double minLat = allPoints.first.latitude, maxLat = allPoints.first.latitude;
      double minLng = allPoints.first.longitude, maxLng = allPoints.first.longitude;
      for (var point in allPoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ), 60.0,
        ),
      );
    });
  }

  Color _getColorForSpeed(double speed) {
    double speedKmh = speed * 3.6;
    if (speedKmh < 4) return Colors.blue.shade700;
    else if (speedKmh < 8) return Colors.green.shade600;
    else if (speedKmh < 12) return Colors.orange.shade700;
    else return Colors.red.shade600;
  }

  Widget _buildLegend() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('속도 (km/h)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
            SizedBox(height: 5),
            _buildLegendItem(Colors.blue.shade700, '< 4'),
            _buildLegendItem(Colors.green.shade600, '4 ~ 8'),
            _buildLegendItem(Colors.orange.shade700, '8 ~ 12'),
            _buildLegendItem(Colors.red.shade600, '> 12'),
            SizedBox(height: 2),
            _buildLegendItem(Colors.deepOrangeAccent, '상대방'),
          ],
        ),
      ),
    );
  }
  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasAnyRoute = widget.myRoutePoints.isNotEmpty || (widget.opponentRoutePoints != null && widget.opponentRoutePoints!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text('경로 상세 보기', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: hasAnyRoute
          ? Stack(
        children: [
          AppleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
                target: (widget.myRoutePoints.isNotEmpty
                    ? widget.myRoutePoints.first.point
                    : widget.opponentRoutePoints!.first.point),
                zoom: 15.0
            ),
            polylines: _polylines,
            annotations: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
          ),
          _buildLegend(),
        ],
      )
          : Center(child: Text('표시할 경로 데이터가 없습니다.')),
    );
  }
}