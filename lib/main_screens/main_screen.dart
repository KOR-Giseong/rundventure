import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:upgrader/upgrader.dart';

import '../Achievement/quest_service.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import '../free_running/free_running_start.dart';
import '../presentation/providers/announcement_provider.dart';
import '../presentation/providers/notification_badge_provider.dart';
import 'components/app_bar_section.dart';
import 'components/bottom_nav_bar.dart';
import 'components/center_button.dart';
import 'components/content_card.dart';
import 'components/free_running_section.dart';
import 'components/friends_section.dart';
import 'components/game_challenge_section.dart';
import 'constants/main_screen_constants.dart';
import 'game_running/game_running_section.dart';
import 'services/watch_command_handler.dart';
import 'widgets/admin_mode_card.dart';
import 'widgets/main_announcement_dialog.dart';
import 'widgets/welcome_message_overlay.dart';

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
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  // ── 애니메이션 ─────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  AnimationController? _fadeController;
  late Animation<double> _fadeAnimation;

  // ── 페이지 컨트롤러 ─────────────────────────────────────────
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── 어드민 / 로딩 ─────────────────────────────────────────
  bool _isAdmin = false;
  bool _loading = true;

  // ── 환영 메시지 ───────────────────────────────────────────
  String? _nickname;
  bool _showWelcomeMessage = false;

  // ── WatchOS 핸들러 ───────────────────────────────────────
  late WatchCommandHandler _watchHandler;

  // ── 퀘스트 서비스 ─────────────────────────────────────────
  final QuestService _questService = QuestService();

  @override
  void initState() {
    super.initState();
    _initAnimation();

    _watchHandler = WatchCommandHandler(
      watch: WatchConnectivity(),
      contextGetter: () => context,
    );
    _watchHandler.start();

    // 어드민 체크 후 Provider 시작
    _checkAdminClaim().then((_) {
      if (!mounted) return;
      final badgeProvider = context.read<NotificationBadgeProvider>();
      badgeProvider.startListening();

      final announcementProvider = context.read<AnnouncementProvider>();
      announcementProvider.initialize().then((_) {
        // 공지사항 데이터 로드 후 다이얼로그 표시 체크
        _checkAndShowAnnouncement();
      });

      // 퀘스트 상태 갱신
      _updateQuestStatus();
    });

    if (widget.showWelcomeMessage) {
      _loadWelcomeMessage();
    }
  }

  @override
  void dispose() {
    _watchHandler.stop();
    _pulseController.dispose();
    _pageController.dispose();
    _fadeController?.dispose();
    // Provider는 MyApp에서 생성했으므로 여기서 dispose하지 않습니다.
    // stopListening은 사용자가 로그아웃해서 트리에서 제거될 때 Provider.dispose에서 처리됩니다.
    super.dispose();
  }

  // ── 초기화 메서드 ──────────────────────────────────────────

  void _initAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _checkAdminClaim() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final result = await user.getIdTokenResult(true);
      if (mounted) {
        setState(() {
          _isAdmin = result.claims?['isAdmin'] == true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateQuestStatus() async {
    try {
      await _questService.getQuests();
    } catch (_) {}
  }

  Future<void> _loadWelcomeMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(user.email)
          .get();

      final loadedNickname = doc.data()?['nickname'] as String?;
      if (!mounted || loadedNickname == null || loadedNickname.isEmpty) return;

      setState(() {
        _nickname = loadedNickname;
        _showWelcomeMessage = true;
      });

      _fadeController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _fadeAnimation = CurvedAnimation(
        parent: _fadeController!,
        curve: Curves.easeInOut,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _fadeController!.forward();
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      await _fadeController!.reverse();
      if (!mounted) return;
      setState(() => _showWelcomeMessage = false);
    } catch (_) {
      if (mounted) setState(() => _showWelcomeMessage = false);
    }
  }

  void _checkAndShowAnnouncement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AnnouncementProvider>();
      if (provider.announcements.isNotEmpty && !provider.dialogShown) {
        _showAnnouncementDialog(provider);
      }
    });
  }

  void _showAnnouncementDialog(AnnouncementProvider provider) {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;

    provider.markDialogShown();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MainAnnouncementDialog(
        announcements: provider.announcements,
        isAdmin: _isAdmin,
        onHideToday: (id) => provider.hideToday(id),
        onRemove: (id) => _removeMainAnnouncement(id),
      ),
    ).then((_) {
      if (mounted) provider.markDialogClosed();
    });
  }

  Future<void> _removeMainAnnouncement(String announcementId) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable('removeMainAnnouncement');
      await callable.call({'announcementId': announcementId});

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(AppSnackBar.success('메인 공지에서 내렸습니다.'));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(AppSnackBar.error('공지를 내리는 데 실패했습니다.'));
      }
    }
  }

  void _onCenterButtonTap() async {
    final prefs = await SharedPreferences.getInstance();
    final withWatch = prefs.getBool(PrefKeys.watchSyncEnabled) ?? false;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RunningPage(withWatch: withWatch)),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final deviceWidth = MediaQuery.of(context).size.width;
    final deviceHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Provider 에서 배지 상태를 감시합니다.
    final badgeProvider = context.watch<NotificationBadgeProvider>();

    return UpgradeAlert(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // ── 메인 콘텐츠 ─────────────────────────────
                Column(
                  children: [
                    SafeArea(
                      top: false,
                      bottom: false,
                      child: AppBarSection(),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
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
                                              onPageChanged: (p) => setState(
                                                  () => _currentPage = p),
                                              userEmail: user.email!,
                                            ),
                                            SizedBox(
                                                height: deviceHeight * 0.01),
                                            FreeRunningSection(
                                              constants: widget.constants,
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const GameSelectionPage(),
                                                ),
                                              ),
                                            ),
                                            // ── 친구 섹션 (배지 포함) ──────
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                const FriendsSection(),
                                                if (badgeProvider.hasFriendBadge)
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
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            SizedBox(
                                                height: deviceHeight * 0.01),
                                            // ── 게임/챌린지 섹션 (배지 포함)
                                            GameChallengeSection(
                                              hasNewNotification: badgeProvider
                                                  .hasAchievementBadge,
                                            ),
                                            // ── 관리자 카드 ───────────────
                                            if (_isAdmin)
                                              const AdminModeCard(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: widget.constants.underbarHeight +
                                        bottomPadding -
                                        90,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // ── 하단 네비게이션 바 ───────────────────────
                Positioned(
                  bottom: -40,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: BottomNavBar(deviceWidth: deviceWidth),
                  ),
                ),

                // ── 가운데 달리기 버튼 ───────────────────────
                CenterButton(
                  animation: _pulseAnimation,
                  deviceWidth: deviceWidth,
                  constants: widget.constants,
                  onTap: _onCenterButtonTap,
                ),

                // ── 환영 메시지 오버레이 ─────────────────────
                if (_showWelcomeMessage && _fadeController != null)
                  WelcomeMessageOverlay(
                    nickname: _nickname,
                    fadeAnimation: _fadeAnimation,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
