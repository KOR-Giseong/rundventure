import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'free_running.dart'; // FreeRunningPage import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:pedometer/pedometer.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RouteDataPoint {
  final LatLng point;
  final double speed;

  RouteDataPoint({required this.point, required this.speed});

  // 1. 저장할 때 쓰는 함수 (toMap)
  Map<String, dynamic> toMap() {
    return {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'speed': speed,
    };
  }

  factory RouteDataPoint.fromMap(Map<String, dynamic> map) {
    return RouteDataPoint(
      point: LatLng(
        (map['latitude'] as num).toDouble(),
        (map['longitude'] as num).toDouble(),
      ),
      speed: (map['speed'] as num).toDouble(),
    );
  }
}

class RunningPage extends StatefulWidget {
  final bool withWatch;
  final String runType;
  final double? targetDistanceKm;
  final String? battleId;

  const RunningPage({
    Key? key,
    required this.withWatch,
    this.runType = 'free', // 기본값은 'free'
    this.targetDistanceKm,
    this.battleId,
  }) : super(key: key);

  @override
  _RunningPageState createState() => _RunningPageState();
}

class _RunningPageState extends State<RunningPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  loc.Location location = loc.Location();
  LatLng? _currentLocation;
  StreamSubscription<loc.LocationData>? _locationSubscription;
  AppleMapController? _appleMapController;
  double _pace = 0.0;
  int _seconds = 0;
  double _kilometers = 0.0;
  double _elevation = 0.0;
  double _averageSpeed = 0.0;
  double _calories = 0.0;
  int _stepCount = 0;
  bool _isPaused = false;
  bool _dialogShownRecently = false;
  double? _userWeight;
  bool _isLoadingUserData = true;
  Timer? _timer;
  loc.LocationData? _lastLocation;
  int _countdown = 3;
  bool _showStartMessage = true;
  late AnimationController _animationController;
  bool _showMap = false;

  List<RouteDataPoint> _routePointsWithSpeed = [];
  late SharedPreferences prefs;
  Annotation? _startMarker;
  Annotation? _endMarker;
  List<Annotation> _waypointMarkers = [];
  DateTime? _initialStartTime;
  Duration _totalPausedDuration = Duration.zero;
  DateTime? _pauseStartTime;

  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;
  StreamSubscription<Map<String, dynamic>>? _watchContextSubscription;
  final _watch = WatchConnectivity();

  final MethodChannel _liveActivityChannel = const MethodChannel('com.rundventure/liveactivity');
  late FlutterTts flutterTts;
  int _nextKmTarget = 1;

  StreamSubscription<StepCount>? _pedometerStream;
  int _initialStepCount = -1; // 트래킹 시작 시점의 총 걸음수

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWatchConnectivity();

    _liveActivityChannel.setMethodCallHandler(_handleNativeMethodCall);

    _initTts();
    _loadUserWeight();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _initSharedPreferences();
    _getCurrentLocation();
    _startCountdown();
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (!mounted) return; // 위젯이 화면에 없으면 무시

    print("🎯 [DART] Native method call received: ${call.method}");

    if (call.method == 'handleLiveActivityCommand') {
      try {
        final command = (call.arguments as Map<dynamic, dynamic>)['command'] as String?;

        if (command == 'pauseRunning') {
          print("⏸️ [DART] Live Activity로부터 '일시정지' 명령 실행");
          if (!_isPaused) _pauseRunning();

        } else if (command == 'resumeRunning') {
          print("▶️ [DART] Live Activity로부터 '재개' 명령 실행");
          if (_isPaused) _resumeRunning();
        }
      } catch (e) {
        print("🚨 [DART] _handleNativeMethodCall Error: $e");
      }
    }
  }

  void _handleWatchCommand(Map<String, dynamic> message, String streamType) {
    print("🎯 [DART] Command received on '$streamType': $message");

    if (!mounted) {
      print("⚠️ [DART] Widget not mounted. Skipping command.");
      return;
    }

    if (message.containsKey('command')) {
      final command = message['command'] as String;

      switch (command) {
        case 'pauseRunning':
          print("⏸️ [DART] 워치로부터 '일시정지' 명령 실행");
          if (!_isPaused) _pauseRunning();
          break;
        case 'resumeRunning':
          print("▶️ [DART] 워치로부터 '재개' 명령 실행");
          if (_isPaused) _resumeRunning();
          break;
        case 'stopRunning':
          print("⏹️ [DART] 워치로부터 '종료' 명령 실행");
          if (_timer?.isActive ?? false) _stopRunning();
          break;
      }
    }
  }

  void _initializeWatchConnectivity() {
    // '아니요'를 눌렀을 경우 워치 리스너를 활성화하지 않습니다.
    if (!widget.withWatch) return;

    _watchMessageSubscription?.cancel();
    _watchContextSubscription?.cancel();
    print("🔄 [DART] Initializing watch connectivity listeners...");

    _watchMessageSubscription = _watch.messageStream.listen(
          (message) {
        _handleWatchCommand(message, "messageStream");
      },
      onError: (error) {
        print("🚨 [DART] Error on messageStream: $error");
      },
    );

    _watchContextSubscription = _watch.contextStream.listen(
          (context) {
        _handleWatchCommand(context, "contextStream");
      },
      onError: (error) {
        print("🚨 [DART] Error on contextStream: $error");
      },
    );

    print("✅ [DART] Watch connectivity listeners are now active.");
  }

  Future<void> _initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setSpeechRate(0.5);

    await flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker
        ],
        IosTextToSpeechAudioMode.voicePrompt
    );

    await flutterTts.setSharedInstance(true);
  }

  Future<void> _speak(String text) async {
    if (!_isPaused) {
      await flutterTts.speak(text);
    }
  }

  Future<void> _initSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('accuracy')) await prefs.setString('accuracy', '가장 높음 (High)');
    if (!prefs.containsKey('distanceFilter')) await prefs.setDouble('distanceFilter', 5.0);
    if (!prefs.containsKey('interval')) await prefs.setInt('interval', 1000);
  }


  String _formatPace(double pace) {
    if (pace.isInfinite || pace.isNaN || pace == 0) return '--:--';
    int min = pace.floor();
    int sec = ((pace - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

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
    // _initSharedPreferences()가 호출된 이후이므로, 여기서는 저장된 값을 사용합니다.
    await location.changeSettings(
        accuracy: _getLocationAccuracy(),
        interval: _getInterval(),
        distanceFilter: _getDistanceFilter());
    final locationData = await location.getLocation();
    if (locationData.latitude != null && locationData.longitude != null) {
      setState(() {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        _elevation = locationData.altitude ?? 0.0;
      });
      _lastLocation = locationData;
    }
  }

  Future<void> _loadUserWeight() async {
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
        setState(() {
          _userWeight = userWeight;
          _isLoadingUserData = false;
        });
      } else {
        setState(() {
          _userWeight = 70.0;
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      print('Error loading user weight: $e');
      setState(() {
        _userWeight = 70.0;
        _isLoadingUserData = false;
      });
    }
  }

  void _startCountdown() async {
    if (!mounted) return;

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'showWarmup'});
    }

    setState(() {
      _showStartMessage = true;
    });
    await flutterTts.speak("준비하세요!");
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _showStartMessage = false;
    });

    for (int i = 3; i > 0; i--) {
      if (!mounted) return;

      if (widget.withWatch) {
        _watch.sendMessage({'command': 'countdown', 'value': i});
      }

      setState(() {
        _countdown = i;
      });
      await flutterTts.speak('$i');
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'startRunningUI'});

      _watch.updateApplicationContext({'isRunning': true});
    }

    setState(() {
      _countdown = 0;
      _showMap = true;
    });
    await flutterTts.speak('운동을 시작합니다!');
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    _liveActivityChannel.invokeMethod('startLiveActivity', {
      'type': 'main',
      'isPaused': false,
    });

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
    await location.enableBackgroundMode(enable: true);

    // 설정 페이지에서 저장된 값을 사용하도록 수정된 함수들을 호출합니다.
    await location.changeSettings(
        accuracy: _getLocationAccuracy(),
        interval: _getInterval(),
        distanceFilter: _getDistanceFilter());

    _lastLocation = null;

    _startLocationTracking();
    _startTimer();
    _startPedometer();
  }

  void _startPedometer() {
    _pedometerStream = Pedometer.stepCountStream.listen(
          (StepCount event) {
        if (!mounted || _isPaused) return; // 일시정지 중이거나 화면 나가면 무시

        if (_initialStepCount == -1) {
          // 트래킹 시작 후 첫 이벤트: 현재까지의 총 걸음수를 '초기값'으로 저장
          _initialStepCount = event.steps;
        }

        // 현재 총 걸음수 - 트래킹 시작 시 걸음수 = 이번 세션의 걸음수
        setState(() {
          _stepCount = event.steps - _initialStepCount;
        });
      },
      onError: (error) {
        print("⛔ 만보계 센서 오류: $error");
        // 센서 오류 시 (예: 시뮬레이터) 걸음수를 0으로 유지
        setState(() {
          _stepCount = 0;
        });
      },
    );
  }

  void _startLocationTracking() {
    _locationSubscription =
        location.onLocationChanged.listen((loc.LocationData currentLocation) {
          if (!mounted) return;
          if (currentLocation.latitude == null ||
              currentLocation.longitude == null) {
            print('위치 정보 누락');
            return;
          }

          // GPS 정확도 체크
          if ((currentLocation.accuracy ?? 100.0) > 25.0) {
            print("⚠️ GPS 정확도 낮음 무시: ${currentLocation.accuracy}m");
            return;
          }

          LatLng newLocation =
          LatLng(currentLocation.latitude!, currentLocation.longitude!);
          double currentAltitude = currentLocation.altitude ?? 0.0;

          if (_lastLocation != null) {
            double lastAltitude = _lastLocation!.altitude ?? 0.0;
            double elevationDiff = currentAltitude - lastAltitude;
            if (elevationDiff > 0.5 && elevationDiff < 10.0) {
              _elevation += elevationDiff;
            }
          }

          if (_lastLocation != null) {
            double distance = Geolocator.distanceBetween(
                _lastLocation!.latitude!,
                _lastLocation!.longitude!,
                currentLocation.latitude!,
                currentLocation.longitude!);

            double timeIntervalSec =
                (currentLocation.time! - (_lastLocation?.time ?? 0)) / 1000;
            if (timeIntervalSec <= 0) timeIntervalSec = 0.5;
            double speed = distance / timeIntervalSec; // m/s

            // 비정상 이동 무시
            if (distance > 50.0) {
              print('비정상적인 거리 이동(순간이동) 감지: $distance m. 무시합니다.');
              _lastLocation = currentLocation;
              return;
            }

            // 자동 일시정지
            if (speed < 0.7 && !_isPaused) {
              if (!_dialogShownRecently) {
                _dialogShownRecently = true;
                _pauseRunning(isAuto: true);
                Future.delayed(Duration(seconds: 20), () {
                  _dialogShownRecently = false;
                });
              }
              _lastLocation = currentLocation;
              return;
            }
            // 자동 재개
            else if (speed > 1.0 && _isPaused) {
              _resumeRunning();
            }

            if (_isPaused) {
              _lastLocation = currentLocation;
              return;
            }

            // 3m 미만 노이즈 필터
            if (distance < 3.0) {
              _lastLocation = currentLocation;
              return;
            }

            if (speed > 10.0) {
              print('비현실적인 속도 감지: $speed m/s');
              _lastLocation = currentLocation;
              return;
            }

            // 칼로리 계산
            if (_userWeight != null) {
              double speedKmh = speed * 3.6;
              double met;
              if (speedKmh < 3.0)
                met = 2.0;
              else if (speedKmh < 4.8)
                met = 3.5;
              else if (speedKmh < 6.4)
                met = 5.0;
              else if (speedKmh < 8.0)
                met = 8.3;
              else if (speedKmh < 9.7)
                met = 9.8;
              else if (speedKmh < 11.3)
                met = 11.0;
              else
                met = 12.8;
              double caloriesPerMinute =
                  (met * 3.5 * _userWeight!) / 200;
              double caloriesThisInterval =
                  caloriesPerMinute * (timeIntervalSec / 60);
              _calories += caloriesThisInterval;
            }

            setState(() {
              _kilometers += distance / 1000;
              _routePointsWithSpeed
                  .add(RouteDataPoint(point: newLocation, speed: speed));
              _updateMarkers();
              _currentLocation = newLocation;
            });

            // 지도 카메라 이동
            if (_appleMapController != null) {
              _appleMapController!
                  .animateCamera(CameraUpdate.newLatLng(newLocation));
            }

            if (_kilometers >= _nextKmTarget) {
              double safePace = _pace;
              if (safePace.isInfinite || safePace.isNaN) safePace = 0.0;

              final int paceMin = safePace.floor();
              final int paceSec = ((safePace - paceMin) * 60).round();

              print("🔊 음성 안내 실행: $_nextKmTarget km 달성! (페이스: $paceMin분 $paceSec초)");

              _speak('$_nextKmTarget 킬로미터. 현재 페이스는 $paceMin 분 $paceSec 초 입니다.');

              _nextKmTarget++;
            }

            // 오프라인 대결 목표 달성 시 종료
            if (widget.runType == 'async_battle' &&
                widget.targetDistanceKm != null) {
              if (_kilometers >= widget.targetDistanceKm!) {
                print(
                    "오프라인 대결 목표 거리(${widget.targetDistanceKm}km) 도달. 자동 종료합니다.");
                if (_timer?.isActive ?? false) { // 중복 호출 방지
                  _stopRunning();
                  _timer?.cancel();
                }
              }
            }

          } else {
            // 첫 위치
            setState(() {
              _routePointsWithSpeed
                  .add(RouteDataPoint(point: newLocation, speed: 0.0));
              _updateMarkers();
              _currentLocation = newLocation; // 초기 위치 설정
            });
          }
          _lastLocation = currentLocation;
        });
  }

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

  void _startTimer() {
    _initialStartTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused && _initialStartTime != null) {
        setState(() {
          _seconds = DateTime.now().difference(_initialStartTime!).inSeconds -
              _totalPausedDuration.inSeconds;
          _updatePaceAndSpeed();

          if (widget.runType == 'async_battle' && widget.targetDistanceKm != null) {
            if (_kilometers >= widget.targetDistanceKm!) {
              print("오프라인 대결 목표 거리(${widget.targetDistanceKm}km) 도달. 자동 종료합니다.");
              _stopRunning();
              timer.cancel();
            }
          }
        });
      }
    });
  }

  void _updatePaceAndSpeed() {
    double newAvgSpeed;
    double newPace;
    if (_kilometers < 0.01 || _seconds < 1) {
      newAvgSpeed = 0.0;
      newPace = 0.0;
    } else {
      newAvgSpeed = _kilometers / (_seconds / 3600);
      newPace = (_seconds / 60) / _kilometers;
    }
    if (newPace < 3.0 && _seconds > 10) newPace = 3.0;
    if (newPace > 30.0) newPace = 30.0;
    _averageSpeed = newAvgSpeed;
    _pace = newPace;

    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'main',
      'kilometers': _kilometers,
      'seconds': _seconds,
      'pace': _pace,
      'calories': _calories,
      'isPaused': _isPaused,
    });

    if (widget.withWatch) {
      final watchData = {
        'type': 'main',
        'kilometers': _kilometers,
        'seconds': _seconds,
        'pace': _pace,
        'calories': _calories,
        'isEnded': false,
      };
      _watch.sendMessage(watchData);
    }
  }

  void _updateCalories() {}

  Future<void> _pauseRunning({bool isAuto = false}) async {
    if (!mounted) return;
    if (_isPaused) return;

    setState(() {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
    });
    if (widget.withWatch) {
      _watch.sendMessage({'command': 'pauseFromPhone'});
    }

    String ttsMessage = isAuto ? "움직임이 없어 일시정지합니다" : "일시정지";
    await flutterTts.speak(ttsMessage);

    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'main',
      'kilometers': _kilometers,
      'seconds': _seconds,
      'pace': _pace,
      'calories': _calories,
      'isPaused': true,
    });
  }

  Future<void> _resumeRunning() async {
    if (!mounted) return;
    if (!_isPaused) return;

    setState(() {
      if (_pauseStartTime != null) {
        final pauseDuration = DateTime.now().difference(_pauseStartTime!);
        _totalPausedDuration += pauseDuration;
      }
      _isPaused = false;
      _dialogShownRecently = false;
    });
    if (widget.withWatch) {
      _watch.sendMessage({'command': 'resumeFromPhone'});
    }
    await flutterTts.speak("운동을 다시 시작합니다");

    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'main',
      'kilometers': _kilometers,
      'seconds': _seconds,
      'pace': _pace,
      'calories': _calories,
      'isPaused': false,
    });
  }

  Future<void> _stopRunning() async {
    // 1. (기존) 타이머, 구독, TTS 중지
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();
    await flutterTts.stop();

    // 2. (수정) 워치 연동 종료 (try-catch로 안전하게)
    if (widget.withWatch) {
      _watch.sendMessage({'command': 'stopFromPhone'});
      try {
        _watch.updateApplicationContext({'isRunning': false, 'isEnded': true});
      } catch (e) {
        print("워치 Context 업데이트 실패 (정상 동작): $e");
      }
    }

    // 3. (기존) 라이브 액티비티 종료
    await _liveActivityChannel.invokeMethod('stopLiveActivity', {
      'type': 'main',
    });

    if (!mounted) return;

    // 4-A. 오프라인 대결('async_battle')인 경우
    if (widget.runType == 'async_battle' && widget.battleId != null) {
      _showLoadingDialog("대결 결과 집계 중..."); // 로딩 다이얼로그 표시

      try {
        // 1. Cloud Function에 보낼 결과 데이터 준비
        final Map<String, dynamic> resultData = {
          'battleId': widget.battleId, // 어떤 대결인지
          'runData': { // 나의 러닝 기록
            'kilometers': _kilometers,
            'seconds': _seconds,
            'pace': _pace,
            'averageSpeed': _averageSpeed,
            'calories': _calories,
            'elevation': _elevation,
            'stepCount': _stepCount,
            'routePoints': _routePointsWithSpeed.map((dp) => dp.toMap()).toList(),
          }
        };

        // 2. Cloud Function 호출 (함수 이름은 'completeAsyncBattle'로 새로 만들 것임)
        FirebaseFunctions functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
        final HttpsCallable callable = functions.httpsCallable('completeAsyncBattle');
        final HttpsCallableResult result = await callable.call(resultData);

        if (!mounted) return; // 비동기 호출 후 mounted 확인
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        if (result.data['success'] == true) {
          // 3. 성공 시
          _showCustomSnackBar("대결을 완료했습니다! 결과는 알림으로 전송됩니다.");
          Navigator.pop(context); // 러닝 페이지 닫기
        } else {
          // 4. 함수 호출은 성공했으나, 로직상 실패 시
          _showCustomSnackBar(result.data['message'] ?? "결과 저장에 실패했습니다.", isError: true);
          Navigator.pop(context); // 러닝 페이지 닫기
        }

      } catch (e) {
        if (!mounted) return; // 비동기 호출 후 mounted 확인
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        print("Cloud Function 'completeAsyncBattle' 호출 오류: $e");
        _showCustomSnackBar("결과 전송 중 오류가 발생했습니다. 기록이 저장되지 않았습니다.", isError: true);
        Navigator.pop(context); // 러닝 페이지 닫기
      }
    }
    // 4-B. 일반 러닝 ('free') 또는 실시간 대결 ('live_battle')인 경우
    else {
      // (기존 코드) 일반 결과 페이지(FreeRunningPage)로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FreeRunningPage(
            kilometers: _kilometers,
            seconds: _seconds,
            pace: _pace,
            bpm: 0,
            stepCount: _stepCount,
            elevation: _elevation,
            averageSpeed: _averageSpeed,
            calories: _calories,
            routePointsWithSpeed: _routePointsWithSpeed,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchMessageSubscription?.cancel();
    _watchContextSubscription?.cancel();
    flutterTts.stop();
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print("▶️ App resumed. Re-initializing watch listeners.");
      _initializeWatchConnectivity();
    }
  }


  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // 사용자가 임의로 닫을 수 없음
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
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          if (_showMap)
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
                  ..._waypointMarkers,
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
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom,
            child: Center(
              child: _showStartMessage
                  ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final offsetAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                  );
                  return ScaleTransition(scale: offsetAnimation, child: child);
                },
                child: Text(
                  '준비하세요!',
                  key: ValueKey<String>('ready'),
                  style: TextStyle(
                    fontSize: 40,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(offset: Offset(2, 2), blurRadius: 10.0, color: Colors.black.withOpacity(0.8)),
                      Shadow(offset: Offset(-2, -2), blurRadius: 10.0, color: Colors.black.withOpacity(0.8)),
                    ],
                  ),
                ),
              )
                  : _countdown > 0
                  ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final offsetAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                  );
                  return ScaleTransition(scale: offsetAnimation, child: child);
                },
                child: Text(
                  '$_countdown',
                  key: ValueKey<int>(_countdown),
                  style: TextStyle(
                    fontSize: 120,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(offset: Offset(2, 2), blurRadius: 10.0, color: Colors.black.withOpacity(0.8)),
                      Shadow(offset: Offset(-2, -2), blurRadius: 10.0, color: Colors.black.withOpacity(0.8)),
                    ],
                  ),
                ),
              )
                  : _buildRunningPageContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningPageContent() {
    if (_isLoadingUserData) {
      return Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRunningInfo('페이스', '${_formatPace(_pace)}/KM'),
              _buildRunningInfo('시간', _formatTime(_seconds)),
              _buildRunningInfo('칼로리', '${_calories.toStringAsFixed(0)}kcal'),
            ],
          ),
        ),
        Spacer(),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${_kilometers.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900),
            ),
            Text(
              'KM',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPaused)
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.stop, color: Colors.white),
                        iconSize: 30,
                        onPressed: _stopRunning,
                      ),
                    ),
                    SizedBox(width: 20),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
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
                  ),
                  child: IconButton(
                    icon: Icon(Icons.pause, color: Colors.white),
                    iconSize: 30,
                    onPressed: _pauseRunning,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRunningInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  loc.LocationAccuracy _getLocationAccuracy() {
    String accuracyStr = prefs.getString('accuracy') ?? '가장 높음 (High)';
    switch (accuracyStr) {
      case '균형 (Balanced)':
        return loc.LocationAccuracy.balanced;
      case '배터리 절약 (Low)':
        return loc.LocationAccuracy.low;
      case '내비게이션 (Navigation)':
        return loc.LocationAccuracy.navigation;
      case '가장 높음 (High)':
      default:
        return loc.LocationAccuracy.high;
    }
  }

  int _getInterval() {
    return prefs.getInt('interval') ?? 1000;
  }

  double _getDistanceFilter() {
    return prefs.getDouble('distanceFilter') ?? 5.0;
  }
}