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
// ▼▼▼▼▼ [ ✨ 신규 추가 ✨ ] ▼▼▼▼▼
import 'admin_list_screen.dart'; // ✅ 임명된 관리자 목록 페이지
// ▲▲▲▲▲ [ ✨ 신규 추가 ✨ ] ▲▲▲▲▲

// AdminPermission 관련 Enum과 Map은 여기서 직접 사용하지 않으므로 제거

// 부모 위젯: 탭 구조 및 AppBar 액션 담당
class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

// ✅ [수정] TabController를 직접 제어하기 위해 SingleTickerProviderStateMixin 추가
class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late Stream<DatabaseEvent> _onlineAdminsStream;
  late Stream<QuerySnapshot> _usersStream;
  late Stream<QuerySnapshot> _adminChatStream;
  // ▼▼▼▼▼ [신규 추가] ▼▼▼▼▼
  late Stream<QuerySnapshot> _reportsStream; // 신고 내역 스트림
  // ▲▲▲▲▲ [신규 추가] ▲▲▲▲▲

  bool _isLoading = true;
  bool _isSuperAdmin = false;
  String _currentUserRole = 'user';

  // ✅ [추가] TabController와 현재 탭 인덱스
  late TabController _tabController;
  int _currentTabIndex = 0;

  // ✅ 테마 색상 정의
  static const Color primaryColor = Color(0xFF1E88E5); // Blue Accent
  static const Color consoleBgColor = Color(0xFFF5F5F5); // Light Gray Background

  @override
  void initState() {
    super.initState();
    // ✅ [수정] TabController 길이 2 -> 3
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    _checkCurrentUserRole(); // 👈 [수정] 2단계에서 이 함수 내부를 변경
    _onlineAdminsStream = FirebaseDatabase.instance.ref('adminStatus').orderByChild('isOnline').equalTo(true).onValue.asBroadcastStream();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots().asBroadcastStream();
    _adminChatStream = FirebaseFirestore.instance.collection('adminChat').orderBy('timestamp').snapshots().asBroadcastStream();

    // ▼▼▼▼▼ [신규 추가] ▼▼▼▼▼
    // 'pending' 상태(미처리)인 신고만 불러옵니다.
    _reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asBroadcastStream();
    // ▲▲▲▲▲ [신규 추가] ▲▲▲▲▲
  }

  // ✅ [추가] TabController dispose
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 2. Custom Claim 방식으로 전체 교체 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  // (더 빠르고 안전하며, Firestore .get() 호출이 필요 없음)
  Future<void> _checkCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Auth 토큰에서 'Custom Claim'을 강제로 새로고침하여 가져옵니다.
      final idTokenResult = await currentUser.getIdTokenResult(true); // 'true'가 핵심

      // 2. Claim(신분증)에서 'role'과 'isSuperAdmin' 정보를 읽어옵니다.
      final claims = idTokenResult.claims ?? {};
      final String role = claims['role'] ?? 'user';
      final bool isSuper = claims['isSuperAdmin'] == true; // setAdminRole 함수가 설정한 값

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
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 2. 교체 완료 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  // ✅ [추가] 채팅 삭제 확인 다이얼로그를 표시하는 함수
  Future<void> _showClearChatConfirmation() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // 심플 디자인 적용
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("전체 삭제 확인")]),
        content: Text("관리자 채팅 기록을 모두 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.", style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text("취소", style: TextStyle(color: Colors.black54))),
          ElevatedButton( // 버튼 디자인 수정
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearAdminChat(); // 삭제 함수 호출
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("삭제", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ [추가] 슈퍼 관리자 권한 복구 로직 함수
  Future<void> _executeSuperAdminRoleRecovery(BuildContext context) async {
    // === 슈퍼 관리자인 경우에만 원래의 로직 실행 ===
    try {
      // 1. 로딩 스낵바 표시 (디자인 개선)
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

      // 2. 함수 호출
      final result = await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('setSuperAdminRole')
          .call();

      // 3. 이전 로딩 스낵바 제거
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // 4. 성공 스낵바 표시
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
      // 3. 이전 로딩 스낵바 제거
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      String errorMessage = "알 수 없는 오류가 발생했습니다.";

      // 에러 코드에 따른 메시지 분기 처리
      if (e.code == 'permission-denied') {
        errorMessage = "권한이 없습니다. (슈퍼 관리자만 가능)";
      } else if (e.code == 'internal') {
        errorMessage = "서버 내부 오류가 발생했습니다.";
      } else {
        errorMessage = "오류 발생: ${e.message}";
      }

      // 4. 실패 스낵바 표시 (빨간색, 간단한 메시지)
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
      // 그 외 일반 예외 처리
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

  // ✅ [신규 추가] 긴급 버튼 클릭 시 확인 다이얼로그 표시 함수
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
            onPressed: () => Navigator.of(ctx).pop(true), // '예' 선택 시 true 반환
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("예 (실행)", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _executeSuperAdminRoleRecovery(context);
      }
    });
  }

  // ✅ [수정] Cloud Function을 호출하여 채팅을 삭제하는 함수 (스낵바 수정)
  Future<void> _clearAdminChat() async {
    // 로딩 다이얼로그 표시
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Center(child: CircularProgressIndicator(color: primaryColor)));

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('clearAdminChat');
      final result = await callable.call();

      final currentUser = FirebaseAuth.instance.currentUser;
      String nickname = currentUser?.email ?? '관리자';
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.email!).get();
      if(userDoc.exists) nickname = (userDoc.data() as Map<String, dynamic>)['nickname'] ?? nickname;

      // 삭제 후 시스템 메시지 추가
      await FirebaseFirestore.instance.collection('adminChat').add({
        'text': '$nickname 님이 모든 채팅 기록을 삭제했습니다.',
        'userEmail': 'system',
        'nickname': '시스템 알림',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if(mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        // ✅ [스낵바 수정] 성공 스낵바 (주황색)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.data['message'] ?? '채팅 기록이 삭제되었습니다.', // '✅' 제거
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9F80), // 주황색
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      if(mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        // ✅ [스낵바 수정] 실패 스낵바 (붉은색)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '채팅 삭제 실패: $e', // '❌' 제거
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

  // ✅ [수정] 섹션 패널 빌더 함수 (디자인 심플하게 변경)
  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 모서리를 조금 더 둥글게
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // 그림자를 연하게
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
        // border: Border.all(color: Colors.grey.shade300, width: 1), // 👈 테두리 제거
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17, // 텍스트 크기 살짝 키움
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              // letterSpacing: 0.5 // 👈 제거 (기본값)
            ),
          ),
          // 👈 Divider 두께 줄이고, 간격 늘림
          const Divider(color: Colors.black12, height: 24, thickness: 0.5),
          child,
        ],
      ),
    );
  }

  // ✅ [수정] 뒤로가기 버튼 오른쪽에 위치할 위젯들을 구성하는 함수
  // 이 함수는 AppBar의 leading에 사용될 예정입니다.
  Widget _buildLeadingWidget(BuildContext context) {
    // 기본 뒤로가기 버튼
    Widget backButton = BackButton(
      color: Colors.black87,
      onPressed: () => Navigator.of(context).pop(), // 명시적으로 pop 호출
    );

    // 긴급 버튼 (슈퍼/총괄 관리자에게 표시)
    Widget emergencyButton = Container();
    if (_isSuperAdmin || _currentUserRole == 'general_admin') {
      emergencyButton = IconButton(
        icon: const Icon(Icons.vpn_key, color: Colors.red),
        tooltip: _isSuperAdmin ? '슈퍼관리자 권한 복구' : '슈퍼관리자 전용 기능 (보기만 가능)',
        onPressed: () async {
          // 1. 총괄 관리자 (권한 없음) 처리
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
            return; // 슈퍼 관리자가 아니면 여기서 종료
          }

          // 2. 슈퍼 관리자 (확인 다이얼로그 호출)
          // ✅ 다이얼로그 호출로 변경
          _showEmergencyConfirmationDialog(context);

        },
      );
    }

    // Row로 묶어 뒤로 가기 버튼과 긴급 버튼을 나란히 배치
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

    // ✅ [수정] DefaultTabController를 Scaffold 내부로 이동하고 controller 전달
    return Scaffold(
      backgroundColor: consoleBgColor, // 대시보드 배경색
      appBar: AppBar(
        // ✅ [수정] AppBar 디자인 심플하게 변경
        backgroundColor: Colors.white,
        elevation: 0, // 👈 그림자 제거
        scrolledUnderElevation: 0, // 👈 스크롤 시 그림자 제거
        // shadowColor: Colors.black12, // 👈 제거
        iconTheme: IconThemeData(color: Colors.black87),

        // ▼▼▼▼▼ [ ✨ 요청 수정: leading 변경 ✨ ] ▼▼▼▼▼
        automaticallyImplyLeading: false, // 기본 뒤로가기 버튼 자동 생성 방지
        leading: _buildLeadingWidget(context), // 뒤로가기 버튼과 긴급 버튼을 묶어서 leading에 배치
        leadingWidth: _isSuperAdmin || _currentUserRole == 'general_admin' ? 100 : 56, // 긴급 버튼 포함 여부에 따라 leading 영역 너비 조절
        // ▲▲▲▲▲ [ ✨ 요청 수정: leading 변경 ✨ ] ▲▲▲▲▲

        title: Text("관리자 콘솔$roleTitle", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        // ▼▼▼▼▼ [ ✨ 요청 수정 ✨ ] ▼▼▼▼▼
        centerTitle: true, // ✅ AppBar 제목 중앙 정렬
        // ▲▲▲▲▲ [ ✨ 요청 수정 ✨ ] ▲▲▲▲▲
        actions: [
          // ▼▼▼▼▼ [ 🔥 긴급 버튼은 leading으로 이동했으므로, 여기서 제거 🔥 ] ▼▼▼▼▼
          // ▲▲▲▲▲ [ 🔥 긴급 버튼 제거 끝 🔥 ] ▲▲▲▲▲

          // 슈퍼관리자 또는 총괄관리자이고, 채팅 탭이 선택되었을 때만 삭제 버튼 표시
          if ((_isSuperAdmin || _currentUserRole == 'general_admin') && _currentTabIndex == 1)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              tooltip: '채팅 전체 삭제',
              onPressed: _showClearChatConfirmation,
            ),

          // ▼▼▼▼▼ [ ✨ 임명된 관리자 목록 버튼 ✨ ] ▼▼▼▼▼
          // 임명된 관리자 목록 보기 버튼 (모든 관리자에게 보임)
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
          const SizedBox(width: 10), // 오른쪽 여백
          // ▲▲▲▲▲ [ ✨ 임명된 관리자 목록 버튼 끝 ✨ ] ▲▲▲▲▲
        ],
        bottom: TabBar(
          // ✅ [수정] TabBar 디자인 변경
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorWeight: 2.5, // 👈 두께 조절
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(icon: Icon(Icons.people_alt_outlined), text: "사용자 관리"),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: "관리자 채팅"),
            // ▼▼▼▼▼ [신규 추가] ▼▼▼▼▼
            Tab(icon: Icon(Icons.report_problem_outlined), text: "신고 내역"),
            // ▲▲▲▲▲ [신규 추가] ▲▲▲▲▲
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
            // ✅ _buildPanel 함수 전달 (새 디자인 적용)
            buildPanel: _buildPanel,
          ),
          AdminChatTab(adminChatStream: _adminChatStream),
          // ▼▼▼▼▼ [신규 추가] ▼▼▼▼▼
          ReportManagementTab(
            reportsStream: _reportsStream,
            buildPanel: _buildPanel,
          ),
          // ▲▲▲▲▲ [신규 추가] ▲▲▲▲▲
        ],
      ),
    );
  }
}