import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({Key? key}) : super(key: key);

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  final Stream<QuerySnapshot> _adminsStream = FirebaseFirestore.instance
      .collection('users')
      .where('role', whereIn: ['admin', 'general_admin', 'super_admin'])
      .snapshots();

  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color consoleBgColor = Color(0xFFF5F5F5);

  /// 역할(role)에 따라 적절한 아이콘과 색상을 반환하는 헬퍼 함수
  Map<String, dynamic> _getRoleAppearance(String role) {
    switch (role) {
      case 'super_admin':
        return {
          'icon': Icons.star_rounded,
          'color': Colors.orange,
          'title': '총 운영자 ✨'
        };
      case 'general_admin':
        return {
          'icon': Icons.military_tech_rounded,
          'color': Colors.purple,
          'title': '총괄 관리자 👑'
        };
      case 'admin':
        return {
          'icon': Icons.verified_user_outlined,
          'color': primaryColor,
          'title': '일반 관리자 🛡️'
        };
      default:
        return {
          'icon': Icons.person_outline,
          'color': Colors.grey,
          'title': '알 수 없음'
        };
    }
  }

  /// 관리자 목록 섹션(예: "슈퍼 관리자")을 빌드하는 헬퍼 함수
  Widget _buildAdminSection(
      String title, List<QueryDocumentSnapshot> admins) {
    if (admins.isEmpty) {
      // 해당 역할의 관리자가 없으면 아무것도 표시하지 않음
      return SizedBox.shrink();
    }

    // 역할에 맞는 아이콘과 색상 가져오기 (첫 번째 관리자 기준)
    final appearance = _getRoleAppearance(admins.first['role']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
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
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 섹션 타이틀 ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Icon(appearance['icon'], color: appearance['color'], size: 22),
                  SizedBox(width: 8),
                  Text(
                    "$title (${admins.length}명)",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.black12, height: 1, thickness: 0.5),
            // --- 관리자 목록 ---
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: admins.length,
              itemBuilder: (context, index) {
                final data = admins[index].data() as Map<String, dynamic>;
                final nickname = data['nickname'] ?? '이름 없음';
                final email = data['email'] ?? admins[index].id;

                return ListTile(
                  title: Text(
                    nickname,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  subtitle: Text(
                    email,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                );
              },
              separatorBuilder: (context, index) {
                // 리스트 항목 사이에 구분선 추가
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(
                      color: Colors.grey.shade200, height: 1, thickness: 0.5),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: consoleBgColor, // AdminScreen과 동일한 배경색
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          "임명된 관리자 목록",
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _adminsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text("오류: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "임명된 관리자가 없습니다.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            );
          }

          // --- 관리자 목록을 역할별로 분류 ---
          final List<QueryDocumentSnapshot> superAdmins = [];
          final List<QueryDocumentSnapshot> generalAdmins = [];
          final List<QueryDocumentSnapshot> admins = [];

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final role = data['role'];

            switch (role) {
              case 'super_admin':
                superAdmins.add(doc);
                break;
              case 'general_admin':
                generalAdmins.add(doc);
                break;
              case 'admin':
                admins.add(doc);
                break;
            }
          }

          // 닉네임 순으로 정렬 (선택 사항)
          final sortLogic = (a, b) {
            String nickA = (a.data() as Map<String, dynamic>)['nickname'] ?? '';
            String nickB = (b.data() as Map<String, dynamic>)['nickname'] ?? '';
            return nickA.compareTo(nickB);
          };
          superAdmins.sort(sortLogic);
          generalAdmins.sort(sortLogic);
          admins.sort(sortLogic);

          // --- UI 빌드 ---
          return ListView(
            padding: const EdgeInsets.only(top: 16.0),
            children: [
              _buildAdminSection(
                _getRoleAppearance('super_admin')['title'],
                superAdmins,
              ),
              _buildAdminSection(
                _getRoleAppearance('general_admin')['title'],
                generalAdmins,
              ),
              _buildAdminSection(
                _getRoleAppearance('admin')['title'],
                admins,
              ),
            ],
          );
        },
      ),
    );
  }
}