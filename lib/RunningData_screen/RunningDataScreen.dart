import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'CustomCalendar_Dialog.dart';
import 'package:rundventure/main_screens/main_screen.dart';
import 'RunningRecords_Page.dart';
import 'Running_Goal_Setting.dart';
import 'dart:math' as math;
import 'package:rundventure/free_running/free_running_start.dart'; // RouteDataPoint 클래스를 임포트
import 'painters/running_data_painters.dart';
import 'full_screen_map_page.dart';
import 'widgets/running_data_widgets.dart';

class RunningStatsPage extends StatefulWidget {
  final String date;

  RunningStatsPage({Key? key, required this.date}) : super(key: key);

  @override
  State<RunningStatsPage> createState() => _RunningStatsPageState();
}

class _RunningStatsPageState extends State<RunningStatsPage> {
  late DateTime _selectedDate;
  bool _isCaloriesSelected = true;
  Map<String, Map<String, dynamic>?> weeklyData = {};
  Map<String, dynamic>? _selectedRecord;
  int calorieGoal = 500;
  double distanceGoal = 10.0;
  bool _isLoadingGoal = true;

  AppleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Annotation> _markers = {};
  List<RouteDataPoint> _routeDataPoints = [];

  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateFormat('yyyy-MM-dd').parse(widget.date);
    _loadGoalForDate(_selectedDate).then((_) {
      _loadWeeklyData();
    });
  }

  @override
  void dispose() {
    super.dispose();
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

    if (_routeDataPoints.isEmpty) {
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
      await Share.shareXFiles([xFile], text: '런드벤처에서 러닝 기록을 확인해보세요! 🏃💨');
    } catch (e) {
      print('공유 오류: $e');
      if (mounted) {
        _showCustomSnackBar('결과를 공유하는 중 오류가 발생했습니다.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() { _isSharing = false; });
      }
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // Check mounted
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
        backgroundColor: isError ? Colors.redAccent.shade400 : Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _loadGoalForDate(DateTime date) async {
    setState(() {
      _isLoadingGoal = true;
    });

    String userEmail = FirebaseAuth.instance.currentUser!.email!;
    String formattedDate = DateFormat('yyyy-MM-dd').format(date);

    try {
      DocumentSnapshot goalSnapshot = await FirebaseFirestore.instance
          .collection('userRunningData')
          .doc(userEmail)
          .collection('goals')
          .doc(formattedDate)
          .get();

      if (goalSnapshot.exists) {
        Map<String, dynamic> data = goalSnapshot.data() as Map<String, dynamic>;
        setState(() {
          calorieGoal = data['calorieGoal'] ?? 500;
          distanceGoal = (data['distanceGoal'] ?? 10.0).toDouble();
          _isLoadingGoal = false;
        });
        return;
      }

      DocumentSnapshot oldGoalSnapshot = await FirebaseFirestore.instance
          .collection('userRunningGoals')
          .doc(userEmail)
          .collection('dailyGoals')
          .doc(formattedDate)
          .get();

      if (oldGoalSnapshot.exists) {
        Map<String, dynamic> data = oldGoalSnapshot.data() as Map<String, dynamic>;
        setState(() {
          calorieGoal = data['calorieGoal'] ?? 500;
          distanceGoal = (data['distanceGoal'] ?? 10.0).toDouble();
          _isLoadingGoal = false;
        });
        await _syncGoalToAllPaths(calorieGoal, distanceGoal, formattedDate);
        return;
      }

      DocumentSnapshot userDataSnapshot = await FirebaseFirestore.instance
          .collection('userRunningData')
          .doc(userEmail)
          .get();

      if (userDataSnapshot.exists) {
        Map<String, dynamic>? userData = userDataSnapshot.data() as Map<String, dynamic>?;
        if (userData != null && userData.containsKey('goals')) {
          Map<String, dynamic> goals = userData['goals'] as Map<String, dynamic>;
          setState(() {
            calorieGoal = goals['calorieGoal'] ?? 500;
            distanceGoal = (goals['distanceGoal'] ?? 10.0).toDouble();
            _isLoadingGoal = false;
          });
          await _syncGoalToAllPaths(calorieGoal, distanceGoal, formattedDate);
          return;
        }
      }

      setState(() {
        calorieGoal = 500;
        distanceGoal = 10.0;
        _isLoadingGoal = false;
      });

    } catch (e) {
      print("Error loading goal: $e");
      setState(() {
        calorieGoal = 500;
        distanceGoal = 10.0;
        _isLoadingGoal = false;
      });
    }
  }

  Future<void> _syncGoalToAllPaths(int calories, double distance, String dateKey) async {
    try {
      String userEmail = FirebaseAuth.instance.currentUser!.email!;
      await FirebaseFirestore.instance
          .collection('userRunningData')
          .doc(userEmail)
          .collection('goals')
          .doc(dateKey)
          .set({
        'calorieGoal': calories,
        'distanceGoal': distance,
        'goalType': distance >= calories ? 'distance' : 'calorie',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('userRunningGoals')
          .doc(userEmail)
          .collection('dailyGoals')
          .doc(dateKey)
          .set({
        'calorieGoal': calories,
        'distanceGoal': distance,
        'goalType': distance >= calories ? 'distance' : 'calorie',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('userRunningData')
          .doc(userEmail)
          .set({
        'goals': {
          'calorieGoal': calories,
          'distanceGoal': distance,
          'goalType': distance >= calories ? 'distance' : 'calorie',
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

    } catch (e) {
      print("Error syncing goals: $e");
    }
  }

  Future<Map<String, dynamic>?> _fetchRunningData(String date) async {
    try {
      String userEmail = FirebaseAuth.instance.currentUser!.email!;
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('userRunningData')
          .doc(userEmail)
          .collection('workouts')
          .doc(date)
          .get();

      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error fetching data: $e");
      return null;
    }
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _loadWeeklyData() async {
    DateTime startOfWeek = _getStartOfWeek(_selectedDate);
    String userEmail = FirebaseAuth.instance.currentUser!.email!;

    // 1. 7일치 데이터 요청을 담을 Future 리스트를 생성합니다.
    List<Future<Map<String, dynamic>>> futures = [];

    for (int i = 0; i < 7; i++) {
      DateTime currentDate = startOfWeek.add(Duration(days: i));
      String formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);

      // 2. 각 날짜의 데이터(운동, 목표)를 가져오는 비동기 작업을 Future로 만듭니다.
      //    await을 사용하지 않고 Future 자체를 리스트에 추가합니다.
      final dailyDataFuture = () async {
        // 운동 데이터와 목표 데이터를 동시에 가져오도록 요청을 병렬화합니다.
        final results = await Future.wait([
          _fetchRunningData(formattedDate),
          FirebaseFirestore.instance
              .collection('userRunningData')
              .doc(userEmail)
              .collection('goals')
              .doc(formattedDate)
              .get(),
          FirebaseFirestore.instance // 이전 경로 목표 데이터도 동시에 요청
              .collection('userRunningGoals')
              .doc(userEmail)
              .collection('dailyGoals')
              .doc(formattedDate)
              .get(),
        ]);

        final workoutData = results[0] as Map<String, dynamic>?;
        final goalSnapshot = results[1] as DocumentSnapshot;
        final oldGoalSnapshot = results[2] as DocumentSnapshot;

        Map<String, dynamic>? goalData;
        if (goalSnapshot.exists) {
          goalData = goalSnapshot.data() as Map<String, dynamic>;
        } else if (oldGoalSnapshot.exists) {
          goalData = oldGoalSnapshot.data() as Map<String, dynamic>;
        }

        // 각 Future가 완료되었을 때 반환할 데이터 구조
        return {
          'formattedDate': formattedDate,
          'workoutData': workoutData,
          'goalData': goalData,
        };
      }();

      futures.add(dailyDataFuture);
    }

    // 3. Future.wait를 사용해 모든 데이터 요청이 완료될 때까지 한 번만 기다립니다.
    final List<Map<String, dynamic>> weeklyResults = await Future.wait(futures);

    // 4. 모든 데이터가 준비되면 weeklyData 맵을 만들고 UI를 갱신합니다.
    Map<String, Map<String, dynamic>?> newWeeklyData = {};
    for (var result in weeklyResults) {
      newWeeklyData[result['formattedDate']] = {
        'data': result['workoutData'],
        'goal': result['goalData'],
      };
    }

    // 5. setState를 마지막에 한 번만 호출하여 UI를 갱신합니다.
    if (mounted) {
      setState(() {
        weeklyData = newWeeklyData;
      });
    }
  }

  void _onMapCreated(AppleMapController controller) {
    _mapController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveCameraToBounds();
    });
  }

  void _updateMapDisplay() {
    _polylines.clear();
    _markers.clear();

    if (_routeDataPoints.isEmpty) return;

    if (_routeDataPoints.length >= 2) {
      for (int i = 0; i < _routeDataPoints.length - 1; i++) {
        final start = _routeDataPoints[i];
        final end = _routeDataPoints[i + 1];
        _polylines.add(Polyline(
          polylineId: PolylineId('route_segment_$i'),
          points: [start.point, end.point],
          color: _getColorForSpeed(end.speed),
          width: 5,
        ));
      }
    }

    _markers.add(
      Annotation(
        annotationId: AnnotationId('start_position'),
        position: _routeDataPoints.first.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    _markers.add(
      Annotation(
        annotationId: AnnotationId('end_position'),
        position: _routeDataPoints.last.point,
        icon: BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  void _moveCameraToBounds() async {
    if (_routeDataPoints.length < 2 || _mapController == null) return;

    final points = _routeDataPoints.map((dp) => dp.point).toList();

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    if (minLat == maxLat) {
      maxLat += 0.001;
      minLat -= 0.001;
    }
    if (minLng == maxLng) {
      maxLng += 0.001;
      minLng -= 0.001;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60.0,
      ),
    );
  }

  Widget _buildWeekDay(String day, bool isComplete) {
    int dayIndex = ['월', '화', '수', '목', '금', '토', '일'].indexOf(day);
    DateTime dayDate = _getStartOfWeek(_selectedDate).add(Duration(days: dayIndex));
    String formattedDayDate = DateFormat('yyyy-MM-dd').format(dayDate);

    final dayInfo = weeklyData[formattedDayDate];
    final dayData = dayInfo?['data'];
    final goalData = dayInfo?['goal'];
    bool hasData = dayData != null;

    double value = 0.0;
    double goal = 1.0;
    if (hasData) {
      if (_isCaloriesSelected) {
        value = (dayData['calories'] ?? 0).toDouble();
        goal = (goalData?['calorieGoal'] ?? calorieGoal).toDouble();
      } else {
        value = (dayData['kilometers'] ?? 0).toDouble();
        goal = (goalData?['distanceGoal'] ?? distanceGoal).toDouble();
      }
    }

    double progress = (goal > 0) ? (value / goal).clamp(0.0, 1.0) : 0.0;
    final double deviceWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedDate = dayDate;
          _selectedRecord = null;
        });
        await _loadGoalForDate(dayDate);
        await _loadWeeklyData();
      },
      child: Column(
        children: [
          Text(day, style: TextStyle(color: hasData ? Colors.deepOrange : Colors.grey, fontSize: deviceWidth * 0.04)),
          SizedBox(height: deviceWidth * 0.02),
          Stack(
            alignment: Alignment.center,
            children: [
              if (hasData)
                SizedBox(
                  width: deviceWidth * 0.08,
                  height: deviceWidth * 0.08,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              Center(
                child: Container(
                  width: deviceWidth * 0.07,
                  height: deviceWidth * 0.08,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSameDay(dayDate, _selectedDate) ? Colors.deepOrange.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(color: hasData ? Colors.deepOrange : Colors.grey[300]!, width: hasData ? 2 : 1),
                  ),
                  child: hasData ? Center(child: Text(_isCaloriesSelected ? '${value.round()}' : value.toStringAsFixed(1), style: TextStyle(fontSize: deviceWidth * 0.022, color: Colors.deepOrange, fontWeight: FontWeight.bold))) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final double deviceWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,

        leadingWidth: 80,

        leading: Center(
          child: InkWell(
            onTap: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen()));
            },
            customBorder: CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: SizedBox(
                width: 55,
                height: 50,
                child: Image.asset(
                  'assets/images/Back-Navs.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),

        title: Text(
          DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(_selectedDate),
          style: TextStyle(
            color: Colors.black,
            fontSize: deviceWidth * 0.04,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          _isSharing
              ? SizedBox(width: 44, height: 44, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0))))
              : IconButton(
            icon: Icon(Icons.ios_share, size: 20, color: Colors.black),
            onPressed: _shareRunResult,
          ),
          IconButton(
            icon: Icon(Icons.calendar_today, size: 20, color: Colors.black),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) => CustomCalendarDialog(
                  selectedDate: _selectedDate,
                  onDateSelected: (DateTime date) {
                    setState(() {
                      _selectedDate = date;
                      _selectedRecord = null;
                    });
                    _loadGoalForDate(date).then((_) => _loadWeeklyData());
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoadingGoal
            ? Center(child: CircularProgressIndicator())
            : FutureBuilder<Map<String, dynamic>?>(
          future: _fetchRunningData(formattedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('데이터를 불러오는 데 오류가 발생했습니다.'));
            } else {
              final selectedData = _selectedRecord ?? snapshot.data ?? {
                'calories': 0, 'pace': 0.0, 'seconds': 0, 'elevation': 0,
                'averageSpeed': 0.0, 'kilometers': 0.0, 'stepCount': 0,
              };

              _routeDataPoints.clear();
              if (selectedData.containsKey('routePointsWithSpeed') && selectedData['routePointsWithSpeed'] is List) {
                final pointsList = selectedData['routePointsWithSpeed'] as List;
                if (pointsList.isNotEmpty) {
                  _routeDataPoints = pointsList.map((p) {
                    return RouteDataPoint(
                      point: LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()),
                      speed: (p['speed'] as num?)?.toDouble() ?? 0.0,
                    );
                  }).toList();
                }
              }

              _updateMapDisplay();

              final double progressValue = _isCaloriesSelected
                  ? (selectedData['calories'] as num).toDouble() / calorieGoal
                  : (selectedData['kilometers'] as num).toDouble() / distanceGoal;

              return Stack(
                children: [
                  Positioned(
                    top: -2000,
                    left: 0,
                    child: RepaintBoundary(
                      key: _shareBoundaryKey,
                      child: RunningShareableCard(data: selectedData, latLngPoints: _routeDataPoints.map((dp) => dp.point).toList()),
                    ),
                  ),
                  ListView(
                    physics: ClampingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 20.0),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0, left: 20.0, right: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildWeekDay('월', false), _buildWeekDay('화', false),
                            _buildWeekDay('수', false), _buildWeekDay('목', false),
                            _buildWeekDay('금', false), _buildWeekDay('토', false),
                            _buildWeekDay('일', false),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      Center(
                        child: SizedBox(
                          width: math.min(deviceWidth * 0.6, 230),
                          height: math.min(deviceWidth * 0.6, 230),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform(
                                transform: Matrix4.rotationX(0.2),
                                alignment: Alignment.center,
                                child: CustomPaint(
                                  painter: ThreeDProgressPainter(progress: progressValue.clamp(0.0, 1.5)),
                                  size: Size(deviceWidth * 0.6, deviceWidth * 0.6),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => GoalSettingPage(
                                            initialCalorieGoal: calorieGoal,
                                            initialDistanceGoal: distanceGoal,
                                            selectedDate: _selectedDate,
                                          ),
                                        ),
                                      );
                                      if (result is Map<String, dynamic>) {
                                        setState(() {
                                          calorieGoal = result['calorieGoal'];
                                          distanceGoal = result['distanceGoal'];
                                        });
                                        String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
                                        await _syncGoalToAllPaths(calorieGoal, distanceGoal, formattedDate);
                                        await _loadWeeklyData();
                                      }
                                    },
                                    icon: Icon(Icons.flag, color: Colors.deepOrange, size: 16),
                                    label: Text('목표 설정', style: TextStyle(fontSize: 13, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.deepOrange,
                                      backgroundColor: Colors.deepOrange.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: deviceWidth * 0.05, vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () { setState(() { _isCaloriesSelected = true; }); },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isCaloriesSelected ? Colors.deepOrange : Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: Text('칼로리', style: TextStyle(color: _isCaloriesSelected ? Colors.white : Colors.black, fontSize: deviceWidth * 0.035)),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () { setState(() { _isCaloriesSelected = false; }); },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: !_isCaloriesSelected ? Colors.deepOrange : Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: Text('거리', style: TextStyle(color: !_isCaloriesSelected ? Colors.white : Colors.black, fontSize: deviceWidth * 0.035)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: deviceWidth * 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_isCaloriesSelected ? '목표 칼로리' : '목표 거리', style: TextStyle(color: Colors.grey[600], fontSize: deviceWidth * 0.038)),
                                      SizedBox(height: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: _isCaloriesSelected ? '${(selectedData['calories'] as num).round()}' : '${(selectedData['kilometers'] as num).toStringAsFixed(2)}',
                                                style: TextStyle(color: Colors.black, fontSize: 40, fontWeight: FontWeight.w900),
                                              ),
                                              TextSpan(
                                                text: _isCaloriesSelected ? '/$calorieGoal' : '/${distanceGoal.toStringAsFixed(0)}',
                                                style: TextStyle(color: Colors.grey, fontSize: 32, fontWeight: FontWeight.bold),
                                              ),
                                              TextSpan(
                                                text: _isCaloriesSelected ? ' KCAL' : ' KM',
                                                style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  flex: 1,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final selectedRecord = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => RunningRecordsPage(date: formattedDate)),
                                      );
                                      if (selectedRecord is Map<String, dynamic>) {
                                        setState(() { _selectedRecord = selectedRecord; });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepOrange,
                                      padding: EdgeInsets.symmetric(horizontal: deviceWidth * 0.02, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('기록 보기', style: TextStyle(color: Colors.white, fontSize: deviceWidth * 0.035)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_routeDataPoints.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 25.0, bottom: 10.0),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(
                                          builder: (context) => FullScreenMapPage(routeDataPoints: _routeDataPoints)
                                      ));
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: Offset(0, 4))],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AbsorbPointer(
                                          child: AppleMap(
                                            onMapCreated: _onMapCreated,
                                            initialCameraPosition: CameraPosition(
                                              target: _routeDataPoints.first.point,
                                              zoom: 15.0,
                                            ),
                                            polylines: _polylines,
                                            annotations: _markers,
                                            myLocationButtonEnabled: false,
                                            zoomGesturesEnabled: false,
                                            scrollGesturesEnabled: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              SizedBox(height: 15),
                            Column(
                              children: [
                                RunningDetailStatCard(label: '평균 페이스', value: '${formatRunningPace((selectedData['pace'] as num).toDouble())}/KM'),
                                RunningDetailStatCard(label: '시간', value: formatRunningDuration((selectedData['seconds'] as num).toInt())),
                                RunningDetailStatCard(label: 
                                  _isCaloriesSelected ? '거리' : '칼로리', value: _isCaloriesSelected
                                      ? '${(selectedData['kilometers'] as num).toStringAsFixed(2)} KM'
                                      : '${(selectedData['calories'] as num).round()} KCAL',
                                ),
                                RunningDetailStatCard(label: '고도', value: '${(selectedData['elevation'] as num?)?.toDouble().toStringAsFixed(1) ?? "0.0"} M'),
                                RunningDetailStatCard(label: '걸음수', value: '${(selectedData['stepCount'] as num?)?.toInt() ?? 0}'),
                                RunningDetailStatCard(label: '평균 속도', value: '${(selectedData['averageSpeed'] as num).toStringAsFixed(1)} KM/H'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

