import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:math' show cos, sqrt, asin;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'GhostRun_Resultpage.dart'; // GhostRunResultScreen이 있는 파일
import 'ghostrunpage.dart'; // GhostRunPage가 있는 파일
import 'package:flutter_tts/flutter_tts.dart';
// ✅ [추가] 워치 커넥티비티 임포트
import 'package:watch_connectivity/watch_connectivity.dart';

class GhostRunTrackingPage extends StatefulWidget {
  final Map<String, dynamic> ghostRunData;
  // ✅ [추가] withWatch 변수 추가
  final bool withWatch;

  const GhostRunTrackingPage({
    Key? key,
    required this.ghostRunData,
    this.withWatch = false, // 기본값 false
  }) : super(key: key);

  @override
  State<GhostRunTrackingPage> createState() => _GhostRunTrackingPageState();
}

class _GhostRunTrackingPageState extends State<GhostRunTrackingPage> with WidgetsBindingObserver {
  AppleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Annotation> _markers = {};
  final List<LatLng> _points = [];

  final FlutterTts _flutterTts = FlutterTts();

  late MethodChannel _liveActivityChannel;

  List<Map<String, double>> _ghostPoints = [];
  double _ghostDistanceKm = 0.0;
  int _ghostTotalSeconds = 0;
  String _ghostTimeDisplay = "00:00";
  String _ghostDistanceDisplay = "0.00km";
  String _ghostPaceDisplay = "0:00";
  int _ghostElapsedSeconds = 0;
  int _ghostIndex = 0;
  BitmapDescriptor? _ghostIcon;

  final Location _location = Location();
  LocationData? _currentLocation;
  // ▼▼▼▼▼ [ ✨ 신규 추가 ✨ ] ▼▼▼▼▼
  LocationData? _previousLocationData; // 👈 속도 및 순간이동 감지를 위한 이전 위치 데이터
  // ▲▲▲▲▲ [ ✨ 신규 추가 ✨ ] ▲▲▲▲▲

  bool _isTracking = false;
  bool _isPaused = false;
  Timer? _timer; // 유저 시간 업데이트 타이머
  Timer? _ghostTimer; // 고스트 위치 업데이트 타이머
  int _elapsedSeconds = 0; // 유저 경과 시간
  DateTime? _trackingStartTime; // 트래킹 시작 시간 (재개 시 업데이트됨)
  DateTime? _pauseStartTime; // 일시정지 시작 시간
  Duration _pausedDuration = Duration.zero; // 총 일시정지 시간

  double _distanceKm = 0.0; // 유저 이동 거리
  double _paceMinPerKm = 0.0; // 유저 현재 페이스

  String _timeDisplay = "00:00";
  String _distanceDisplay = "0.00km";
  String _paceDisplay = "0:00";

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _raceStatus = ""; // 경주 상태 메시지 (예: "고스트보다 5초 빠름")
  bool _isAdmin = false;

  bool _followUserLocation = true; // 지도 카메라가 유저를 따라갈지 여부
  StreamSubscription<LocationData>? _locationSubscription; // 위치 구독 (dispose에서 취소 필요)

  String _countdownMessage = "";
  bool _showCountdown = false;
  int _countdown = 3;
  // ✅✅✅ [수정 1/3] 카운트다운 텍스트 크기를 위한 변수 추가
  double _countdownFontSize = 60.0;

  // ✅ [추가] 워치 커넥티비티 변수
  final _watch = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;


  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
    _initTts();

    _liveActivityChannel = const MethodChannel('com.rundventure/liveactivity');

    // ✅ [수정 1/2] Native(Swift)의 App Intent 호출을 수신할 핸들러 설정
    _liveActivityChannel.setMethodCallHandler(_handleNativeMethodCall);

    _loadGhostIcon();
    _loadGhostData();
    _initLocationTracking();
    WidgetsBinding.instance.addObserver(this);

    _startCountdown();

    // ✅ [추가] 워치 리스너 초기화 호출
    _initializeWatchConnectivity();
  }

  // ✅ [수정 2/2] Native(Swift)에서 "handleLiveActivityCommand" 호출 시 실행될 함수
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (!mounted) return; // 위젯이 화면에 없으면 무시

    print("🎯 [DART] Native method call received: ${call.method}");

    if (call.method == 'handleLiveActivityCommand') {
      try {
        final command = (call.arguments as Map<dynamic, dynamic>)['command'] as String?;

        if (command == 'pauseRunning') {
          print("⏸️ [DART] Live Activity로부터 '일시정지' 명령 실행");
          if (!_isPaused) _pauseTracking(); // 👈 고스트런 함수 호출

        } else if (command == 'resumeRunning') {
          print("▶️ [DART] Live Activity로부터 '재개' 명령 실행");
          if (_isPaused) _resumeTracking(); // 👈 고스트런 함수 호출
        }
      } catch (e) {
        print("🚨 [DART] _handleNativeMethodCall Error: $e");
      }
    }
  }

  // ✅ [추가] 워치 리스너 초기화 함수
  void _initializeWatchConnectivity() {
    // '아니요'를 눌렀을 경우 (withWatch == false) 워치 리스너를 활성화하지 않습니다.
    if (!widget.withWatch) return;

    _watchMessageSubscription?.cancel();
    print("🔄 [DART-GhostRace] Initializing watch connectivity listeners...");

    _watchMessageSubscription = _watch.messageStream.listen(
          (message) {
        print("🎯 [DART-GhostRace] Command received: $message");
        if (!mounted) return;

        if (message.containsKey('command')) {
          final command = message['command'] as String;
          switch (command) {
            case 'pauseRunning':
              print("⏸️ [DART-GhostRace] 워치로부터 '일시정지' 명령 실행");
              if (!_isPaused) _pauseTracking();
              break;
            case 'resumeRunning':
              print("▶️ [DART-GhostRace] 워치로부터 '재개' 명령 실행");
              if (_isPaused) _resumeTracking();
              break;
            case 'stopRunning':
              print("⏹️ [DART-GhostRace] 워치로부터 '종료' 명령 실행");
              // '경주' 모드는 워치에서 종료해도 정상 종료 흐름을 따릅니다.
              if (_isTracking) _finishRace();
              break;
          }
        }
      },
      onError: (error) {
        print("🚨 [DART-GhostRace] Error on messageStream: $error");
      },
    );
    print("✅ [DART-GhostRace] Watch connectivity listeners are now active.");
  }


  void _updateLiveActivity() {
    // if (!_isTracking) return; // ✅ [수정] _isPaused 조건 제거 (일시정지 상태도 전송해야 함)
    // 💡 [수정] _isTracking이 false여도 (즉, 종료되었어도) 호출될 수 있으니, _isTracking일 때만 호출하도록 복원
    if (!_isTracking) return;
    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'ghost_race',
      'userTime': _timeDisplay,
      'userDistance': _distanceKm.toStringAsFixed(2),
      'userPace': _paceDisplay,
      'raceStatus': _raceStatus.isNotEmpty ? _raceStatus : "고스트와 경주 중",
      'isPaused': _isPaused, // ✅ [추가] 일시정지 상태 전송
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ghostTimer?.cancel();
    _locationSubscription?.cancel();
    _flutterTts.stop();
    WidgetsBinding.instance.removeObserver(this);
    // ✅ [추가] 워치 구독 취소
    _watchMessageSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isTracking && !_isPaused) {
      setState(() {});
      // ✅ [추가] 앱이 다시 활성화될 때 워치 리스너 재시작
      _initializeWatchConnectivity();
    }
  }

  Future<void> _checkIfAdmin() async {
    final user = _auth.currentUser;
    if (user != null) {
      final idTokenResult = await user.getIdTokenResult(true);
      if (mounted) {
        setState(() {
          _isAdmin = idTokenResult.claims?['isAdmin'] == true;
        });
      }
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    // ✅ [수정] iOS 오디오 설정 강화 (무음 모드 무시 + 스피커 강제 + 음악과 함께 재생)
    await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback, // 👈 'playback'은 무음 모드에서도 소리가 납니다.
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers, // 👈 노래 들으면서도 안내음 나옴
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker // 👈 이어폰 없으면 스피커로 강제
        ],
        IosTextToSpeechAudioMode.voicePrompt
    );

    // ✅ [추가] 공유 인스턴스 활성화 (오류 방지)
    await _flutterTts.setSharedInstance(true);
  }

  Future<void> _speak(String text) async {
    // 💡 [수정] _pauseTracking에서 "일시정지"를 말할 수 있도록 _isPaused 조건 제거
    // (호출하는 쪽에서 _isPaused를 체크하도록 변경)
    await _flutterTts.speak(text);
  }

  // ✅✅✅ [수정 2/3] _startCountdown 함수 수정
  void _startCountdown() {
    setState(() {
      _showCountdown = true;
      _countdownMessage = "준비하세요!";
      _countdownFontSize = 60.0; // "준비하세요!" 텍스트 크기
    });
    _speak("준비하세요");

    // ✅ [수정] 카운트다운 시작 시 워치 상태 설정
    if (widget.withWatch) {
      // ▼▼▼▼▼ [ ✨ 여기가 수정되었습니다 (try-catch 추가) ✨ ] ▼▼▼▼▼
      try {
        _watch.updateApplicationContext({
          'runType': 'ghostRace', // 👈 '경주' 모드
          'isRunning': true,
          'isEnded': false,
        });
      } catch (e) {
        print("워치 Context 업데이트 실패 (정상 동작): $e");
      }
      // ▲▲▲▲▲ [ ✨ 수정 완료 ✨ ] ▲▲▲▲▲
      _watch.sendMessage({'command': 'showWarmup'});
    }

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdownMessage = "$_countdown";
          _countdownFontSize = 60.0; // 숫자 텍스트 크기
        });
        _speak("$_countdown");

        // ✅ [추가] 워치로 카운트다운 숫자 전송
        if (widget.withWatch) {
          _watch.sendMessage({'command': 'countdown', 'value': _countdown});
        }

        _countdown--;
      } else {
        timer.cancel();
        setState(() {
          _countdownMessage = "대결을 시작합니다!";
          _countdownFontSize = 40.0; // 👈 "대결을 시작합니다!" 텍스트 크기 (이 값을 조절하세요)
          _showCountdown = false;
        });
        _speak("대결을 시작합니다!");

        // ✅ [추가] 워치로 시작 신호 전송
        if (widget.withWatch) {
          _watch.sendMessage({'command': 'startRunningUI'});
        }

        _startTracking(); // 유저 타이머 시작
        _startGhostRun(); // 고스트 타이머 시작

        _liveActivityChannel.invokeMethod('startLiveActivity', {
          'type': 'ghost_race',
          'isPaused': false, // ✅ [추가] 초기 상태는 false
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _countdownMessage = "";
            });
          }
        });
      }
    });
  }

  Future<void> _loadGhostIcon() async {
    try {
      final Uint8List markerIcon = await getBytesFromAsset('assets/images/ghostlogo.png', 80);
      _ghostIcon = BitmapDescriptor.fromBytes(markerIcon);
    } catch (e) {
      print('고스트 아이콘 로드 실패: $e');
      _ghostIcon = BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueViolet);
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  void _loadGhostData() {
    List<dynamic> points = widget.ghostRunData['locationPoints'] ?? [];
    _ghostPoints = points.map((point) {
      // GeoPoint 또는 Map 형태 처리
      if (point is GeoPoint) {
        return { 'latitude': point.latitude, 'longitude': point.longitude };
      } else if (point is Map) {
        return { 'latitude': (point['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (point['longitude'] as num?)?.toDouble() ?? 0.0 };
      }
      return {'latitude': 0.0, 'longitude': 0.0}; // 예외 처리
    }).toList();


    _ghostDistanceKm = (widget.ghostRunData['distance'] as num?)?.toDouble() ?? 0.0;
    _ghostTotalSeconds = (widget.ghostRunData['time'] as num?)?.toInt() ?? 0;

    final minutes = _ghostTotalSeconds ~/ 60;
    final seconds = _ghostTotalSeconds % 60;
    _ghostTimeDisplay = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    _ghostDistanceDisplay = "${_ghostDistanceKm.toStringAsFixed(2)}km";

    double ghostPace = 0.0;
    if(_ghostDistanceKm > 0 && _ghostTotalSeconds > 0) { // 0으로 나누기 방지
      ghostPace = (_ghostTotalSeconds / 60) / _ghostDistanceKm;
    }

    if (ghostPace.isFinite && ghostPace > 0) {
      final paceMinutes = ghostPace.floor();
      final paceSeconds = ((ghostPace - paceMinutes) * 60).floor();
      _ghostPaceDisplay = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
    } else {
      _ghostPaceDisplay = "--:--"; // 유효하지 않은 경우
    }
  }

  void _startGhostRun() {
    if (_ghostPoints.isEmpty || _ghostTotalSeconds <= 0) return; // 유효성 검사 추가
    _updateGhostMarker(LatLng(_ghostPoints.first['latitude']!, _ghostPoints.first['longitude']!));
    _ghostTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return; // 일시정지 중이면 고스트도 멈춤
      setState(() {
        _ghostElapsedSeconds++;
        if (_ghostElapsedSeconds >= _ghostTotalSeconds) {
          // 고스트 완주
          _updateGhostMarker(LatLng(_ghostPoints.last['latitude']!, _ghostPoints.last['longitude']!));
          timer.cancel();
          return;
        }
        // 시간 비율에 따라 고스트 위치 계산
        double progressRatio = _ghostElapsedSeconds / _ghostTotalSeconds;
        double expectedDistance = _ghostDistanceKm * progressRatio;
        double calculatedDistance = 0.0;
        for (int i = 0; i < _ghostPoints.length - 1; i++) {
          double segmentDistance = _calculateDistance(
              _ghostPoints[i]['latitude']!, _ghostPoints[i]['longitude']!,
              _ghostPoints[i+1]['latitude']!, _ghostPoints[i+1]['longitude']!
          ) / 1000;

          // 부동 소수점 오차 감안
          if (calculatedDistance + segmentDistance >= expectedDistance - 1e-9) {
            double remainingDistance = expectedDistance - calculatedDistance;
            double segmentProgress = (segmentDistance < 1e-9) ? 1.0 : remainingDistance / segmentDistance; // 0으로 나누기 방지
            segmentProgress = segmentProgress.clamp(0.0, 1.0); // 0~1 범위 유지

            // 선형 보간법으로 현재 위치 계산
            double lat = _ghostPoints[i]['latitude']! + segmentProgress * (_ghostPoints[i+1]['latitude']! - _ghostPoints[i]['latitude']!);
            double lng = _ghostPoints[i]['longitude']! + segmentProgress * (_ghostPoints[i+1]['longitude']! - _ghostPoints[i]['longitude']!);
            _updateGhostMarker(LatLng(lat, lng));
            // 고스트가 지나간 경로를 표시하기 위해 인덱스 업데이트
            if (_ghostIndex != i) {
              _ghostIndex = i;
              // _updateGhostPolylines(); // 필요 시 고스트 경로 업데이트
            }
            break; // 현재 위치 찾았으므로 루프 종료
          }
          calculatedDistance += segmentDistance;
        }
        // 마지막 세그먼트까지 도달했는데도 expectedDistance가 더 큰 경우 (거의 완주 시점)
        if (_ghostElapsedSeconds > 0 && calculatedDistance < expectedDistance) {
          _updateGhostMarker(LatLng(_ghostPoints.last['latitude']!, _ghostPoints.last['longitude']!));
        }
      });
    });
  }

  void _updateGhostMarker(LatLng position) {
    final marker = Annotation(
      annotationId: AnnotationId('ghost_marker'),
      position: position,
      icon: _ghostIcon ?? BitmapDescriptor.defaultAnnotationWithHue(BitmapDescriptor.hueViolet),
      zIndex: 2, // 유저 마커보다 위에 표시될 수 있도록 zIndex 설정
    );
    // 마커 업데이트 전에 mounted 확인 (dispose 후 호출 방지)
    if (mounted) {
      setState(() {
        _markers.removeWhere((m) => m.annotationId.value == 'ghost_marker'); // 기존 마커 제거
        _markers.add(marker); // 새 마커 추가
      });
    }
  }

  void _updateGhostPolylines() {
    // 고스트 전체 경로 표시 (시작 시 한 번만 호출해도 충분할 수 있음)
    if (_ghostPoints.isEmpty) return;
    final ghostPolyline = Polyline(
      polylineId: PolylineId('ghost_track'),
      points: _ghostPoints.map((p) => LatLng(p['latitude']!, p['longitude']!)).toList(),
      color: Colors.purple.withOpacity(0.7), // 반투명 보라색
      width: 5,
    );
    if (mounted) {
      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == 'ghost_track');
        _polylines.add(ghostPolyline);
      });
    }
  }

  void _compareWithGhost() {
    // 유효성 검사 강화
    if (_distanceKm <= 0 || _elapsedSeconds <= 0 || _ghostDistanceKm <= 0 || !_paceMinPerKm.isFinite || _paceMinPerKm <= 0) return;
    // 현재 페이스로 완주 시 예상 시간 계산
    double expectedFinishTime = _paceMinPerKm * _ghostDistanceKm * 60; // 초 단위
    // 고스트 기록과의 시간 차이
    double timeDifference = expectedFinishTime - _ghostTotalSeconds; // 초 단위

    // 상태 메시지 업데이트
    if (timeDifference < -1) { // 1초 이상 빠를 때
      _raceStatus = "고스트보다 약 ${timeDifference.abs().toStringAsFixed(0)}초 빠릅니다";
    } else if (timeDifference > 1) { // 1초 이상 느릴 때
      _raceStatus = "고스트보다 약 ${timeDifference.toStringAsFixed(0)}초 느립니다";
    } else { // ±1초 이내일 때
      _raceStatus = "고스트와 비슷한 페이스입니다";
    }
  }

  Future<void> _initLocationTracking() async {
    try {
      // 위치 서비스 활성화 확인 및 요청
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 서비스 필요')));
            Navigator.pop(context);
          }
          return;
        }
      }
      // 위치 권한 확인 및 요청
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          if (mounted) {
            await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('권한 필요'), content: const Text('위치 권한 필요'), actions: [TextButton(onPressed: ()=>Navigator.of(ctx).pop(), child: const Text('확인'))]));
            Navigator.of(context).pop();
          }
          return;
        }
      }

      // 위치 설정 및 백그라운드 모드 활성화
      await _location.changeSettings(accuracy: LocationAccuracy.high, interval: 1000, distanceFilter: 0);
      await _location.enableBackgroundMode(enable: true);
      _currentLocation = await _location.getLocation();
      _previousLocationData = _currentLocation; // 👈 [추가] 초기 위치를 이전 위치로 설정
      if(mounted) setState(() {}); // 초기 위치 설정 후 UI 업데이트

      // 위치 변경 감지 리스너 설정
      _locationSubscription = _location.onLocationChanged.listen((LocationData newLocation) {
        // 유효성 검사 강화
        if (!_isTracking || _isPaused || !mounted || _trackingStartTime == null) return;
        if (newLocation.latitude == null || newLocation.longitude == null || (newLocation.accuracy != null && newLocation.accuracy! > 20)) return;

        final newPoint = LatLng(newLocation.latitude!, newLocation.longitude!);

        // ▼▼▼▼▼ [ ✨✨✨ 핵심 수정: _previousLocationData 사용 ✨✨✨ ] ▼▼▼▼▼
        // 1. 이전 위치 데이터 가져오기
        LocationData? lastLoc = _previousLocationData;

        // 2. UI 및 카메라 업데이트
        if(mounted) {
          setState(() {
            _currentLocation = newLocation;
            // 카메라가 유저를 따라가도록 설정되어 있으면 지도 이동
            if (_followUserLocation && _mapController != null) {
              // 비동기로 카메라 이동 (UI 블로킹 방지)
              Future(() => _mapController!.animateCamera(CameraUpdate.newLatLng(newPoint)));
            }
          });
        }

        // 3. 이전 위치가 있을 때만 거리/속도 계산 및 검사
        if (lastLoc != null) {
          final distanceInMeters = _calculateDistance(
              lastLoc.latitude!, lastLoc.longitude!,
              newPoint.latitude!, newPoint.longitude!
          );

          // ▼▼▼▼▼ [ ✨ 신규 추가: 비정상 이동 방지 로직 ✨ ] ▼▼▼▼▼
          // 시간 간격 계산
          double timeIntervalSec = (newLocation.time! - (lastLoc.time ?? 0)) / 1000;
          if (timeIntervalSec <= 0) timeIntervalSec = 0.5; // 0 나누기 방지

          // 속도 계산 (m/s)
          double speed = distanceInMeters / timeIntervalSec;

          // 1. 순간이동 감지 (2초 이내 50m 초과)
          if (distanceInMeters > 50.0) {
            print('비정상적인 거리 이동(순간이동) 감지: $distanceInMeters m. 무시합니다.');
            _previousLocationData = newLocation; // 👈 위치는 갱신하지만
            return; // 👈 거리/경로에 추가 안 함.
          }

          // 2. 비현실적인 속도 감지 (시속 36km/h 초과)
          if (speed > 10.0) {
            print('비현실적인 속도 감지: $speed m/s. 무시합니다.');
            _previousLocationData = newLocation; // 👈 위치는 갱신하지만
            return; // 👈 거리/경로에 추가 안 함.
          }
          // ▲▲▲▲▲ [ ✨ 신규 추가 ✨ ] ▲▲▲▲▲

          // 기존의 작은 이동 무시
          if (distanceInMeters < 2) {
            _previousLocationData = newLocation; // 👈 위치는 갱신하지만
            return;
          }

          // --- 모든 검사 통과 ---
          _distanceKm += distanceInMeters / 1000; // 거리를 km 단위로 누적
          _distanceDisplay = "${_distanceKm.toStringAsFixed(2)}km"; // 표시용 거리 문자열 업데이트

          // 현재 경과 시간 계산
          final elapsed = DateTime.now().difference(_trackingStartTime!) - _pausedDuration;
          _elapsedSeconds = elapsed.inSeconds;

          // 유효한 거리와 시간이 있을 때 페이스 계산
          if (_distanceKm > 0 && _elapsedSeconds > 0) {
            _paceMinPerKm = (_elapsedSeconds / 60) / _distanceKm; // 분/km 단위 페이스 계산
            if (_paceMinPerKm.isFinite && _paceMinPerKm > 0) { // 유효한 페이스 값인지 확인
              final paceMinutes = _paceMinPerKm.floor(); // 분
              final paceSeconds = ((_paceMinPerKm - paceMinutes) * 60).round().clamp(0, 59); // 초 (0~59 범위)
              _paceDisplay = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}"; // 표시용 페이스 문자열 업데이트
            } else {
              _paceDisplay = "--:--"; // 유효하지 않으면 기본값
            }
            _compareWithGhost(); // 고스트와 비교
          } else {
            _paceDisplay = "--:--";
          }
        }

        // 4. 검사를 통과했거나, 첫 번째 위치일 경우 경로에 추가
        _points.add(newPoint); // 현재 위치를 경로에 추가
        _updatePolylines(); // 지도에 경로 업데이트

        // 5. 현재 위치를 다음 계산을 위한 "이전 위치"로 저장
        _previousLocationData = newLocation;
        // ▲▲▲▲▲ [ ✨✨✨ 핵심 수정 완료 ✨✨✨ ] ▲▲▲▲▲

        // ✅ [수정] 위치 변경 시 워치로 데이터 전송
        if (widget.withWatch) {
          _sendWatchData();
        }

        _updateLiveActivity(); // 라이브 액티비티 업데이트

        // 유저 거리가 고스트 목표 거리를 넘으면 레이스 종료
        if (_ghostDistanceKm > 0 && _distanceKm >= _ghostDistanceKm) {
          _finishRace();
        }
      });
    } catch (e) {
      print("위치 초기화 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('위치 서비스 오류: $e')));
        Navigator.pop(context);
      }
    }
  }


  // ✅ [추가] 워치로 데이터를 전송하는 별도 함수
  void _sendWatchData() {
    if (!widget.withWatch || !_isTracking || _isPaused) return;

    // paceMinPerKm이 유효하지 않으면 0.0 전송
    double paceToSend = (_paceMinPerKm.isFinite && _paceMinPerKm > 0) ? _paceMinPerKm : 0.0;

    _watch.sendMessage({
      'type': 'main',
      'kilometers': _distanceKm,
      'seconds': _elapsedSeconds,
      'pace': paceToSend, // 유효한 페이스 또는 0.0 전송
      'calories': 0.0, // 고스트런은 칼로리 없음
      'raceStatus': _raceStatus, // ✅ 경주 상태 포함
      'isEnded': false,
    });
  }

  void _startTracking() {
    _trackingStartTime = DateTime.now(); // 현재 시간을 시작 시간으로 기록
    _pausedDuration = Duration.zero; // 총 일시정지 시간 초기화
    _pauseStartTime = null; // 일시정지 시작 시간 초기화
    _isTracking = true;
    _isPaused = false;

    // 1초마다 유저 시간 업데이트하는 타이머 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused || !_isTracking || _trackingStartTime == null) return; // 유효성 검사 강화

      // 현재 시간과 시작 시간의 차이에서 총 일시정지 시간을 빼서 실제 경과 시간 계산
      final elapsed = DateTime.now().difference(_trackingStartTime!) - _pausedDuration;
      setState(() {
        _elapsedSeconds = elapsed.inSeconds; // 초 단위로 저장
        final minutes = _elapsedSeconds ~/ 60; // 분 계산
        final seconds = _elapsedSeconds % 60; // 초 계산
        _timeDisplay = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"; // 표시용 시간 문자열 업데이트

        // ✅ [수정] 1초 타이머에서도 워치로 데이터 전송
        if (widget.withWatch) {
          _sendWatchData();
        }

        _updateLiveActivity(); // 라이브 액티비티 업데이트
      });
    });
  }

  void _pauseTracking() {
    if (_trackingStartTime != null && !_isPaused) { // 러닝 중에만 누적
      // 💡 [수정] _pausedDuration 계산 로직 수정
      // _pausedDuration += DateTime.now().difference(_trackingStartTime!); // ⛔️ 제거
      _pauseStartTime = DateTime.now(); // 👈 [추가] 일시정지 시작 시간만 기록
    }
    // 💡 [수정] _speak 호출을 setState 전에
    _speak("일시정지");
    setState(() {
      _isPaused = true;
      // _trackingStartTime = null; // ⛔️ 제거 (재개 시 _pausedDuration 계산에 필요)
    });

    // ✅ [추가] 워치로 일시정지 명령 전송
    if (widget.withWatch) {
      _watch.sendMessage({'command': 'pauseFromPhone'});
    }

    // ✅ [추가] 일시정지 즉시 Live Activity 업데이트
    _updateLiveActivity();
  }

  void _resumeTracking() {
    // 💡 [수정] 총 일시정지 시간 누적
    if (_pauseStartTime != null) { // 일시정지 시작 시간이 기록되어 있으면
      _pausedDuration += DateTime.now().difference(_pauseStartTime!); // 총 일시정지 시간에 더함
    }
    // _trackingStartTime = DateTime.now(); // ⛔️ 제거 (기존 시작 시간 유지)
    _pauseStartTime = null; // 일시정지 시작 시간 초기화
    setState(() {
      _isPaused = false;
    });
    // 💡 [수정] _speak 호출을 setState 이후에
    _speak("운동을 다시 시작합니다");

    // ✅ [추가] 워치로 재개 명령 전송
    if (widget.withWatch) {
      _watch.sendMessage({'command': 'resumeFromPhone'});
    }

    // ✅ [추가] 재개 즉시 Live Activity 업데이트
    _updateLiveActivity();
  }

  // 트래킹 관련 리소스 정리 함수
  void _stopAndCleanUp() {
    _timer?.cancel();
    _ghostTimer?.cancel();
    _locationSubscription?.cancel();
    // 라이브 액티비티 종료 시도 (오류 발생 가능성 있음)
    try {
      _liveActivityChannel.invokeMethod('stopLiveActivity', {
        'type': 'ghost_race',
      });
    } catch (e) {
      print("라이브 액티비티 종료 오류: $e");
    }
  }

  // 종료 확인 다이얼로그
  Future<bool> _showStopConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('러닝 중지', style: TextStyle(color: Colors.white)),
        content: const Text('러닝을 중지하고 이전 화면으로 돌아가시겠습니까?\n(기록은 저장되지 않습니다)', style: TextStyle(color: Colors.white)),
        actions: <Widget>[
          TextButton(
            child: const Text('아니오', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('예', style: TextStyle(color: Colors.blue)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;
  }

  // 레이스 완료 처리 함수
  Future<void> _finishRace() async {
    if (!_isTracking) return; // 이미 종료 처리가 시작되었으면 중복 실행 방지
    _isTracking = false; // 트래킹 상태 비활성화

    // 💡 [추가] 최종 경과 시간 계산 (일시정지 상태에서 종료 시)
    if (_isPaused && _pauseStartTime != null) {
      // _pauseTracking 로직과 동일하게, 마지막 _pausedDuration을 확정
      // _pausedDuration += DateTime.now().difference(_trackingStartTime!); // ⛔️ _trackingStartTime이 null일 수 있음
      // _pauseStartTime을 기준으로 계산해야 함
      _pausedDuration += DateTime.now().difference(_pauseStartTime!); // 👈 마지막 일시정지 시간 누적
      _pauseStartTime = null;
    }

    // 💡 [추가] _trackingStartTime이 null이 아닌지 확인
    if (_trackingStartTime != null) {
      final elapsed = DateTime.now().difference(_trackingStartTime!) - _pausedDuration;
      _elapsedSeconds = elapsed.inSeconds; // 최종 시간 확정
    }
    // _elapsedSeconds는 타이머에 의해 이미 최신 상태일 것이나, 안전장치로 재계산


    // 승패 판정
    final bool isWin = _elapsedSeconds < _ghostTotalSeconds;
    final String raceResult = isWin ? 'win' : (_elapsedSeconds == _ghostTotalSeconds ? 'tie' : 'lose');

    // ✅ [수정] 워치 종료 명령 전송 (최종 데이터 + 승패 결과 포함)
    if (widget.withWatch) {
      double finalPace = (_ghostDistanceKm > 0 && _elapsedSeconds > 0) ? (_elapsedSeconds / 60) / _ghostDistanceKm : 0.0;
      if (!finalPace.isFinite) finalPace = 0.0; // 유효성 검사

      _watch.sendMessage({
        'command': 'stopFromPhone', // 👈 워치 요약 화면 표시 명령
        'kilometers': _ghostDistanceKm, // 최종 유저 거리 (목표 거리)
        'seconds': _elapsedSeconds,   // 최종 유저 시간
        'pace': finalPace,        // 최종 유저 페이스
        'calories': 0.0,              // 칼로리 없음
        'raceOutcome': raceResult,    // 🏁 승패 결과 ('win', 'lose', 'tie')
        'isEnded': true,
      });

      // ▼▼▼▼▼ [ ✨ 여기가 수정되었습니다 (try-catch, await 추가) ✨ ] ▼▼▼▼▼
      try {
        await _watch.updateApplicationContext({
          'runType': 'ghostRace', // 👈 런 타입 재확인
          'isRunning': false,
          'isEnded': true          // 👈 종료 상태로 변경
        });
      } catch (e) {
        print("워치 Context 업데이트 실패 (정상 동작): $e");
      }
      // ▲▲▲▲▲ [ ✨ 수정 완료 ✨ ] ▲▲▲▲▲
    }

    _stopAndCleanUp(); // 타이머, 위치 구독 등 정리


    // 결과 음성 안내
    // 💡 [수정] _isPaused 상태와 관계없이 종료 음성 안내
    if (raceResult == 'win') _speak("승리했습니다!");
    else if (raceResult == 'lose') _speak("아쉽지만 패배했습니다.");
    else _speak("무승부입니다.");

    // 고스트 최종 페이스 계산
    double ghostPaceResult = 0.0;
    if (_ghostDistanceKm > 0 && _ghostTotalSeconds > 0) { // 0 나누기 방지
      ghostPaceResult = (_ghostTotalSeconds / 60) / _ghostDistanceKm;
    }
    if (!ghostPaceResult.isFinite) ghostPaceResult = 0.0; // 유효성 검사

    // 💡 [수정] 최종 페이스 재계산 (0 나누기 방지)
    if (_ghostDistanceKm > 0 && _elapsedSeconds > 0) {
      _paceMinPerKm = (_elapsedSeconds / 60) / _ghostDistanceKm;
    } else {
      _paceMinPerKm = 0.0;
    }


    // 결과 데이터 구성
    final Map<String, dynamic> userResult = {
      'time': _elapsedSeconds,
      'distance': _ghostDistanceKm, // 유저가 완주한 거리는 고스트 거리와 동일
      'pace': (_paceMinPerKm.isFinite && _paceMinPerKm > 0) ? _paceMinPerKm : 0.0, // 유효값 또는 0
      'locationPoints': _points.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
    };
    final Map<String, dynamic> ghostResult = {
      'time': _ghostTotalSeconds,
      'distance': _ghostDistanceKm,
      'pace': ghostPaceResult,
      'locationPoints': _ghostPoints.map((p) {
        // Null safety check
        final lat = p['latitude'];
        final lng = p['longitude'];
        if (lat != null && lng != null) {
          return GeoPoint(lat, lng);
        }
        return GeoPoint(0,0); // 기본값 또는 오류 처리
      }).toList(),
    };

    // 기록 저장
    await _saveRunRecord(raceResult: raceResult);

    // 결과 화면으로 이동
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GhostRunResultScreen(
            userResult: userResult,
            ghostResult: ghostResult,
            isWin: isWin,
          ),
        ),
      );
    }
  }

  // 관리자 모드 즉시 종료 함수
  Future<void> _finishForAdmin() async {
    if (!_isTracking) return;
    _isTracking = false;

    // 가짜 결과 생성 (무조건 승리)
    final double finalDistance = _distanceKm > 0.1 ? _distanceKm : _ghostDistanceKm; // 최소 0.1km 또는 고스트 거리
    final int finalTime = _ghostTotalSeconds > 10 ? _ghostTotalSeconds - 10 : 50; // 고스트보다 10초 빠르게 (최소 50초)
    final double finalPace = (finalDistance > 0 && finalTime > 0) ? (finalTime / 60) / finalDistance : 0.0; // 0 나누기 방지
    final bool isWin = true;
    final String raceResult = 'win';

    // ✅ [수정] 워치 종료 명령 전송 (가짜 최종 데이터 + 승패 결과 포함)
    if (widget.withWatch) {
      _watch.sendMessage({
        'command': 'stopFromPhone',
        'kilometers': finalDistance,
        'seconds': finalTime,
        'pace': finalPace.isFinite ? finalPace : 0.0, // 유효성 검사
        'calories': 0.0,
        'raceOutcome': raceResult, // 🏁 승패 결과
        'isEnded': true,
      });

      // ▼▼▼▼▼ [ ✨ 여기가 수정되었습니다 (try-catch, await 추가) ✨ ] ▼▼▼▼▼
      try {
        await _watch.updateApplicationContext({
          'runType': 'ghostRace',
          'isRunning': false,
          'isEnded': true
        });
      } catch (e) {
        print("워치 Context 업데이트 실패 (정상 동작): $e");
      }
      // ▲▲▲▲▲ [ ✨ 수정 완료 ✨ ] ▲▲▲▲▲
    }

    _stopAndCleanUp();
    _speak("관리자 모드로 경기를 종료합니다.");

    // 가짜 결과 데이터 구성
    final Map<String, dynamic> userResult = {
      'time': finalTime,
      'distance': finalDistance,
      'pace': finalPace.isFinite ? finalPace : 0.0, // 유효성 검사
      'locationPoints': _points.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
    };
    final Map<String, dynamic> ghostResult = {
      'time': _ghostTotalSeconds,
      'distance': _ghostDistanceKm,
      'pace': (_ghostDistanceKm > 0 && _ghostTotalSeconds > 0) ? (_ghostTotalSeconds / 60) / _ghostDistanceKm : 0.0, // 0 나누기 방지 및 유효성 검사
      'locationPoints': _ghostPoints.map((p) {
        final lat = p['latitude'];
        final lng = p['longitude'];
        if (lat != null && lng != null) {
          return GeoPoint(lat, lng);
        }
        return GeoPoint(0,0);
      }).toList(),
    };

    // 가짜 기록 저장
    await _saveRunRecord(raceResult: raceResult, userDistance: finalDistance, userTime: finalTime, userPace: finalPace.isFinite ? finalPace : 0.0);

    // 결과 화면으로 이동
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GhostRunResultScreen(
            userResult: userResult,
            ghostResult: ghostResult,
            isWin: isWin,
          ),
        ),
      );
    }
  }

  // 파이어베이스에 기록 저장 함수
// ✅✅✅ [핵심 수정] _saveRunRecord 함수 ✅✅✅
  // 파이어베이스에 기록 저장 함수 (WriteBatch 사용 및 경험치 추가)
  Future<void> _saveRunRecord({required String raceResult, double? userDistance, int? userTime, double? userPace}) async {
    try {
      final String userEmail = _auth.currentUser?.email ?? '';
      if (userEmail.isEmpty) return; // 이메일 없으면 저장 불가
      final now = DateTime.now();

      // 💡 [수정] _paceMinPerKm이 null이 될 수 있는 가능성 보완
      double finalPace = userPace ?? _paceMinPerKm;
      if (finalPace <= 0 && (userDistance ?? _ghostDistanceKm) > 0 && (userTime ?? _elapsedSeconds) > 0) {
        finalPace = ((userTime ?? _elapsedSeconds) / 60) / (userDistance ?? _ghostDistanceKm);
      }

      // 저장할 데이터 맵 구성
      final record = {
        'date': Timestamp.fromDate(now), // 현재 시간
        'time': userTime ?? _elapsedSeconds, // 관리자 종료 시 받은 시간 or 실제 경과 시간
        'distance': userDistance ?? _ghostDistanceKm, // 관리자 종료 시 받은 거리 or 고스트 거리
        'pace': finalPace.isFinite ? finalPace : 0.0, // 유효성 검사 추가
        'isFirstRecord': false, // 경주 모드이므로 항상 false
        'locationPoints': _points.map((p) => GeoPoint(p.latitude, p.longitude)).toList(), // 유저 경로
        'ghostRecordId': widget.ghostRunData['id'] ?? '', // 대결한 고스트 기록 ID
        'raceResult': raceResult, // 승/패/무승부 결과
        'isLatestRecord': raceResult == 'win', // 승리했을 때만 최신 기록으로 표시
      };

      // --- WriteBatch 시작 ---
      WriteBatch batch = _firestore.batch();

      // 1. 'records' 컬렉션에 새 문서 추가 (batch용 참조 생성)
      DocumentReference docRef = _firestore.collection('ghostRunRecords').doc(userEmail).collection('records').doc();
      batch.set(docRef, record);

      // 2. 승리했을 경우, 유저 문서에 최신 기록 정보 업데이트
      if (raceResult == 'win') {
        // 2a. (기존) latestRecordId 업데이트
        final userGhostDocRef = _firestore.collection('ghostRunRecords').doc(userEmail);
        batch.set(userGhostDocRef, {
          'latestRecordId': docRef.id, // 새로 추가된 문서 ID
          'latestRecordDate': Timestamp.fromDate(now), // 기록 시간
        }, SetOptions(merge: true)); // 기존 필드가 있으면 덮어쓰지 않고 병합

        // 2b. (신규) 보너스 경험치 지급
        final int victoryBonusExp = 100; // 🏆 승리 보너스 (100 EXP)
        final userRankingRef = _firestore.collection('users').doc(userEmail);

        // users 컬렉션의 주간/월간 경험치 증가
        batch.update(userRankingRef, {
          'weeklyExp': FieldValue.increment(victoryBonusExp),
          'monthlyExp': FieldValue.increment(victoryBonusExp),
          // 'totalXp': FieldValue.increment(victoryBonusExp), // (필요시)
        });
        print("✅ 고스트런 승리! 보너스 +${victoryBonusExp} EXP 지급");
      }

      // 3. Batch 실행
      await batch.commit();
      // --- WriteBatch 종료 ---

    } catch (e) {
      print('기록 저장 중 오류 발생: $e');
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("기록 저장 실패: $e")));
      }
    }
  }

  // 두 지점 간 거리 계산 함수 (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // 파이 / 180 (라디안 변환용)
    const earthRadiusKm = 6371.0; // 지구 반지름 (km)
    // 위도/경도 차이를 라디안으로 변환하고 Haversine 공식 적용
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 2 * earthRadiusKm * asin(sqrt(a)) * 1000; // 결과를 미터 단위로 반환
  }

  // 고스트 현재 위치로 지도 이동 함수
  void _moveToGhost() {
    if (_ghostPoints.isNotEmpty && _mapController != null) {
      // 현재 고스트 인덱스에 해당하는 위치 가져오기
      // 💡 [수정] _ghostIndex가 _ghostPoints 길이를 넘지 않도록 clamp
      int safeIndex = _ghostIndex.clamp(0, _ghostPoints.length - 1);
      LatLng ghostPosition = LatLng(_ghostPoints[safeIndex]['latitude']!, _ghostPoints[safeIndex]['longitude']!);
      // 지도를 해당 위치로 애니메이션 이동 (줌 레벨 16)
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(ghostPosition, 16.0));
    }
  }

  // 유저 경로 Polyline 업데이트 함수
  void _updatePolylines() {
    if (_points.isEmpty) return; // 경로 없으면 무시
    // 유저 경로 Polyline 생성
    final myPolyline = Polyline(
      polylineId: PolylineId('run_track'), // ID 설정
      points: List.from(_points), // 현재까지 기록된 모든 지점 사용
      color: Colors.blue, // 파란색
      width: 5, // 두께 5
    );
    setState(() {
      // 기존 유저 경로 Polyline 제거 후 새로 추가
      _polylines.removeWhere((p) => p.polylineId.value == 'run_track');
      _polylines.add(myPolyline);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 뒤로가기 버튼 처리 (종료 확인 다이얼로그 표시)
    return WillPopScope(
      onWillPop: () async {
        bool stop = await _showStopConfirmDialog();
        if (stop && mounted) {
          _stopAndCleanUp();
          // GhostRunPage로 돌아가기 (이전 화면 스택 모두 제거)
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => GhostRunPage()), (route) => false);
        }
        return false; // WillPopScope 자체 뒤로가기 비활성화
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 지도 표시 영역
            AppleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentLocation?.latitude ?? 37.5665, _currentLocation?.longitude ?? 126.9780), // 초기 위치 (없으면 서울 시청)
                zoom: 16.0,
              ),
              mapType: MapType.standard, // 표준 지도 타입
              myLocationEnabled: true, // 내 위치 표시 활성화
              myLocationButtonEnabled: false, // 기본 내 위치 버튼 비활성화
              zoomGesturesEnabled: true, // 줌 제스처 활성화
              polylines: _polylines, // 지도에 표시할 경로들
              annotations: _markers, // 지도에 표시할 마커들 (고스트 위치)
              onMapCreated: (AppleMapController controller) {
                // 지도 컨트롤러 초기화
                _mapController = controller;
                _updateGhostPolylines(); // 고스트 전체 경로 표시
              },
            ),
            // ✅✅✅ [수정 3/3] 카운트다운 오버레이 Text 위젯 수정
            // 카운트다운 오버레이
            if (_showCountdown || _countdownMessage.isNotEmpty)
              Container(
                color: Colors.black.withOpacity(0.8), // 반투명 검정 배경
                alignment: Alignment.center,
                child: Text(
                  _countdownMessage,
                  // const TextStyle을 TextStyle로 변경하고 _countdownFontSize 변수 사용
                  style: TextStyle(color: Colors.white, fontSize: _countdownFontSize, fontWeight: FontWeight.bold),
                ),
              ),
            // 상단 뒤로가기 버튼
            Positioned(
              top: 40,
              left: 10,
              child: GestureDetector(
                onTap: () async {
                  bool stop = await _showStopConfirmDialog();
                  if (stop && mounted) {
                    _stopAndCleanUp();
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => GhostRunPage()), (route) => false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
            // 상단 중앙 타이틀
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                  child: const Text('고스트런', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            // 관리자 모드 즉시 종료 버튼
            if (_isAdmin)
              Positioned(
                top: 40,
                right: 10,
                child: GestureDetector(
                  onTap: _finishForAdmin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('테스트 종료', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            // 경주 상태 메시지 (트래킹 중에만 표시)
            if (_isTracking)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      _raceStatus.isEmpty ? '고스트와 경주 중입니다!' : _raceStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            // 고스트 위치로 이동 버튼
            Positioned(
              top: 140,
              right: 10,
              child: GestureDetector(
                // 누르고 있을 때: 고스트 위치로 이동, 카메라 따라가기 비활성화
                onTapDown: (_) { setState(() { _followUserLocation = false; }); _moveToGhost(); },
                // 뗄 때: 카메라 따라가기 다시 활성화, 내 위치로 복귀
                onTapUp: (_) { setState(() { _followUserLocation = true; }); if (_currentLocation != null && _mapController != null) { _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!))); } },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                  child: Image.asset('assets/images/ghostlogo.png', width: 24, height: 24, color: Colors.purple, fit: BoxFit.contain), // 고스트 아이콘
                ),
              ),
            ),
            // 하단 정보 및 컨트롤 패널
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8), // 반투명 검정 배경
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만 차지
                  children: [
                    // 유저 정보 표시 영역
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        const Text("Me", style: TextStyle(color: Colors.white, fontSize: 12)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildInfoBox(_timeDisplay, "Time", Colors.white)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInfoBox(_distanceDisplay, "Km", Colors.white)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInfoBox(_paceDisplay, "min/km", Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 고스트 정보 표시 영역
                    Row(
                      children: [
                        Image.asset('assets/images/ghostlogo.png', width: 16, height: 16, color: Colors.purple, fit: BoxFit.contain), // 고스트 아이콘
                        const SizedBox(width: 4),
                        const Text("Ghost", style: TextStyle(color: Colors.purple, fontSize: 12)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildInfoBox(_ghostTimeDisplay, "Time", Colors.purple)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInfoBox(_ghostDistanceDisplay, "Km", Colors.purple)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInfoBox(_ghostPaceDisplay, "min/km", Colors.purple)), // 고스트 페이스 표시
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 컨트롤 버튼 영역 (일시정지/재개)
                    if (!_isPaused) // 러닝 중일 때
                      Center(
                        child: GestureDetector(
                          onTap: _pauseTracking, // 탭하면 일시정지
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange), // 주황색 원
                            child: const Icon(Icons.pause, color: Colors.white, size: 32), // 일시정지 아이콘
                          ),
                        ),
                      )
                    else // 일시정지 중일 때
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _resumeTracking, // 탭하면 재개
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green), // 초록색 원
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32), // 재생 아이콘
                            ),
                          ),
                          // 여기에 종료 버튼 추가 가능 (GhostRun_FirstTrackingPage 참고)
                          // 예:
                          // const SizedBox(width: 40),
                          // GestureDetector(onTap: _finishRace, ... ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 정보 표시용 작은 박스 위젯 빌더
  Widget _buildInfoBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.black), // 검정 배경, 둥근 모서리
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)), // 값 (주어진 색상)
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), // 레이블 (회색)
        ],
      ),
    );
  }
}