import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rundventure/challenge/FreeTalk_Chat_Screen.dart';
import 'package:rundventure/challenge/challenge_screen/navigation_bar.dart'
as custom;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/admin_screen.dart';
import '../admin/utils/admin_permissions.dart';
import 'announcement_form.dart';
import 'chat_room_screen.dart';
import 'components/challenge_form.dart';
import 'admin/event_challenge_detail_screen.dart';
import 'admin/ended_event_challenges_screen.dart';
import 'free_talk_form.dart';

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

// -----------------------------------------------------------------------------
// 챌린지 탭 위젯
// -----------------------------------------------------------------------------
class ChallengeTab extends StatefulWidget {
  final bool isLocked;
  final bool isAdmin;
  final bool isBeingManaged;
  final VoidCallback onManagePressed;
  final Future<Map<String, dynamic>> Function(String) getUserInfo;
  final Map<String, Map<String, dynamic>> userInfoCache;
  const ChallengeTab(
      {Key? key,
        required this.isLocked,
        required this.isAdmin,
        required this.isBeingManaged,
        required this.onManagePressed,
        required this.getUserInfo,
        required this.userInfoCache})
      : super(key: key);
  @override
  State<ChallengeTab> createState() => _ChallengeTabState();
}

class _ChallengeTabState extends State<ChallengeTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _prepareUserData(List<DocumentSnapshot> docs) async {
    final futures = <Future>[];
    for (final doc in docs) {
      final email = (doc.data() as Map<String, dynamic>)['userEmail'];
      if (email != null && !widget.userInfoCache.containsKey(email)) {
        futures.add(widget.getUserInfo(email));
      }
    }
    await Future.wait(futures);
  }

  Widget _buildEventChallengePost(
      DocumentSnapshot eventDoc, BuildContext context) {
    final data = eventDoc.data() as Map<String, dynamic>;
    final eventId = eventDoc.id;
    final String title = data['name'] ?? '제목 없음';
    final String slogan = data['slogan'] ?? '이벤트 챌린지에 참여해보세요!';
    final int participantCount = data['participantCount'] ?? 0;
    final int participantLimit = data['participantLimit'] ?? 0;
    final Timestamp timestamp =
        data['timestamp'] ?? Timestamp.now();
    final duration = int.tryParse(data['duration']?.toString() ?? '0') ?? 0;
    final endDate = timestamp.toDate().add(Duration(days: duration));
    final daysLeft = endDate.difference(DateTime.now()).inDays;

    final String status = data['status'] ?? 'active';

    String limitText =
    participantLimit > 0 ? '$participantCount / $participantLimit명' : '$participantCount명';

    String daysLeftText = '종료';
    Color daysLeftColor = Colors.red;

    String statusTagText = '🔥 이벤트';
    Color statusTagColor = Colors.blueAccent;
    Color borderColor = Colors.blueAccent;
    BoxShadow shadow = BoxShadow(
      color: Colors.blue.withOpacity(0.1),
      blurRadius: 8,
      offset: Offset(0, 4),
    );

    if (status == 'active') {
      daysLeftText = daysLeft >= 0 ? 'D-$daysLeft' : '종료';
      daysLeftColor = Colors.red;
    } else if (status == 'calculating') {
      daysLeftText = '집계 중';
      daysLeftColor = Colors.black87;

      statusTagText = '📊 집계 중';
      statusTagColor = Colors.grey[700]!;
      borderColor = Colors.grey[700]!;
      shadow = BoxShadow(
        color: Colors.grey.withOpacity(0.1),
        blurRadius: 8,
        offset: Offset(0, 4),
      );
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventChallengeDetailScreen(eventChallengeId: eventId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [ shadow ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusTagColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusTagText,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const Spacer(),
                Text(
                  daysLeftText,
                  style: TextStyle(
                      color: daysLeftColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                )
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              slogan,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people_alt_outlined,
                    color: Colors.grey[600], size: 16),
                const SizedBox(width: 6),
                Text(
                  '현재 $limitText 참여 중!',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.isLocked && !widget.isBeingManaged) {
      return _buildLockedPlaceholder(
        '챌린지 게시판',
        isAdmin: widget.isAdmin,
        onManagePressed: widget.onManagePressed,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '챌린지 제목 또는 닉네임으로 검색...',
              prefixIcon:
              const Icon(Icons.search, color: Colors.grey, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear,
                    color: Colors.grey, size: 20),
                onPressed: () => _searchController.clear(),
              )
                  : null,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.black),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('eventChallenges')
                      .where('status', whereIn: ['active', 'calculating'])
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return SizedBox.shrink(); // 이벤트 없으면 공간 차지 안함
                    }
                    final eventDocs = snapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: eventDocs.length,
                      itemBuilder: (context, index) {
                        // 이벤트 챌린지용 위젯 빌더 호출
                        return _buildEventChallengePost(eventDocs[index], context);
                      },
                    );
                  },
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('challenges')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final allDocs = snapshot.data!.docs;
                    final filteredDocs = allDocs.where((doc) {
                      if (_searchQuery.isEmpty) return true;
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['name'] ?? '').toLowerCase();
                      final userEmail = data['userEmail'];
                      final nickname =
                      (widget.userInfoCache[userEmail]?['nickname'] ?? '')
                          .toLowerCase();
                      final query = _searchQuery.toLowerCase();
                      return title.contains(query) || nickname.contains(query);
                    }).toList();
                    return FutureBuilder(
                      future: _prepareUserData(filteredDocs),
                      builder: (context, futureSnapshot) {
                        if (futureSnapshot.connectionState ==
                            ConnectionState.waiting)
                          return const Center(
                              child: CircularProgressIndicator());
                        if (filteredDocs.isEmpty)
                          return Center(
                              child: Text(_searchQuery.isEmpty
                                  ? '작성된 챌린지 게시물이 없습니다.'
                                  : '검색 결과가 없습니다.'));
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final userInfo =
                                widget.userInfoCache[data['userEmail']] ??
                                    {'nickname': '정보 없음', 'profileImageUrl': ''};
                            return _buildChallengePost(
                                doc,
                                userInfo['nickname']!,
                                userInfo['profileImageUrl']!,
                                context);
                          },
                        );
                      },
                    );
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: TextButton.icon(
                    icon: Icon(Icons.history, color: Colors.grey[600], size: 20),
                    label: Text(
                      '종료된 이벤트 보기',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EndedEventChallengesScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 자유게시판 탭 위젯 (수정 없음)
// -----------------------------------------------------------------------------
class FreeTalkTab extends StatefulWidget {
  final bool isLocked;
  final bool isAdmin;
  final bool isBeingManaged;
  final VoidCallback onManagePressed;
  final Future<Map<String, dynamic>> Function(String) getUserInfo;
  final Map<String, Map<String, dynamic>> userInfoCache;
  const FreeTalkTab(
      {Key? key,
        required this.isLocked,
        required this.isAdmin,
        required this.isBeingManaged,
        required this.onManagePressed,
        required this.getUserInfo,
        required this.userInfoCache})
      : super(key: key);
  @override
  State<FreeTalkTab> createState() => _FreeTalkTabState();
}

class _FreeTalkTabState extends State<FreeTalkTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _prepareUserData(List<DocumentSnapshot> docs) async {
    final futures = <Future>[];
    for (final doc in docs) {
      final email = (doc.data() as Map<String, dynamic>)['userEmail'];
      if (email != null && !widget.userInfoCache.containsKey(email)) {
        futures.add(widget.getUserInfo(email));
      }
    }
    await Future.wait(futures);
  }

  Future<int> _getLikeCount(String postId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('freeTalks')
        .doc(postId)
        .collection('likes')
        .get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.isLocked && !widget.isBeingManaged) {
      return _buildLockedPlaceholder(
        '자유게시판',
        isAdmin: widget.isAdmin,
        onManagePressed: widget.onManagePressed,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '자유게시판 제목 또는 닉네임으로 검색...',
              prefixIcon:
              const Icon(Icons.search, color: Colors.grey, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear,
                    color: Colors.grey, size: 20),
                onPressed: () => _searchController.clear(),
              )
                  : null,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.black),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('freeTalks')
                .orderBy('isNotice', descending: true)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final title = (data['title'] ?? '').toLowerCase();
                final userEmail = data['userEmail'];
                final nickname =
                (widget.userInfoCache[userEmail]?['nickname'] ?? '')
                    .toLowerCase();
                final query = _searchQuery.toLowerCase();
                return title.contains(query) || nickname.contains(query);
              }).toList();
              return FutureBuilder(
                future: _prepareUserData(filteredDocs),
                builder: (context, futureSnapshot) {
                  if (futureSnapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (filteredDocs.isEmpty)
                    return Center(
                        child: Text(_searchQuery.isEmpty
                            ? '작성된 게시물이 없습니다.'
                            : '검색 결과가 없습니다.'));
                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final userInfo =
                          widget.userInfoCache[data['userEmail']] ??
                              {'nickname': '정보 없음', 'profileImageUrl': ''};
                      return FutureBuilder<int>(
                        future: _getLikeCount(doc.id),
                        builder: (context, likeSnap) {
                          return _buildFreeTalkPost(
                              doc,
                              userInfo['nickname']!,
                              userInfo['profileImageUrl']!,
                              likeSnap.data ?? 0,
                              context,
                              isNotice: data['isNotice'] ?? false);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 공지사항 탭 위젯 (수정 없음)
// -----------------------------------------------------------------------------
class AnnouncementsTab extends StatefulWidget {
  final bool canManage;
  const AnnouncementsTab({Key? key, required this.canManage}) : super(key: key);
  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '공지사항 제목으로 검색...',
                prefixIcon:
                const Icon(Icons.search, color: Colors.grey, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: Colors.grey, size: 20),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData)
                  return const Center(child: Text("등록된 공지사항이 없습니다."));
                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return title.contains(query);
                }).toList();
                if (filteredDocs.isEmpty) {
                  return Center(
                      child: Text(_searchQuery.isEmpty
                          ? "등록된 공지사항이 없습니다."
                          : "검색 결과가 없습니다."));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8.0),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    return _buildAnnouncementPost(
                        filteredDocs[index], context, widget.canManage);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 헬퍼 위젯 (수정 없음)
// -----------------------------------------------------------------------------
Widget _buildLockedPlaceholder(String boardName,
    {required bool isAdmin, VoidCallback? onManagePressed}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('$boardName 점검 중',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            '관리자에 의해 게시판이 일시적으로 비활성화되었습니다.\n나중에 다시 확인해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.security, size: 18),
              label: const Text('게시물 관리'),
              onPressed: onManagePressed,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildChallengePost(DocumentSnapshot challenge, String nickname,
    String profileImageUrl, BuildContext context) {
  final challengeId = challenge.id;
  final String title = challenge['name'] ?? '제목 없음';
  final String subtitle =
      "기간: ${challenge['duration']} | 거리: ${challenge['distance']}";
  final String time =
      (challenge['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(
          0, 16) ??
          "날짜 없음";
  return Column(children: [
    InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChatRoomScreen(challengeId: challengeId))),
        child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  const SizedBox(height: 6),
                  Row(children: [
                    CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: profileImageUrl.isNotEmpty
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl.isNotEmpty
                            ? null
                            : Icon(Icons.person,
                            size: 18, color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    Text(nickname,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(time,
                        style:
                        TextStyle(color: Colors.grey[600], fontSize: 12))
                  ])
                ]))),
    Divider(height: 1, thickness: 0.5, color: Colors.grey[300])
  ]);
}

Widget _buildFreeTalkPost(DocumentSnapshot post, String nickname,
    String profileImageUrl, int likeCount, BuildContext context,
    {bool isNotice = false}) {
  final data = post.data() as Map<String, dynamic>;
  final String title = data['title'] ?? '제목 없음';
  final String content = data['content'] ?? '';
  final String time =
      (data['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(
          0, 16) ??
          "날짜 없음";
  final String imageUrl =
  data.containsKey('imageUrl') ? data['imageUrl'] ?? '' : '';
  return Column(children: [
    InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => FreeTalkDetailScreen(
                    postId: post.id,
                    nickname: nickname,
                    title: title,
                    content: content,
                    timestamp: data['timestamp'],
                    postAuthorEmail: data['userEmail'],
                    imageUrl: imageUrl))),
        child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isNotice ? '📢 $title' : title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isNotice ? Colors.red.shade700 : Colors.black)),
                  const SizedBox(height: 6),
                  Row(children: [
                    CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: profileImageUrl.isNotEmpty
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl.isNotEmpty
                            ? null
                            : Icon(Icons.person,
                            size: 18, color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    Text(nickname,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(time,
                        style:
                        TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const Spacer(),
                    const Icon(Icons.thumb_up_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('$likeCount',
                        style:
                        TextStyle(color: Colors.grey[600], fontSize: 12)),
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.photo_camera_back_outlined,
                          size: 14, color: Colors.grey)
                    ]
                  ])
                ]))),
    Divider(height: 1, thickness: 0.5, color: Colors.grey[300])
  ]);
}

// (수정 없음) _buildAnnouncementPost 위젯
Widget _buildAnnouncementPost(
    DocumentSnapshot post, BuildContext context, bool canManage) {
  final data = post.data() as Map<String, dynamic>;
  final String title = data['title'] ?? '제목 없음';
  final String content = data['content'] ?? '';
  final String time =
      (data['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(
          0, 10) ??
          "날짜 없음";

  return Column(
    children: [
      InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child:
                        Icon(Icons.close, size: 24, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        content,
                        style: TextStyle(
                            fontSize: 15, height: 1.6, color: Colors.grey[800]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      time,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (canManage) ...[
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('메인 공지 등록'),
                            content: const Text(
                                '이 공지를 앱 시작 시 팝업되는\n[메인 공지사항]으로 등록하시겠습니까?'),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('취소')),
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('등록',
                                      style: TextStyle(color: Colors.blue))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            // MainScreen은 'message' 필드를 읽으므로 'content'를 'message'로 복사
                            await FirebaseFirestore.instance
                                .collection('mainAnnouncements')
                                .add({
                              'title': title,
                              'message': content,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                            if (ScaffoldMessenger.of(context).mounted) {
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
                                          '메인 공지사항으로 등록되었습니다.',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Color(
                                      0xFFFF9F80), // 성공 색상 (주황)
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.fromLTRB(
                                      15, 5, 15, 15),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (ScaffoldMessenger.of(context).mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '등록 실패: $e',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors
                                      .redAccent.shade400, // 실패 색상
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.fromLTRB(
                                      15, 5, 15, 15),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Icon(Icons.campaign_outlined,
                          color: Colors.blueAccent,
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('공지 삭제'),
                            content: const Text('정말 이 공지사항을 삭제하시겠습니까?'),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('취소')),
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('삭제',
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection('announcements')
                              .doc(post.id)
                              .delete();
                        }
                      },
                      child: Icon(Icons.delete_outline,
                          color: Colors.grey, size: 20),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                time,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
      Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),
    ],
  );
}