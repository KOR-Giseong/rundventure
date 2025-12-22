import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:intl/intl.dart'; // AdminChatTab으로 이동
// import 'admin_support_dashboard_screen.dart'; // UserManagementTab으로 이동

// 분리된 파일들 임포트
import 'tabs/user_management_tab.dart';
import 'tabs/admin_chat_tab.dart';
import 'tabs/report_management_tab.dart';
import 'admin_list_screen.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late Stream<DatabaseEvent> _onlineAdminsStream;
  late Stream<QuerySnapshot> _usersStream;
  late Stream<QuerySnapshot> _adminChatStream;
  late Stream<QuerySnapshot> _reportsStream;

  bool _isLoading = true;
  bool _isSuperAdmin = false;
  String _currentUserRole = 'user';

  late TabController _tabController;
  int _currentTabIndex = 0;

  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color consoleBgColor = Color(0xFFF5F5F5); // Light Gray Background

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    _checkCurrentUserRole();
    _onlineAdminsStream = FirebaseDatabase.instance.ref('adminStatus').orderByChild('isOnline').equalTo(true).onValue.asBroadcastStream();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots().asBroadcastStream();
    _adminChatStream = FirebaseFirestore.instance.collection('adminChat').orderBy('timestamp').snapshots().asBroadcastStream();

    _reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asBroadcastStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final idTokenResult = await currentUser.getIdTokenResult(true);

      final claims = idTokenResult.claims ?? {};
      final String role = claims['role'] ?? 'user';
      final bool isSuper = claims['isSuperAdmin'] == true;

      if (mounted) {
        setState(() {
          _currentUserRole = role;
          _isSuperAdmin = isSuper;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error fetching user claims: $e");
    }
  }

  Future<void> _showClearChatConfirmation() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("전체 삭제 확인")]),
        content: Text("관리자 채팅 기록을 모두 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.", style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text("취소", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearAdminChat();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("삭제", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSuperAdminRoleRecovery(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Expanded(child: Text('권한 부여 요청 중... 잠시만 기다려주세요.', style: TextStyle(fontWeight: FontWeight.w500))),
            ],
          ),
          backgroundColor: Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 20),
        ),
      );

      final result = await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('setSuperAdminRole')
          .call();

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      '성공: ${result.data['message']}\n⚠️ 반드시 로그아웃 후 다시 로그인하세요!',
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  )
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      String errorMessage = "알 수 없는 오류가 발생했습니다.";

      if (e.code == 'permission-denied') {
        errorMessage = "권한이 없습니다. (슈퍼 관리자만 가능)";
      } else if (e.code == 'internal') {
        errorMessage = "서버 내부 오류가 발생했습니다.";
      } else {
        errorMessage = "오류 발생: ${e.message}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("작업 중 오류가 발생했습니다."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showEmergencyConfirmationDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [Icon(Icons.vpn_key, color: Colors.red), SizedBox(width: 8), Text("긴급 권한 복구 확인")]),
        content: Text(
          "현재 사용자의 계정을 **슈퍼 관리자**로 임명합니다.\n\n이것은 최종 권한 키이며, 시스템에 중요한 변경을 가할 수 있습니다. 정말 실행하시겠습니까?",
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text("아니오 (취소)", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("예 (실행)", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _executeSuperAdminRoleRecovery(context);
      }
    }    );
  }

  Future<void> _clearAdminChat() async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Center(child: CircularProgressIndicator(color: primaryColor)));

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('clearAdminChat');
      final result = await callable.call();

      final currentUser = FirebaseAuth.instance.currentUser;
      String nickname = currentUser?.email ?? '관리자';
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.email!).get();
      if(userDoc.exists) nickname = (userDoc.data() as Map<String, dynamic>)['nickname'] ?? nickname;

      await FirebaseFirestore.instance.collection('adminChat').add({
        'text': '$nickname 님이 모든 채팅 기록을 삭제했습니다.',
        'userEmail': 'system',
        'nickname': '시스템 알림',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if(mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.data['message'] ?? '채팅 기록이 삭제되었습니다.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9F80),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      if(mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '채팅 삭제 실패: $e',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Divider(color: Colors.black12, height: 24, thickness: 0.5),
          child,
        ],
      ),
    );
  }

  Widget _buildLeadingWidget(BuildContext context) {
    Widget backButton = BackButton(
      color: Colors.black87,
      onPressed: () => Navigator.of(context).pop(),
    );

    Widget emergencyButton = Container();
    if (_isSuperAdmin || _currentUserRole == 'general_admin') {
      emergencyButton = IconButton(
        icon: const Icon(Icons.vpn_key, color: Colors.red),
        tooltip: _isSuperAdmin ? '슈퍼관리자 권한 복구' : '슈퍼관리자 전용 기능 (보기만 가능)',
        onPressed: () async {
          if (!_isSuperAdmin) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '권한 없음: 이 기능은 슈퍼 관리자만 실행할 수 있습니다.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }

          _showEmergencyConfirmationDialog(context);

        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        backButton,
        emergencyButton,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String roleTitle = '';
    if (_isSuperAdmin) {
      roleTitle = ' - 슈퍼 관리자';
    } else {
      switch (_currentUserRole) {
        case 'general_admin':
          roleTitle = ' - 총괄 관리자';
          break;
        case 'admin':
          roleTitle = ' - 일반 관리자';
          break;
      }
    }

    return Scaffold(
      backgroundColor: consoleBgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),

        automaticallyImplyLeading: false,
        leading: _buildLeadingWidget(context),
        leadingWidth: _isSuperAdmin || _currentUserRole == 'general_admin' ? 100 : 56,

        title: Text("관리자 콘솔$roleTitle", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          if ((_isSuperAdmin || _currentUserRole == 'general_admin') && _currentTabIndex == 1)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              tooltip: '채팅 전체 삭제',
              onPressed: _showClearChatConfirmation,
            ),

          IconButton(
            icon: Icon(Icons.admin_panel_settings_outlined, color: Colors.black87),
            tooltip: '임명된 관리자 목록',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminListScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorWeight: 2.5,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(icon: Icon(Icons.people_alt_outlined), text: "사용자 관리"),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: "관리자 채팅"),
            Tab(icon: Icon(Icons.report_problem_outlined), text: "신고 내역"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
        controller: _tabController,
        children: [
          UserManagementTab(
            usersStream: _usersStream,
            onlineAdminsStream: _onlineAdminsStream,
            isSuperAdmin: _isSuperAdmin,
            currentUserRole: _currentUserRole,
            buildPanel: _buildPanel,
          ),
          AdminChatTab(adminChatStream: _adminChatStream),
          ReportManagementTab(
            reportsStream: _reportsStream,
            buildPanel: _buildPanel,
          ),
        ],
      ),
    );
  }
}