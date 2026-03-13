import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/event_challenge_detail_screen.dart';
import '../admin/ended_event_challenges_screen.dart';
import 'challenge_post_widgets.dart';

/// 챌린지 게시판 탭 위젯입니다.
class ChallengeTab extends StatefulWidget {
  final bool isLocked;
  final bool isAdmin;
  final bool isBeingManaged;
  final VoidCallback onManagePressed;
  final Future<Map<String, dynamic>> Function(String) getUserInfo;
  final Map<String, Map<String, dynamic>> userInfoCache;

  const ChallengeTab({
    Key? key,
    required this.isLocked,
    required this.isAdmin,
    required this.isBeingManaged,
    required this.onManagePressed,
    required this.getUserInfo,
    required this.userInfoCache,
  }) : super(key: key);

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
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final duration = int.tryParse(data['duration']?.toString() ?? '0') ?? 0;
    final endDate = timestamp.toDate().add(Duration(days: duration));
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    final String status = data['status'] ?? 'active';

    String limitText = participantLimit > 0
        ? '$participantCount / $participantLimit명'
        : '$participantCount명';

    String daysLeftText = '종료';
    Color daysLeftColor = Colors.red;
    String statusTagText = '🔥 이벤트';
    Color statusTagColor = Colors.blueAccent;
    Color borderColor = Colors.blueAccent;
    BoxShadow shadow = BoxShadow(
      color: Colors.blue.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
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
        offset: const Offset(0, 4),
      );
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventChallengeDetailScreen(eventChallengeId: eventId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [shadow],
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
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const Spacer(),
                Text(
                  daysLeftText,
                  style: TextStyle(
                      color: daysLeftColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(slogan,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('참가자: $limitText',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.isLocked && !widget.isBeingManaged) {
      return buildLockedPlaceholder(
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
                      return const SizedBox.shrink();
                    }
                    final eventDocs = snapshot.data!.docs;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: eventDocs.length,
                      itemBuilder: (context, index) {
                        return _buildEventChallengePost(
                            eventDocs[index], context);
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
                      return const Center(
                          child: CircularProgressIndicator());
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
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data =
                                doc.data() as Map<String, dynamic>;
                            final userInfo =
                                widget.userInfoCache[data['userEmail']] ??
                                    {
                                      'nickname': '정보 없음',
                                      'profileImageUrl': ''
                                    };
                            return buildChallengePost(
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
                    icon: Icon(Icons.history,
                        color: Colors.grey[600], size: 20),
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
                          builder: (context) =>
                              EndedEventChallengesScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
