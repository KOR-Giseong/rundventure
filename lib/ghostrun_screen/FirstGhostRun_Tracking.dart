import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:math' show cos, sqrt, asin;
import 'GhosRun_Setting.dart'; // 오타 수정: GhostRun_Setting.dart 가정
import 'ghostrunpage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

class FirstGhostRunTrackingPage extends StatefulWidget {
  final bool withWatch;

  const FirstGhostRunTrackingPage({
    Key? key,
    this.withWatch = false,
  }) : super(key: key);

  @override
  State<FirstGhostRunTrackingPage> createState() =>
      _FirstRunTrackingPageState();
}

class _FirstRunTrackingPageState extends State<FirstGhostRunTrackingPage> with WidgetsBindingObserver {
  final FlutterTts _flutterTts = FlutterTts();

  late MethodChannel _liveActivityChannel;

  AppleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final List<LatLng> _points = [];
  final Location _location = Location();
  LocationData? _currentLocation;
  LocationData? _previousLocationData;
  bool _isTracking = false;
  bool _isPaused = false;
  Timer? _timer; // UI 업데이트 타이머 (기존 _uiTimer 역할 통합)
  Timer? _autoSaveTimer;
  bool _autoSaved = false;
  double _distanceKm = 0.0;
  double _paceMinPerKm = 0.0; // 최종 저장용 페이스
  double _smoothedPace = 0.0; // UI 표시 및 워치 전송용 페이스
  int _lastAnnouncedKm = 0;
  String _timeDisplay = "00:00";
  String _distanceDisplay = "0.00";
  String _paceDisplay = "--:--"; // 초기값 변경
  DateTime? _startTime; // 트래킹 시작 또는 재개 시간
  Duration _pausedElapsed = Duration.zero; // 총 일시정지 시간

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _countdownMessage = "";
  bool _showCountdown = false;
  int _countdown = 3;
  double _countdownFontSize = 60.0;

  String _autoSaveStatus = "자동 저장 설정 확인 중...";

  StreamSubscription<LocationData>? _locationSubscription;

  final _watch = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _liveActivityChannel = const MethodChannel('com.rundventure/liveactivity');

    _liveActivityChannel.setMethodCallHandler(_handleNativeMethodCall);

    _initTts();
    _initLocationTracking();
    _startCountdown();
    _loadAutoSaveStatus();

    _initializeWatchConnectivity();
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (!mounted) return; // 위젯이 화면에 없으면 무시

    print("🎯 [DART] Native method call received: ${call.method}");

    if (call.method == 'handleLiveActivityCommand') {
      try {
        final command = (call.arguments as Map<dynamic, dynamic>)['command'] as String?;

        if (command == 'pauseRunning') {
          print("⏸️ [DART] Live Activity로부터 '일시정지' 명령 실행");
          if (!_isPaused) _pauseTracking();

        } else if (command == 'resumeRunning') {
          print("▶️ [DART] Live Activity로부터 '재개' 명령 실행");
          if (_isPaused) _resumeTracking();
        }
      } catch (e) {
        print("🚨 [DART] _handleNativeMethodCall Error: $e");
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _timer?.cancel(); // _uiTimer 대신 _timer 사용
    _autoSaveTimer?.cancel();
    _flutterTts.stop();

    _watchMessageSubscription?.cancel();

    super.dispose();
  }

  void _initializeWatchConnectivity() {
    // 워치 사용 안 함 옵션 선택 시 리스너 활성화 안 함
    if (!widget.withWatch) return;

    _watchMessageSubscription?.cancel(); // 기존 구독 취소
    print("🔄 [DART-GhostRecord] Initializing watch connectivity listeners...");

    _watchMessageSubscription = _watch.messageStream.listen(
          (message) {
        print("🎯 [DART-GhostRecord] Command received: $message");
        if (!mounted) return; // 위젯 unmount 시 처리 중단

        if (message.containsKey('command')) {
          final command = message['command'] as String;
          switch (command) {
            case 'pauseRunning':
              print("⏸️ [DART-GhostRecord] 워치로부터 '일시정지' 명령 실행");
              if (!_isPaused) _pauseTracking(); // 일시정지 상태 아닐 때만 실행
              break;
            case 'resumeRunning':
              print("▶️ [DART-GhostRecord] 워치로부터 '재개' 명령 실행");
              if (_isPaused) _resumeTracking(); // 일시정지 상태일 때만 실행
              break;
            case 'stopRunning':
              print("⏹️ [DART-GhostRecord] 워치로부터 '종료' 명령 실행");
              // '첫 기록' 모드는 워치에서 종료해도 무조건 저장하고 종료
              if (_isTracking) _finishTracking(save: true);
              break;
          }
        }
      },
      onError: (error) {
        print("🚨 [DART-GhostRecord] Error on messageStream: $error");
      },
    );
    print("✅ [DART-GhostRecord] Watch connectivity listeners are now active.");
  }


  void _updateLiveActivity() {
    // 라이브 액티비티 업데이트
    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'ghost_record', // 라이브 액티비티 타입
      'time': _timeDisplay,
      'distance': _distanceDisplay,
      'pace': _paceDisplay,
      'isPaused': _isPaused,
    });
  }


  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker
        ],
        IosTextToSpeechAudioMode.voicePrompt
    );

    await _flutterTts.setSharedInstance(true);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  /// 지도 카메라 위치를 비동기적으로 업데이트하는 함수
  Future<void> _updateCameraPosition(LatLng newPoint) async {
    if (_mapController == null || !mounted) return; // 컨트롤러 없거나 unmount 시 중단
    try {
      // 현재 줌 레벨 가져오기 (비동기)
      final double? currentZoom = await _mapController!.getZoomLevel();
      // await 후에도 mounted 상태인지 재확인 (중요)
      if (mounted && currentZoom != null) {
        // 현재 줌 레벨 유지하며 새 위치로 카메라 이동 애니메이션
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(newPoint, currentZoom));
      }
    } catch (e) {
      print("Error getting zoom level or animating camera: $e");
    }
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
        backgroundColor: isError ? Colors.redAccent.shade400 : Colors.purpleAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2), // 오류 시 더 길게
      ),
    );
  }

  Future<void> _initLocationTracking() async {
    try {
      // 위치 서비스 활성화 확인 및 요청
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            _showCustomSnackBar('러닝을 시작하려면 위치 서비스를 켜주세요.', isError: true);
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
          // 권한 거부 시 다이얼로그 표시 후 화면 종료
          if (mounted) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('권한 필요'),
                content: const Text('러닝 기능을 사용하려면 위치 정보 접근 권한이 반드시 필요합니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
            if (!mounted) return;
            Navigator.of(context).pop();
          }
          return;
        }
      }

      // 위치 설정 (정확도, 간격, 거리 필터) 및 백그라운드 모드 활성화
      await _location.changeSettings(accuracy: LocationAccuracy.high, interval: 1000, distanceFilter: 0);
      await _location.enableBackgroundMode(enable: true);
      // 초기 위치 가져오기
      final locationData = await _location.getLocation();

      // 초기 위치 상태 업데이트
      if (mounted) {
        setState(() {
          _currentLocation = locationData;
          _previousLocationData = locationData;
        });
      }

      // 위치 변경 리스너 등록
      _locationSubscription = _location.onLocationChanged.listen((LocationData newLocation) {
        // 트래킹 중 아니거나, 일시정지거나, 시작 시간 없으면 무시
        if (!_isTracking || _isPaused || _startTime == null) return;
        // 정확도 낮은 위치 무시 (20m 초과)
        if (newLocation.accuracy == null || newLocation.accuracy! > 20) return;

        final newPoint = LatLng(
            newLocation.latitude ?? 0.0,
            newLocation.longitude ?? 0.0);

        if (!mounted) return;

        LocationData? lastLoc = _previousLocationData;

        // 2. UI 및 카메라 업데이트
        if (mounted) {
          setState(() {
            _currentLocation = newLocation;
          });
          // 카메라 업데이트 (비동기 호출, 기다리지 않음)
          _updateCameraPosition(newPoint);
        }

        if (lastLoc != null) {
          final distanceInMeters = _calculateDistance(
              lastLoc.latitude!, lastLoc.longitude!,
              newPoint.latitude, newLocation.longitude ?? 0.0);

          double timeIntervalSec = ((newLocation.time ?? 0) - (lastLoc.time ?? 0)) / 1000;
          if (timeIntervalSec <= 0) timeIntervalSec = 0.5;

          double speed = distanceInMeters / timeIntervalSec;

          if (distanceInMeters > 50.0) {
            print('비정상적인 거리 이동(순간이동) 감지: $distanceInMeters m. 무시합니다.');
            _previousLocationData = newLocation;
            return;
          }

          if (speed > 10.0) {
            print('비현실적인 속도 감지: $speed m/s. 무시합니다.');
            _previousLocationData = newLocation;
            return;
          }

          if (distanceInMeters < 2) {
            _previousLocationData = newLocation;
            return;
          }

          // --- 모든 검사 통과 ---
          // 거리 누적 (km 단위) 및 표시 문자열 업데이트
          _distanceKm += distanceInMeters / 1000;
          _distanceDisplay = _distanceKm.toStringAsFixed(2);

          // 현재 경과 시간 계산 (총 일시정지 시간 제외)
          final elapsed = _pausedElapsed + DateTime.now().difference(_startTime!);
          int currentElapsedSeconds = elapsed.inSeconds;

          // 페이스 계산 (최소 50m 이동 및 10초 경과 후)
          if (_distanceKm > 0.05 && currentElapsedSeconds > 10) {
            final rawPace = currentElapsedSeconds / 60 / _distanceKm; // 분/km
            // 이동 평균 필터 적용 (갑작스런 페이스 변화 완화)
            _smoothedPace = _smoothedPace == 0.0
                ? rawPace // 초기값 설정
                : _smoothedPace * 0.8 + rawPace * 0.2; // 이전 값 80%, 새 값 20%
            final paceMinutes = _smoothedPace.floor();
            final paceSeconds = ((_smoothedPace - paceMinutes) * 60).round();
            _paceDisplay = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
          } else {
            _paceDisplay = "--:--"; // 조건 미달 시 초기값
          }

          if (_distanceKm.floor() > _lastAnnouncedKm) {
            _lastAnnouncedKm = _distanceKm.floor();
            final minutes = elapsed.inMinutes;
            final seconds = elapsed.inSeconds % 60;
            if (!_isPaused) _speak("$_lastAnnouncedKm 킬로미터, ${minutes}분 ${seconds}초 경과.");
          }
          _updateLiveActivity();

          if (widget.withWatch) {
            _sendWatchData(currentElapsedSeconds);
          }
        }

        _points.add(newPoint);
        _updatePolylines();

        _previousLocationData = newLocation;
      });
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('위치 정보를 가져오는 중 오류: $e', isError: true);
        Navigator.pop(context);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { // 앱이 다시 활성화될 때
      setState(() {});
      _initializeWatchConnectivity();
    }
  }

  void _startCountdown() {
    setState(() {
      _showCountdown = true;
      _countdownMessage = "준비하세요!";
      _countdownFontSize = 60.0; // "준비하세요!" 텍스트 크기
    });
    _speak("준비하세요");

    if (widget.withWatch) {
      try {
        _watch.updateApplicationContext({
          'runType': 'ghostRecord',
          'isRunning': true,
          'isEnded': false,
        });
      } catch (e) {
        print("워치 Context 업데이트 실패 (정상 동작): $e");
      }
      _watch.sendMessage({'command': 'showWarmup'});
    }

    // 1초 간격 타이머 시작
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) { // 카운트다운 진행 중
        setState(() {
          _countdownMessage = "$_countdown"; // 숫자 표시
          _countdownFontSize = 60.0; // 숫자 텍스트 크기
        });
        _speak("$_countdown");

        if (widget.withWatch) {
          _watch.sendMessage({'command': 'countdown', 'value': _countdown});
        }

        _countdown--;
      } else {
        timer.cancel();
        setState(() {
          _countdownMessage = "기록을 측정합니다!";
          _countdownFontSize = 40.0;
          _showCountdown = false;
          _isTracking = true;
          _isPaused = false;
        });
        _speak("기록을 측정합니다!");

        if (widget.withWatch) {
          _watch.sendMessage({'command': 'startRunningUI'});
        }

        _startTracking();
        _startAutoSaveTimer();

        _liveActivityChannel.invokeMethod('startLiveActivity', {
          'type': 'ghost_record',
          'isPaused': false,
        });

        // 1초 후 "출발!" 메시지 숨김
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


  Future<void> _loadAutoSaveStatus() async {
    // SharedPreferences에서 자동 저장 설정 로드
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('autoSaveEnabled') ?? true; // 기본값 true
    final minutes = prefs.getInt('autoSaveMinutes') ?? 30; // 기본값 30분

    // 상태 메시지 업데이트
    if (!enabled) {
      setState(() {
        _autoSaveStatus = "자동 저장 꺼짐";
      });
    } else {
      setState(() {
        _autoSaveStatus = "$minutes분 후 자동 저장";
      });
    }
  }

  void _sendWatchData(int currentSeconds) {
    // 워치 사용 안 함, 트래킹 중 아님, 일시정지 중이면 전송 안 함
    if (!widget.withWatch || !_isTracking || _isPaused) return;

    // 워치로 전송할 데이터 맵 구성
    _watch.sendMessage({
      'type': 'main', // 데이터 타입
      'kilometers': _distanceKm,
      'seconds': currentSeconds,
      'pace': _smoothedPace, // UI 표시용 페이스 전송
      'calories': 0.0, // 고스트런은 칼로리 없음
      'isEnded': false, // 아직 종료 아님
    });
  }

  void _startTracking() {
    _startTime = DateTime.now(); // 현재 시간을 시작/재개 시간으로 기록
    _pausedElapsed = Duration.zero; // 총 일시정지 시간 초기화 (첫 시작이므로)

    // 1초마다 UI 업데이트 및 워치 데이터 전송 타이머 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // 일시정지 중이거나 시작 시간 없으면 무시
      if (_isPaused || _startTime == null) return;
      // 실제 경과 시간 계산
      final elapsed = _pausedElapsed + DateTime.now().difference(_startTime!);
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds % 60;
      // UI 상태 업데이트
      setState(() {
        _timeDisplay = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        _updateLiveActivity();

        if (widget.withWatch) {
          _sendWatchData(elapsed.inSeconds);
        }
      });
    });
  }


  Future<void> _startAutoSaveTimer() async {
    // 설정 로드
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('autoSaveEnabled') ?? true;
    final minutes = prefs.getInt('autoSaveMinutes') ?? 30;

    // 비활성화 시 상태 메시지 변경 후 종료
    if (!enabled) {
      setState(() { _autoSaveStatus = "자동 저장 꺼짐"; });
      return;
    }

    // 활성화 시 상태 메시지 변경
    setState(() { _autoSaveStatus = "$minutes분 후 자동 저장"; });

    // 설정된 시간 후 자동 저장 실행 타이머 시작
    _autoSaveTimer?.cancel(); // 기존 타이머 취소
    _autoSaveTimer = Timer(Duration(minutes: minutes), () {
      if (_isTracking && !_autoSaved) {
        if (!_isPaused) _speak("$minutes분 경과, 기록을 자동 저장합니다.");

        final autoSaveElapsedSeconds = (_pausedElapsed + (_startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero)).inSeconds;

        _saveRunRecord(autoSaveElapsedSeconds, isAutoSave: true).then((_) {
          if (mounted) {
            setState(() {
              _autoSaved = true;
              _autoSaveStatus = "자동 저장됨";
            });

            _showCustomSnackBar('$minutes분 경과! 기록이 자동 저장되었습니다.');

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _isTracking) {
                _finishTracking(save: false);
              }
            });
          }
        });
      }
    });
  }

  void _pauseTracking() {
    if (_startTime != null && !_isPaused) {
      _pausedElapsed += DateTime.now().difference(_startTime!);
    }
    _speak("일시정지");
    setState(() {
      _isPaused = true;
      _startTime = null;
    });

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'pauseFromPhone'});
    }

    _updateLiveActivity();
  }

  void _resumeTracking() {
    _startTime = DateTime.now();
    setState(() {
      _isPaused = false;
    });
    if (!_isPaused) _speak("운동을 다시 시작합니다");

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'resumeFromPhone'});
    }

    _updateLiveActivity();
  }

  // 종료 확인 다이얼로그
  Future<bool> _showStopConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 바깥 탭으로 닫기 비활성화
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900], // 어두운 배경
        title: const Text("러닝 중지", style: TextStyle(color: Colors.white)),
        content: const Text("러닝을 중지하시겠습니까?\n(기록은 저장되지 않습니다)", style: TextStyle(color: Colors.white)),
        actions: [
          TextButton( // 아니오 버튼
            onPressed: () => Navigator.pop(context, false), // false 반환
            child: const Text("아니오", style: TextStyle(color: Colors.grey)),
          ),
          TextButton( // 예 버튼
            onPressed: () => Navigator.pop(context, true), // true 반환
            child: const Text("예", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    ) ?? false; // 다이얼로그 닫힐 때 기본값 false
  }

  // 저장 확인 다이얼로그 (일시정지 중 종료 버튼)
  Future<bool> _showSaveConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('기록 저장', style: TextStyle(color: Colors.white)),
          content: const Text('현재 러닝 기록을 저장하시겠습니까?', style: TextStyle(color: Colors.white)),
          actions: <Widget>[
            TextButton( // 취소 버튼
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
              onPressed: () { Navigator.of(context).pop(false); }, // false 반환
            ),
            TextButton( // 저장 버튼
              child: const Text('저장', style: TextStyle(color: Colors.blue)),
              onPressed: () { Navigator.of(context).pop(true); }, // true 반환
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Firestore에 기록 저장 함수
  Future<void> _saveRunRecord(int finalElapsedSeconds, {bool isAutoSave = false}) async {
    // 자동 저장인데 이미 저장된 경우 중복 저장 방지
    if (_autoSaved && isAutoSave) return;
    // 자동 저장 완료 상태 업데이트 (UI 표시용)
    setState(() {
      if (isAutoSave) _autoSaved = true;
    });

    try {
      final userEmail = _auth.currentUser?.email ?? ''; // 현재 유저 이메일
      if (userEmail.isEmpty) return; // 이메일 없으면 저장 불가

      final elapsedSeconds = finalElapsedSeconds; // 최종 경과 시간

      // 최종 페이스 계산 (0으로 나누기 방지)
      if (_distanceKm > 0 && elapsedSeconds > 0) {
        _paceMinPerKm = (elapsedSeconds / 60) / _distanceKm;
      } else {
        _paceMinPerKm = 0.0; // 거리나 시간이 0이면 페이스도 0
      }

      // 저장할 데이터 맵 구성
      final record = {
        'date': Timestamp.now(), // 현재 시간 (타임스탬프)
        'time': elapsedSeconds, // 최종 시간 (초)
        'distance': _distanceKm, // 최종 거리 (km)
        'pace': _paceMinPerKm, // 최종 페이스 (분/km)
        'isFirstRecord': true, // 이 페이지는 항상 첫 기록
        // 경로 좌표 리스트 (GeoPoint 형식)
        'locationPoints': _points.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
        'autoSaved': isAutoSave, // 자동 저장 여부 플래그
      };

      // Firestore 'records' 컬렉션에 새 문서 추가
      DocumentReference docRef = await _firestore.collection('ghostRunRecords').doc(userEmail).collection('records').add(record);

      // 유저 문서에 최신 기록 ID 및 날짜 업데이트 (merge: true로 기존 필드 유지)
      await _firestore.collection('ghostRunRecords').doc(userEmail).set({
        'latestRecordId': docRef.id,
        'latestRecordDate': Timestamp.now(),
      }, SetOptions(merge: true));

      print('기록 저장 완료. 자동 저장: $isAutoSave');
    } catch (e) {
      print('기록 저장 오류: $e');
      if(mounted){
        _showCustomSnackBar('기록 저장 실패: $e', isError: true);
      }
    }
  }

  // 트래킹 종료 처리 함수
// FirstGhostRunTrackingPage.dart

  Future<void> _finishTracking({bool save = true}) async {
    // --- 기존 코드 ---
    _timer?.cancel();
    _autoSaveTimer?.cancel();
    _locationSubscription?.cancel();
    setState(() => _isTracking = false);

    Duration finalElapsed;
    if (_isPaused) {
      finalElapsed = _pausedElapsed;
    } else {
      finalElapsed = _pausedElapsed + (_startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero);
    }
    final finalElapsedSeconds = finalElapsed.inSeconds;

    _liveActivityChannel.invokeMethod('stopLiveActivity', {
      'type': 'ghost_record',
    });

    if (widget.withWatch) {
      double finalPace = 0.0;
      if (_distanceKm > 0 && finalElapsedSeconds > 0) {
        finalPace = (finalElapsedSeconds / 60) / _distanceKm;
        if (!finalPace.isFinite || finalPace <= 0) {
          finalPace = 0.0;
        }
      }

      _watch.sendMessage({
        'command': 'stopFromPhone',
        'kilometers': _distanceKm,
        'seconds': finalElapsedSeconds,
        'pace': finalPace,
        'calories': 0.0,
        'isEnded': true,
      });
      try {
        await _watch.updateApplicationContext({
          'runType': 'ghostRecord',
          'isRunning': false,
          'isEnded': true
        });
      } catch (e) {
        print("워치 Context 업데이트 실패 (정상 동작): $e");
      }
    }

    if (save) {
      _speak("운동을 종료하고 기록을 저장합니다.");
      await _saveRunRecord(finalElapsedSeconds);
    } else {
      _speak("운동을 종료합니다.");
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GhostRunPage()),
      );
    }
  }

  // 지도 Polyline 업데이트 함수
  void _updatePolylines() {
    if (_points.length < 2) return; // 점 2개 이상 필요
    // 새 Polyline 생성
    final polyline = Polyline(
      polylineId: PolylineId('run_track'), // ID
      points: List.from(_points), // 현재까지 기록된 모든 점
      color: Colors.blue, // 색상
      width: 5, // 두께
    );
    // 상태 업데이트 (기존 Polyline 제거 후 새로 추가)
    setState(() {
      _polylines.clear();
      _polylines.add(polyline);
    });
  }

  // 거리 계산 함수 (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    const earthRadiusKm = 6371.0;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 2 * earthRadiusKm * asin(sqrt(a)) * 1000; // 미터 단위 반환
  }

  @override
  Widget build(BuildContext context) {
    // 뒤로가기 제스처 처리 (종료 확인)
    return WillPopScope(
      onWillPop: () async {
        bool stop = await _showStopConfirmDialog();
        if (stop) {
          await _finishTracking(save: false); // 저장 안 하고 종료
        }
        return false; // 시스템 뒤로가기 비활성화
      },
      child: Scaffold(
        body: Stack( // 지도 위에 UI 요소들을 겹치기 위해 Stack 사용
          children: [
            // 지도 배경
            _currentLocation != null // 현재 위치 있어야 지도 표시
                ? AppleMap(
              initialCameraPosition: CameraPosition( // 초기 카메라 위치
                target: LatLng(
                  _currentLocation!.latitude ?? 37.5665, // 현재 위도 (없으면 서울 시청)
                  _currentLocation!.longitude ?? 126.9780, // 현재 경도 (없으면 서울 시청)
                ),
                zoom: 16.0,
              ),
              mapType: MapType.standard, // 표준 지도
              myLocationEnabled: true, // 내 위치 표시
              myLocationButtonEnabled: false, // 기본 위치 버튼 숨김
              polylines: _polylines, // 경로 표시
              onMapCreated: (AppleMapController controller) {
                // 지도 컨트롤러 저장
                _mapController = controller;
              },
            )
                : const Center(child: CircularProgressIndicator()),

            if (_showCountdown || _countdownMessage.isNotEmpty)
              Container(
                color: Colors.black.withOpacity(0.8),
                alignment: Alignment.center,
                child: Text(
                  _countdownMessage,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _countdownFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // 상단 UI 요소들 (버튼, 타이틀)
            Positioned( // 뒤로가기 버튼
              top: 40, left: 10,
              child: GestureDetector(
                onTap: () async {
                  bool stop = await _showStopConfirmDialog();
                  if (stop) { await _finishTracking(save: false); }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration( color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                  child: const Icon( Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
            Positioned( // 중앙 타이틀
              top: 50, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration( color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                  child: const Text( '첫 기록 측정', style: TextStyle( color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            Positioned( // 설정 버튼
              top: 40, right: 10,
              child: GestureDetector(
                onTap: () async {
                  _pauseTracking(); // 설정 화면 가기 전에 일시정지
                  await Navigator.push( context, MaterialPageRoute(builder: (_) => const GhostRunSettingsPage()))
                      .then((_) { // 설정 화면에서 돌아왔을 때
                    _loadAutoSaveStatus(); // 자동 저장 상태 다시 로드
                    _autoSaveTimer?.cancel(); // 기존 자동 저장 타이머 취소
                    _startAutoSaveTimer(); // 새 설정으로 타이머 다시 시작
                    _resumeTracking(); // 러닝 재개
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration( color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: const Icon( Icons.settings, color: Colors.white, size: 24),
                ),
              ),
            ),
            // 자동 저장 상태 표시
            Positioned(
              top: 100, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration( color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: _autoSaved ? Colors.green : Colors.white, size: 16), // 자동 저장 완료 시 녹색 아이콘
                    const SizedBox(width: 4),
                    Text( _autoSaveStatus, style: TextStyle( color: _autoSaved ? Colors.green : Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),

            // 하단 정보 및 컨트롤 패널
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8), // 반투명 검정 배경
                  borderRadius: const BorderRadius.only( topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20), // 내부 여백
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 내용물 크기만큼만
                  children: [
                    // 시간, 거리, 페이스 정보 표시
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn("Time", _timeDisplay),
                        _buildInfoColumn("Km", "${_distanceDisplay}km"), // km 단위 표시
                        _buildInfoColumn("Min/Km", _paceDisplay),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 컨트롤 버튼 (일시정지 또는 재개/종료)
                    if (!_isPaused) // 러닝 중일 때
                      GestureDetector( // 일시정지 버튼
                        onTap: _pauseTracking,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration( shape: BoxShape.circle, color: Colors.orange), // 주황색 원
                          child: const Icon( Icons.pause, color: Colors.white, size: 32),
                        ),
                      )
                    else // 일시정지 중일 때
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector( // 종료(저장) 버튼
                            onTap: () async {
                              bool save = await _showSaveConfirmDialog(); // 저장 확인
                              if (save) { await _finishTracking(save: true); } // 저장하고 종료
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration( shape: BoxShape.circle, color: Colors.blue), // 파란색 원
                              child: const Icon( Icons.stop, color: Colors.white, size: 32),
                            ),
                          ),
                          const SizedBox(width: 40), // 버튼 사이 간격
                          GestureDetector( // 재개 버튼
                            onTap: _resumeTracking,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration( shape: BoxShape.circle, color: Colors.green), // 초록색 원
                              child: const Icon( Icons.play_arrow, color: Colors.white, size: 32),
                            ),
                          ),
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

  // 정보 표시용 컬럼 위젯 빌더
  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text( label, style: const TextStyle( color: Colors.grey, fontSize: 14)), // 레이블 (회색)
        const SizedBox(height: 8),
        Text( value, style: const TextStyle( color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), // 값 (흰색, 굵게)
      ],
    );
  }
}