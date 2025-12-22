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

// --- 러닝 로직 임포트 ---
import 'package:geolocator/geolocator.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:pedometer/pedometer.dart';

// 'free_running_start.dart' (RouteDataPoint 클래스 사용)
import 'package:rundventure/free_running/free_running_start.dart';

// --- 결과 페이지 임포트 ---
import 'friend_battle_result_screen.dart';


class FriendBattleRunningScreen extends StatefulWidget {
  final String battleId;
  final Map<String, dynamic> battleData;

  final bool withWatch;

  const FriendBattleRunningScreen({
    Key? key,
    required this.battleId,
    required this.battleData,
    this.withWatch = false,
  }) : super(key: key);

  @override
  _FriendBattleRunningScreenState createState() => _FriendBattleRunningScreenState();
}

class _FriendBattleRunningScreenState extends State<FriendBattleRunningScreen>
    with WidgetsBindingObserver {

  // ===================================================================
  // 1. 대결 상태 및 Firebase 변수
  // ===================================================================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _myEmail = FirebaseAuth.instance.currentUser?.email;
  late final bool _isMeChallenger;
  late final String _myNickname;
  late final String? _myProfileUrl;
  late final String _opponentNickname;
  late final String? _opponentProfileUrl;
  late final String _opponentEmail;
  late final double _targetDistanceKm;

  StreamSubscription<DocumentSnapshot>? _battleSubscription;
  Timer? _firestoreUpdateTimer;

  bool _isCancelling = false;
  bool _isNavigatingToResult = false;

  String? _userRole;

  // --- 나의 러닝 상태 ---
  bool _isMyRunFinished = false; // 내가 완주했는지
  String _myStatus = 'running'; // 'running', 'stopping', 'finished'
  double _myKilometers = 0.0;
  double _myPace = 0.0;
  int _mySeconds = 0;
  int _myTotalMilliseconds = 0;
  final Stopwatch _stopwatch = Stopwatch();

  double _myElevation = 0.0;
  double _myAverageSpeed = 0.0;
  double _myCalories = 0.0;
  int _myStepCount = 0;

  // --- 상대방 러닝 상태 (Firestore 구독) ---
  String _opponentStatus = 'ready'; // 'ready', 'running', 'paused', 'stopping', 'finished'
  double _opponentKilometers = 0.0;
  double _opponentPace = 0.0;

  // ===================================================================
  // 2. 기존 RunningPage 로직 변수들
  // ===================================================================
  loc.Location location = loc.Location();
  StreamSubscription<loc.LocationData>? _locationSubscription;
  loc.LocationData? _lastLocation;
  List<RouteDataPoint> _routePointsWithSpeed = [];
  Timer? _timer;
  double? _userWeight;
  bool _isLoadingUserData = true;
  DateTime? _initialStartTime;
  late SharedPreferences prefs;

  final _watch = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;
  StreamSubscription<Map<String, dynamic>>? _watchContextSubscription;
  final MethodChannel _liveActivityChannel = const MethodChannel('com.rundventure/liveactivity');
  late FlutterTts flutterTts;
  int _nextKmTarget = 1;
  StreamSubscription<StepCount>? _pedometerStream;
  int _initialStepCount = -1;

  AppleMapController? _appleMapController;
  LatLng? _currentLocation;
  Annotation? _startMarker;
  Annotation? _endMarker;

  Timer? _longPressTimer;
  bool _isStopping = false;

  bool _showLongPressHint = false;
  Timer? _hintTimer;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. 대결 기본 정보 설정
    _isMeChallenger = widget.battleData['challengerEmail'] == _myEmail;
    _targetDistanceKm = (widget.battleData['targetDistanceKm'] as num).toDouble();

    if (_isMeChallenger) {
      _myNickname = widget.battleData['challengerNickname'];
      _myProfileUrl = widget.battleData['challengerProfileUrl'];
      _opponentNickname = widget.battleData['opponentNickname'];
      _opponentProfileUrl = widget.battleData['opponentProfileUrl'];
      _opponentEmail = widget.battleData['opponentEmail'];
    } else {
      _myNickname = widget.battleData['opponentNickname'];
      _myProfileUrl = widget.battleData['opponentProfileUrl'];
      _opponentNickname = widget.battleData['challengerNickname'];
      _opponentProfileUrl = widget.battleData['challengerProfileUrl'];
      _opponentEmail = widget.battleData['challengerEmail'];
    }

    _checkUserRole();

    _initializeBattle();
  }

  Future<void> _checkUserRole() async {
    if (_myEmail == null) return;
    try {
      final userDoc = await _firestore.collection('users').doc(_myEmail).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'] ?? 'user';
        });
      }
    } catch (e) {
      print("권한 확인 실패: $e");
    }
  }

  /// (수정) 카운트다운 없이 즉시 러닝 시작
  Future<void> _initializeBattle() async {
    // 1. 서비스 초기화 (러닝 추적 제외)
    await _initRunningServices();

    if (!mounted) return;

    if (widget.withWatch) {
      try {
        await _watch.updateApplicationContext({
          'runType': 'friendRace',
          'targetDistanceKm': _targetDistanceKm,
          'opponentNickname': _opponentNickname,
          'opponentDistance': _opponentKilometers,
          'isRunning': true,
          'isEnded': false,
          'isPaused': false,
        });
      } catch (e) {
        print("Watch updateApplicationContext Error: $e");
      }
    }

    _initializeTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 모든 스트림과 타이머 해제
    _battleSubscription?.cancel();
    _firestoreUpdateTimer?.cancel();
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();
    _watchMessageSubscription?.cancel();
    _watchContextSubscription?.cancel();
    flutterTts.stop();
    _longPressTimer?.cancel();
    _hintTimer?.cancel();
    _stopwatch.stop();

    if (!_isMyRunFinished) {
      _liveActivityChannel.invokeMethod('stopLiveActivity', {'type': 'friend_battle'});
    }
    super.dispose();
  }

  // ===================================================================
  // 3. 대결 핵심 로직 (Firestore 구독 및 전송)
  // ===================================================================

  /// (1-1) 3초마다 내 러닝 데이터를 Firestore에 업데이트하는 타이머 시작
  void _startFirestoreUpdateTimer() {
    _firestoreUpdateTimer?.cancel();
    _firestoreUpdateTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!mounted || _isMyRunFinished) {
        timer.cancel();
        return;
      }
      _updateMyDataToFirestore();
    });
  }

  Future<void> _updateMyDataToFirestore() async {
    if (!mounted || _myEmail == null) return;

    final Map<String, dynamic> myDataUpdate = {
      _isMeChallenger ? 'challengerStatus' : 'opponentStatus': _myStatus,
      _isMeChallenger ? 'challengerDistance' : 'opponentDistance': _myKilometers,
      _isMeChallenger ? 'challengerPace' : 'opponentPace': _myPace,
    };

    try {
      await _firestore
          .collection('friendBattles')
          .doc(widget.battleId)
          .update(myDataUpdate);
    } catch (e) {
      // (전송 실패는 흔할 수 있으므로, 로그만 남기고 달리기를 중단하지 않음)
      print("🚨 내 대결 데이터 전송 실패: $e");
    }
  }

  /// (1-3) Firestore의 대결 문서를 실시간으로 구독
  void _listenToBattleStatus() {
    _battleSubscription?.cancel();
    _battleSubscription = _firestore
        .collection('friendBattles')
        .doc(widget.battleId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists || _isNavigatingToResult) {
        if(!snapshot.exists) {
          _stopRunAndPop("대결이 취소되었거나 삭제되었습니다.");
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String?;

      // 상대방 데이터 추출
      final String opponentStatus = data[_isMeChallenger ? 'opponentStatus' : 'challengerStatus'] ?? 'ready';
      final double opponentKm = (data[_isMeChallenger ? 'opponentDistance' : 'challengerDistance'] ?? 0.0).toDouble();
      final double opponentPace = (data[_isMeChallenger ? 'opponentPace' : 'challengerPace'] ?? 0.0).toDouble();

      // UI 갱신을 위해 setState
      setState(() {
        _opponentStatus = opponentStatus;
        _opponentKilometers = opponentKm;
        _opponentPace = opponentPace;
      });

      // (1) 누군가에 의해 대결이 취소된 경우
      if (status == 'cancelled' || status == 'rejected') {
        _stopRunAndPop("상대방이 대결을 중단했습니다.");
        return;
      }

      // (2) 양쪽 다 완주했는지 확인
      _checkIfBothFinished();
    });
  }

  /// (1-4) 양쪽 다 완주했는지 확인
  void _checkIfBothFinished() {
    if (_isMyRunFinished && _opponentStatus == 'finished') {
      _navigateToResults();
    }
  }

  Future<void> _cancelBattle() async {
    if (_isCancelling || _isNavigatingToResult || _isStopping) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('대결 중단'),
          content: Text('정말로 대결을 중단하시겠습니까?\n이 대결은 기권패 처리됩니다.'),
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

    setState(() => _isCancelling = true);

    try {
      final Timestamp runTimestamp = Timestamp.now();
      final WriteBatch batch = _firestore.batch();

      final battleDocRef = _firestore.collection('friendBattles').doc(widget.battleId);
      final Map<String, dynamic> myDataUpdate = {
        _isMeChallenger ? 'challengerDistance' : 'opponentDistance': _myKilometers,
        _isMeChallenger ? 'challengerPace' : 'opponentPace': _myPace,
        _isMeChallenger ? 'challengerFinalTimeMs' : 'opponentFinalTimeMs': _myTotalMilliseconds,
        'updatedAt': runTimestamp,
      };
      batch.update(battleDocRef, myDataUpdate);

      final battleRecordData = {
        'date': runTimestamp,
        'kilometers': _myKilometers,
        'seconds': _mySeconds,
        'pace': _myPace,
        'bpm': 0,
        'stepCount': _myStepCount,
        'elevation': _myElevation,
        'averageSpeed': _myAverageSpeed,
        'calories': _myCalories,
        'routePointsWithSpeed': _routePointsWithSpeed.map((dp) => dp.toMap()).toList(),
        'battleId': widget.battleId,
        'isWinner': false,
        'opponentEmail': _opponentEmail,
        'opponentNickname': _opponentNickname,
        'email': _myEmail,
        'timestamp': runTimestamp,
        'finalTimeMs': _myTotalMilliseconds,
      };

      final battleRecordDocRef = _firestore
          .collection('friendBattles')
          .doc(widget.battleId)
          .collection('records')
          .doc(_myEmail);

      batch.set(battleRecordDocRef, battleRecordData);

      await batch.commit();
      print("✅ [중단] 중단 직전 기록 저장 완료.");

      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('cancelFriendBattle');
      await callable.call({'battleId': widget.battleId});

    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        _showErrorDialog(e.message ?? "알 수 없는 오류");
        setState(() => _isCancelling = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog("취소 요청 중 오류가 발생했습니다.");
        setState(() => _isCancelling = false);
      }
    }
  }


  /// (1-6) 대결 종료 및 결과 화면으로 이동
  Future<void> _navigateToResults() async {
    if (_isNavigatingToResult) return; // 중복 이동 방지
    _isNavigatingToResult = true;

    print("🏁 양쪽 모두 완료! 결과 화면으로 이동합니다.");

    // 모든 리스너/타이머 중지
    _battleSubscription?.cancel();
    _firestoreUpdateTimer?.cancel();
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();
    _watchMessageSubscription?.cancel();
    _watchContextSubscription?.cancel();
    flutterTts.stop();
    _longPressTimer?.cancel();
    _hintTimer?.cancel();
    _stopwatch.stop();

    // 라이브 액티비티/워치 종료
    _liveActivityChannel.invokeMethod('stopLiveActivity', {'type': 'friend_battle'});

    // Firestore에서 최종 데이터 한 번 더 가져오기
    final finalDoc = await _firestore.collection('friendBattles').doc(widget.battleId).get();
    final finalData = finalDoc.data() ?? widget.battleData;

    // (내 페이스, 상대방 페이스/거리/초 계산)
    final bool isMeChallenger = finalData['challengerEmail'] == _myEmail;
    final double targetDistanceKm = (finalData['targetDistanceKm'] as num).toDouble();

    final double opponentPace = (isMeChallenger ? finalData['opponentPace'] : finalData['challengerPace'] as num).toDouble();
    final double opponentKm = (isMeChallenger ? finalData['opponentDistance'] : finalData['challengerDistance'] as num).toDouble();

    final int myTimeMs = (isMeChallenger
        ? finalData['challengerFinalTimeMs']
        : finalData['opponentFinalTimeMs']) as int? ?? (_mySeconds * 1000);

    final int opponentTimeMs = (isMeChallenger
        ? finalData['opponentFinalTimeMs']
        : finalData['challengerFinalTimeMs']) as int? ?? 0;

    final bool isDraw = myTimeMs == opponentTimeMs;
    final bool isWinner = (opponentTimeMs > 0) && (myTimeMs < opponentTimeMs);

    if (widget.withWatch) {
      _watch.sendMessage({
        'command': 'stopFromPhone',
        'runType': 'friendRace',
        'kilometers': _myKilometers,
        'seconds': _mySeconds,
        'pace': _myPace,
        'calories': _myCalories,
        'targetDistanceKm': _targetDistanceKm,
        'opponentDistance': opponentKm,
        'raceOutcome': isDraw ? "draw" : (isWinner ? "win" : "lose"),
        'isEnded': true,
      });

      try {
        await _watch.updateApplicationContext({
          'runType': 'friendRace',
          'isRunning': false,
          'isEnded': true,
          'kilometers': _myKilometers,
          'seconds': _mySeconds,
          'pace': _myPace,
          'calories': _myCalories,
          'targetDistanceKm': _targetDistanceKm,
          'opponentNickname': _opponentNickname,
          'opponentDistance': opponentKm,
          'raceOutcome': isDraw ? "draw" : (isWinner ? "win" : "lose"),
        });
      } catch (e) {
        print("Watch updateApplicationContext Error on Finish: $e");
      }
    }

    if (isDraw) {
      await _speak("무승부입니다.");
    } else if (isWinner) {
      await _speak("승리했습니다!");
    } else {
      await _speak("아쉽지만 패배했습니다.");
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FriendBattleResultScreen(
            battleId: widget.battleId,
            finalBattleData: finalData,
            myRoutePoints: _routePointsWithSpeed,
            myFinalSeconds: _mySeconds,
            myFinalTimeMs: _myTotalMilliseconds,

            myStepCount: _myStepCount,
            myElevation: _myElevation,
            myAverageSpeed: _myAverageSpeed,
            myCalories: _myCalories,
          ),
        ),
      );
    }
  }

  /// (1-7) 에러 발생 또는 취소 시 러닝을 중단하고 Pop
  void _stopRunAndPop(String message) {
    if (!mounted || _isNavigatingToResult) return;
    _isNavigatingToResult = true; // 화면 이동 중 플래그

    print("🛑 대결 중단: $message");

    // 모든 러닝 로직 중단
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();
    _firestoreUpdateTimer?.cancel();
    _battleSubscription?.cancel();
    flutterTts.stop();
    _longPressTimer?.cancel();
    _hintTimer?.cancel();
    _stopwatch.stop();
    _liveActivityChannel.invokeMethod('stopLiveActivity', {'type': 'friend_battle'});

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'stopFromPhone', 'runType': 'friendRace', 'isEnded': true});
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
          title: Text('대결 종료'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// (1-8) 에러 다이얼로그 (중단 실패 등)
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
  // 4. 러닝 핵심 로직 (RunningPage에서 이식 및 수정)
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

  Future<void> _initRunningServices() async {
    // 1. TTS
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

    await _loadUserWeight();

    await _initSharedPreferences();

    _liveActivityChannel.setMethodCallHandler(_handleNativeMethodCall);
    if (widget.withWatch) {
      _initializeWatchConnectivity();
    }

    await _getCurrentLocation();
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (!mounted) return;
    print("🎯 [BATTLE DART] Native method call received: ${call.method}");
    if (call.method == 'handleLiveActivityCommand') {
      try {
        final command = (call.arguments as Map<dynamic, dynamic>)['command'] as String?;
        if (command == 'pauseRunning') {
        } else if (command == 'resumeRunning') {
        }
      } catch (e) {
        print("🚨 [BATTLE DART] _handleNativeMethodCall Error: $e");
      }
    }
  }

  void _initializeWatchConnectivity() {
    if (!widget.withWatch) return;

    _watchMessageSubscription?.cancel();
    _watchContextSubscription?.cancel();
    print("🔄 [BATTLE DART] Initializing watch connectivity listeners...");

    _watchMessageSubscription = _watch.messageStream.listen(
          (message) {
        _handleWatchCommand(message, "messageStream");
      },
    );
  }

  void _handleWatchCommand(Map<String, dynamic> message, String streamType) {
    print("🎯 [BATTLE DART] Command received on '$streamType': $message");
    if (!mounted || _isMyRunFinished) return;

    if (message.containsKey('command')) {
      final command = message['command'] as String;
      switch (command) {
        case 'stopRunning':
          _cancelBattle();
          break;
      }
    }
  }

  /// (4-5) TTS
  Future<void> _speak(String text) async {
    if (!_isMyRunFinished) {
      await flutterTts.speak(text);
    }
  }

  /// (4-6) 몸무게 로드
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
        _userWeight = userWeight;
      } else {
        _userWeight = 70.0;
      }
    } catch (e) {
      print('Error loading user weight: $e');
      _userWeight = 70.0;
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  /// (4-7) SharedPreferences 로드
  Future<void> _initSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('accuracy')) await prefs.setString('accuracy', '가장 높음 (High)');
    if (!prefs.containsKey('distanceFilter')) await prefs.setDouble('distanceFilter', 5.0);
    if (!prefs.containsKey('interval')) await prefs.setInt('interval', 1000);
  }

  Future<void> _initializeTracking() async {
    // 1. 라이브 액티비티 시작
    _liveActivityChannel.invokeMethod('startLiveActivity', {
      'type': 'friend_battle',
      'isPaused': false,
      'opponentNickname': _opponentNickname,
      'targetDistanceKm': _targetDistanceKm,
    });

    if (widget.withWatch) {
      _watch.sendMessage({'command': 'startRunningUI'});
    }
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

    // 5. 위치 설정 적용
    await location.changeSettings(
        accuracy: _getLocationAccuracy(),
        interval: _getInterval(),
        distanceFilter: _getDistanceFilter());

    // 6. _lastLocation 초기화 (순간이동 방지)
    _lastLocation = null;

    _startLocationTracking();
    _startTimer();
    _startPedometer();

    _listenToBattleStatus();
    _startFirestoreUpdateTimer();
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

  void _startLocationTracking() {
    _locationSubscription =
        location.onLocationChanged.listen((loc.LocationData currentLocation) {
          if (!mounted || _isMyRunFinished) return;
          if (currentLocation.latitude == null || currentLocation.longitude == null) return;

          if ((currentLocation.accuracy ?? 100.0) > 25.0) {
            print("⚠️ GPS 정확도 낮음 무시: ${currentLocation.accuracy}m");
            return;
          }

          LatLng newLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          double currentAltitude = currentLocation.altitude ?? 0.0;

          // (UI 업데이트는 유효성 검사 통과 후 아래에서 실행)

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
            double speed = distance / timeIntervalSec;

            if (distance > 50.0 || speed > 12.0) {
              print("⚠️ 비정상 이동 무시: Dist=$distance, Speed=$speed");
              return;
            }

            if (distance < 3.0) {
              return;
            }
            if (_isMyRunFinished) {
              _lastLocation = currentLocation;
              return;
            }

            // --- 여기부터는 유효한 이동으로 인정 ---

            // 칼로리 계산
            if (_userWeight != null) {
              double speedKmh = speed * 3.6;
              double met = (speedKmh < 3.0) ? 2.0 : (speedKmh < 4.8) ? 3.5 : (speedKmh < 6.4) ? 5.0 :
              (speedKmh < 8.0) ? 8.3 : (speedKmh < 9.7) ? 9.8 : (speedKmh < 11.3) ? 11.0 : 12.8;
              double caloriesPerMinute = (met * 3.5 * _userWeight!) / 200;
              double caloriesThisInterval = caloriesPerMinute * (timeIntervalSec / 60);
              _myCalories += caloriesThisInterval;
            }

            // setState (거리, 경로)
            setState(() {
              _myKilometers += distance / 1000;
              _routePointsWithSpeed.add(RouteDataPoint(point: newLocation, speed: speed));
              _updateMarkers();
              _currentLocation = newLocation;
            });

            if (_appleMapController != null) {
              _appleMapController!.animateCamera(CameraUpdate.newLatLng(newLocation));
            }

            if (_myKilometers >= _nextKmTarget) {
              double safePace = _myPace;
              if (safePace.isInfinite || safePace.isNaN) safePace = 0.0;

              final int paceMin = safePace.floor();
              final int paceSec = ((safePace - paceMin) * 60).round();

              print("🔊 음성 안내 실행: $_nextKmTarget km 달성! (페이스: $paceMin분 $paceSec초)");
              _speak('$_nextKmTarget 킬로미터. 현재 페이스는 $paceMin 분 $paceSec 초 입니다.');
              _nextKmTarget++;
            }

            if (_myKilometers >= _targetDistanceKm) {
              _finishMyRun();
            }

          } else {
            setState(() {
              _routePointsWithSpeed.add(RouteDataPoint(point: newLocation, speed: 0.0));
              _updateMarkers();
              _currentLocation = newLocation;
            });
          }
          // 마지막으로 유효한 위치만 갱신
          _lastLocation = currentLocation;
        });
  }

  void _startTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) { // 0.1초마다 UI 갱신
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isMyRunFinished) {
        setState(() {
          _myTotalMilliseconds = _stopwatch.elapsedMilliseconds;
          _mySeconds = _stopwatch.elapsed.inSeconds;
          _updatePaceAndSpeed();
        });
      }
    });
  }

  void _startPedometer() {
    _pedometerStream = Pedometer.stepCountStream.listen(
          (StepCount event) {
        if (!mounted || _isMyRunFinished) return;
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

  void _updatePaceAndSpeed() {
    double newAvgSpeed;
    double newPace;
    // 1초 미만일 때 계산 방지
    if (_myKilometers < 0.01 || _mySeconds < 1) {
      newAvgSpeed = 0.0;
      newPace = 0.0;
    } else {
      newAvgSpeed = _myKilometers / (_mySeconds / 3600);
      newPace = (_mySeconds / 60) / _myKilometers;
    }
    if (newPace < 3.0 && _mySeconds > 10) newPace = 3.0;
    if (newPace > 30.0) newPace = 30.0;

    // setState
    setState(() {
      _myAverageSpeed = newAvgSpeed;
      _myPace = newPace;
    });

    // 라이브 액티비티 업데이트
    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'friend_battle',
      'myKilometers': _myKilometers,
      'mySeconds': _mySeconds,
      'myPace': _myPace,
      'isMyRunFinished': _isMyRunFinished,
      'opponentNickname': _opponentNickname,
      'opponentDistance': _opponentKilometers,
      'isOpponentFinished': (_opponentStatus == 'finished'),
    });

    if (widget.withWatch) {
      final watchData = {
        'type': 'battle',
        'kilometers': _myKilometers,
        'seconds': _mySeconds,
        'pace': _myPace,
        'calories': _myCalories,
        'isEnded': false,
        'opponentDistance': _opponentKilometers,
      };
      _watch.sendMessage(watchData);
    }
  }

  /// (4-13) 헬퍼 (위치 정확도)
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

  Future<void> _finishMyRun() async {
    if (_isMyRunFinished) return; // 중복 호출 방지

    print("🏁 [나] 완주! (Target: $_targetDistanceKm, Actual: $_myKilometers)");

    _stopwatch.stop();
    _myTotalMilliseconds = _stopwatch.elapsedMilliseconds;
    _mySeconds = _stopwatch.elapsed.inSeconds;

    // 1. 상태 변경
    setState(() {
      _isMyRunFinished = true;
      _myStatus = 'finished';
    });

    // 2. 하드웨어 리스너 중지
    _timer?.cancel();
    _locationSubscription?.cancel();
    _pedometerStream?.cancel();
    _firestoreUpdateTimer?.cancel();
    _longPressTimer?.cancel();
    _hintTimer?.cancel();

    // 3. TTS (완주 안내)
    await flutterTts.speak("완주했습니다! 상대방을 기다립니다.");

    // 4. 마지막 데이터 Firestore에 전송 (정확한 값 보정)
    _myKilometers = _targetDistanceKm;
    _updatePaceAndSpeed();

    try {
      final WriteBatch batch = _firestore.batch();
      final Timestamp runTimestamp = Timestamp.now();

      final battleDocRef = _firestore.collection('friendBattles').doc(widget.battleId);
      final Map<String, dynamic> myDataUpdate = {
        _isMeChallenger ? 'challengerStatus' : 'opponentStatus': 'finished',
        _isMeChallenger ? 'challengerDistance' : 'opponentDistance': _myKilometers,
        _isMeChallenger ? 'challengerPace' : 'opponentPace': _myPace,
        _isMeChallenger ? 'challengerFinalTimeMs' : 'opponentFinalTimeMs': _myTotalMilliseconds,
        'updatedAt': runTimestamp,
      };
      batch.update(battleDocRef, myDataUpdate);

      final battleRecordData = {
        'date': runTimestamp,
        'kilometers': _myKilometers,
        'seconds': _mySeconds,
        'pace': _myPace,
        'bpm': 0,
        'stepCount': _myStepCount,
        'elevation': _myElevation,
        'averageSpeed': _myAverageSpeed,
        'calories': _myCalories,
        'routePointsWithSpeed': _routePointsWithSpeed.map((dp) => dp.toMap()).toList(),
        'battleId': widget.battleId,
        'isWinner': false,
        'opponentEmail': _opponentEmail,
        'opponentNickname': _opponentNickname,
        'email': _myEmail,
        'timestamp': runTimestamp,
        'finalTimeMs': _myTotalMilliseconds,
      };

      final battleRecordDocRef = _firestore
          .collection('friendBattles')
          .doc(widget.battleId)
          .collection('records')
          .doc(_myEmail);

      batch.set(battleRecordDocRef, battleRecordData);

      await batch.commit();
      print("✅ [나] 완주! 상세 기록(밀리초 포함) 및 상태 즉시 저장 완료.");

    } catch (e) {
      print("🚨 [나] 완주 기록 저장 실패: $e");
    }


    // 5. 라이브 액티비티 '완주' 상태로 업데이트
    _liveActivityChannel.invokeMethod('updateLiveActivity', {
      'type': 'friend_battle',
      'isMyRunFinished': true,
      'myKilometers': _myKilometers,
      'mySeconds': _mySeconds,
      'myPace': _myPace,
      'opponentNickname': _opponentNickname,
      'opponentDistance': _opponentKilometers,
      'isOpponentFinished': (_opponentStatus == 'finished'),
    });

    if (widget.withWatch) {
      _watch.sendMessage({
        'type': 'battle',
        'kilometers': _myKilometers, 'seconds': _mySeconds, 'pace': _myPace,
        'calories': _myCalories, 'isEnded': false, 'isMyRunFinished': true,
        'opponentDistance': _opponentKilometers,
      });
    }

    _checkIfBothFinished();
  }


  // ===================================================================
  // 5. 헬퍼 함수 (Formatters)
  // ===================================================================

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatPace(double pace) {
    if (pace.isInfinite || pace.isNaN || pace == 0) return '--:--';
    int min = pace.floor();
    int sec = ((pace - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildOpponentStatusIndicator() {
    String text;
    Color color;
    switch (_opponentStatus) {
      case 'stopping':
        text = '중단 중...';
        color = Colors.redAccent;
        break;
      case 'paused': // (호환용)
        text = '일시정지';
        color = Colors.orange;
        break;
      case 'finished':
        text = '완주!';
        color = Colors.green;
        break;
      default:
        text = '러닝 중';
        color = Colors.deepPurple[600]!;
    }
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAnyAdmin =
        _userRole == 'admin' || _userRole == 'head_admin' || _userRole == 'super_admin';

    return WillPopScope(
      // 뒤로가기 = 대결 중단
      onWillPop: () async {
        if (!_isMyRunFinished && !_isCancelling && !_isStopping) {
          await _cancelBattle();
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

  /// (신규) 완주/대기 오버레이 UI
  Widget _buildFinishOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, color: Colors.white, size: 80),
            SizedBox(height: 20),
            Text(
              '${_formatTime(_mySeconds)}',
              style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
            ),
            Text(
              '완주!',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              _opponentStatus == 'finished'
                  ? '상대방도 완주! 잠시 후 결과가 표시됩니다...'
                  : '$_opponentNickname 님을 기다리는 중...',
              style: TextStyle(color: Colors.grey[300], fontSize: 16),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }

  /// (신규) 취소/중단 로딩 오버레이
  Widget _buildCancellingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildLongPressHint() {
    return AnimatedOpacity(
      opacity: _showLongPressHint ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: _showLongPressHint
          ? Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withOpacity(0.9), // 어두운 토스트 색상
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              '중단하려면 버튼을 3초간 꾹 누르세요.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      )
          : SizedBox(height: 46),
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
                  stops: [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildPlayerHeader(),
              _buildDistanceComparator(),
              _buildLongPressHint(),
              Spacer(),
              _buildMainStats(),
              Spacer(),
              _buildControls(),
            ],
          ),
        ),

        // 5. 완주 시 오버레이
        if (_isMyRunFinished)
          _buildFinishOverlay(),

        if (_isCancelling)
          _buildCancellingOverlay(),

        if (isAnyAdmin && !_isMyRunFinished)
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'debugMyFinish',
              onPressed: _finishMyRun,
              backgroundColor: Colors.orange,
              child: Icon(Icons.flag, color: Colors.white),
            ),
          ),
        if (isAnyAdmin && !_isMyRunFinished)
          Positioned(
            bottom: 190,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'debugOpponentFinish',
              onPressed: () async {
                final String opponentStatusField = _isMeChallenger ? 'opponentStatus' : 'challengerStatus';
                final String opponentPaceField = _isMeChallenger ? 'opponentPace' : 'challengerPace';
                final String opponentDistanceField = _isMeChallenger ? 'opponentDistance' : 'challengerDistance';
                final String opponentTimeMsField = _isMeChallenger ? 'opponentFinalTimeMs' : 'challengerFinalTimeMs';

                await _firestore.collection('friendBattles').doc(widget.battleId).update({
                  opponentStatusField: 'finished',
                  opponentPaceField: 5.5,
                  opponentDistanceField: _targetDistanceKm,
                  opponentTimeMsField: _myTotalMilliseconds + 1500,
                });
              },
              backgroundColor: Colors.red[800],
              child: Icon(Icons.person_off, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '나 ($_myNickname)',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_myKilometers.toStringAsFixed(2)} km',
                  style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildOpponentStatusIndicator(),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _opponentNickname,
                        style: TextStyle(color: Colors.deepPurple, fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_opponentKilometers.toStringAsFixed(2)} km',
                  style: TextStyle(color: Colors.deepPurple, fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceComparator() {
    double myProgress = (_myKilometers / _targetDistanceKm).clamp(0.0, 1.0);
    double opponentProgress = (_opponentKilometers / _targetDistanceKm).clamp(0.0, 1.0);

    // 리드/낙오 거리 계산
    double diff = _myKilometers - _opponentKilometers;
    String diffText;
    Color diffColor;
    if (_isMyRunFinished) {
      diffText = '완주!';
      diffColor = Colors.green;
    }
    else if (diff.abs() < 0.01) { // 10m 이내
      diffText = '박빙';
      diffColor = Colors.black87;
    } else if (diff > 0) {
      diffText = '${(diff * 1000).toStringAsFixed(0)}m 리드';
      diffColor = Colors.blueAccent;
    } else {
      diffText = '${(diff.abs() * 1000).toStringAsFixed(0)}m 낙오';
      diffColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            diffText,
            style: TextStyle(color: diffColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    // 상대방
                    AnimatedContainer(
                      duration: Duration(milliseconds: 500),
                      height: 10,
                      width: constraints.maxWidth * opponentProgress,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[300]!,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    // 내 프로그레스 바 (앞)
                    AnimatedContainer(
                      duration: Duration(milliseconds: 500),
                      height: 10,
                      width: constraints.maxWidth * myProgress,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                );
              }
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0km', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text('${_targetDistanceKm.toStringAsFixed(0)}km', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

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
              _buildStatColumn('시간', _formatTime(_mySeconds)),
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
          style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildControls() {
    // 완주했으면 버튼 숨김
    if (_isMyRunFinished) {
      return SizedBox(height: 80); // 버튼 공간 확보
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              _hintTimer?.cancel();
              if (mounted) {
                setState(() => _showLongPressHint = true);
              }
              _hintTimer = Timer(Duration(seconds: 3), () {
                if (mounted) {
                  setState(() => _showLongPressHint = false);
                }
              });
            },
            onLongPressStart: (details) {
              _longPressTimer?.cancel();
              _longPressTimer = Timer(Duration(seconds: 3), () {
                if (mounted) {
                  setState(() => _isStopping = false);
                  _cancelBattle();
                }
              });
              setState(() {
                _isStopping = true;
                _myStatus = 'stopping';
              });
              _updateMyDataToFirestore();
            },
            onLongPressEnd: (details) {
              if (_longPressTimer?.isActive ?? false) {
                _longPressTimer?.cancel();
                if (mounted) {
                  setState(() {
                    _isStopping = false;
                    _myStatus = 'running';
                  });
                  _updateMyDataToFirestore();
                }
              }
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: _isStopping ? Colors.red[900] : Colors.redAccent, // 꾹 누르면 더 진하게
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                  ]
              ),
              child: _isStopping
                  ? Padding( // 꾹 누르는 동안 프로그레스 인디케이터 표시
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
                  : Icon(Icons.stop, color: Colors.white, size: 30), // 기본 아이콘
            ),
          ),
        ],
      ),
    );
  }
}