import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'challenge_post_widgets.dart';

/// 공지사항 탭 위젯입니다.
class AnnouncementsTab extends StatefulWidget {
  final bool canManage;

  const AnnouncementsTab({Key? key, required this.canManage}) : super(key: key);

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab>
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '공지사항 제목으로 검색...',
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
                  .collection('announcements')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData)
                  return const Center(child: Text("등록된 공지사항이 없습니다."));
                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return title.contains(query);
                }).toList();
                if (filteredDocs.isEmpty) {
                  return Center(
                      child: Text(_searchQuery.isEmpty
                          ? "등록된 공지사항이 없습니다."
                          : "검색 결과가 없습니다."));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8.0),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    return buildAnnouncementPost(
                        filteredDocs[index], context, widget.canManage);
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
