import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_ko show KoMessages;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rundventure/challenge/chat_room_screen.dart';
import '../challenge/FreeTalk_Chat_Screen.dart';
import '../friends/friend_management_screen.dart';
import 'package:rundventure/game_selection/friend_battle_lobby_screen.dart';
import 'package:rundventure/game_selection/async_battle_list_screen.dart';

enum SnackBarType { info, success, error }

class UserNotificationPage extends StatefulWidget {
  @override
  _UserNotificationPageState createState() => _UserNotificationPageState();
}

class _UserNotificationPageState extends State<UserNotificationPage>
    with SingleTickerProviderStateMixin {

  List<DocumentSnapshot> notifications = [];
  StreamSubscription? _subscription;
  bool _isAdmin = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 탭 2개 설정 (일반 / 활동)
    _tabController = TabController(length: 2, vsync: this);
    // 탭 변경 시 화면 갱신 (삭제/읽음 버튼 타겟 변경을 위해)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _checkAdminStatus();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final idTokenResult = await user.getIdTokenResult(true);
      if (mounted) {
        setState(() {
          _isAdmin = idTokenResult.claims?['isAdmin'] == true;
        });
      }
    } catch (e) {
      print("관리자 권한 확인 오류: $e");
    }
  }

  void _listenToNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('notifications')
        .doc(user.email)
        .collection('items')
        .orderBy('timestamp', descending: true);

    _subscription = ref.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          notifications = snapshot.docs;
        });
      }
    });
  }

  bool _isSocialNotification(String type) {
    // 활동 알림(댓글, 친구, 대결 등)인지 확인
    return [
      'comment',
      'freeTalkComment',
      'friend_request',
      'battle_request',
      'async_battle_request',
      'async_battle_turn',
      'async_battle_result'
    ].contains(type);
  }

  List<DocumentSnapshot> get _generalList {
    // 탭 1: 일반 알림 (시스템, 관리자, 도전과제, 퀘스트 등)
    return notifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final type = data['type'] as String? ?? '';
      return !_isSocialNotification(type);
    }).toList();
  }

  List<DocumentSnapshot> get _socialList {
    // 탭 2: 활동 알림 (소셜, 대결, 댓글)
    return notifications.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final type = data['type'] as String? ?? '';
      return _isSocialNotification(type);
    }).toList();
  }

  List<DocumentSnapshot> get _currentTabList {
    return _tabController.index == 0 ? _generalList : _socialList;
  }

  void _markAsRead(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    if (data.containsKey('isRead') && data['isRead'] == false) {
      doc.reference.update({'isRead': true});
    }
  }

  void _deleteNotification(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final type = data['type'] as String?;

    await doc.reference.delete();

    if (type == 'achievement_completed') {
      final achievementId = data['achievementId'] as String?;
      if (achievementId != null && achievementId.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final String notificationKey = 'achv_notif_${achievementId}';
          await prefs.remove(notificationKey);
        } catch (e) {
          print("Error removing SharedPreferences key: $e");
        }
      }
    }
  }

  void _markAllAsRead() async {
    final targetList = _currentTabList;
    if (targetList.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in targetList) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      if (data.containsKey('isRead') && data['isRead'] == false) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  void _deleteAllNotifications() async {
    final targetList = _currentTabList;
    if (targetList.isEmpty) return;

    final String tabName = _tabController.index == 0 ? "일반 알림" : "활동 알림";

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('$tabName 전체 삭제',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text('현재 탭의 모든 알림을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(fontSize: 15)),
          actionsPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          actions: <Widget>[
            TextButton(
              child: Text('취소', style: TextStyle(color: Colors.grey[700])),
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
              ),
              child: Text('삭제',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final prefs = await SharedPreferences.getInstance();
      List<String> keysToRemove = [];

      for (final doc in targetList) {
        batch.delete(doc.reference);

        final data = doc.data() as Map<String, dynamic>? ?? {};
        final type = data['type'] as String?;
        if (type == 'achievement_completed') {
          final achievementId = data['achievementId'] as String?;
          if (achievementId != null && achievementId.isNotEmpty) {
            keysToRemove.add('achv_notif_${achievementId}');
          }
        }
      }
      await batch.commit();

      for (String key in keysToRemove) {
        await prefs.remove(key);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$tabName이 모두 삭제되었습니다.")),
        );
      }
    } catch (e) {
      print("전체 삭제 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("삭제 중 오류가 발생했습니다.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('ko', timeago_ko.KoMessages());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNotificationList(_generalList, "📭 일반 알림이 없습니다"),
                  _buildNotificationList(_socialList, "📭 활동 알림이 없습니다"),
                ],
              ),
            ),

            if (_currentTabList.isNotEmpty) _buildMarkAllAsReadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<DocumentSnapshot> list, String emptyMsg) {
    if (list.isEmpty) {
      return Center(child: Text(emptyMsg));
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final noti = list[index];
        return NotificationCard(
          parentContext: context,
          key: ValueKey(noti.id),
          notification: noti,
          onMarkAsRead: () => _markAsRead(noti),
          onDelete: () => _deleteNotification(noti),
          isAdmin: _isAdmin,
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // 1. 상단 타이틀 및 뒤로가기/삭제 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Image.asset(
                      'assets/images/Back-Navs.png',
                      width: 60,
                      height: 60,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    '알림',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold                    ),
                  ),
                ),
                if (_currentTabList.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _deleteAllNotifications,
                        child: Text(
                          '전체삭제',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: CircleBorder(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 2. 탭 바 추가
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[400],
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(text: "일반 알림"), // 시스템, 관리자, 도전과제
              Tab(text: "활동 알림"), // 댓글, 친구, 대결
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarkAllAsReadButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: _markAllAsRead,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          minimumSize: Size(double.infinity, 50),
        ),
        child: const Text("현재 탭 모두 읽음", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class NotificationCard extends StatefulWidget {
  final BuildContext parentContext;
  final DocumentSnapshot notification;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;
  final bool isAdmin;

  const NotificationCard({
    required Key key,
    required this.parentContext,
    required this.notification,
    required this.onMarkAsRead,
    required this.onDelete,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _NotificationCardState createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _isExpanded = false;

  Future<void> _designateAsAnnouncement(BuildContext context) async {
    final data = widget.notification.data() as Map<String, dynamic>? ?? {};
    final title = data['title'] as String?;
    final message = data['message'] as String?;
    final type = data['type'] as String?;

    final nonAnnounceableTypes = [
      'comment',
      'freeTalkComment',
      'friend_request',
      'quest_completed',
      'achievement_completed',
      'battle_request',
      'async_battle_request',
      'async_battle_turn',
      'async_battle_result',
      'admin_personal',
    ];

    if (nonAnnounceableTypes.contains(type)) {
      _showCustomSnackBar("이 유형의 알림은 메인 공지로 등록할 수 없습니다.",
          type: SnackBarType.error);
      return;
    }
    if (title == null || message == null || title.isEmpty || message.isEmpty) {
      _showCustomSnackBar("공지 등록에 필요한 정보가 부족합니다.", type: SnackBarType.error);
      return;
    }
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('designateAsMainAnnouncement');

      await callable.call({'title': title, 'message': message});

      _showCustomSnackBar("메인 공지사항으로 등록되었습니다.", type: SnackBarType.success);
    } on FirebaseFunctionsException catch (e) {
      _showCustomSnackBar("오류: ${e.message ?? '알 수 없는 오류'}",
          type: SnackBarType.error);
    } catch (e) {
      _showCustomSnackBar("알 수 없는 오류가 발생했습니다.", type: SnackBarType.error);
    }
  }

  Future<void> _callBattleFunction(
      BuildContext context, String functionName, Map<String, dynamic> params) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable(functionName);
      await callable.call(params);
      if (!context.mounted) return;
      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, e.message ?? "알 수 없는 오류");
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, "작업 중 오류가 발생했습니다.");
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showCustomSnackBar(String message,
      {SnackBarType type = SnackBarType.info}) {
    ScaffoldMessenger.of(widget.parentContext).removeCurrentSnackBar();

    final behavior = SnackBarBehavior.floating;
    final margin = EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0);
    final duration = Duration(seconds: 2);

    Widget content;
    Color backgroundColor;
    ShapeBorder shape;

    switch (type) {
      case SnackBarType.success:
        backgroundColor = Color(0xFFFF9F80);
        shape = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12));
        content = Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
        break;

      case SnackBarType.error:
        backgroundColor = Colors.redAccent.shade400;
        shape = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12));
        content = Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
        break;

      case SnackBarType.info:
        backgroundColor = Colors.grey[850]!;
        shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        );
        content = Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white));
    }

    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        behavior: behavior,
        margin: margin,
        shape: shape,
        duration: duration,
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'admin_personal':
        return Icons.admin_panel_settings_outlined;
      case 'async_battle_request':
      case 'async_battle_turn':
        return Icons.history_toggle_off_rounded;
      case 'async_battle_result':
        return Icons.poll_outlined;
      case 'battle_request':
        return Icons.sports_kabaddi_outlined;
      case 'friend_request':
        return Icons.person_add_outlined;
      case 'comment':
      case 'freeTalkComment':
        return Icons.chat_bubble_outline_rounded;
      case 'quest_completed':
        return Icons.list_alt_rounded;
      case 'achievement_completed':
        return Icons.emoji_events_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'admin_personal':
        return Colors.blueGrey.shade600;
      case 'async_battle_request':
      case 'async_battle_turn':
        return Colors.orange.shade600;
      case 'async_battle_result':
        return Colors.purple.shade400;
      case 'battle_request':
        return Colors.red.shade600;
      case 'friend_request':
        return Colors.orange.shade700;
      case 'comment':
      case 'freeTalkComment':
        return Colors.blueAccent.shade200;
      case 'quest_completed':
        return Colors.purple.shade400;
      case 'achievement_completed':
        return Colors.amber.shade700;
      default:
        return Colors.green.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.notification.data() as Map<String, dynamic>? ?? {};

    final dynamic timestampValue = data['timestamp'];
    DateTime? timestamp;
    if (timestampValue is Timestamp) {
      timestamp = timestampValue.toDate();
    } else if (timestampValue is String) {
      timestamp = DateTime.tryParse(timestampValue);
    }
    final relativeTime =
    timestamp != null ? timeago.format(timestamp, locale: 'ko') : '';

    final bool isRead = data['isRead'] as bool? ?? false;
    final String message = data['message'] as String? ?? '';

    String title = data['title'] as String? ?? '';
    final String type = data['type'] as String? ?? '';
    final String? challengeId = data['challengeId'] as String?;
    final String? postId = data['postId'] as String?;

    final String? battleId = data['battleId'] as String?;

    if (title.isEmpty && type == 'comment') {
      final userName = data['userName'] as String? ?? '누군가';
      title = "$userName 님이 챌린지에 댓글을 남겼습니다.";
    } else if (title.isEmpty && type == 'freeTalkComment') {
      final userName = data['userName'] as String? ?? '누군가';
      title = "$userName 님이 게시물에 댓글을 남겼습니다.";
    } else if (title.isEmpty && type == 'friend_request') {
      title = "새로운 친구 요청";
    } else if (title.isEmpty && type == 'battle_request') {
      title = "새로운 대결 신청";
    } else if (title.isEmpty && type == 'async_battle_request') {
      title = "오프라인 대결 신청";
    } else if (title.isEmpty && type == 'async_battle_turn') {
      title = "오프라인 대결 턴";
    } else if (title.isEmpty && type == 'async_battle_result') {
      title = "오프라인 대결 결과";
    } else if (title.isEmpty && type == 'quest_completed') {
      title = "퀘스트 완료!";
    } else if (title.isEmpty && type == 'achievement_completed') {
      title = "도전과제 달성!";
    } else if (title.isEmpty && type == 'admin_personal') {
      title = "관리자 알림";
    } else if (title.isEmpty) {
      title = "새로운 알림";
    }

    final bool isChallengeComment =
    (type == 'comment' && challengeId != null && challengeId.isNotEmpty);
    final bool isFreeTalkComment =
    (type == 'freeTalkComment' && postId != null && postId.isNotEmpty);
    final bool isFriendRequest = (type == 'friend_request');
    final bool isBattleRequest =
    (type == 'battle_request' && battleId != null && battleId.isNotEmpty);
    final bool isAsyncBattleNotification = [
      'async_battle_request',
      'async_battle_turn',
      'async_battle_result'
    ].contains(type) &&
        battleId != null &&
        battleId.isNotEmpty;

    final bool isNavigable = isChallengeComment ||
        isFreeTalkComment ||
        isFriendRequest ||
        isBattleRequest ||
        isAsyncBattleNotification;

    final nonAnnounceableTypes = [
      'comment', 'freeTalkComment', 'friend_request', 'quest_completed',
      'achievement_completed', 'battle_request', 'async_battle_request',
      'async_battle_turn', 'async_battle_result',
      'admin_personal',
    ];
    final bool isAnnounceable = widget.isAdmin &&
        !nonAnnounceableTypes.contains(type) &&
        title.isNotEmpty &&
        message.isNotEmpty;

    void handleTap() {
      setState(() {
        _isExpanded = !_isExpanded;
      });

      if (!isRead) {
        widget.onMarkAsRead();
      }

      if (isNavigable) {
        _showCustomSnackBar('이동하려면 꾹 눌러주세요.', type: SnackBarType.info);
      }
    }

    void handleAction(BuildContext buildContext) {
      if (!isRead) widget.onMarkAsRead();

      if (isFriendRequest) {
        Navigator.push(
          buildContext,
          MaterialPageRoute(
            builder: (context) => FriendManagementScreen(initialIndex: 1),
          ),
        );
      } else if (isBattleRequest) {
        showDialog(
          context: buildContext,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('대결 신청',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Text(message.isNotEmpty ? message : '러닝 대결을 수락하시겠습니까?',
                  style: TextStyle(fontSize: 15)),
              actionsPadding:
              EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              actions: <Widget>[
                TextButton(
                  child: Text('거절', style: TextStyle(color: Colors.redAccent)),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _callBattleFunction(
                        buildContext, 'respondToFriendBattleRequest', {
                      'battleId': battleId,
                      'response': 'rejected',
                    });
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('수락'),
                  onPressed: () async {
                    Navigator.pop(dialogContext);

                    showDialog(
                      context: buildContext,
                      barrierDismissible: false,
                      builder: (context) =>
                          Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final callable = FirebaseFunctions.instanceFor(
                          region: 'asia-northeast3')
                          .httpsCallable('respondToFriendBattleRequest');
                      await callable.call({
                        'battleId': battleId,
                        'response': 'accepted',
                      });

                      if (!context.mounted || !buildContext.mounted) return;
                      Navigator.pop(context);

                      Navigator.push(
                        buildContext,
                        MaterialPageRoute(
                          builder: (context) => FriendBattleLobbyScreen(
                            battleId: battleId,
                            isChallenger: false,
                          ),
                        ),
                      );
                    } on FirebaseFunctionsException catch (e) {
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      if (!buildContext.mounted) return;
                      _showErrorDialog(buildContext, e.message ?? "알 수 없는 오류");
                    } catch (e) {
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      if (!buildContext.mounted) return;
                      _showErrorDialog(buildContext, "작업 중 오류가 발생했습니다.");
                    }
                  },
                ),
              ],
            );
          },
        );
      } else if (isAsyncBattleNotification) {
        Navigator.push(
          buildContext,
          MaterialPageRoute(
            builder: (context) => const AsyncBattleListScreen(),
          ),
        );
      } else if (isChallengeComment) {
        Navigator.push(
          buildContext,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(challengeId: challengeId),
          ),
        );
      } else if (isFreeTalkComment) {
        Navigator.push(
          buildContext,
          MaterialPageRoute(
            builder: (context) => FreeTalkDetailScreen(postId: postId),
          ),
        );
      }
    }

    final IconData iconData = _getNotificationIcon(type);
    final Color iconColor = _getNotificationColor(type);

    Widget cardContent = Material(
      color: isRead ? Colors.white : Colors.blue.shade50.withOpacity(0.5),
      child: InkWell(
        onTap: handleTap,
        onLongPress: isNavigable ? () => handleAction(context) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            border:
            Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                padding: const EdgeInsets.only(top: 2.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      iconData,
                      color: iconColor,
                      size: 20,
                    ),
                    if (!isRead)
                      Positioned(
                        top: 0,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight:
                        isRead ? FontWeight.normal : FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isExpanded &&
                        message.isNotEmpty &&
                        !isFriendRequest)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          maxLines: null,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        relativeTime,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey[400], size: 20),
                onPressed: widget.onDelete,
                tooltip: '알림 삭제',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );

    if (isAnnounceable) {
      return Dismissible(
        key: widget.key!,
        direction: DismissDirection.endToStart,
        background: Container(),
        secondaryBackground: Container(
          color: Colors.blueAccent,
          alignment: Alignment.centerRight,
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
              SizedBox(height: 2),
              Text(
                '메인 공지',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            await _designateAsAnnouncement(context);
          }
          return false;
        },
        child: cardContent,
      );
    } else {
      return cardContent;
    }
  }
}