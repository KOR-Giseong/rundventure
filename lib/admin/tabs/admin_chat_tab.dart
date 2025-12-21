import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// 탭 2: 관리자 채팅
// -----------------------------------------------------------------------------
class AdminChatTab extends StatefulWidget {
  final Stream<QuerySnapshot> adminChatStream;
  const AdminChatTab({Key? key, required this.adminChatStream})
      : super(key: key);
  @override
  _AdminChatTabState createState() => _AdminChatTabState();
}

class _AdminChatTabState extends State<AdminChatTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser;
  static const Color primaryColor = Color(0xFF1E88E5);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ▼▼▼▼▼▼▼▼▼▼ [추가된 부분] ▼▼▼▼▼▼▼▼▼▼
  // 검색 결과의 인덱스와 GlobalKey를 저장하기 위한 리스트
  List<int> _matchIndices = [];
  List<GlobalKey> _matchKeys = [];
  // 현재 보고 있는 검색 결과의 인덱스 (-1은 선택되지 않음을 의미)
  int _currentMatchIndex = -1;
  // ▲▲▲▲▲▲▲▲▲▲ [추가된 부분] ▲▲▲▲▲▲▲▲▲▲

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 검색 컨트롤러 리스너 추가
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
          // 검색어가 변경되면 현재 선택된 하이라이트 해제
          _currentMatchIndex = -1;
        });
      }
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ▼▼▼▼▼▼▼▼▼▼ [추가된 함수] ▼▼▼▼▼▼▼▼▼▼
  // 특정 인덱스의 매치 항목으로 스크롤하는 함수
  void _scrollToMatch(int index) {
    if (index < 0 || index >= _matchKeys.length) return;

    // 현재 선택된 인덱스 업데이트
    setState(() {
      _currentMatchIndex = index;
    });

    // 해당 GlobalKey의 컨텍스트를 가져와 화면에 보이도록 스크롤
    final context = _matchKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: Duration(milliseconds: 300), // 부드러운 스크롤
        alignment: 0.5, // 화면 중앙에 오도록 정렬
      );
    }
  }

  // 다음 검색 결과로 이동 (아래로)
  void _findNext() {
    if (_matchIndices.isEmpty) return;
    int nextIndex = _currentMatchIndex + 1;
    if (nextIndex >= _matchIndices.length) {
      nextIndex = 0; // 마지막이면 처음으로 순환
    }
    _scrollToMatch(nextIndex);
  }

  // 이전 검색 결과로 이동 (위로)
  void _findPrevious() {
    if (_matchIndices.isEmpty) return;
    int prevIndex = _currentMatchIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _matchIndices.length - 1; // 처음이면 마지막으로 순환
    }
    _scrollToMatch(prevIndex);
  }
  // ▲▲▲▲▲▲▲▲▲▲ [추가된 함수] ▲▲▲▲▲▲▲▲▲▲

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildSearchInput(), // 검색창 위젯

        // ▼▼▼▼▼▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼▼▼▼▼▼
        // 검색 컨트롤 UI (검색어가 있을 때만 보임)
        if (_searchQuery.isNotEmpty) _buildSearchControls(),
        // ▲▲▲▲▲▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲▲▲▲▲▲

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.adminChatStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                return Center(
                    child: CircularProgressIndicator(color: primaryColor));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return Center(
                    child: Text("메시지가 없습니다.",
                        style: TextStyle(color: Colors.grey.shade600)));

              final allDocs = snapshot.data!.docs;

              // --- [ 검색 매칭 로직 ] ---
              // build가 실행될 때마다(검색어 변경 시) 매치 목록을 새로 만듦
              _matchIndices.clear();
              _matchKeys.clear();
              if (_searchQuery.isNotEmpty) {
                for (int i = 0; i < allDocs.length; i++) {
                  final data = allDocs[i].data() as Map<String, dynamic>;
                  final text = (data['text'] ?? '').toLowerCase();
                  final nickname = (data['nickname'] ?? '').toLowerCase();

                  // 시스템 메시지(userEmail == 'system')는 검색에서 제외
                  if (data['userEmail'] != 'system' &&
                      (text.contains(_searchQuery) ||
                          nickname.contains(_searchQuery)))
                  {
                    _matchIndices.add(i); // 매치되는 문서의 인덱스 저장
                  }
                }
                // 매치된 개수만큼 GlobalKey 생성
                _matchKeys = List.generate(_matchIndices.length, (_) => GlobalKey());
              }
              // 현재 선택된 인덱스가 매치 목록 범위를 벗어나면 리셋
              if (_currentMatchIndex >= _matchIndices.length) {
                _currentMatchIndex = -1;
              }
              // --- [ 검색 매칭 로직 끝 ] ---

              // 검색 중이 아닐 때만 자동 스크롤
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_chatScrollController.hasClients && _searchQuery.isEmpty) {
                  _chatScrollController
                      .jumpTo(_chatScrollController.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller: _chatScrollController,
                padding:
                EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                itemCount: allDocs.length,
                itemBuilder: (context, index) {
                  final doc = allDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isMe = data['userEmail'] == currentUser?.email;

                  // --- [ Key 할당 로직 ] ---
                  GlobalKey? itemKey;
                  if (_matchIndices.contains(index)) {
                    // 이 아이템이 검색 결과 중 몇 번째인지 찾음
                    int matchIndex = _matchIndices.indexOf(index);
                    itemKey = _matchKeys[matchIndex];
                  }

                  // --- 날짜 구분선 로직 (Ascending List) ---
                  bool showDateSeparator = false;
                  final dynamic currentTimestamp = data['timestamp'];

                  if (currentTimestamp is Timestamp) {
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final previousDoc = allDocs[index - 1];
                      final dynamic previousTimestamp =
                      (previousDoc.data()
                      as Map<String, dynamic>)['timestamp'];

                      if (previousTimestamp is Timestamp) {
                        if (_isDifferentDay(
                            currentTimestamp, previousTimestamp)) {
                          showDateSeparator = true;
                        }
                      }
                    }
                  }

                  // ▼▼▼▼▼▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼▼▼▼▼▼
                  // Container로 감싸고 Key 할당
                  return Container(
                    key: itemKey,
                    child: Column(
                      children: [
                        if (showDateSeparator && currentTimestamp is Timestamp)
                          _buildDateSeparator(currentTimestamp),

                        _buildChatMessage(data, isMe, _searchQuery),
                      ],
                    ),
                  );
                  // ▲▲▲▲▲▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲▲▲▲▲▲
                },
              );
            },
          ),
        ),
        _buildChatInput(),
      ],
    );
  }

  // 검색창 위젯 (변경 없음)
  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '메시지 또는 닉네임 검색...',
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Colors.grey[600]),
            onPressed: () => _searchController.clear(),
          )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100, // 배경색
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), // 둥근 모서리
            borderSide: BorderSide.none, // 테두리 없음
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 10), // 높이 조절
        ),
      ),
    );
  }

  // ▼▼▼▼▼▼▼▼▼▼ [추가된 부분] ▼▼▼▼▼▼▼▼▼▼
  // 검색 컨트롤 (매치 카운트, 위/아래 버튼) 위젯
  Widget _buildSearchControls() {
    bool hasMatches = _matchIndices.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 매치 카운트
          Text(
            hasMatches ? "${_currentMatchIndex + 1} / ${_matchIndices.length}" : "0 / 0",
            style: TextStyle(
              color: hasMatches ? Colors.black87 : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 16),
          // 이전(위) 버튼
          IconButton(
            icon: Icon(Icons.arrow_upward,
                color: hasMatches ? primaryColor : Colors.grey),
            onPressed: hasMatches ? _findPrevious : null,
            tooltip: '이전 검색 결과',
          ),
          // 다음(아래) 버튼
          IconButton(
            icon: Icon(Icons.arrow_downward,
                color: hasMatches ? primaryColor : Colors.grey),
            onPressed: hasMatches ? _findNext : null,
            tooltip: '다음 검색 결과',
          ),
        ],
      ),
    );
  }
  // ▲▲▲▲▲▲▲▲▲▲ [추가된 부분] ▲▲▲▲▲▲▲▲▲▲


  Widget _buildChatMessage(
      Map<String, dynamic> data, bool isMe, String searchQuery) {
    if (data['userEmail'] == 'system') {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            data['text'] ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final CrossAxisAlignment alignment =
    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final Color color = isMe ? primaryColor : Color(0xFFE0E0E0);
    final Color textColor = isMe ? Colors.white : Colors.black;

    // 하이라이트 스타일 정의
    final TextStyle normalStyle = TextStyle(color: textColor, fontSize: 15);
    final TextStyle highlightStyle = TextStyle(
      color: Colors.redAccent, // 닉네임 하이라이트와 동일하게
      backgroundColor: Colors.yellow.withOpacity(0.5), // 텍스트 하이라이트는 배경색 추가
      fontWeight: FontWeight.bold,
      fontSize: 15,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
              // 닉네임 Text를 RichText로 변경 (하이라이트)
              child: RichText(
                text: _highlightText(
                  data['nickname'] ?? '이름없음',
                  searchQuery,
                  TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87),
                  TextStyle( // 닉네임 하이라이트 스타일
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.redAccent,
                      backgroundColor: Colors.yellow.withOpacity(0.5)),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14.0, vertical: 10.0),
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 1,
                            offset: Offset(0, 1))
                      ]),
                  // 메시지 Text를 RichText로 변경 (하이라이트)
                  child: RichText(
                    text: _highlightText(
                      data['text'],
                      searchQuery,
                      normalStyle,
                      highlightStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Text(
              data['timestamp'] != null
                  ? DateFormat('HH:mm')
                  .format((data['timestamp'] as Timestamp).toDate())
                  : '',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Material(
      elevation: 4.0, // 그림자 강조
      shadowColor: Colors.black26,
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none),
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendAdminChatMessage(),
              ),
            ),
            SizedBox(width: 8),
            Container(
              // 전송 버튼 배경 추가
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: Colors.white),
                onPressed: _sendAdminChatMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendAdminChatMessage() async {
    if (_chatController.text.trim().isEmpty) return;
    if (currentUser == null) return;
    String nickname = currentUser!.email ?? '관리자';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.email!)
        .get();
    if (userDoc.exists)
      nickname = (userDoc.data() as Map<String, dynamic>)['nickname'] ?? nickname;
    await FirebaseFirestore.instance.collection('adminChat').add({
      'text': _chatController.text.trim(),
      'userEmail': currentUser!.email,
      'nickname': nickname,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _chatController.clear();
  }

  // 날짜가 다른지 확인하는 헬퍼 함수
  bool _isDifferentDay(Timestamp ts1, Timestamp ts2) {
    final date1 = ts1.toDate();
    final date2 = ts2.toDate();
    return date1.year != date2.year ||
        date1.month != date2.month ||
        date1.day != date2.day;
  }

  // 날짜 구분선 위젯 ('ko_KR' 포함)
  Widget _buildDateSeparator(Timestamp timestamp) {
    final date = timestamp.toDate();
    final formatter = DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR');
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Color(0xFFEFEFF4), // 연한 회색 배경
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          formatter.format(date),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 검색어 하이라이트를 위한 RichText 헬퍼 함수
  TextSpan _highlightText(
      String text, String query, TextStyle normalStyle, TextStyle highlightStyle) {
    if (query.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: normalStyle);
    }

    final List<TextSpan> spans = [];
    final String textLower = text.toLowerCase();
    final String queryLower = query.toLowerCase();

    int start = 0;
    while (start < text.length) {
      final int matchIndex = textLower.indexOf(queryLower, start);

      // 일치하는 부분이 더 이상 없으면
      if (matchIndex == -1) {
        spans.add(TextSpan(text: text.substring(start), style: normalStyle));
        break;
      }

      // 일치하는 부분 *이전*의 텍스트 (일반 스타일)
      if (matchIndex > start) {
        spans.add(TextSpan(
            text: text.substring(start, matchIndex), style: normalStyle));
      }

      // 일치하는 부분 *자체*의 텍스트 (하이라이트 스타일)
      final int matchEnd = matchIndex + query.length;
      spans.add(TextSpan(
          text: text.substring(matchIndex, matchEnd), style: highlightStyle));

      // 다음 검색 시작 위치 갱신
      start = matchEnd;
    }

    return TextSpan(children: spans);
  }
}