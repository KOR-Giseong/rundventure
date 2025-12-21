// [전체 코드] async_battle_running_screen.dart

import 'dart:async';
import 'dart:ui'; // FontFeature를 위해 추가
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

// --- 러닝 로직 임포트 ---
import 'package:geolocator/geolocator.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:pedometer/pedometer.dart';

// RouteDataPoint 클래스 임포트
import 'package:rundventure/free_running/free_running_start.dart';

// 스낵바 헬퍼 임포트
import 'async_battle_list_screen.dart';


class AsyncBattleRunningScreen extends StatefulWidget {
  final String battleId;
  final double targetDistanceKm;
  final bool withWatch;

  const AsyncBattleRunningScreen({
    Key? key,
    required this.battleId,
    required this.targetDistanceKm,
    this.withWatch = false,
  }) : super(key: key);

  @override
  _AsyncBattleRunningScreenState createState() => _AsyncBattleRunningScreenState();
}

class _AsyncBattleRunningScreenState extends State<AsyncBattleRunningScreen>
    with WidgetsBindingObserver {

  // ===================================================================
  // 1. 대결 상태 및 Firebase 변수
  // ===================================================================
  final String? _myEmail = FirebaseAuth.instance.currentUser?.email;
  late final double _targetDistanceKm;

  bool _isProcessing = false; // 로딩 중 상태

  // 권한 상태 변수
  String? _userRole; // 'user', 'admin', 'head_admin', 'super_admin'

  // --- 나의 러닝 상태 ---
  bool _isMyRunFinished = false; // 내가 완주했는지
  String _myStatus = 'running'; // 'running', 'paused', 'finished'
  double _myKilometers = 0.0;
  double _myPace = 0.0;

  // ▼▼▼▼▼ [ ⭐️ 수정: 정밀 측정을 위해 double로 변경 ⭐️ ] ▼▼▼▼▼
  double _mySeconds = 0.0; // 기존 int에서 double로 변경 (소수점 초 단위 저장)
  // ▲▲▲▲▲ [ ⭐️ 수정: 정밀 측정을 위해 double로 변경 ⭐️ ] ▲▲▲▲▲

  double _myElevation = 0.0;
  double _myAverageSpeed = 0.0;
  double _myCalories = 0.0;
  int _myStepCount = 0;

  String _myNickname = '알수없음';

  // ===================================================================
  // 2. 기존 RunningPage 로직 변수들
  // ===================================================================
  loc.Location location = loc.Location();
  StreamSubscription<loc.LocationData>? _locationSubscription;
  loc.LocationData? _lastLocation;
  List<RouteDataPoint> _routePointsWithSpeed = [];
  Timer? _timer;
  bool _isPaused = false;
  bool _dialogShownRecently = false; // 자동 일시정지 스로틀링
  double? _userWeight;
  bool _isLoadingUserData = true;
  DateTime? _initialStartTime;
  Duration _totalPausedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  late SharedPreferences prefs;

  // --- 워치 / 라이브 액티비티 / TTS / 만보계 ---
  final _watch = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;
  StreamSubscription<Map<String, dynamic>>? _watchContextSubscription;
  final MethodChannel _liveActivityChannel = const MethodChannel('com.rundventure/liveactivity');
  late FlutterTts flutterTts;
  int _nextKmTarget = 1;
  StreamSubscription<StepCount>? _pedometerStream;
  int _initialStepCount = -1;

  // --- 지도 관련 ---
  AppleMapController? _appleMapController;
  LatLng? _currentLocation;
  Annotation? _startMarker;
  Annotation? _endMarker;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. 대결 기본 정보 설정
    _targetDistanceKm = widget.targetDistanceKm;

    _checkUserRole(); // 권한 확인

    // 2. 러닝 초기화 및 즉시 시작
    _initializeBattle();
  }

  // 권한 확인 로직
  Future<void> _checkUserRole() async {
    if (_myEmail == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_myEmail).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'] ?? 'user';
        });
      }
    } catch (e) {
      print("권한 확인 실패: $e");
    }
  }

  /// 카운트다운 없이 즉시 러닝 시작
  Future<void> _initializeBattle() async {
    // 1. 서비스 초기화 (러닝 추적 제외)
    await _initRunningServices();

    if (!mounted) return;

    if (widget.withWatch) {
      try {
        // 1. 폰에서 러닝을 시작함을 워치에 알림
        await _watch.updateApplicationContext({
          'runType': 'asyncRace',
          'targetDistanceKm': _targetDistanceKm,
          'isRunning': true,
          'isEnded': false,
          'isPaused': false,
        });
      } catch (e) {
        print("Watch updateApplicationContext Error: $e");
      }
    }

    // 2. 러닝 추적 시작
    _initializeTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 모든 스트림과 타이머 해제
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();
    _watchMessageSubscription?.cancel();
    _watchContextSubscription?.cancel();
    flutterTts.stop();

    // 라이브 액티비티 종료 (아직 안 끝났다면)
    if (!_isMyRunFinished) {
      _liveActivityChannel.invokeMethod('stopLiveActivity', {'type': 'async_battle'});
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && widget.withWatch) {
      print("▶️ App resumed. Re-initializing watch listeners.");
      _initializeWatchConnectivity();
    }
  }


  // ===================================================================
  // 3. 오프라인 대결 핵심 로직 (중단/취소)
  // ===================================================================

  /// 대결 취소 (Cloud Function 호출)
  Future<void> _stopAndCancelRun() async {
    if (_isProcessing) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('러닝 중단'),
          content: Text('정말로 러닝을 중단하시겠습니까?\n이 대결은 취소되며, 기록은 저장되지 않습니다.'),
          actions: [
            TextButton(
              child: Text('아니오', style: TextStyle(color: Colors.grey[700])),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: Text('중단', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('cancelAsyncBattle');
      await callable.call({'battleId': widget.battleId});

      _stopRunAndPop("대결이 취소되었습니다.");

    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        _showErrorDialog(e.message ?? "알 수 없는 오류");
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog("취소 요청 중 오류가 발생했습니다.");
        setState(() => _isProcessing = false);
      }
    }
  }

  /// 에러 발생 또는 취소 시 러닝을 중단하고 Pop
  void _stopRunAndPop(String message) {
    if (!mounted) return;

    _isProcessing = true;

    print("🛑 러닝 중단: $message");

    // 모든 러닝 로직 중단
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();
    flutterTts.stop();
    _liveActivityChannel.invokeMethod('stopLiveActivity', {'type': 'async_battle'});

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'stopFromPhone', 'runType': 'asyncRace', 'isEnded': true});
      try {
        _watch.updateApplicationContext({'isRunning': false, 'isEnded': true});
      } catch (e) {
        print("Watch updateApplicationContext Error on Stop: $e");
      }
    }

    // 사용자에게 알림
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('러닝 종료'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(context); // 다이얼로그 닫기
                Navigator.pop(context); // 러닝 화면 닫기
              },
            ),
          ],
        );
      },
    );
  }

  /// 에러 다이얼로그
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  // ===================================================================
  // 4. 러닝 핵심 로직
  // ===================================================================

  /// 맵 초기 위치 설정
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }
    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }
    await location.changeSettings(
        accuracy: _getLocationAccuracy(),
        interval: _getInterval(),
        distanceFilter: _getDistanceFilter());
    final locationData = await location.getLocation();
    if (locationData.latitude != null && locationData.longitude != null) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
          _myElevation = locationData.altitude ?? 0.0;
        });
      }
      _lastLocation = locationData;
    }
  }


  /// 러닝 서비스 초기화
  Future<void> _initRunningServices() async {
    // 1. TTS (오디오 설정 강화)
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setSpeechRate(0.5);

    // ▼▼▼▼▼ [ 🔊 오디오 설정 강화 ] ▼▼▼▼▼
    await flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback, // 무음 모드에서도 재생
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers, // 음악과 함께 재생
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker // 스피커 강제
        ],
        IosTextToSpeechAudioMode.voicePrompt
    );
    await flutterTts.setSharedInstance(true);
    // ▲▲▲▲▲ [ 🔊 오디오 설정 강화 ] ▲▲▲▲▲

    // 2. Weight & Nickname
    await _loadUserData();

    // 3. SharedPreferences
    await _initSharedPreferences();

    // 4. Watch/LA 핸들러
    _liveActivityChannel.setMethodCallHandler(_handleNativeMethodCall);

    if (widget.withWatch) {
      _initializeWatchConnectivity();
    }

    // 5. 지도 초기 위치 설정
    await _getCurrentLocation();
  }

  /// Native(Swift)의 App Intent 호출을 수신할 핸들러
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (!mounted) return;
    print("🎯 [ASYNC DART] Native method call received: ${call.method}");
    if (call.method == 'handleLiveActivityCommand') {
      try {
        final command = (call.arguments as Map<dynamic, dynamic>)['command'] as String?;
        if (command == 'pauseRunning') {
          if (!_isPaused) _pauseRunning();
        } else if (command == 'resumeRunning') {
          if (_isPaused) _resumeRunning();
        }
      } catch (e) {
        print("🚨 [ASYNC DART] _handleNativeMethodCall Error: $e");
      }
    }
  }

  /// Watch Connectivity 초기화
  void _initializeWatchConnectivity() {
    if (!widget.withWatch) return;

    _watchMessageSubscription?.cancel();
    _watchContextSubscription?.cancel();
    print("🔄 [ASYNC DART] Initializing watch connectivity listeners...");

    _watchMessageSubscription = _watch.messageStream.listen(
          (message) {
        _handleWatchCommand(message, "messageStream");
      },
    );
  }

  /// 워치 커맨드 핸들러
  void _handleWatchCommand(Map<String, dynamic> message, String streamType) {
    print("🎯 [ASYNC DART] Command received on '$streamType': $message");

    if (!mounted || _isMyRunFinished) return;

    if (message.containsKey('command')) {
      final command = message['command'] as String;
      switch (command) {
        case 'pauseRunning':
          if (!_isPaused) _pauseRunning();
          break;
        case 'resumeRunning':
          if (_isPaused) _resumeRunning();
          break;
        case 'stopRunning':
          _stopAndCancelRun();
          break;
      }
    }
  }

  /// TTS
  Future<void> _speak(String text) async {
    if (!_isPaused && !_isMyRunFinished) {
      await flutterTts.speak(text);
    }
  }

  /// 몸무게 & 닉네임 로드
  Future<void> _loadUserData() async {
    try {
      String userEmail = FirebaseAuth.instance.currentUser!.email!;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userEmail).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final weightData = data['weight'];
        double userWeight;
        if (weightData is String) {
          userWeight = double.tryParse(weightData) ?? 70.0;
        } else if (weightData is num) {
          userWeight = weightData.toDouble();
        } else {
          userWeight = 70.0;
        }
        _userWeight = userWeight;
        _myNickname = data['nickname'] as String? ?? '알수없음';
      } else {
        _userWeight = 70.0;
        _myNickname = '알수없음';
      }
    } catch (e) {
      print('Error loading user data: $e');
      _userWeight = 70.0;
      _myNickname = '알수없음';
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  /// SharedPreferences 로드
  Future<void> _initSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('accuracy')) await prefs.setString('accuracy', '가장 높음 (High)');
    if (!prefs.containsKey('distanceFilter')) await prefs.setDouble('distanceFilter', 5.0);
    if (!prefs.containsKey('interval')) await prefs.setInt('interval', 1000);
  }

  /// 트래킹 시작
  Future<void> _initializeTracking() async {
    // 1. 라이브 액티비티 시작
    _liveActivityChannel.invokeMethod('startLiveActivity', {
      'type': 'async_battle',
      'isPaused': false,
      'targetDistanceKm': _targetDistanceKm,
    });

    // 2. 워치에 시작 신호
    if (widget.withWatch) {
      _watch.sendMessage({'command': 'startRunningUI'});
    }

    // 3. 위치 권한 확인 및 백그라운드 모드
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      _stopRunAndPop("위치 서비스가 비활성화되어 있습니다.");
      return;
    }
    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        _stopRunAndPop("위치 권한이 거부되었습니다.");
        return;
      }
    }
    await location.enableBackgroundMode(enable: true);

    // 4. 위치 설정 적용
    await location.changeSettings(
        accuracy: _getLocationAccuracy(),
        interval: _getInterval(),
        distanceFilter: _getDistanceFilter());

    _lastLocation = null;

    // 5. 서비스 시작
    _startLocationTracking();
    _startTimer(); // 👈 정밀 타이머 시작
    _startPedometer();
  }

  /// 마커 업데이트
  void _updateMarkers() {
    if (!mounted) return;
    setState(() {
      if (_routePointsWithSpeed.isNotEmpty) {
        _startMarker = Annotation(
            annotationId: AnnotationId('start'),
            position: _routePointsWithSpeed.first.point,
            icon: BitmapDescriptor.defaultAnnotationWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: '출발 지점'));
        _endMarker = Annotation(
            annotationId: AnnotationId('end'),
            position: _routePointsWithSpeed.last.point,
            icon:
            BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: '종료 지점'));
      }
    });
  }

  /// 위치 추적 (지도 업데이트 로직 추가)
  void _startLocationTracking() {
    _locationSubscription =
        location.onLocationChanged.listen((loc.LocationData currentLocation) {
          if (!mounted || _isMyRunFinished) return;
          if (currentLocation.latitude == null || currentLocation.longitude == null) return;

          // GPS 정확도 체크
          if ((currentLocation.accuracy ?? 100.0) > 25.0) {
            print("⚠️ GPS 정확도 낮음 무시: ${currentLocation.accuracy}m");
            return;
          }

          LatLng newLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          double currentAltitude = currentLocation.altitude ?? 0.0;

          if (_lastLocation != null) {
            double lastAltitude = _lastLocation!.altitude ?? 0.0;
            double elevationDiff = currentAltitude - lastAltitude;
            if (elevationDiff > 0.5 && elevationDiff < 10.0) {
              _myElevation += elevationDiff;
            }
          }

          if (_lastLocation != null) {
            double distance = Geolocator.distanceBetween(
                _lastLocation!.latitude!, _lastLocation!.longitude!,
                currentLocation.latitude!, currentLocation.longitude!);
            double timeIntervalSec = (currentLocation.time! - (_lastLocation?.time ?? 0)) / 1000;
            if (timeIntervalSec <= 0) timeIntervalSec = 0.5;
            double speed = distance / timeIntervalSec; // m/s

            // 비정상 이동 무시
            if (distance > 50.0 || speed > 12.0) {
              print("⚠️ 비정상 이동 무시: Dist=$distance, Speed=$speed");
              return;
            }

            // 미세 노이즈 무시
            if (distance < 3.0) {
              return;
            }

            // 자동 일시정지 (0.7 m/s 미만)
            if (speed < 0.7 && !_isPaused) {
              if (!_dialogShownRecently) {
                _dialogShownRecently = true;
                _pauseRunning(isAuto: true);
                Future.delayed(Duration(seconds: 20), () => _dialogShownRecently = false);
              }
              _lastLocation = currentLocation;
              return;
            }
            // 자동 재개 (1.0 m/s 초과)
            else if (speed > 1.0 && _isPaused) {
              _resumeRunning();
            }

            if (_isPaused || _isMyRunFinished) {
              _lastLocation = currentLocation;
              return;
            }

            // 칼로리 계산
            if (_userWeight != null) {
              double speedKmh = speed * 3.6;
              double met = (speedKmh < 3.0) ? 2.0 : (speedKmh < 4.8) ? 3.5 : (speedKmh < 6.4) ? 5.0 :
              (speedKmh < 8.0) ? 8.3 : (speedKmh < 9.7) ? 9.8 : (speedKmh < 11.3) ? 11.0 : 12.8;
              double caloriesPerMinute = (met * 3.5 * _userWeight!) / 200;
              double caloriesThisInterval = caloriesPerMinute * (timeIntervalSec / 60);
              _myCalories += caloriesThisInterval;
            }

            // setState
            setState(() {
              _myKilometers += distance / 1000;
              _routePointsWithSpeed.add(RouteDataPoint(point: newLocation, speed: speed));
              _updateMarkers();
              _currentLocation = newLocation;
            });

            // 지도 카메라 이동
            if (_appleMapController != null && !_isPaused) {
              _appleMapController!.animateCamera(CameraUpdate.newLatLng(newLocation));
            }

            // ▼▼▼▼▼ [ 🔊 1km 음성 안내 로직 (안전하게 수정됨) ] ▼▼▼▼▼
            if (_myKilometers >= _nextKmTarget) {
              double safePace = _myPace;
              if (safePace.isInfinite || safePace.isNaN) safePace = 0.0;

              final int paceMin = safePace.floor();
              final int paceSec = ((safePace - paceMin) * 60).round();

              print("🔊 음성 안내 실행: $_nextKmTarget km 달성! (페이스: $paceMin분 $paceSec초)");
              _speak('$_nextKmTarget 킬로미터. 현재 페이스는 $paceMin 분 $paceSec 초 입니다.');

              _nextKmTarget++; // 다음 목표 설정 (1 -> 2 -> 3...)
            }
            // ▲▲▲▲▲ [ 🔊 수정 완료 ] ▲▲▲▲▲

            // 완주 확인
            if (_myKilometers >= _targetDistanceKm) {
              _finishMyRun();
            }

          } else {
            // 첫 위치
            setState(() {
              _routePointsWithSpeed.add(RouteDataPoint(point: newLocation, speed: 0.0));
              _updateMarkers();
              _currentLocation = newLocation;
            });
          }
          _lastLocation = currentLocation;
        });
  }

  // ▼▼▼▼▼ [ ⭐️ 수정: 정밀 타이머 로직 (0.05초 단위 갱신) ⭐️ ] ▼▼▼▼▼
  void _startTimer() {
    _initialStartTime = DateTime.now();
    // 50ms (0.05초) 마다 UI 갱신 (기존 1초에서 변경)
    _timer = Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused && _initialStartTime != null && !_isMyRunFinished) {
        setState(() {
          // 현재 시간 - 시작 시간 - 일시정지 시간 = 실제 달린 시간 (밀리초)
          int elapsedMillis = DateTime.now().difference(_initialStartTime!).inMilliseconds -
              _totalPausedDuration.inMilliseconds;

          // 이를 초 단위(소수점 포함)로 변환하여 저장 (기존에는 inSeconds 사용)
          _mySeconds = elapsedMillis / 1000.0;

          _updatePaceAndSpeed();
        });
      }
    });
  }
  // ▲▲▲▲▲ [ ⭐️ 수정: 정밀 타이머 로직 (0.05초 단위 갱신) ⭐️ ] ▲▲▲▲▲

  /// 만보계 시작
  void _startPedometer() {
    _pedometerStream = Pedometer.stepCountStream.listen(
          (StepCount event) {
        if (!mounted || _isPaused || _isMyRunFinished) return;
        if (_initialStepCount == -1) {
          _initialStepCount = event.steps;
        }
        setState(() {
          _myStepCount = event.steps - _initialStepCount;
        });
      },
      onError: (error) {
        print("⛔ 만보계 센서 오류: $error");
        setState(() => _myStepCount = 0);
      },
    );
  }

  /// 페이스 및 속도 업데이트
  void _updatePaceAndSpeed() {
    double newAvgSpeed;
    double newPace;

    // _mySeconds는 이제 double이므로 바로 비교 가능 (1초 미만이면 0 처리)
    if (_myKilometers < 0.01 || _mySeconds < 1.0) {
      newAvgSpeed = 0.0;
      newPace = 0.0;
    } else {
      newAvgSpeed = _myKilometers / (_mySeconds / 3600.0);
      newPace = (_mySeconds / 60.0) / _myKilometers;
    }
    if (newPace < 3.0 && _mySeconds > 10.0) newPace = 3.0;
    if (newPace > 30.0) newPace = 30.0;

    setState(() {
      _myAverageSpeed = newAvgSpeed;
      _myPace = newPace;
    });

    // 라이브 액티비티 업데이트
    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'async_battle',
      'kilometers': _myKilometers,
      'seconds': _mySeconds.toInt(), // LA는 아직 int로 보냄 (표시용)
      'pace': _myPace,
      'calories': _myCalories,
      'isPaused': _isPaused,
      'isMyRunFinished': _isMyRunFinished,
    });

    if (widget.withWatch) {
      final watchData = {
        'type': 'battle',
        'kilometers': _myKilometers,
        'seconds': _mySeconds.toInt(), // 워치도 int로 보냄
        'pace': _myPace,
        'calories': _myCalories,
        'isEnded': false,
      };
      _watch.sendMessage(watchData);
    }
  }

  /// 헬퍼 (위치 정확도)
  loc.LocationAccuracy _getLocationAccuracy() {
    String accuracyStr = prefs.getString('accuracy') ?? '가장 높음 (High)';
    switch (accuracyStr) {
      case '균형 (Balanced)': return loc.LocationAccuracy.balanced;
      case '배터리 절약 (Low)': return loc.LocationAccuracy.low;
      case '내비게이션 (Navigation)': return loc.LocationAccuracy.navigation;
      case '가장 높음 (High)': default: return loc.LocationAccuracy.high;
    }
  }
  int _getInterval() => prefs.getInt('interval') ?? 1000;
  double _getDistanceFilter() => prefs.getDouble('distanceFilter') ?? 5.0;

  /// 일시정지
  Future<void> _pauseRunning({bool isAuto = false}) async {
    if (!mounted || _isPaused || _isMyRunFinished) return;

    setState(() {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
      _myStatus = 'paused';
    });

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'pauseFromPhone'});
    }

    String ttsMessage = isAuto ? "움직임이 없어 일시정지합니다" : "일시정지";
    await flutterTts.speak(ttsMessage);

    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'async_battle', 'isPaused': true,
      'kilometers': _myKilometers, 'seconds': _mySeconds.toInt(),
      'pace': _myPace, 'calories': _myCalories, 'isMyRunFinished': _isMyRunFinished,
    });
  }

  /// 재개
  Future<void> _resumeRunning() async {
    if (!mounted || !_isPaused || _isMyRunFinished) return;

    setState(() {
      if (_pauseStartTime != null) {
        _totalPausedDuration += DateTime.now().difference(_pauseStartTime!);
      }
      _isPaused = false;
      _dialogShownRecently = false;
      _myStatus = 'running';
    });

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'resumeFromPhone'});
    }

    await flutterTts.speak("운동을 다시 시작합니다");

    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'async_battle', 'isPaused': false,
      'kilometers': _myKilometers, 'seconds': _mySeconds.toInt(),
      'pace': _myPace, 'calories': _myCalories, 'isMyRunFinished': _isMyRunFinished,
    });
  }

  /// 완주
  Future<void> _finishMyRun() async {
    if (_isMyRunFinished || _isProcessing) return;

    if (widget.battleId == null || widget.battleId.isEmpty) {
      _showErrorDialog("치명적인 오류: Battle ID가 없습니다. 이 기록은 저장될 수 없습니다.");
      setState(() {
        _isMyRunFinished = false;
        _isPaused = false;
        _isProcessing = false;
      });
      return;
    }

    print("🏁 [ASYNC] 완주! (Target: $_targetDistanceKm, Actual: $_myKilometers)");

    // 1. 상태 변경
    setState(() {
      _isMyRunFinished = true;
      _isPaused = true;
      _myStatus = 'finished';
      _isProcessing = true;
    });

    // 2. 하드웨어 리스너 중지
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();

    // 3. TTS (완주 음성 안내)
    await flutterTts.speak("완주했습니다! 기록을 전송합니다.");

    // 4. 마지막 데이터 정리
    if (_myKilometers < _targetDistanceKm) {
      _myKilometers = widget.targetDistanceKm;
    }
    _updatePaceAndSpeed();

    // 5. 라이브 액티비티/워치 '종료'
    _liveActivityChannel.invokeMethod('stopLiveActivity', {'type': 'async_battle'});

    if (widget.withWatch) {
      _watch.sendMessage({
        'command': 'stopFromPhone',
        'runType': 'asyncRace',
        'kilometers': _myKilometers,
        'seconds': _mySeconds.toInt(),
        'pace': _myPace,
        'calories': _myCalories,
        'targetDistanceKm': _targetDistanceKm,
        'isEnded': true,
      });
      try {
        await _watch.updateApplicationContext({
          'runType': 'asyncRace',
          'isRunning': false,
          'isEnded': true,
          'kilometers': _myKilometers,
          'seconds': _mySeconds.toInt(),
          'pace': _myPace,
          'calories': _myCalories,
          'targetDistanceKm': _targetDistanceKm,
        });
      } catch (e) {
        print("Watch updateApplicationContext Error on Finish: $e");
      }
    }

    // 6. Cloud Function 호출 (소수점 초 포함 전송)
    final Map<String, dynamic> runData = {
      'seconds': _mySeconds, // 👈 [핵심] double 타입(소수점 포함)으로 전송
      'pace': _myPace,
      'stepCount': _myStepCount,
      'elevation': _myElevation,
      'averageSpeed': _myAverageSpeed,
      'calories': _myCalories,
      'routePoints': _routePointsWithSpeed.map((p) => p.toMap()).toList(),
    };

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      final callable = functions.httpsCallable('completeAsyncBattle');

      final result = await callable.call({
        'battleId': widget.battleId,
        'runData': runData,
        'completerNickname': _myNickname,
      });

      if (mounted) {
        _showCustomSnackBar(context, result.data['message'] ?? '기록이 전송되었습니다.');
        Navigator.pop(context); // 러닝 화면 닫기
      }
    } on FirebaseFunctionsException catch (e) {
      print("Error calling completeAsyncBattle: ${e.message}");
      if (mounted) {
        _showErrorDialog(e.message ?? "기록 전송에 실패했습니다. 다시 시도해주세요.");
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        _showErrorDialog("알 수 없는 오류로 기록 전송에 실패했습니다.");
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  // ===================================================================
  // 5. 헬퍼 함수 (Formatters) - 정밀 시간 포맷
  // ===================================================================

  // ▼▼▼▼▼ [ ⭐️ 수정: 정밀 시간 표시 (분:초.백분초) ⭐️ ] ▼▼▼▼▼
  String _formatTime(double seconds) {
    // 1. 전체 초를 정수로 변환 (분/초 계산용)
    final int totalSec = seconds.floor();

    final int hours = totalSec ~/ 3600;
    final int minutes = (totalSec % 3600) ~/ 60;
    final int secs = totalSec % 60;

    // 2. 소수점 이하 2자리(백분초) 추출 (0.456 -> 45)
    final int centi = ((seconds - totalSec) * 100).floor();

    // "00:00.00" 형식
    String timeStr = '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${centi.toString().padLeft(2, '0')}';

    // 1시간 넘어가면 "00:00:00.00" 형식
    if (hours > 0) {
      timeStr = '${hours.toString().padLeft(2, '0')}:$timeStr';
    }
    return timeStr;
  }
  // ▲▲▲▲▲ [ ⭐️ 수정: 정밀 시간 표시 (분:초.백분초) ⭐️ ] ▲▲▲▲▲

  String _formatPace(double pace) {
    if (pace.isInfinite || pace.isNaN || pace == 0) return '--:--';
    int min = pace.floor();
    int sec = ((pace - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }


  // ===================================================================
  // 6. UI (Build)
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final bool isAnyAdmin =
        _userRole == 'admin' || _userRole == 'head_admin' || _userRole == 'super_admin';

    return WillPopScope(
      onWillPop: () async {
        if (!_isMyRunFinished) {
          await _stopAndCancelRun();
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoadingUserData
            ? Center(child: CircularProgressIndicator(color: Color(0xFFFF9F80)))
            : _buildBattleUI(isAnyAdmin),
      ),
    );
  }

  /// 완주/전송중 오버레이 UI
  Widget _buildFinishOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              Text(
                '기록 전송 중...',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(color: Colors.white),
            ] else ... [
              Icon(Icons.flag, color: Colors.white, size: 80),
              SizedBox(height: 20),
              // ▼▼▼▼▼ [ ⭐️ 수정: 정밀 시간 표시 ⭐️ ] ▼▼▼▼▼
              Text(
                _formatTime(_mySeconds),
                style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
              ),
              // ▲▲▲▲▲ [ ⭐️ 수정: 정밀 시간 표시 ⭐️ ] ▲▲▲▲▲
              Text(
                '완주!',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '기록 전송에 실패했습니다.\n(컨트롤 버튼을 눌러 중단하거나 앱 재시작)',
                style: TextStyle(color: Colors.grey[300], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  "나가기 (기록 미저장)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBattleUI(bool isAnyAdmin) {
    return Stack(
      children: [
        Positioned.fill(
          child: AppleMap(
            onMapCreated: (controller) {
              _appleMapController = controller;
              if (_currentLocation != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLocation!, 15),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? LatLng(37.5665, 126.9780),
              zoom: 17,
            ),
            annotations: {
              if (_startMarker != null) _startMarker!,
              if (_endMarker != null) _endMarker!,
            },
            polylines: {
              Polyline(
                polylineId: PolylineId('running_route'),
                color: Colors.blue,
                width: 5,
                points: _routePointsWithSpeed.map((dp) => dp.point).toList(),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.8),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white.withOpacity(0.8),
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              // 1. 상단: 내 정보
              _buildPlayerHeader(),

              // 3. 하단: 핵심 스탯
              Spacer(),
              _buildMainStats(),
              Spacer(),

              // 4. 컨트롤 버튼
              _buildControls(),
            ],
          ),
        ),

        if (!_isMyRunFinished && isAnyAdmin)
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'debugFinish',
              onPressed: _finishMyRun,
              backgroundColor: Colors.orange,
              child: Icon(Icons.flag, color: Colors.white),
            ),
          ),

        if (_isMyRunFinished)
          _buildFinishOverlay(),
      ],
    );
  }

  /// 상단: 내 정보
  Widget _buildPlayerHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오프라인 대결',
                style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_myKilometers.toStringAsFixed(2)} km',
                style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '목표',
                style: TextStyle(color: Colors.deepPurple, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_targetDistanceKm.toStringAsFixed(0)} km',
                style: TextStyle(color: Colors.deepPurple, fontSize: 28, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 하단: 핵심 스탯
  Widget _buildMainStats() {
    return Column(
      children: [
        Text(
          '${_formatPace(_myPace)}',
          style: TextStyle(
            color: Colors.black,
            fontSize: 72,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '현재 페이스 (/km)',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
        SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ▼▼▼▼▼ [ ⭐️ 수정: 시간 표시에 정밀 포맷 적용 ⭐️ ] ▼▼▼▼▼
              _buildStatColumn('시간', _formatTime(_mySeconds)),
              // ▲▲▲▲▲ [ ⭐️ 수정: 시간 표시에 정밀 포맷 적용 ⭐️ ] ▲▲▲▲▲
              _buildStatColumn('칼로리', '${_myCalories.toStringAsFixed(0)} kcal'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          // 소수점까지 나오면 글자가 길어지므로 폰트 사이즈를 약간 조정하거나 모노스페이스 폰트 사용 권장
          style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()] // 숫자 너비 고정
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
      ],
    );
  }

  /// 컨트롤 버튼
  Widget _buildControls() {
    if (_isMyRunFinished && _isProcessing) {
      return SizedBox(height: 80);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isMyRunFinished && !_isProcessing)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                  ]
              ),
              child: IconButton(
                icon: Icon(Icons.stop, color: Colors.white),
                iconSize: 30,
                onPressed: _stopAndCancelRun,
              ),
            )
          else if (_isPaused)
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                      ]
                  ),
                  child: IconButton(
                    icon: Icon(Icons.stop, color: Colors.white),
                    iconSize: 30,
                    onPressed: _stopAndCancelRun,
                  ),
                ),
                SizedBox(width: 20),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                      ]
                  ),
                  child: IconButton(
                    icon: Icon(Icons.play_arrow, color: Colors.black),
                    iconSize: 30,
                    onPressed: _resumeRunning,
                  ),
                ),
              ],
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                  ]
              ),
              child: IconButton(
                icon: Icon(Icons.pause, color: Colors.white),
                iconSize: 30,
                onPressed: () => _pauseRunning(isAuto: false),
              ),
            ),
        ],
      ),
    );
  }
}

void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
  if (!ScaffoldMessenger.of(context).mounted) return;
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