import 'dart:async';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 [수정] (이미 import 되어 있음)
import '../admin/admin_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../admin_password.dart'; // Admin 비밀번호 관련 페이지 import
import '../free_running/free_running_start.dart'; // RunningPage가 있는 파일 import
import '../ghostrun_screen/FirstGhostRun_Tracking.dart'; // 고스트런 첫 기록 페이지 import
import '../ghostrun_screen/GhostRun_TrackingPage.dart'; // 고스트런 대결 페이지 import
import '../ghostrun_screen/ghostrunpage.dart'; // 고스트런 메뉴 페이지 import
import '../login_screens/login_screen.dart'; // 로그인 스크린 import
import 'components/app_bar_section.dart'; // 앱 바 섹션 컴포넌트 import
import 'components/content_card.dart'; // 컨텐츠 카드 컴포넌트 import
import 'components/free_running_section.dart'; // 자유 러닝 섹션 컴포넌트 import
import 'components/game_challenge_section.dart'; // 게임 챌린지 섹션 컴포넌트 import
import 'components/bottom_nav_bar.dart'; // 하단 네비게이션 바 컴포넌트 import
import 'components/center_button.dart'; // 중앙 버튼 컴포넌트 import
import 'constants/main_screen_constants.dart'; // 메인 화면 상수 import
import 'package:rundventure/main.dart'; // 메인 앱 파일 import (GameSelectionPage 위함)
import 'package:intl/intl.dart'; // 날짜 포맷팅 import

import 'game_running/game_running_section.dart'; // 게임 러닝 섹션 import (GameSelectionPage 위함)

// ▼▼▼▼▼ [친구 기능] 1. 새로운 친구 섹션 import ▼▼▼▼▼
import 'components/friends_section.dart';
// ▲▲▲▲▲ [친구 기능] 1. 새로운 친구 섹션 import ▲▲▲▲▲

// ▼▼▼▼▼ [ ✨ 추가된 import ✨ ] ▼▼▼▼▼
import 'package:rundventure/Achievement/quest_service.dart'; // ✅ QuestService 임포트
import 'package:upgrader/upgrader.dart'; // 👈 🚀 [업데이트 팝업] 패키지 import
// ▲▲▲▲▲ [ ✨ 추가된 import ✨ ] ▲▲▲▲▲

class MainScreen extends StatefulWidget {
  final MainScreenConstants constants;
  final bool isAdmin;
  final bool showWelcomeMessage;

  const MainScreen({
    Key? key,
    this.constants = const MainScreenConstants(),
    this.isAdmin = false,
    this.showWelcomeMessage = false,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  AnimationController? _fadeController;
  late Animation<double> _fadeAnimation;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _isAdmin = false;
  bool _loading = true;
  String? nickname;
  bool _showWelcomeMessage = true;

  StreamSubscription<Map<String, dynamic>>? _watchMessageSubscription;
  final _watch = WatchConnectivity();

  // --- 공지사항 관련 상태 변수 ---
  List<DocumentSnapshot> _announcements = [];
  StreamSubscription? _announcementsSubscription;
  Set<String> _hiddenToday = {};
  bool _isAnnouncementDialogShown = false;

  final QuestService _questService = QuestService();

  // 친구/채팅 알림
  bool _hasNewFriendRequests = false;
  StreamSubscription? _friendRequestSubscription;
  bool _hasNewChatMessages = false;
  StreamSubscription? _chatMessageSubscription;

  bool _hasNewAchievements = false;
  StreamSubscription? _achievementNotificationSubscription;
  bool _hasUnclaimedQuests = false;
  StreamSubscription? _questSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _checkAdminClaim().then((_) {
      _loadHiddenAnnouncements();
      _listenForMainAnnouncements();
      _listenForFriendRequests();
      _listenForNewChatMessages();

      _updateQuestStatus().then((_) {
        _listenForNewAchievements();
        _listenForUnclaimedQuests();
      });
    });
    _loadDataAndShowWelcomeMessage();
    _initializeWatchConnectivity(); // 워치 리스너 초기화
  }

  // (수정 없음)
  Future<void> _loadHiddenAnnouncements() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey =
        "hiddenAnnouncements_${DateFormat('yyyy-MM-dd').format(DateTime.now())}";
    final hiddenIds = prefs.getStringList(todayKey) ?? [];
    if (mounted) {
      setState(() {
        _hiddenToday = hiddenIds.toSet();
      });
    }
  }

  // (수정 없음)
  void _listenForMainAnnouncements() {
    _announcementsSubscription = FirebaseFirestore.instance
        .collection('mainAnnouncements')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final filteredDocs = snapshot.docs
            .where((doc) => !_hiddenToday.contains(doc.id))
            .toList();

        if (filteredDocs.isNotEmpty && !_isAnnouncementDialogShown) {
          _isAnnouncementDialogShown = true;

          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) {
              _isAnnouncementDialogShown = false;
              return;
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return MainAnnouncementDialog(
                      announcements: filteredDocs,
                      isAdmin: _isAdmin,
                      onHideToday: (id) => _hideAnnouncementForToday(id),
                      onRemove: (id) => _removeMainAnnouncement(id),
                    );
                  },
                ).then((_) {
                  if (mounted) {
                    setState(() {
                      _isAnnouncementDialogShown = false;
                    });
                  }
                });
              } else {
                _isAnnouncementDialogShown = false;
              }
            });
          });
        }
        setState(() {
          _announcements = filteredDocs;
        });
      }
    });
  }

  // (수정 없음)
  void _listenForFriendRequests() {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    _friendRequestSubscription?.cancel();

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .collection('friendRequests')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots();

    _friendRequestSubscription = query.listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasNewFriendRequests = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  // (수정 없음)
  String _emailToKey(String email) {
    return email.replaceAll('.', '_dot_').replaceAll('@', '_at_');
  }

  // (수정 없음)
  void _listenForNewChatMessages() {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    final String myEmailKey = _emailToKey(userEmail);

    _chatMessageSubscription?.cancel();

    final query = FirebaseFirestore.instance
        .collection('userChats')
        .where('participants', arrayContains: userEmail)
        .where('isReadBy_$myEmailKey', isEqualTo: false)
        .limit(1)
        .snapshots();

    _chatMessageSubscription = query.listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasNewChatMessages = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  // (수정 없음)
  Future<void> _updateQuestStatus() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    try {
      await _questService.getQuests();
    } catch (e) {
      print("Error updating quest status on main screen: $e");
    }
  }

  // (수정 없음)
  void _listenForNewAchievements() {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    _achievementNotificationSubscription?.cancel();

    final query = FirebaseFirestore.instance
        .collection('notifications')
        .doc(userEmail)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .where('type', isEqualTo: 'achievement_completed')
        .limit(1)
        .snapshots();

    _achievementNotificationSubscription = query.listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasNewAchievements = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  // (수정 없음)
  void _listenForUnclaimedQuests() {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    _questSubscription?.cancel();

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .collection('activeQuests')
        .where('isCompleted', isEqualTo: true)
        .where('isClaimed', isEqualTo: false)
        .limit(1)
        .snapshots();

    _questSubscription = query.listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasUnclaimedQuests = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  // (수정 없음)
  Future<void> _hideAnnouncementForToday(String announcementId) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey =
        "hiddenAnnouncements_${DateFormat('yyyy-MM-dd').format(DateTime.now())}";

    _hiddenToday.add(announcementId);
    await prefs.setStringList(todayKey, _hiddenToday.toList());

    if (mounted) {
      setState(() {
        _announcements.removeWhere((doc) => doc.id == announcementId);
      });
    }
  }

  // (수정 없음)
  Future<void> _removeMainAnnouncement(String announcementId) async {
    try {
      final callable =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('removeMainAnnouncement');

      await callable.call({'announcementId': announcementId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '메인 공지에서 내렸습니다.',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFFFF9F80), // 성공 색상 (주황)
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '오류: 공지를 내리는 데 실패했습니다.',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent.shade400, // 실패 색상 (붉은색)
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // (수정 없음)
  void _initializeWatchConnectivity() {
    _watchMessageSubscription?.cancel();
    _watchMessageSubscription = _watch.messageStream.listen((message) async {
      if (!message.containsKey('command')) return;
      if (!mounted) return;

      final command = message['command'] as String;
      print("🎯 [DART-MainScreen] Command received FROM WATCH: $command");

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("⚠️ User not logged in. Sending 'loginRequired' error to watch.");
        _watch.sendMessage({'error': 'loginRequired'});
        return;
      }

      switch (command) {
        case 'startRunningFromWatch':
          print("워치 명령: '자유 러닝' 바로 시작 (withWatch: true)");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RunningPage(withWatch: true),
            ),
          );
          break;
        case 'startGhostRunFromWatch':
          print("워치 명령: '고스트 런' 시작. 기록 확인 중...");
          final Map<String, dynamic>? latestGhostRecord =
          await _getLatestGhostRecord();

          if (latestGhostRecord == null) {
            print("...기록 없음. '첫 기록' 페이지로 바로 이동 (withWatch: true)");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FirstGhostRunTrackingPage(withWatch: true),
              ),
            );
          } else {
            print("...기록 있음. '고스트 대결' 페이지로 바로 이동 (withWatch: true)");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GhostRunTrackingPage(
                    ghostRunData: latestGhostRecord, withWatch: true),
              ),
            );
          }
          break;
      }
    });
    print("✅ [DART-MainScreen] Watch connectivity listener initialized.");
  }

  // ▼▼▼▼▼ [ ✨ 1. 수정된 함수 ✨ ] ▼▼▼▼▼
  /// (수정) Apple Watch 연동 다이얼로그 대신 SharedPreferences에서 설정값을 읽어옵니다.
  void _showUseWatchDialog(BuildContext context) async { // 👈 async로 변경
    final prefs = await SharedPreferences.getInstance();
    // 'watchSyncEnabled' 키로 저장된 값을 읽어오며, 없으면 false(끄기)를 기본값으로 합니다.
    final bool withWatch = prefs.getBool('watchSyncEnabled') ?? false;

    if (!mounted) return; // 비동기 작업 후 context 유효성 검사

    // 설정값(withWatch)에 따라 바로 해당 페이지로 이동합니다.
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (context) => RunningPage(withWatch: withWatch)),
    );
  }
  // ▲▲▲▲▲ [ ✨ 1. 수정된 함수 ✨ ] ▲▲▲▲▲

  // (수정 없음)
  void _initializeAnimation() {
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  // (수정 없음)
  Future<void> _checkAdminClaim() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final idTokenResult = await user.getIdTokenResult(true);
      if (mounted) {
        setState(() {
          _isAdmin = idTokenResult.claims?['isAdmin'] == true;
          _loading = false;
        });
      }
    } catch (e) {
      print("관리자 권한 확인 오류: $e");
      if (mounted) {
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
      }
    }
  }

  // (수정 없음)
  Future<void> _loadDataAndShowWelcomeMessage() async {
    if (!widget.showWelcomeMessage) {
      setState(() => _showWelcomeMessage = false);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      setState(() => _showWelcomeMessage = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();
      final loadedNickname = doc.data()?['nickname'] as String?;

      if (mounted && loadedNickname != null && loadedNickname.isNotEmpty) {
        setState(() {
          nickname = loadedNickname;
          _showWelcomeMessage = true;
        });

        _fadeController = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 800),
        );
        _fadeAnimation = CurvedAnimation(
          parent: _fadeController!,
          curve: Curves.easeInOut,
        );

        await Future.delayed(Duration(milliseconds: 300));
        if (!mounted) return;
        await _fadeController?.forward();
        await Future.delayed(Duration(seconds: 3));
        if (!mounted) return;
        await _fadeController?.reverse();
        if (!mounted) return;
        setState(() => _showWelcomeMessage = false);
      } else {
        if (mounted) {
          setState(() => _showWelcomeMessage = false);
        }
      }
    } catch (e) {
      print("닉네임 로딩 오류: $e");
      if (mounted) {
        setState(() => _showWelcomeMessage = false);
      }
    }
  }

  // (수정 없음)
  Future<Map<String, dynamic>?> _getLatestGhostRecord() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return null;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('ghostRunRecords')
          .doc(userEmail)
          .get();

      if (userDoc.exists && userDoc.data()!.containsKey('latestRecordId')) {
        String latestRecordId = userDoc.data()!['latestRecordId'];
        final recordDoc = await FirebaseFirestore.instance
            .collection('ghostRunRecords')
            .doc(userEmail)
            .collection('records')
            .doc(latestRecordId)
            .get();

        if (recordDoc.exists) {
          final data = recordDoc.data()!;
          data['id'] = recordDoc.id;
          return data;
        }
      }
      return null;
    } catch (e) {
      print("Error getting latest ghost record: $e");
      return null;
    }
  }

  @override
  void dispose() {
    _watchMessageSubscription?.cancel();
    _announcementsSubscription?.cancel();
    _friendRequestSubscription?.cancel();
    _chatMessageSubscription?.cancel();
    _achievementNotificationSubscription?.cancel();
    _questSubscription?.cancel();
    _controller.dispose();
    _pageController.dispose();
    _fadeController?.dispose();
    super.dispose();
  }

  // (수정 없음)
  @override
  Widget build(BuildContext context) {
    final deviceWidth = MediaQuery.of(context).size.width;
    final deviceHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(body: Center(child: Text("로그인이 필요합니다")));
    }

    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userEmail = user.email!;

    return UpgradeAlert(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    SafeArea(
                      top: false,
                      bottom: false,
                      child: AppBarSection(),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, viewportConstraints) {
                          return SingleChildScrollView(
                            child: Container(
                              constraints: BoxConstraints(
                                minHeight: viewportConstraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    children: [
                                      Transform.translate(
                                        offset: const Offset(0, -15),
                                        child: Column(
                                          children: [
                                            ContentCardSection(
                                              pageController: _pageController,
                                              currentPage: _currentPage,
                                              onPageChanged: (page) =>
                                                  setState(
                                                          () => _currentPage = page),
                                              userEmail: userEmail,
                                            ),
                                            SizedBox(
                                                height: deviceHeight * 0.01),
                                            FreeRunningSection(
                                              constants: widget.constants,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                      const GameSelectionPage()),
                                                );
                                              },
                                            ),

                                            SizedBox(height: deviceHeight * 0.0),

                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                FriendsSection(),
                                                if (_hasNewFriendRequests ||
                                                    _hasNewChatMessages)
                                                  Positioned(
                                                    top: 4,
                                                    right: 16,
                                                    child: Container(
                                                      padding:
                                                      const EdgeInsets.all(
                                                          4.5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                            color: Colors.white,
                                                            width: 1.5),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),

                                            SizedBox(
                                                height: deviceHeight * 0.01),

                                            GameChallengeSection(
                                              hasNewNotification:
                                              _hasNewAchievements ||
                                                  _hasUnclaimedQuests,
                                            ),

                                            if (_isAdmin)
                                              _buildAdminModeCard(context),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                      height: widget.constants.underbarHeight +
                                          bottomPadding -
                                          90),
                                ],
                              ),
                            ),
                          );
                        },
                      ), // LayoutBuilder 끝
                    ),
                  ],
                ),

                // (수정 없음) 하단 네비게이션 바
                Positioned(
                  bottom: -40,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: BottomNavBar(deviceWidth: deviceWidth),
                  ),
                ),
                // (수정 없음) 가운데 달리기 시작 버튼
                CenterButton(
                  animation: _animation,
                  deviceWidth: deviceWidth,
                  constants: widget.constants,
                  onTap: () => _showUseWatchDialog(context), // 👈 ✨ [수정] 수정된 함수 호출
                ),
                // (수정 없음) 환영 메시지
                if (_showWelcomeMessage &&
                    nickname != null &&
                    nickname!.isNotEmpty)
                  Positioned(
                    top: 100,
                    left: 80,
                    right: 80,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "$nickname 님, 환영합니다!",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (수정 없음)
  Widget _buildAdminModeCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminAuthScreen()),
          );
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.bottomRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.white.withOpacity(0.3),
                    ],
                    stops: [0.1, 0.9],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/flame.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '관리자 전용',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '사용자 및 앱 설정 관리',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                    Image.asset(
                      'assets/images/nextbutton.png',
                      width: 40,
                      height: 40,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// (수정 없음)
class MainAnnouncementDialog extends StatefulWidget {
  final List<DocumentSnapshot> announcements;
  final bool isAdmin;
  final Function(String) onHideToday;
  final Function(String) onRemove;

  const MainAnnouncementDialog({
    Key? key,
    required this.announcements,
    required this.isAdmin,
    required this.onHideToday,
    required this.onRemove,
  }) : super(key: key);

  @override
  _MainAnnouncementDialogState createState() => _MainAnnouncementDialogState();
}

// (수정 없음)
class _MainAnnouncementDialogState extends State<MainAnnouncementDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hideTodayChecked = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 300,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemCount: widget.announcements.length,
                    itemBuilder: (context, index) {
                      final announcement = widget.announcements[index];
                      final data = announcement.data() as Map<String, dynamic>;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Icon(Icons.campaign,
                                    color: Colors.blueAccent, size: 20),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data['title'] ?? '공지사항',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ),
                              if (widget.isAdmin)
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: IconButton(
                                    icon: Icon(Icons.delete_forever,
                                        color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      widget.onRemove(announcement.id);
                                      Navigator.of(context).pop();
                                    },
                                    tooltip: '메인 공지에서 내리기',
                                    padding: EdgeInsets.zero,
                                  ),
                                )
                            ],
                          ),
                          SizedBox(height: 12),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Text(
                                  data['message'] ?? '',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.announcements.length > 1) _buildPageIndicator(),
                    Spacer(),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _hideTodayChecked = !_hideTodayChecked;
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _hideTodayChecked,
                              onChanged: (bool? newValue) {
                                setState(() {
                                  _hideTodayChecked = newValue ?? false;
                                });
                              },
                              visualDensity: VisualDensity.compact,
                              activeColor: Colors.grey[700],
                              materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                            ),
                            Text('오늘 하루 안 보기',
                                style: TextStyle(
                                    color: Colors.grey[700], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_hideTodayChecked) {
                          final currentAnnouncementId =
                              widget.announcements[_currentPage].id;
                          widget.onHideToday(currentAnnouncementId);
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text('닫기',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (수정 없음)
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.announcements.length, (index) {
        return Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Colors.blueAccent
                : Colors.grey.withOpacity(0.4),
          ),
        );
      }),
    );
  }
}