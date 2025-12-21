import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../admin_support_dashboard_screen.dart'; // 경로 수정
import '../utils/admin_permissions.dart'; // 분리한 파일 임포트
import '../dialogs/permissions_dialog.dart'; // 분리한 파일 임포트
import '../dialogs/user_details_dialog.dart'; // 분리한 파일 임포트

// -----------------------------------------------------------------------------
// 탭 1: 사용자 관리
// -----------------------------------------------------------------------------
class UserManagementTab extends StatefulWidget {
  final Stream<QuerySnapshot> usersStream;
  final Stream<DatabaseEvent> onlineAdminsStream;
  final bool isSuperAdmin;
  final String currentUserRole;
  // ✅ buildPanel 함수 타입 추가
  final Widget Function({required String title, required Widget child}) buildPanel;

  const UserManagementTab({
    Key? key,
    required this.usersStream,
    required this.onlineAdminsStream,
    required this.isSuperAdmin,
    required this.currentUserRole,
    required this.buildPanel, // 생성자에 추가
  }) : super(key: key);

  @override
  _UserManagementTabState createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab>
    with AutomaticKeepAliveClientMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final TextEditingController _newPasswordController = TextEditingController();
  final String _superAdminEmail = 'ghdrltjd244142@gmail.com';
  Map<String, dynamic> _currentAdminPermissions = {};

  static const Color primaryColor = Color(0xFF1E88E5); // Blue Accent

  // ▼▼▼▼▼ [ ✨ 신규 추가 ✨ ] ▼▼▼▼▼
  bool _isCleaningSessions = false; // 세션 정리 로딩 스피너용
  // ▲▲▲▲▲ [ ✨ 신규 추가 ✨ ] ▲▲▲▲▲

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // ▼▼▼▼▼ [핵심 수정] ▼▼▼▼▼
    // 관리자 탭이 로드될 때, 온라인 상태를 RTDB에 등록하고
    // 비정상 종료 시 자동 삭제되도록 예약을 겁니다.
    _setAdminOnlineStatus();
    // ▲▲▲▲▲ [핵심 수정] ▼▼▼▼▼

    if (widget.currentUserRole == 'admin') {
      _loadAdminPermissions();
    }
    _searchController.addListener(() {
      if (mounted) setState(() => _searchQuery = _searchController.text);
    });
  }

  // ▼▼▼▼▼ [새로 추가된 함수] ▼▼▼▼▼
  /// 관리자 세션 시작 시 RTDB에 온라인 상태를 설정하고,
  /// 비정상 종료 시 자동 삭제되도록 onDisconnect 핸들러를 등록합니다.
  Future<void> _setAdminOnlineStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    // currentUser가 null이거나 uid가 없으면 실행 중지
    if (currentUser == null || currentUser.uid == null) {
      print("Admin online status: User not logged in.");
      return;
    }

    // 1. RTDB 경로는 UID를 사용합니다.
    final uid = currentUser.uid;
    final adminStatusRef = FirebaseDatabase.instance.ref('adminStatus/$uid');

    // 2. Firestore에서 최신 닉네임을 가져옵니다. (users 컬렉션은 email을 키로 사용)
    String nickname = '관리자'; // 기본값
    try {
      // currentUser.email이 null일 수 있으므로 방어 코드 추가
      if (currentUser.email != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.email)
            .get();
        if (userDoc.exists) {
          nickname = userDoc.data()?['nickname'] ?? '관리자';
        }
      } else {
        print("Admin online status: User email is null, cannot fetch nickname.");
      }
    } catch (e) {
      print("관리자 닉네임 로딩 실패: $e");
    }

    // 3. RTDB에 '온라인' 상태와 '최신 닉네임'을 씁니다.
    // (이것이 "옛날 닉네임" 문제를 해결합니다)
    try {
      await adminStatusRef.set({
        'isOnline': true,
        'nickname': nickname, // 닉네임을 매번 갱신
        'lastSeen': ServerValue.timestamp, // RTDB 서버 시간
      });

      // 4. [가장 중요] 연결이 끊어지면(강제종료, 크래시) RTDB가 자동으로 이 데이터를 삭제하도록 예약합니다.
      // (이것이 "좀비 데이터" 문제를 해결합니다)
      await adminStatusRef.onDisconnect().remove();
      print("관리자 온라인 상태($nickname, $uid) 설정 및 onDisconnect 핸들러 등록 완료.");

    } catch (e) {
      print("RTDB onDisconnect 설정 실패: $e");
      // 여기서는 스낵바를 띄우기 어려울 수 있으므로 콘솔 로그만 남깁니다.
    }
  }
  // ▲▲▲▲▲ [새로 추가된 함수] ▲▲▲▲▲

  Future<void> _loadAdminPermissions() async {
    if (currentUser == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.email)
        .get();
    if (userDoc.exists &&
        (userDoc.data() as Map<String, dynamic>)
            .containsKey('adminPermissions')) {
      if (mounted) {
        setState(() {
          _currentAdminPermissions =
          (userDoc.data() as Map<String, dynamic>)['adminPermissions'];
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  bool _hasPermission(AdminPermission permission) {
    if (widget.isSuperAdmin || widget.currentUserRole == 'general_admin') {
      return true;
    }
    return _currentAdminPermissions[permission.name] ?? false;
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text.trim().isEmpty) {
      // ✅ [스낵바 수정] 붉은색 경고
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '새 암호를 입력하세요.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('admin_config')
          .set({'password': _newPasswordController.text.trim()});

      // ✅ [스낵바 수정] 주황색 성공
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '암호가 성공적으로 변경되었습니다.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
      _newPasswordController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      // ✅ [스낵바 수정] 붉은색 실패
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '암호 변경 중 오류 발생: $e',
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

  // ▼▼▼▼▼ [ ✨ 수정된 부분 ✨ ] ▼▼▼▼▼
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 실시간 접속 관리자 (모든 관리자 공통)
        widget.buildPanel(
            title: "실시간 접속 관리자",
            child: Column( // ✅ Column으로 감싸서 리스트와 버튼을 넣음
              children: [
                _buildOnlineAdminList(), // 기존 리스트

                // ▼▼▼▼▼ [ ✨ 신규 추가된 버튼 ✨ ] ▼▼▼▼▼
                // 슈퍼 관리자 또는 총괄 관리자에게만 보임
                if (widget.isSuperAdmin || widget.currentUserRole == 'general_admin')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _isCleaningSessions
                        ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : TextButton.icon(
                      icon: Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.blueGrey),
                      label: Text("오래된 세션 정리", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: _runClearStaleSessions,
                    ),
                  ),
                // ▲▲▲▲▲ [ ✨ 신규 추가된 버튼 ✨ ] ▲▲▲▲▲
              ],
            )
        ),
        // ▲▲▲▲▲ [ ✨ 수정된 부분 ✨ ] ▲▲▲▲▲

        // 1:1 고객 문의 패널
        if (widget.currentUserRole == 'admin' ||
            widget.currentUserRole == 'general_admin' ||
            widget.isSuperAdmin)
          widget.buildPanel(
            title: "1:1 고객 문의",
            // StreamBuilder로 감싸서 실시간 '읽지 않음' 여부 확인
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('supportChats')
                  .where('isReadByAdmin', isEqualTo: false) // '읽지 않음' 상태
                  .limit(1) // 1개라도 있는지 효율적으로 확인
                  .snapshots(),
              builder: (context, snapshot) {
                // '읽지 않음' 메시지가 1개 이상 있는지 여부
                bool hasUnreadMessages =
                    snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                return Stack(
                  clipBehavior: Clip.none, // 스택 밖으로 뱃지가 나가도 보이게
                  children: [
                    // 기존 버튼
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                            const AdminSupportDashboardScreen(),
                          ),
                        );
                      },
                      icon: Icon(Icons.support_agent_outlined, size: 20),
                      label:
                      Text("문의 내역 확인하기", style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        elevation: 1,
                      ),
                    ),
                    // '읽지 않음' 뱃지 (빨간 점)
                    if (hasUnreadMessages)
                      Positioned(
                        top: -4, // 버튼 상단에서 살짝 위로
                        right: -4, // 버튼 우측에서 살짝 밖으로
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 10,
                            minHeight: 10,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

        // 전체 알림 전송 (권한 필요)
        if (_hasPermission(AdminPermission.canSendNotifications))
          widget.buildPanel(
            title: "전체 알림 전송",
            child: Column( // Column으로 감싸서 배너와 폼을 넣음
              children: [
                // ▼▼▼▼▼ [신규 추가] 안내 문구 배너 (알림) ▼▼▼▼▼
                Container(
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.only(bottom: 16.0), // 폼과의 간격
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "알림은 모든 사용자에게 즉시 전송됩니다. 긴급 공지 외 불필요한 알림 전송(남용)을 삼가주세요.",
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ▲▲▲▲▲ [신규 추가] 안내 문구 배너 (알림) ▲▲▲▲▲
                _buildNotificationForm(), // 기존 폼
              ],
            ),
          ),

        // 관리자 암호 변경 (슈퍼 관리자만)
        if (widget.isSuperAdmin)
          widget.buildPanel(
            title: "관리자 암호 변경",
            child: Column( // Column으로 감싸서 배너와 폼을 넣음
              children: [
                // ▼▼▼▼▼ [신규 추가] 안내 문구 배너 (보안) ▼▼▼▼▼
                Container(
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.only(bottom: 16.0), // 폼과의 간격
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "이 암호는 관리자 등록 시 사용되는 마스터 암호입니다. 절대 외부에 노출하지 마시고, 주기적으로 변경해주세요.",
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ▲▲▲▲▲ [신규 추가] 안내 문구 배너 (보안) ▲▲▲▲▲
                _buildPasswordChangeForm(), // 기존 폼
              ],
            ),
          ),

        // 등록된 사용자 관리 (권한 필요)
        if (_hasPermission(AdminPermission.canManageUsers) ||
            _hasPermission(AdminPermission.canManageAdminRoles))
          widget.buildPanel(
            title: "등록된 사용자 관리",
            child: Column( // Column으로 감싸서 배너와 폼을 넣음
              children: [
                // ▼▼▼▼▼ [신규 추가] 안내 문구 배너 (개인정보) ▼▼▼▼▼
                Container(
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.only(bottom: 16.0), // 폼과의 간격
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.admin_panel_settings_outlined, color: Colors.blue[700], size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "사용자 정보(이메일, 닉네임, 신체 정보 등)는 민감한 개인정보입니다. 운영 목적 외 열람 및 수정을 금합니다.",
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ▲▲▲▲▲ [신규 추가] 안내 문구 배너 (개인정보) ▲▲▲▲▲
                _buildUserManagementSection(), // 기존 폼
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOnlineAdminList() {
    return SizedBox(
      height: 100,
      child: StreamBuilder<DatabaseEvent>(
        stream: widget.onlineAdminsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData)
            return Center(
                child: CircularProgressIndicator(color: primaryColor));
          if (snapshot.hasError) return Text("오류: ${snapshot.error}");
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null)
            return Center(
                child: Text("접속 중인 관리자가 없습니다.",
                    style: TextStyle(color: Colors.grey.shade600)));

          // data가 Map<Object?, Object?> 타입일 수 있으므로 안전하게 캐스팅
          final dataObject = snapshot.data!.snapshot.value;
          if (dataObject is! Map) {
            return Center(
                child: Text("데이터 형식이 올바르지 않습니다.",
                    style: TextStyle(color: Colors.grey.shade600)));
          }
          final data = Map<String, dynamic>.from(dataObject as Map);

          final onlineAdmins = data.entries
              .where((e) => (e.value as Map?)?['isOnline'] == true) // isOnline: true 필터링 추가
              .map((e) =>
          (e.value as Map)['nickname'] as String? ?? '이름없음')
              .toList();
          if (onlineAdmins.isEmpty)
            return Center(
                child: Text("접속 중인 관리자가 없습니다.",
                    style: TextStyle(color: Colors.grey.shade600)));
          return ListView.builder(
            itemCount: onlineAdmins.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.circle,
                  size: 10, color: Colors.green.shade600),
              title: Text(onlineAdmins[index],
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.black87)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationForm() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: '제목',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          decoration: InputDecoration(
            labelText: '내용',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _sendNotificationToAllUsers,
          icon: Icon(Icons.notifications_active_outlined, size: 20),
          label: Text("알림 전송", style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 50),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordChangeForm() {
    return Column(
      children: [
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            labelText: '새 암호 (숫자 4자리 이상)',
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _changePassword,
          icon: Icon(Icons.key_outlined, size: 20),
          label: const Text('새 암호 저장', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 1,
          ),
        )
      ],
    );
  }

  Widget _buildUserManagementSection() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '이메일 또는 닉네임으로 검색',
            prefixIcon: Icon(Icons.person_search_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            filled: true,
            fillColor: Colors.grey.shade100,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () => _searchController.clear())
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          // ✅ [수정] 사용자 목록 영역 디자인
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300)),
            height: 400,
            child: _buildUserList()),
      ],
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.usersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData)
          return Center(
              child: CircularProgressIndicator(color: primaryColor));
        if (snapshot.hasError)
          return Center(child: Text("불러오기 실패: ${snapshot.error}"));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return Center(
              child: Text("사용자가 없습니다.",
                  style: TextStyle(color: Colors.grey.shade600)));
        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] ?? doc.id).toString().toLowerCase();
          final nickname = (data['nickname'] ?? '').toString().toLowerCase();
          final query = _searchQuery.toLowerCase();
          return email.contains(query) || nickname.contains(query);
        }).toList();
        if (filteredDocs.isEmpty)
          return Center(
              child: Text("일치하는 사용자가 없습니다.",
                  style: TextStyle(color: Colors.grey.shade600)));
        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email'] ?? doc.id;
            final nickname = data['nickname'] ?? '이름 없음';
            final role = data['role'] ?? 'user';
            final isCurrentUser = currentUser?.email == email;
            final isTargetSuperAdmin = email == _superAdminEmail;

            // ✅ [수정] 정지 상태 확인
            final bool isSuspended = data['isSuspended'] ?? false;

            bool canManage = false;
            if (widget.isSuperAdmin) {
              // 슈퍼 관리자는 본인과 타겟 슈퍼 관리자를 제외한 모두 관리 가능
              canManage = !isCurrentUser && !isTargetSuperAdmin;
            } else if (widget.currentUserRole == 'general_admin') {
              // 총괄 관리자는 본인, 슈퍼 관리자, 다른 총괄 관리자를 제외한
              // 'admin' 또는 'user' 역할만 관리 가능하도록 UI를 제한합니다.
              canManage = !isCurrentUser &&
                  role != 'super_admin' &&
                  role != 'general_admin';
            }

            Color roleColor;
            IconData roleIcon;
            if (role == 'general_admin') {
              roleColor = Colors.purple;
              roleIcon = Icons.military_tech_outlined;
            } else if (role == 'admin') {
              roleColor = primaryColor;
              roleIcon = Icons.verified_user_outlined;
            } else {
              roleColor = Colors.grey.shade600;
              roleIcon = Icons.person_outline;
            }

            // ✅ [추가] 정지된 유저 시각적 표시
            if (isSuspended) {
              roleColor = Colors.red.shade400;
              roleIcon = Icons.block;
            }

            return Container(
              decoration: BoxDecoration(
                  border: Border(
                      bottom:
                      BorderSide(color: Colors.grey.shade200, width: 0.5)),
                  color: Colors.white),
              child: ListTile(
                // ✅ [수정] contentPadding을 조정하여 공간 확보
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10.0, vertical: 2.0),
                leading: CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.15),
                  child: Icon(roleIcon, color: roleColor, size: 20),
                ),
                title: Text(nickname,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87)),
                // ✅ [핵심 수정] subtitle에 softWrap: false 및 maxLines: 1을 명시하여 강제적으로 한 줄 표시 및 오버플로우 방지
                subtitle: Text(
                  email,
                  style: TextStyle(color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap:
                  false, // 텍스트가 줄 바꿈되는 것을 방지하여 공간 관리를 단순화합니다.
                ),
                // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 ⭐️⭐️⭐️ ] ▼▼▼▼▼
                onTap: () => _showUserDetailsDialog(
                  context,
                  doc,
                  _hasPermission(AdminPermission.canSendNotifications), // 👈 [수정] 알림 전송 권한 전달
                ),
                // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 ⭐️⭐️⭐️ ] ▲▲▲▲▲
                trailing: canManage
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.manage_accounts,
                          color: Colors.green),
                      tooltip: '관리자 역할/권한 수정',
                      onPressed: () =>
                          _showRoleManagementDialog(context, doc),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      tooltip: '사용자 삭제',
                      onPressed: () =>
                          _showDeleteConfirmation(context, doc, email),
                    ),
                  ],
                )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRoleManagementDialog(
      BuildContext context, DocumentSnapshot userDoc) async {
    final targetUserData = userDoc.data() as Map<String, dynamic>;
    final targetEmail = targetUserData['email'] ?? userDoc.id;
    final targetRole = targetUserData['role'];
    if (widget.isSuperAdmin) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('역할 지정: $targetEmail'),
          content: Text('어떤 역할로 지정하시겠습니까?'),
          actions: [
            TextButton(
                child: Text('일반 사용자'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _demoteUser(targetEmail);
                }),
            TextButton(
                child: Text('일반 관리자'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                      context: context,
                      builder: (dCtx) => PermissionsDialog(
                          userEmail: targetEmail, isGeneralAdmin: false));
                }),
            TextButton(
                child: Text('총괄 관리자'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                      context: context,
                      builder: (dCtx) => PermissionsDialog(
                          userEmail: targetEmail, isGeneralAdmin: true));
                }),
          ],
        ),
      );
    } else if (widget.currentUserRole == 'general_admin') {
      if (targetRole == 'super_admin' || targetRole == 'general_admin') {
        // ✅ [스낵바 수정] 붉은색 경고
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '총괄 관리자 이상의 역할은 변경할 수 없습니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
        return;
      }

      // 타겟이 'admin' 또는 'user'인 경우, 역할 변경 옵션 다이얼로그를 띄웁니다.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          // ✅ 심플한 디자인 적용
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('역할 관리: $targetEmail',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87)),
              const Divider(color: Colors.black12, height: 16, thickness: 1),
            ],
          ),
          content: Text('어떤 역할로 지정하시겠습니까?',
              style: TextStyle(color: Colors.grey.shade700)),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            // 1. 일반 사용자로 해제 (취소/위험 강조)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _demoteUser(targetEmail); // 일반 사용자 해제 함수 호출
              },
              child: Text('일반 사용자 (해제)',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)), // 빨간색으로 위험 강조
            ),
            // 2. 일반 관리자 권한 수정/임명 (Primary Color 강조)
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // 권한 설정을 위한 PermissionsDialog 호출
                showDialog(
                    context: context,
                    builder: (dCtx) => PermissionsDialog(
                        userEmail: targetEmail, isGeneralAdmin: false));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('일반 관리자 (권한 설정)'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _demoteUser(String email) async {
    try {
      // ✅ 리전을 'asia-northeast3'로 명시해야 서울 서버의 함수를 찾을 수 있음
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('removeAdminRole');

      await callable.call({'email': email});
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(email).get();
      final nickname = userDoc.exists
          ? (userDoc.data() as Map<String, dynamic>)['nickname']
          : email;
      await FirebaseFirestore.instance.collection('adminChat').add({
        'text': '$nickname 님이 관리자에서 해제되었습니다.',
        'userEmail': 'system',
        'nickname': '시스템 알림',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        // ✅ [스낵바 수정] 주황색 성공
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '일반 사용자로 변경되었습니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
      if (mounted) {
        // ✅ [스낵바 수정] 붉은색 실패
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '역할 변경 실패: $e',
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

  Future<void> _sendNotificationToAllUsers() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      if (mounted) {
        // ✅ [스낵바 수정] 붉은색 경고
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '제목과 내용을 모두 입력해주세요',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
      return;
    }
    try {
      // ✅✅✅ [핵심 수정] Cloud Function 리전(region) 지정 ✅✅✅
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('sendNotificationToAllUsers');

      await callable.call({'title': title, 'message': message});
      if (mounted) {
        // ✅ [스낵바 수정] 주황색 성공
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '모든 사용자에게 알림이 전송되었습니다',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
      _titleController.clear();
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        // ✅ [스낵바 수정] 붉은색 실패
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '알림 전송 실패: $e',
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

  // ▼▼▼▼▼ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 ⭐️⭐️⭐️ ] ▼▼▼▼▼
  void _showUserDetailsDialog(BuildContext context, DocumentSnapshot doc, bool canSendNotifications) {
    showDialog(
      context: context,
      builder: (ctx) => UserDetailsDialog(
        userDoc: doc,
        canSendNotifications: canSendNotifications, // 👈 [수정] 권한 전달
      ),
    );
  }
  // ▲▲▲▲▲ [ ⭐️⭐️⭐️ 여기가 수정된 부분입니다 ⭐️⭐️⭐️ ] ▲▲▲▲▲

  Future<void> _showDeleteConfirmation(
      BuildContext context, DocumentSnapshot doc, String email) async {
    // 테마 색상 정의 (UserManagementTabState 내에 primaryColor가 정의되어 있어야 함)
    const Color primaryColor = Color(0xFF1E88E5);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        // ✅ 심플한 디자인 적용
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          // 제목 스타일 변경
          Text("사용자 삭제 확인",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 18))
        ]),
        // 내용 스타일 변경
        content: Text("정말 $email 사용자를 삭제하시겠어요?\n이 작업은 되돌릴 수 없습니다.",
            style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          // 취소 버튼 스타일
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("취소", style: TextStyle(color: Colors.black54))),

          // ✅ 삭제 버튼을 ElevatedButton으로 변경하여 위험 강조
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final callable =
                FirebaseFunctions.instance.httpsCallable('deleteUser');
                await callable.call({'uid': doc.id});
                if (mounted) {
                  // ✅ [스낵바 수정] 주황색 성공
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '사용자 삭제 완료',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                if (mounted) {
                  // ✅ [스낵바 수정] 붉은색 실패
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '삭제 실패: $e',
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
            },
            // 버튼 디자인: 빨간색 배경, 흰색 글자
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text("완전 삭제", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ▼▼▼▼▼ [ ✨ 신규 추가된 함수 ✨ ] ▼▼▼▼▼
  /// 'clearStaleAdminSessions' Cloud Function을 호출합니다.
  Future<void> _runClearStaleSessions() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('오래된 세션 정리'),
        content: const Text(
          '접속이 종료되었음에도 목록에 남아있는 (1시간 이상된) 관리자 세션을 강제로 정리합니다.\n\n현재 접속 중인 관리자는 영향을 받지 않습니다.\n실행하시겠습니까?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('정리 실행', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) setState(() => _isCleaningSessions = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('clearStaleAdminSessions');

      final result = await callable.call();
      final message = result.data?['message'] ?? '세션 정리가 완료되었습니다.';

      if (mounted) {
        // ✅ [스낵바 수정] 주황색 성공
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
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
      if (mounted) {
        // ✅ [스낵바 수정] 붉은색 실패
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '세션 정리 실패: ${e.toString()}',
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
    } finally {
      if (mounted) setState(() => _isCleaningSessions = false);
    }
  }
// ▲▲▲▲▲ [ ✨ 신규 추가된 함수 ✨ ] ▲▲▲▲▲
}