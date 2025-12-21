import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_support_chat_room_screen.dart';

class AdminSupportDashboardScreen extends StatefulWidget {
  const AdminSupportDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminSupportDashboardScreenState createState() =>
      _AdminSupportDashboardScreenState();
}

class _AdminSupportDashboardScreenState
    extends State<AdminSupportDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          // ✅ [수정] trim()을 추가하여 검색어의 앞뒤 공백을 제거합니다.
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: IconButton(
            icon: Image.asset('assets/images/Back-Navs.png',
                width: 45, height: 45),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        title: const Text('1:1 문의함',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          // ▼▼▼▼▼ [신규 추가] 안내 문구 배너 ▼▼▼▼▼
          Container(
            padding: const EdgeInsets.all(12.0),
            // ✅ [수정] 좌우 패딩을 16으로 설정하여 검색창과 맞춤
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "관리자 안내: 1:1 문의 내역은 사용자의 민감한 개인정보를 포함할 수 있습니다. 상담 내용은 절대 외부로 유출되어서는 안 됩니다.",
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
          // ▲▲▲▲▲ [신규 추가] 안내 문구 배너 ▲▲▲▲▲

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '닉네임 또는 내용으로 검색...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
                filled: true,
                fillColor: Colors.grey[100], // 배경색 변경
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 14), // 패딩 조정
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('supportChats')
                  .orderBy('isReadByAdmin', descending: false)
                  .orderBy('lastUpdated', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        '오류가 발생했습니다. Firestore 색인이 필요할 수 있습니다.\n\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('접수된 문의가 없습니다.'));
                }

                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nickname =
                  (data['userNickname'] ?? '').toLowerCase();

                  // ▼▼▼▼▼▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼▼▼▼▼▼
                  // lastMessage(채팅 내용)을 가져옵니다.
                  final String lastMessage =
                  (data['lastMessage'] ?? '').toLowerCase();

                  // 닉네임 *또는* 채팅 내용에 검색어가 포함되어 있는지 확인합니다.
                  return nickname.contains(_searchQuery) ||
                      lastMessage.contains(_searchQuery);
                  // ▲▲▲▲▲▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲▲▲▲▲▲

                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(child: Text('검색 결과가 없습니다.'));
                }

                return ListView.separated(
                  itemCount: filteredDocs.length,
                  separatorBuilder: (context, index) {
                    return Divider(
                        height: 1,
                        color: Colors.grey[200],
                        indent: 16,
                        endIndent: 16);
                  },
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String userEmail = data['userEmail'] ?? '알 수 없음';
                    final String userNickname =
                        data['userNickname'] ?? userEmail;
                    final String lastMessage = data['lastMessage'] ?? '...';
                    final bool isReadByAdmin = data['isReadByAdmin'] ?? false;
                    final bool isChatClosed = data['isChatClosed'] ?? false;
                    final Timestamp? lastUpdated = data['lastUpdated'];

                    final String? assignedAdmin =
                    data['assignedAdminNickname'];

                    String timeAgo = '';
                    if (lastUpdated != null) {
                      timeAgo = DateFormat('MM/dd HH:mm')
                          .format(lastUpdated.toDate());
                    }

                    Icon statusIcon;
                    if (!isReadByAdmin) {
                      statusIcon = Icon(Icons.circle,
                          color: Colors.blueAccent, size: 12);
                    } else if (isChatClosed) {
                      statusIcon = Icon(Icons.circle,
                          color: Colors.redAccent, size: 12);
                    } else {
                      statusIcon =
                          Icon(Icons.circle, color: Colors.green, size: 12);
                    }

                    return Material(
                      color: !isReadByAdmin
                          ? Colors.blue[50]!.withOpacity(0.5)
                          : Colors.white,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminSupportChatRoomScreen(
                                userEmail: userEmail,
                                userNickname: userNickname,
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: statusIcon,
                          title: Text(
                            userNickname,
                            style: TextStyle(
                              fontWeight: !isReadByAdmin
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (assignedAdmin != null && !isChatClosed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    '담당: $assignedAdmin',
                                    style: TextStyle(
                                      color: Colors.blueAccent[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Text(
                            timeAgo,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ),
                      ),
                    );
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