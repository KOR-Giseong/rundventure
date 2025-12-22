import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rundventure/RunningData_screen/RunningDataScreen.dart';
import 'package:rundventure/free_running/settings_page.dart';
import 'dart:async';
import 'dart:math';
import 'package:rundventure/main_screens/main_screen.dart';
import 'package:location/location.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rundventure/free_running/free_running_start.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FreeRunningPage extends StatefulWidget {
  final double kilometers;
  final int seconds;
  final double pace;
  final int bpm;
  final int stepCount;
  final double elevation;
  final double averageSpeed;
  final double calories;
  final List<RouteDataPoint> routePointsWithSpeed;

  FreeRunningPage({
    required this.kilometers,
    required this.seconds,
    required this.pace,
    required this.bpm,
    required this.stepCount,
    required this.elevation,
    required this.averageSpeed,
    required this.calories,
    required this.routePointsWithSpeed,
  });

  @override
  _FreeRunningPageState createState() => _FreeRunningPageState();
}

class _FreeRunningPageState extends State<FreeRunningPage> {
  late AppleMapController mapController;
  Set<Polyline> polylines = {};
  Set<Annotation> markers = {};
  bool _isSaving = false;
  bool _isMapReady = false;
  Location location = Location();
  StreamSubscription<LocationData>? _locationSubscription;

  final _watch = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;
  StreamSubscription<Map<String, dynamic>>? _watchContextSubscription;

  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _isSharing = false;

  bool _watchSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadWatchSyncSetting();
    _updatePolylines();
    _addEndMarker();
    _setupLocationService();
    _initializeWatchConnectivity();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _watchMessageSubscription?.cancel();
    _watchContextSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadWatchSyncSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _watchSyncEnabled = prefs.getBool('watchSyncEnabled') ?? false;
      });
      print("✅ FreeRunningPage 워치 연동 설정 로드됨: $_watchSyncEnabled");
    }
  }

  void _initializeWatchConnectivity() {
    void handleWatchCommand(Map<String, dynamic> message) {
      if (!mounted) return;
      if (message.containsKey('command')) {
        final command = message['command'] as String;
        print("✅ iPhone received command from Watch: $command");

        if (command == 'saveRunning') {
          if (!_isSaving) {
            _saveRunningData();
          }
        }
        else if (command == 'cancelRunning') {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
                  (Route<dynamic> route) => false
          );
        }
      }
    }

    _watchMessageSubscription = _watch.messageStream.listen(handleWatchCommand);
    _watchContextSubscription = _watch.contextStream.listen(handleWatchCommand);
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
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  Color _getColorForSpeed(double speed) {
    double speedKmh = speed * 3.6;
    if (speedKmh < 4) return Colors.blue.shade700;
    else if (speedKmh < 8) return Colors.green.shade600;
    else if (speedKmh < 12) return Colors.orange.shade700;
    else return Colors.red.shade600;
  }

  Future<void> _shareRunResult() async {
    if (_isSharing) return;

    if (widget.routePointsWithSpeed.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          icon: Icon(Icons.error_outline, color: Colors.orangeAccent, size: 48),
          title: Text('공유할 수 없음', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('기록된 러닝 경로가 없어 공유 기능을 사용할 수 없습니다.'),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() { _isSharing = true; });

    try {
      RenderRepaintBoundary boundary = _shareBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/rundventure_result.png').create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '런드벤에서 러닝을 완료했어요! 🏃💨');
    } catch (e) {
      print('공유 오류: $e');
      _showCustomSnackBar('결과를 공유하는 중 오류가 발생했습니다.', isError: true);
    } finally {
      if (mounted) {
        setState(() { _isSharing = false; });
      }
    }
  }

  Future<void> _setupLocationService() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) return;
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) return;
    }

    location.changeSettings(accuracy: LocationAccuracy.high, interval: 500, distanceFilter: 5);

    _locationSubscription = location.onLocationChanged.listen((LocationData currentLocation) {
      if (_isMapReady && mounted && currentLocation.latitude != null && currentLocation.longitude != null) {
        mapController.animateCamera(
          CameraUpdate.newLatLng(LatLng(currentLocation.latitude!, currentLocation.longitude!)),
        );
      }
    });
  }

  Future<void> _onMapCreated(AppleMapController controller) async {
    mapController = controller;

    final latLngPoints = widget.routePointsWithSpeed.map((dp) => dp.point).toList();

    if (latLngPoints.isNotEmpty) {
      try {
        if (latLngPoints.length >= 2) {
          double minLat = latLngPoints.map((p) => p.latitude).reduce(min);
          double maxLat = latLngPoints.map((p) => p.latitude).reduce(max);
          double minLng = latLngPoints.map((p) => p.longitude).reduce(min);
          double maxLng = latLngPoints.map((p) => p.longitude).reduce(max);

          await controller.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng)), 50.0));

        } else {
          await controller.animateCamera(CameraUpdate.newLatLngZoom(latLngPoints.first, 15));
        }
      } catch (e) {
        print('카메라 이동 오류: $e');
        if(latLngPoints.isNotEmpty) {
          await controller.animateCamera(CameraUpdate.newLatLngZoom(latLngPoints.last, 15.0));
        }
      }
    }

    if (mounted) {
      setState(() { _isMapReady = true; });
    }
  }

  void _updatePolylines() {
    polylines.clear();
    if (widget.routePointsWithSpeed.length < 2) return;

    for (int i = 0; i < widget.routePointsWithSpeed.length - 1; i++) {
      final startPoint = widget.routePointsWithSpeed[i];
      final endPoint = widget.routePointsWithSpeed[i + 1];
      final color = _getColorForSpeed(endPoint.speed);

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_segment_$i'),
          points: [startPoint.point, endPoint.point],
          color: color,
          width: 5,
        ),
      );
    }
    if(mounted) setState(() {});
  }

  void _addEndMarker() {
    if (widget.routePointsWithSpeed.isNotEmpty) {
      markers.add(Annotation(
          annotationId: AnnotationId('end_position'),
          position: widget.routePointsWithSpeed.last.point,
          infoWindow: InfoWindow(title: '종료 지점'),
          icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueRed)));
    }
  }


  Future<void> _saveRunningData() async {
    if (!mounted) return;
    setState(() { _isSaving = true; });

    final _firestore = FirebaseFirestore.instance;
    final _auth = FirebaseAuth.instance;
    final int xpPerKm = 100;

    try {
      List<Map<String, dynamic>> routePointsList = widget.routePointsWithSpeed
          .map((dataPoint) => dataPoint.toMap())
          .toList();

      String email = _auth.currentUser?.email ?? '';
      if (email == '') throw Exception("사용자 이메일을 찾을 수 없습니다.");
      String date = DateTime.now().toIso8601String().substring(0, 10);
      final Timestamp runTimestamp = Timestamp.now();

      final runningData = {
        'date': runTimestamp,
        'kilometers': widget.kilometers,
        'seconds': widget.seconds,
        'pace': widget.pace,
        'bpm': widget.bpm,
        'stepCount': widget.stepCount,
        'elevation': widget.elevation,
        'averageSpeed': widget.averageSpeed,
        'calories': widget.calories,
        'routePointsWithSpeed': routePointsList
      };

      // --- Batch 작업 시작 ---
      WriteBatch batch = _firestore.batch();

      // 1. 러닝 기록 저장 (workouts 컬렉션 - 일일 통계용)
      final workoutDocRef = _firestore.collection('userRunningData').doc(email).collection('workouts').doc(date);
      batch.set(workoutDocRef, runningData, SetOptions(merge: true));

      // 2. 러닝 기록 저장 (records 컬렉션 - 개별 기록용)
      final recordDocRef = workoutDocRef.collection('records').doc();
      batch.set(recordDocRef, {...runningData, 'timestamp': runTimestamp});

      // 3. 이번 러닝으로 얻는 경험치 계산
      final int runExp = (widget.kilometers * xpPerKm).round();

      // 4. 사용자 문서('users/{email}')의 weeklyExp/monthlyExp 필드 업데이트
      final userRef = _firestore.collection('users').doc(email);
      batch.update(userRef, {
        'weeklyExp': FieldValue.increment(runExp),
        'monthlyExp': FieldValue.increment(runExp),
      });
      print("✅ 주간/월간 경험치 업데이트: +${runExp} EXP for $email");

      // --- 챌린지 업데이트 로직 ---
      final challengesSnapshot = await _firestore
          .collection('challenges')
          .where('participants', arrayContains: email)
          .get();

      if (challengesSnapshot.docs.isNotEmpty) {
        print("참여 중인 ${challengesSnapshot.docs.length}개의 챌린지 거리 업데이트 시작...");
        for (var challengeDoc in challengesSnapshot.docs) {
          final challengeData = challengeDoc.data();
          final Timestamp? challengeStartTime = challengeData['timestamp'] as Timestamp?;
          final int durationDays = int.tryParse(challengeData['duration'] ?? '0') ?? 0;
          final Map<String, dynamic> participantMap = Map<String, dynamic>.from(challengeData['participantMap'] ?? {});

          if (challengeStartTime == null || durationDays == 0) continue;

          Timestamp? userJoinTimestamp;
          if (participantMap.containsKey(email)) {
            try {
              userJoinTimestamp = Timestamp.fromDate(DateTime.parse(participantMap[email]));
            } catch (e) {
              print(" - 챌린지 ${challengeDoc.id}의 사용자 참여 시간 파싱 오류. 건너뜀. $e");
              continue;
            }
          } else {
            continue;
          }

          final DateTime challengeEndDate = challengeStartTime.toDate().add(Duration(days: durationDays));
          final DateTime runTime = runTimestamp.toDate();

          if (runTime.isAfter(userJoinTimestamp.toDate()) && runTime.isBefore(challengeEndDate)) {
            final double targetDistance = double.tryParse(challengeData['distance'] ?? '0') ?? 0;
            final double currentTotalDistance = (challengeData['totalDistance'] as num? ?? 0.0).toDouble();
            final double newTotalDistance = currentTotalDistance + widget.kilometers;
            final double newProgress = (targetDistance > 0) ? (newTotalDistance / targetDistance).clamp(0.0, 1.0) : 0.0;

            batch.update(challengeDoc.reference, {
              'totalDistance': FieldValue.increment(widget.kilometers),
              'progress': newProgress
            });
          }
        }
      }
      // --- 챌린지 업데이트 끝 ---

      // 5. 모든 작업을 Batch로 한 번에 실행
      await batch.commit();

      _showCustomSnackBar('러닝 기록이 저장되었습니다.');

      if (_watchSyncEnabled) {
        try {
          final message = {'command': 'resetToMainMenu'};
          _watch.sendMessage(message);
          await _watch.updateApplicationContext(message);
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          // 워치가 없거나 연결되지 않아도 여기서 에러를 잡으므로 앱이 멈추지 않음
          print("⚠️ 워치 통신 실패 (설정 ON이지만 실패 - 정상 처리): $e");
        }
      }

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RunningStatsPage(date: date)));

    } catch (e) {
      print('저장 오류: $e');
      _showCustomSnackBar('저장 중 오류가 발생했습니다: ${e.toString()}', isError: true);
    } finally {
      if (mounted) { setState(() { _isSaving = false; }); }
    }
  }

  Future<void> _showCancelConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('저장을 취소하시겠습니까?'),
        content: Text('현재 기록은 저장되지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('아니오', style: TextStyle(color: Colors.blue))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('예', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (result == true && mounted) {
      if (_watchSyncEnabled) {
        try {
          final message = {'command': 'resetToMainMenu'};
          _watch.sendMessage(message);
          await _watch.updateApplicationContext(message);
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print("⚠️ 워치 통신 실패 (설정 ON이지만 실패 - 정상 처리): $e");
        }
      }

      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final latLngPoints = widget.routePointsWithSpeed.map((dp) => dp.point).toList();

    return Stack(
      children: [
        Positioned(
          top: -2000,
          left: 0,
          child: RepaintBoundary(
            key: _shareBoundaryKey,
            child: _buildShareableCard(latLngPoints),
          ),
        ),
        _buildMainContent(latLngPoints),
      ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
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
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<LatLng> latLngPoints) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 21),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _isSharing
                        ? SizedBox(width: 48, height: 48, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))))
                        : IconButton(icon: Icon(Icons.ios_share, size: 28), onPressed: _shareRunResult),
                    Text('자유러닝 결과', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage())), child: Icon(Icons.settings, size: 30)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                width: double.infinity,
                child: Stack(
                  children: [
                    AppleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(target: latLngPoints.isNotEmpty ? latLngPoints.last : LatLng(37.5665, 126.9780), zoom: 15.0),
                      polylines: polylines,
                      annotations: markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 80,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.0)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 80,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.0)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              width: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.0)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              width: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.0)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildLegend(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${widget.kilometers.toStringAsFixed(2)}KM', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                            Text(DateTime.now().toString().substring(0, 16), style: TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            _buildDetailCard('평균 페이스', formatPace(widget.pace)),
                            _buildDetailCard('걸음수', '${widget.stepCount}'),
                            _buildDetailCard('시간', formatTime(widget.seconds)),
                            _buildDetailCard('고도', '${widget.elevation.toStringAsFixed(0)} m'),
                            _buildDetailCard('칼로리', '${widget.calories.toStringAsFixed(0)} kcal'),
                            _buildDetailCard('평균 속도', '${widget.averageSpeed.toStringAsFixed(1)} km/h'),
                          ],
                        ),
                        const SizedBox(height: 25),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _showCancelConfirmationDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: BorderSide(color: Colors.black), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 16)),
                  child: Text('취소', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveRunningData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2))
                      : Text('저장', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareableCard(List<LatLng> latLngPoints) {
    final double safeKilometers = widget.kilometers.isFinite ? widget.kilometers : 0.0;
    final double safePace = widget.pace.isFinite ? widget.pace : 0.0;
    final int safeSeconds = widget.seconds;
    final double safeCalories = widget.calories.isFinite ? widget.calories : 0.0;

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
              Text(safeKilometers.toStringAsFixed(2), style: TextStyle(color: Colors.black, fontSize: 90, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              Text('킬로미터', style: TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn('평균 페이스', formatPace(safePace)),
                  _buildStatColumn('시간', formatTime(safeSeconds)),
                  _buildStatColumn('칼로리', '${safeCalories.toStringAsFixed(0)} kcal'),
                ],
              ),
              SizedBox(height: 40),
              Center(child: Text('RUNDVENTURE', style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none))),
            ],
          ),
        ),
      );
    }

    double minLat = latLngPoints.map((p) => p.latitude).reduce(min);
    double maxLat = latLngPoints.map((p) => p.latitude).reduce(max);
    double minLng = latLngPoints.map((p) => p.longitude).reduce(min);
    double maxLng = latLngPoints.map((p) => p.longitude).reduce(max);
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
            size: Size(450, 800),
            painter: RoutePainter(points: latLngPoints, bounds: bounds),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 60.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(safeKilometers.toStringAsFixed(2), style: TextStyle(color: Colors.black, fontSize: 90, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                Text('킬로미터', style: TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatColumn('평균 페이스', formatPace(safePace)),
                    _buildStatColumn('시간', formatTime(safeSeconds)),
                    _buildStatColumn('칼로리', '${safeCalories.toStringAsFixed(0)} kcal'),
                  ],
                ),
                SizedBox(height: 40),
                Center(child: Text('RUNDVENTURE', style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 18, decoration: TextDecoration.none)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
      ],
    );
  }

  Widget _buildDetailCard(String label, String value) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: Offset(0, 2))]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: deviceWidth * 0.038, color: Colors.grey[700])),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: deviceWidth * 0.045, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  String formatPace(double pace) {
    if (pace <= 0.0 || !pace.isFinite) return "--'--''";
    int minutes = pace.floor();
    int seconds = ((pace - minutes) * 60).round();
    if (seconds == 60) {
      minutes++;
      seconds = 0;
    }
    return '${minutes}\'${seconds.toString().padLeft(2, '0')}\'\'';
  }

  String formatTime(int seconds) {
    final int minutes = (seconds ~/ 60) % 60;
    final int hours = seconds ~/ 3600;
    final int remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
}

class RoutePainter extends CustomPainter {
  final List<LatLng> points;
  final LatLngBounds bounds;

  RoutePainter({required this.points, required this.bounds});

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

    final startPoint = _scalePoint(points.first, size);
    _drawCircle(canvas, startPoint, Colors.green);

    final endPoint = _scalePoint(points.last, size);
    _drawCircle(canvas, endPoint, Colors.red);
  }

  Offset _scalePoint(LatLng point, Size size) {
    double minLat = bounds.southwest.latitude;
    double maxLat = bounds.northeast.latitude;
    double minLng = bounds.southwest.longitude;
    double maxLng = bounds.northeast.longitude;

    double lngRange = maxLng - minLng;
    double latRange = maxLat - minLat;

    // Handle edge case where lat or lng range is zero to avoid division by zero
    double normalizedX = (lngRange.abs() < 0.00001) ? 0.5 : (point.longitude - minLng) / lngRange;
    double normalizedY = (latRange.abs() < 0.00001) ? 0.5 : (point.latitude - minLat) / latRange;


    double paddingX = size.width * 0.15;
    double paddingY = size.height * 0.15;
    double drawWidth = size.width - 2 * paddingX;
    double drawHeight = size.height - 2 * paddingY;
    double scaledX = paddingX + normalizedX * drawWidth;
    double scaledY = paddingY + (1 - normalizedY) * drawHeight; // Invert Y-axis for screen coordinates

    return Offset(scaledX, scaledY);
  }

  void _drawCircle(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8.0, paint);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.bounds != bounds;
  }
}