import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rundventure/challenge/challenge_screen/navigation_bar.dart'
    as custom;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/utils/admin_permissions.dart';
import 'announcement_form.dart';
import 'free_talk_form.dart';
import 'tabs/challenge_tab.dart';
import 'tabs/free_talk_tab.dart';
import 'tabs/announcements_tab.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({Key? key}) : super(key: key);

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  int _selectedTabIndex = 0;

  bool _isSuperAdmin = false;
  String _currentUserRole = 'user';
  Map<String, dynamic> _currentAdminPermissions = {};

  final DocumentReference _boardStatusRef =
  FirebaseFirestore.instance.collection('boardStatus').doc('status');

  final Map<String, Map<String, dynamic>> _userInfoCache = {};

  bool _hasNewChallenges = false;
  bool _hasNewFreeTalks = false;
  bool _hasNewAnnouncements = false;

  bool _adminWantsToManageChallenge = false;
  bool _adminWantsToManageFreeTalk = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUserPermissions();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _checkAllTabsForNewContent();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUserPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    if (user.email == 'ghdrltjd244142@gmail.com') {
      if (mounted) {
        setState(() {
          _isSuperAdmin = true;
          _currentUserRole = 'super_admin';
        });
      }
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email!)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        if (mounted) {
          setState(() {
            _currentUserRole = data['role'] ?? 'user';
            if (data.containsKey('adminPermissions')) {
              _currentAdminPermissions = data['adminPermissions'];
            }
          });
        }
      }
    } catch (e) {
      print("권한 확인 오류: $e");
    }
  }

  bool _hasPermission(AdminPermission permission) {
    if (_isSuperAdmin || _currentUserRole == 'general_admin') return true;
    return _currentAdminPermissions[permission.name] ?? false;
  }

  void _handleTabSelection() {
    if (mounted) {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
        _markTabAsRead(_selectedTabIndex);
      }
      if (_tabController.index != 0 && _adminWantsToManageChallenge) {
        setState(() => _adminWantsToManageChallenge = false);
      }
      if (_tabController.index != 1 && _adminWantsToManageFreeTalk) {
        setState(() => _adminWantsToManageFreeTalk = false);
      }
    }
  }

  Future<void> _markTabAsRead(int index) async {
    String key;
    bool needsUpdate = false;
    switch (index) {
      case 0:
        key = 'last_visit_challenges';
        if (_hasNewChallenges) {
          needsUpdate = true;
          setState(() => _hasNewChallenges = false);
        }
        break;
      case 1:
        key = 'last_visit_freeTalks';
        if (_hasNewFreeTalks) {
          needsUpdate = true;
          setState(() => _hasNewFreeTalks = false);
        }
        break;
      case 2:
        key = 'last_visit_announcements';
        if (_hasNewAnnouncements) {
          needsUpdate = true;
          setState(() => _hasNewAnnouncements = false);
        }
        break;
      default:
        return;
    }
    if (needsUpdate) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, DateTime.now().toIso8601String());
    }
  }

  Future<void> _checkAllTabsForNewContent() async {
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait([
      _isNewContentAvailable(prefs, 'challenges', 'last_visit_challenges'),
      _isNewContentAvailable(prefs, 'freeTalks', 'last_visit_freeTalks'),
      _isNewContentAvailable(
          prefs, 'announcements', 'last_visit_announcements'),
    ]);
    if (mounted) {
      setState(() {
        _hasNewChallenges = results[0];
        _hasNewFreeTalks = results[1];
        _hasNewAnnouncements = results[2];
      });
    }
  }

  Future<bool> _isNewContentAvailable(
      SharedPreferences prefs, String collectionName, String prefKey) async {
    try {
      final lastVisitString = prefs.getString(prefKey);
      final lastVisitTime = lastVisitString != null
          ? DateTime.parse(lastVisitString)
          : DateTime.fromMillisecondsSinceEpoch(0);
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final latestPostTimestamp =
        (snapshot.docs.first.data()['timestamp'] as Timestamp).toDate();
        return latestPostTimestamp.isAfter(lastVisitTime);
      }
    } catch (e) {
      print('$collectionName 새 글 확인 오류: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>> _getUserInfo(String encodedEmail) async {
    if (_userInfoCache.containsKey(encodedEmail))
      return _userInfoCache[encodedEmail]!;
    try {
      String decodedEmail =
      encodedEmail.replaceAll('_at_', '@').replaceAll('_dot_', '.');
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(decodedEmail)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        final userInfo = {
          'nickname': data['nickname'] ?? '익명',
          'profileImageUrl': data['profileImageUrl'] ?? ''
        };
        _userInfoCache[encodedEmail] = userInfo;
        return userInfo;
      }
    } catch (e) {
      print("사용자 정보 가져오기 실패: $e");
    }
    return {'nickname': '익명', 'profileImageUrl': ''};
  }

  void _showLockSettingsDialog(Map<String, dynamic> currentStatus) {
    bool challengeLocked = currentStatus['isChallengeLocked'] ?? false;
    bool freeTalkLocked = currentStatus['isFreeTalkLocked'] ?? false;
    // 1. '익명 댓글 잠금' 상태 변수 추가
    bool anonymousCommentingDisabled =
        currentStatus['isAnonymousCommentingDisabled'] ?? false;

    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0)),
                title: const Text('게시판 잠금 설정',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  SwitchListTile(
                      title: const Text(
                        '챌린지 게시판 잠금',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: challengeLocked,
                      activeColor: Colors.black,
                      onChanged: (value) =>
                          setDialogState(() => challengeLocked = value)),
                  SwitchListTile(
                      title: const Text(
                        '자유게시판 잠금',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: freeTalkLocked,
                      activeColor: Colors.black,
                      onChanged: (value) =>
                          setDialogState(() => freeTalkLocked = value)),
                  SwitchListTile(
                      title: const Text(
                        '익명 댓글 기능 잠금',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: anonymousCommentingDisabled,
                      activeColor: Colors.black,
                      onChanged: (value) => setDialogState(
                              () => anonymousCommentingDisabled = value)),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child:
                      const Text('취소', style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0))),
                      onPressed: () async {
                        // 3. '익명 댓글 잠금' 상태 저장 로직 추가
                        await _boardStatusRef.set({
                          'isChallengeLocked': challengeLocked,
                          'isFreeTalkLocked': freeTalkLocked,
                          'isAnonymousCommentingDisabled':
                          anonymousCommentingDisabled,
                        }, SetOptions(merge: true));
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      child: const Text('저장'))
                ])));
  }

  Widget? _buildFloatingActionButton(bool isFreeTalkLocked) {
    final bool isAdmin = _currentUserRole != 'user';
    final bool shouldShowFreeTalkFab =
        !isFreeTalkLocked || (isAdmin && _adminWantsToManageFreeTalk);

    if (_selectedTabIndex == 1 && shouldShowFreeTalkFab) {
      return FloatingActionButton.extended(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const FreeTalkForm())),
          label: const Text("글쓰기"),
          icon: const Icon(Icons.edit),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white);
    }
    if (_selectedTabIndex == 2 &&
        _hasPermission(AdminPermission.canManageAnnouncements)) {
      return FloatingActionButton.extended(
          onPressed: () async {
            // Navigator.push의 결과를 기다립니다.
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnnouncementForm()),
            );

            // AnnouncementForm에서 true를 반환하면 (성공) 스낵바를 띄우고 탭을 이동합니다.
            if (result == true && mounted) {
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
                          '공지사항이 성공적으로 등록되었습니다.',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Color(0xFFFF9F80), // 성공 색상 (주황)
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
                  duration: Duration(seconds: 2),
                ),
              );
              // 공지사항 탭(인덱스 2)으로 이동
              _tabController.animateTo(2);
            }
          },
          label: const Text("공지 작성"),
          icon: const Icon(Icons.campaign),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _boardStatusRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final boardStatus = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final isChallengeLocked = boardStatus['isChallengeLocked'] ?? false;
        final isFreeTalkLocked = boardStatus['isFreeTalkLocked'] ?? false;

        final bool isAdmin = _currentUserRole != 'user';

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                custom.NavigationBar(
                  actions: [
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.settings),
                        tooltip: '게시판 잠금 설정',
                        onPressed: () => _showLockSettingsDialog(boardStatus),
                      ),
                  ],
                  isChallengeBoardLocked: isChallengeLocked,
                  isAdmin: isAdmin,
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.black,
                  indicatorColor: Colors.black,
                  tabs: [
                    _buildTabWithBadge("챌린지", _hasNewChallenges),
                    _buildTabWithBadge("자유게시판", _hasNewFreeTalks),
                    _buildTabWithBadge("공지사항", _hasNewAnnouncements),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ChallengeTab(
                        isLocked: isChallengeLocked,
                        isAdmin: isAdmin,
                        isBeingManaged: _adminWantsToManageChallenge,
                        onManagePressed: () =>
                            setState(() => _adminWantsToManageChallenge = true),
                        getUserInfo: _getUserInfo,
                        userInfoCache: _userInfoCache,
                      ),
                      FreeTalkTab(
                        isLocked: isFreeTalkLocked,
                        isAdmin: isAdmin,
                        isBeingManaged: _adminWantsToManageFreeTalk,
                        onManagePressed: () =>
                            setState(() => _adminWantsToManageFreeTalk = true),
                        getUserInfo: _getUserInfo,
                        userInfoCache: _userInfoCache,
                      ),
                      AnnouncementsTab(
                        canManage: _hasPermission(
                            AdminPermission.canManageAnnouncements),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          floatingActionButton: _buildFloatingActionButton(isFreeTalkLocked),
          floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Tab _buildTabWithBadge(String title, bool showBadge) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          if (showBadge)
            Padding(
              padding: const EdgeInsets.only(left: 5.0),
              child: Icon(Icons.circle, color: Colors.red, size: 8),
            ),
        ],
      ),
    );
  }
}

