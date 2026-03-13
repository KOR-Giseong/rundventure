import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../FreeTalk_Chat_Screen.dart';
import '../chat_room_screen.dart';

/// 챌린지/자유게시판/공지사항 탭에서 공통으로 사용되는 포스트 빌더 함수 모음입니다.

Widget buildLockedPlaceholder(
  String boardName, {
  required bool isAdmin,
  VoidCallback? onManagePressed,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('$boardName 점검 중',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            '관리자에 의해 게시판이 일시적으로 비활성화되었습니다.\n나중에 다시 확인해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.security, size: 18),
              label: const Text('게시물 관리'),
              onPressed: onManagePressed,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget buildChallengePost(DocumentSnapshot challenge, String nickname,
    String profileImageUrl, BuildContext context) {
  final challengeId = challenge.id;
  final String title = challenge['name'] ?? '제목 없음';
  final String subtitle =
      "기간: ${challenge['duration']} | 거리: ${challenge['distance']}";
  final String time =
      (challenge['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 16) ??
          "날짜 없음";
  return Column(children: [
    InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChatRoomScreen(challengeId: challengeId))),
        child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              const SizedBox(height: 6),
              Row(children: [
                CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: profileImageUrl.isNotEmpty
                        ? null
                        : Icon(Icons.person, size: 18, color: Colors.grey[600])),
                const SizedBox(width: 8),
                Text(nickname,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(width: 8),
                Text(time,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ])
            ]))),
    Divider(height: 1, thickness: 0.5, color: Colors.grey[300])
  ]);
}

Widget buildFreeTalkPost(DocumentSnapshot post, String nickname,
    String profileImageUrl, int likeCount, BuildContext context,
    {bool isNotice = false}) {
  final data = post.data() as Map<String, dynamic>;
  final String title = data['title'] ?? '제목 없음';
  final String content = data['content'] ?? '';
  final String time =
      (data['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 16) ??
          "날짜 없음";
  final String imageUrl =
      data.containsKey('imageUrl') ? data['imageUrl'] ?? '' : '';
  return Column(children: [
    InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => FreeTalkDetailScreen(
                    postId: post.id,
                    nickname: nickname,
                    title: title,
                    content: content,
                    timestamp: data['timestamp'],
                    postAuthorEmail: data['userEmail'],
                    imageUrl: imageUrl))),
        child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isNotice ? '📢 $title' : title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isNotice ? Colors.red.shade700 : Colors.black)),
              const SizedBox(height: 6),
              Row(children: [
                CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: profileImageUrl.isNotEmpty
                        ? null
                        : Icon(Icons.person, size: 18, color: Colors.grey[600])),
                const SizedBox(width: 8),
                Text(nickname,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(width: 8),
                Text(time,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Spacer(),
                const Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$likeCount',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.photo_camera_back_outlined,
                      size: 14, color: Colors.grey)
                ]
              ])
            ]))),
    Divider(height: 1, thickness: 0.5, color: Colors.grey[300])
  ]);
}

Widget buildAnnouncementPost(
    DocumentSnapshot post, BuildContext context, bool canManage) {
  final data = post.data() as Map<String, dynamic>;
  final String title = data['title'] ?? '제목 없음';
  final String content = data['content'] ?? '';
  final String time =
      (data['timestamp'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 10) ??
          "날짜 없음";

  return Column(
    children: [
      InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(Icons.close,
                            size: 24, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(content,
                          style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors.grey[800])),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(time,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  if (canManage) ...[
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('메인 공지 등록'),
                            content: const Text(
                                '이 공지를 앱 시작 시 팝업되는\n[메인 공지사항]으로 등록하시겠습니까?'),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(false),
                                  child: const Text('취소')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(true),
                                  child: const Text('등록',
                                      style:
                                          TextStyle(color: Colors.blue))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('mainAnnouncements')
                                .add({
                              'title': title,
                              'message': content,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(children: const [
                                    Icon(Icons.check_circle_outline,
                                        color: Colors.white),
                                    SizedBox(width: 12),
                                    Expanded(
                                        child: Text('메인 공지사항으로 등록되었습니다.',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.w500))),
                                  ]),
                                  backgroundColor: const Color(0xFFFF9F80),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  margin: const EdgeInsets.fromLTRB(
                                      15, 5, 15, 15),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text('등록 실패: $e',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.w500))),
                                  ]),
                                  backgroundColor: Colors.redAccent.shade400,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  margin: const EdgeInsets.fromLTRB(
                                      15, 5, 15, 15),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Icon(Icons.campaign_outlined,
                          color: Colors.blueAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('공지 삭제'),
                            content:
                                const Text('정말 이 공지사항을 삭제하시겠습니까?'),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(false),
                                  child: const Text('취소')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(true),
                                  child: const Text('삭제',
                                      style:
                                          TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection('announcements')
                              .doc(post.id)
                              .delete();
                        }
                      },
                      child: Icon(Icons.delete_outline,
                          color: Colors.grey, size: 20),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
      Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),
    ],
  );
}
