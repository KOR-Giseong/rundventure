import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'challenge_post_widgets.dart';

/// 자유게시판 탭 위젯입니다.
class FreeTalkTab extends StatefulWidget {
  final bool isLocked;
  final bool isAdmin;
  final bool isBeingManaged;
  final VoidCallback onManagePressed;
  final Future<Map<String, dynamic>> Function(String) getUserInfo;
  final Map<String, Map<String, dynamic>> userInfoCache;

  const FreeTalkTab({
    Key? key,
    required this.isLocked,
    required this.isAdmin,
    required this.isBeingManaged,
    required this.onManagePressed,
    required this.getUserInfo,
    required this.userInfoCache,
  }) : super(key: key);

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
      return buildLockedPlaceholder(
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
                  if (futureSnapshot.connectionState ==
                      ConnectionState.waiting)
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
                          return buildFreeTalkPost(
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
