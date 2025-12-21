import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ [제거] 직접 쿼리 안 함
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SearchFriendScreen extends StatefulWidget {
  const SearchFriendScreen({Key? key}) : super(key: key);

  @override
  _SearchFriendScreenState createState() => _SearchFriendScreenState();
}

// ▼▼▼▼▼ [ 헬퍼 클래스: 검색 결과 모델 ] ▼▼▼▼▼
class FriendSearchResult {
  final String email;
  final String nickname;
  final String? profileImageUrl;
  final String friendshipStatus; // 'none', 'friends', 'pending_sent', 'pending_received'

  FriendSearchResult({
    required this.email,
    required this.nickname,
    this.profileImageUrl,
    required this.friendshipStatus,
  });

  // Firebase Function에서 반환된 Map<String, dynamic>을 파싱하는 팩토리 생성자
  factory FriendSearchResult.fromMap(Map<String, dynamic> map) {
    return FriendSearchResult(
      email: map['email'] as String,
      nickname: map['nickname'] as String,
      profileImageUrl: map['profileImageUrl'] as String?,
      friendshipStatus: map['friendshipStatus'] as String,
    );
  }
}
// ▲▲▲▲▲ [ 헬퍼 클래스 끝 ] ▲▲▲▲▲


class _SearchFriendScreenState extends State<SearchFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  // final String? _myEmail = FirebaseAuth.instance.currentUser?.email;
  final String? _myNickname = FirebaseAuth.instance.currentUser?.displayName;

  bool _isProcessingRequest = false;
  String? _processingEmail; // 현재 요청을 처리 중인 이메일

  List<FriendSearchResult> _searchResults = [];
  String _lastSearchTerm = "";

  bool _isSearching = false; // 검색 로딩 상태

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 스낵바 표시
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// ✅ [핵심] Cloud Function을 호출하여 사용자 검색
  Future<void> _searchUsers() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      _showCustomSnackBar("검색할 닉네임을 입력해주세요.", isError: true);
      return;
    }

    // 키보드 숨기기
    FocusScope.of(context).unfocus();

    if (mounted) {
      setState(() {
        _isSearching = true; // 검색 시작
        _searchResults = [];
        _lastSearchTerm = searchTerm;
      });
    }

    try {
      // 1. 'searchUsersWithStatus' 함수 호출
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('searchUsersWithStatus');

      // 2. 검색어 전달
      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>(
        {'nickname': searchTerm},
      );

      // 3. 결과 처리
      final bool success = result.data['success'] ?? false;
      if (success && mounted) {
        final List<dynamic> userListDynamic = result.data['users'] ?? [];

        final List<FriendSearchResult> userList = userListDynamic
            .map((user) => FriendSearchResult.fromMap(Map<String, dynamic>.from(user as Map)))
            .toList();

        setState(() {
          _searchResults = userList;
        });

      } else {
        _showCustomSnackBar(result.data['message'] ?? '검색 결과를 가져오지 못했습니다.', isError: true);
      }

    } on FirebaseFunctionsException catch (e) {
      print("Cloud Function 오류: ${e.code} / ${e.message}");
      if (mounted) {
        _showCustomSnackBar("검색 오류: ${e.message ?? '알 수 없는 오류'}", isError: true);
      }
    } catch (e) {
      print("일반 오류: $e");
      if (mounted) {
        _showCustomSnackBar("검색 중 알 수 없는 오류가 발생했습니다.", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false; // 검색 종료
        });
      }
    }
  }


  /// ✅ [핵심] 친구 신청 보내기
  /// (Part 1에서 만든 서버 함수가 30명 제한에 걸리면 에러를 던지고, 여기서 그 에러 메시지를 띄웁니다)
  Future<void> _sendFriendRequest(String recipientEmail) async {
    if (_isProcessingRequest) return;

    if (mounted) {
      setState(() {
        _isProcessingRequest = true;
        _processingEmail = recipientEmail;
      });
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('sendFriendRequest');

      await callable.call({'recipientEmail': recipientEmail});

      if (mounted) {
        _showCustomSnackBar("친구 요청을 보냈습니다.", isError: false);

        // 성공 시 상태 변경 ('pending_sent')
        setState(() {
          final index = _searchResults.indexWhere((result) => result.email == recipientEmail);
          if (index != -1) {
            _searchResults[index] = FriendSearchResult(
              email: _searchResults[index].email,
              nickname: _searchResults[index].nickname,
              profileImageUrl: _searchResults[index].profileImageUrl,
              friendshipStatus: 'pending_sent', // 👈 상태 변경
            );
          }
        });
      }

    } on FirebaseFunctionsException catch (e) {
      // 🔥 [중요] 서버에서 "친구 정원(30명)을 초과하여..." 에러를 보내면 여기서 잡힙니다.
      print("Firebase Functions 오류 (sendFriendRequest): ${e.message}");
      // e.message가 그대로 스낵바에 표시됩니다.
      _showCustomSnackBar("오류: ${e.message ?? '알 수 없는 오류'}", isError: true);
    } catch (e) {
      print("일반 오류 (sendFriendRequest): $e");
      _showCustomSnackBar("요청 중 오류가 발생했습니다.", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingRequest = false;
          _processingEmail = null; // 처리 완료
        });
      }
    }
  }

  /// 상태에 따른 위젯 빌더
  Widget _buildTrailingWidget(String friendshipStatus, String userEmail) {
    // 로딩 중 표시
    if (_isProcessingRequest && _processingEmail == userEmail) {
      return Container(
        width: 80,
        alignment: Alignment.center,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    switch (friendshipStatus) {
      case 'friends':
        return Container(
          width: 80,
          alignment: Alignment.center,
          child: Text(
            '이미 친구',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        );
      case 'pending_sent':
        return ElevatedButton(
          onPressed: null, // 비활성화
          child: Text('요청 보냄'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.grey[700],
            padding: EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      case 'pending_received':
        return Container(
          width: 80,
          alignment: Alignment.center,
          child: Text(
            '요청 받음',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500),
          ),
        );
      case 'none':
      default:
        return ElevatedButton(
          onPressed: () => _sendFriendRequest(userEmail),
          child: Text('신청'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFFF9F80),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              'assets/images/Back-Navs.png',
              width: 50,
              height: 50,
            ),
          ),
        ),
        title: const Text(
          '친구 찾기',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // 배경 탭 시 키보드 닫기
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- 검색 바 ---
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '닉네임 입력',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                      onSubmitted: (_) => _searchUsers(), // 엔터키로 검색
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSearching ? null : _searchUsers,
                    child: Text('검색'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: Size(60, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // --- 검색 결과 ---
              Expanded(
                child: Stack(
                  children: [
                    // 로딩 중
                    if (_isSearching)
                      Center(child: CircularProgressIndicator()),

                    // 결과 없음
                    if (!_isSearching && _searchResults.isEmpty)
                      Center(
                        child: Text(
                          _lastSearchTerm.isEmpty
                              ? '친구의 닉네임으로 검색해보세요.'
                              : "'$_lastSearchTerm' 님을 찾을 수 없습니다.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ),

                    // 결과 표시
                    if (!_isSearching && _searchResults.isNotEmpty)
                      ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final resultData = _searchResults[index];
                          final friendshipStatus = resultData.friendshipStatus;
                          final userEmail = resultData.email;
                          final userNickname = resultData.nickname;
                          final userProfileUrl = resultData.profileImageUrl;

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: (userProfileUrl != null && userProfileUrl.isNotEmpty)
                                  ? NetworkImage(userProfileUrl)
                                  : AssetImage('assets/images/user.png') as ImageProvider,
                            ),
                            title: Text(userNickname, style: TextStyle(fontWeight: FontWeight.w600)),
                            trailing: _buildTrailingWidget(friendshipStatus, userEmail),
                          );
                        },
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