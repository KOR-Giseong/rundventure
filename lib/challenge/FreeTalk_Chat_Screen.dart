import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../admin/utils/admin_permissions.dart';
import '../profile/other_user_profile.dart';

const String defaultProfileImageUrl =
    'https://cdn-icons-png.flaticon.com/512/847/847969.png';

class FreeTalkDetailScreen extends StatefulWidget {
  final String postId;
  final String? nickname;
  final String? title;
  final String? content;
  final Timestamp? timestamp;
  final String? postAuthorEmail;
  final String? imageUrl;

  const FreeTalkDetailScreen({
    Key? key,
    required this.postId,
    this.nickname,
    this.title,
    this.content,
    this.timestamp,
    this.postAuthorEmail,
    this.imageUrl,
  }) : super(key: key);

  @override
  State<FreeTalkDetailScreen> createState() => _FreeTalkDetailScreenState();
}

class _FreeTalkDetailScreenState extends State<FreeTalkDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  bool isAnonymous = true;
  String? nickname;
  String? postAuthorProfileImageUrl;
  bool hasLiked = false;
  bool hasDisliked = false;
  int likeCount = 0;
  int dislikeCount = 0;
  String? replyingToCommentId;
  String? replyingToNickname;
  bool isImageExpanded = false;
  bool isExpanded = false;
  bool isNotice = false;
  bool isEditing = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _currentTitle = '';
  String _currentContent = '';
  String _postAuthorEmail = '';
  String _nickname = '';
  Timestamp _timestamp = Timestamp.now();
  String? _imageUrl; // 이미지 URL도 상태 변수로

  bool _isLoading = false;

  bool _isSuperAdmin = false;
  String _currentUserRole = 'user';
  Map<String, dynamic> _currentAdminPermissions = {};

  @override
  void initState() {
    super.initState();

    if (widget.title == null || widget.nickname == null) {
      setState(() {
        _isLoading = true;
      });
      _loadPostData();
    } else {
      _currentTitle = widget.title!;
      _currentContent = widget.content!;
      _postAuthorEmail = widget.postAuthorEmail!;
      _nickname = widget.nickname!;
      _timestamp = widget.timestamp!;
      _imageUrl = widget.imageUrl;

      _titleController.text = _currentTitle;
      _contentController.text = _currentContent;

      _loadPostAuthorProfileImage();
      _loadLikeDislikeState();
      _loadNoticeFlag();
    }

    _loadNickname();
    _checkCurrentUserPermissions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPostData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('freeTalks')
          .doc(widget.postId)
          .get();
      if (!doc.exists || !mounted) {
        setState(() {
          _isLoading = false;
          _currentTitle = "삭제된 게시물입니다.";
          _currentContent = "";
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final authorEmail = data['userEmail'] ?? '';

      final authorInfo = await _getUserInfo(authorEmail);

      if (mounted) {
        setState(() {
          _currentTitle = data['title'] ?? '제목 없음';
          _currentContent = data['content'] ?? '내용 없음';
          _postAuthorEmail = authorEmail;
          _nickname = authorInfo['nickname'] ?? '익명';
          _timestamp = data['timestamp'] ?? Timestamp.now();
          _imageUrl = data['imageUrl'] as String?;
          postAuthorProfileImageUrl = authorInfo['profileImageUrl'];
          isNotice = data['isNotice'] ?? false;

          _titleController.text = _currentTitle;
          _contentController.text = _currentContent;

          _isLoading = false;
        });

        _loadLikeDislikeState();
      }
    } catch (e) {
      print("게시물 데이터 로드 오류: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentTitle = "오류가 발생했습니다.";
        });
      }
    }
  }

  Future<void> _checkCurrentUserPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    if (user.email == 'ghdrltjd244142@gmail.com') {
      if (mounted) setState(() => _isSuperAdmin = true);
      return;
    }

    try {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.email!).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        if (mounted) {
          setState(() {
            _currentUserRole = data['role'] ?? 'user';
            if (data.containsKey('adminPermissions')) {
              _currentAdminPermissions = data['adminPermissions'];
            }
          });
        }
      }
    } catch (e) {
      print("관리자 권한 확인 오류(DetailScreen): $e");
    }
  }

  bool _hasPermission(AdminPermission permission) {
    if (_isSuperAdmin || _currentUserRole == 'general_admin') return true;
    return _currentAdminPermissions[permission.name] ?? false;
  }

  Future<void> _loadNoticeFlag() async {
    if (widget.title != null) {
      final doc = await FirebaseFirestore.instance
          .collection('freeTalks')
          .doc(widget.postId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['isNotice'] == true) {
          setState(() {
            isNotice = true;
          });
        }
      }
    }
  }

  List<DocumentSnapshot> _getNestedReplies(
      String parentId, List<DocumentSnapshot> allReplies) {
    List<DocumentSnapshot> nestedReplies = [];

    for (var reply in allReplies) {
      final replyData = reply.data() as Map<String, dynamic>;
      if (replyData['parentId'] == parentId) {
        nestedReplies.add(reply);
        nestedReplies.addAll(_getNestedReplies(reply.id, allReplies));
      }
    }

    return nestedReplies;
  }

  Future<void> _loadNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.email).get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        nickname = data['nickname'] ?? '익명';
      });
    } else {
      setState(() {
        nickname = '익명';
      });
    }
  }

  Future<void> _loadPostAuthorProfileImage() async {
    final postAuthorEmail = _postAuthorEmail;
    final userInfo = await _getUserInfo(postAuthorEmail);

    setState(() {
      postAuthorProfileImageUrl = userInfo['profileImageUrl'];
    });
  }

  Future<Map<String, String>> _getUserInfo(String encodedEmail) async {
    try {
      String decodedEmail =
      encodedEmail.replaceAll('_at_', '@').replaceAll('_dot_', '.');
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(decodedEmail)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'nickname': data['nickname'] ?? '익명',
          'profileImageUrl': data['profileImageUrl'] ?? '',
        };
      }
    } catch (e) {
      print("사용자 정보 가져오기 실패: $e");
    }
    return {'nickname': '익명', 'profileImageUrl': ''};
  }

  // 댓글 작성 - 보안 규칙 위반으로 인해 알림 로직 제거, 단일 set 사용
  Future<void> _submitComment(bool isAnonymousCommentingDisabled) async {
    final commentText = _commentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (commentText.isEmpty || user == null) return;

    final userEmail = user.email!;

    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userEmail).get();

    String realUserNickname;
    if (userDoc.exists && userDoc.data() != null) {
      final userData = userDoc.data() as Map<String, dynamic>;
      realUserNickname = userData['nickname'] ?? '익명';
    } else {
      realUserNickname = '익명';
    }

    final bool isAnonymousFinal =
    isAnonymousCommentingDisabled ? false : isAnonymous;

    final String commenterNickname =
    isAnonymousFinal ? '익명' : realUserNickname;

    final postRef =
    FirebaseFirestore.instance.collection('freeTalks').doc(widget.postId);

    final newCommentRef = postRef.collection('comments').doc();
    String imageUrl = ''; // 이미지 첨부 기능 미구현

    await newCommentRef.set({
      'userEmail': userEmail,
      'isAnonymous': isAnonymousFinal,
      'nickname': commenterNickname,
      'content': commentText,
      'timestamp': FieldValue.serverTimestamp(),
      'parentId': replyingToCommentId,
      'imageUrl': imageUrl,
    });

    // 알림 로직 제거됨 (보안 규칙 위반)
    // for (String emailToNotify in usersToNotify) {
    //   if (emailToNotify == userEmail) {
    //     continue;
    //   }
    //
    //   final notificationRef = FirebaseFirestore.instance
    //       .collection('notifications')
    //       .doc(emailToNotify)
    //       .collection('items')
    //       .doc();
    //
    //   batch.set(notificationRef, {
    //     'type': 'freeTalkComment',
    //     'userName': commenterNickname,
    //     'message': commentText,
    //     'title': "$commenterNickname 님이 '${postTitle}'에 댓글을 남겼습니다.",
    //     'postId': widget.postId,
    //     'commenterEmail': userEmail,
    //     'timestamp': FieldValue.serverTimestamp(),
    //     'isRead': false,
    //   });
    // }
    //
    // await batch.commit();

    setState(() {
      replyingToCommentId = null;
      replyingToNickname = null;
    });

    _commentController.clear();
  }

  Future<void> _loadLikeDislikeState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email!;
    final postRef =
    FirebaseFirestore.instance.collection('freeTalks').doc(widget.postId);

    final likeSnap = await postRef.collection('likes').doc(email).get();
    final dislikeSnap = await postRef.collection('dislikes').doc(email).get();

    final likeCountSnap = await postRef.collection('likes').get();
    final dislikeCountSnap = await postRef.collection('dislikes').get();

    setState(() {
      hasLiked = likeSnap.exists;
      hasDisliked = dislikeSnap.exists;
      likeCount = likeCountSnap.size;
      dislikeCount = dislikeCountSnap.size;
    });
  }

  Future<void> _handleLikeDislike(bool isLike) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email!;
    final postRef =
    FirebaseFirestore.instance.collection('freeTalks').doc(widget.postId);

    final likeDoc = postRef.collection('likes').doc(email);
    final dislikeDoc = postRef.collection('dislikes').doc(email);

    final likeSnap = await likeDoc.get();
    final dislikeSnap = await dislikeDoc.get();

    if (isLike) {
      if (likeSnap.exists) {
        await likeDoc.delete();
      } else {
        await likeDoc.set({
          'userEmail': email,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (dislikeSnap.exists) await dislikeDoc.delete();
      }
    } else {
      if (dislikeSnap.exists) {
        await dislikeDoc.delete();
      } else {
        await dislikeDoc.set({
          'userEmail': email,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (likeSnap.exists) await likeDoc.delete();
      }
    }

    await _loadLikeDislikeState();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dt = timestamp.toDate();
    return DateFormat('MM/dd HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final postRef =
    FirebaseFirestore.instance.collection('freeTalks').doc(widget.postId);
    final commentsRef = postRef.collection('comments');
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;

    final decodedPostAuthorEmail =
    _postAuthorEmail.replaceAll('_at_', '@').replaceAll('_dot_', '.');
    final isPostAuthor = currentUserEmail == decodedPostAuthorEmail;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon:
            Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
            onPressed: () => Navigator.of(context).pop(),
            padding: const EdgeInsets.only(left: 8),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentTitle == "삭제된 게시물입니다." || _currentTitle == "오류가 발생했습니다.") {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon:
            Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
            onPressed: () => Navigator.of(context).pop(),
            padding: const EdgeInsets.only(left: 8),
          ),
        ),
        body: Center(
            child: Text(_currentTitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('자유게시판',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black)),
        centerTitle: true,
        leading: IconButton(
          icon:
          Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.only(left: 8),
        ),
        actions: [
          if ((isPostAuthor) ||
              _hasPermission(AdminPermission.canManageFreeBoard))
            IconButton(
              icon: Icon(isEditing ? Icons.check : Icons.edit_outlined,
                  color: Colors.black, size: 22),
              onPressed: () async {
                if (isEditing) {
                  final newTitle = _titleController.text.trim();
                  final newContent = _contentController.text.trim();

                  await FirebaseFirestore.instance
                      .collection('freeTalks')
                      .doc(widget.postId)
                      .update({
                    'title': newTitle,
                    'content': newContent,
                  });

                  setState(() {
                    isEditing = false;
                    _currentTitle = newTitle;
                    _currentContent = newContent;
                  });
                } else {
                  setState(() {
                    isEditing = true;
                  });
                }
              },
            ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 22),
              onPressed: () {
                setState(() {
                  _titleController.text = _currentTitle;
                  _contentController.text = _currentContent;
                  isEditing = false;
                });
              },
            ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherUserProfileScreen(
                                        userEmail: _postAuthorEmail),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 18,
                                backgroundImage: NetworkImage(
                                  (postAuthorProfileImageUrl == null ||
                                      postAuthorProfileImageUrl!.isEmpty)
                                      ? defaultProfileImageUrl
                                      : postAuthorProfileImageUrl!,
                                ),
                                backgroundColor: Colors.grey[200],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              OtherUserProfileScreen(
                                                  userEmail: _postAuthorEmail),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      _nickname,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_formatTimestamp(_timestamp),
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            if (isPostAuthor ||
                                _hasPermission(
                                    AdminPermission.canManageFreeBoard))
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 22),
                                onPressed: () async {
                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12)),
                                      title: const Text('게시물 삭제'),
                                      content: const Text(
                                          '정말 이 게시물을 삭제하시겠습니까?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('취소')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('삭제',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (shouldDelete == true) {
                                    await FirebaseFirestore.instance
                                        .collection('freeTalks')
                                        .doc(widget.postId)
                                        .delete();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isNotice) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '📢 공지사항',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.red),
                            ),
                          ),
                        ],
                        isEditing
                            ? TextField(
                          controller: _titleController,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: isNotice ? Colors.red : Colors.black,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        )
                            : Text(
                          _currentTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: isNotice ? Colors.red : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        isEditing
                            ? TextField(
                          controller: _contentController,
                          maxLines: null,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        )
                            : Text(
                          _currentContent,
                          style:
                          const TextStyle(fontSize: 15, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        if (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isExpanded = !isExpanded;
                                });
                              },
                              child: InteractiveViewer(
                                panEnabled: true,
                                boundaryMargin: const EdgeInsets.all(20),
                                minScale: 1.0,
                                maxScale: 3.0,
                                child: Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.contain,
                                  width: isExpanded
                                      ? MediaQuery.of(context).size.width
                                      : 450,
                                  height: isExpanded ? null : 450,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Text(
                                      '이미지를 불러올 수 없습니다',
                                      style: TextStyle(color: Colors.grey),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _handleLikeDislike(true),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                        hasLiked
                                            ? Icons.thumb_up
                                            : Icons.thumb_up_outlined,
                                        color: hasLiked
                                            ? Colors.red
                                            : Colors.grey[600],
                                        size: 20),
                                    const SizedBox(width: 4),
                                    Text('$likeCount',
                                        style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _handleLikeDislike(false),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                        hasDisliked
                                            ? Icons.thumb_down
                                            : Icons.thumb_down_outlined,
                                        color: hasDisliked
                                            ? Colors.blue
                                            : Colors.grey[600],
                                        size: 20),
                                    const SizedBox(width: 4),
                                    Text('$dislikeCount',
                                        style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  StreamBuilder<QuerySnapshot>(
                    stream: commentsRef.orderBy('timestamp').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('오류가 발생했습니다: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allComments = snapshot.data!.docs;

                      final parentComments = allComments
                          .where((doc) =>
                      (doc.data() as Map<String, dynamic>)['parentId'] ==
                          null)
                          .toList();
                      final replyComments = allComments
                          .where((doc) =>
                      (doc.data() as Map<String, dynamic>)['parentId'] !=
                          null)
                          .toList();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: parentComments.length,
                        itemBuilder: (context, index) {
                          final parent = parentComments[index];
                          final parentData =
                          parent.data() as Map<String, dynamic>;
                          final parentId = parent.id;

                          final children =
                          _getNestedReplies(parentId, replyComments);

                          return Column(
                            children: [
                              _buildCommentItem(
                                  parent, parentData, commentsRef),
                              for (final reply in children)
                                Padding(
                                  padding: const EdgeInsets.only(left: 40),
                                  child: _buildCommentItem(
                                      reply,
                                      reply.data() as Map<String, dynamic>,
                                      commentsRef),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 댓글 입력창 - 실시간 익명 댓글 잠금 상태 확인
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('boardStatus').doc('status').snapshots(),
            builder: (context, snapshot) {

              bool isAnonymousDisabled = false;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                isAnonymousDisabled = data?['isAnonymousCommentingDisabled'] ?? false;
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      top: BorderSide(color: Colors.grey[200]!, width: 1)),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replyingToCommentId != null)
                      Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${replyingToNickname ?? "알 수 없음"}님에게 답글',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700]),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  replyingToCommentId = null;
                                  replyingToNickname = null;
                                });
                              },
                              child: Icon(Icons.close,
                                  size: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        if (!isAnonymousDisabled)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isAnonymous = !isAnonymous;
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                    isAnonymous
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: Colors.grey[700],
                                    size: 20),
                                const SizedBox(width: 6),
                                Text('익명',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700])),
                              ],
                            ),
                          ),
                        if (!isAnonymousDisabled) const SizedBox(width: 12),

                        Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              decoration: InputDecoration(
                                hintText: replyingToCommentId == null
                                    ? '댓글을 입력하세요'
                                    : '답글을 입력하세요',
                                hintStyle:
                                TextStyle(color: Colors.grey[400], fontSize: 14),
                                border: InputBorder.none,
                                contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.done,
                              onEditingComplete: () {
                                FocusScope.of(context).unfocus();
                              },
                            )),
                        IconButton(
                          icon: const Icon(Icons.send, size: 22),
                          color: Colors.grey[700],
                          onPressed: () => _submitComment(isAnonymousDisabled),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
      DocumentSnapshot doc, Map<String, dynamic> data, CollectionReference commentsRef) {
    final timestamp = (data['timestamp'] is Timestamp)
        ? data['timestamp'] as Timestamp
        : Timestamp.now();
    final commentEmail = data['userEmail'] as String?;
    final isAnonymousComment = data['isAnonymous'] == true;
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;

    final decodedPostAuthorEmail =
    _postAuthorEmail.replaceAll('_at_', '@').replaceAll('_dot_', '.');
    final isAuthor =
        commentEmail != null && commentEmail == decodedPostAuthorEmail;

    final isMyComment = commentEmail != null && commentEmail == currentUserEmail;
    final commentNickname = data['nickname'] ?? '익명';
    final displayName = isAnonymousComment ? '익명' : commentNickname;
    final fullName = isAuthor ? '$displayName (글쓴이)' : displayName;

    return FutureBuilder<DocumentSnapshot?>(
      future: commentEmail != null
          ? FirebaseFirestore.instance.collection('users').doc(commentEmail).get()
          : null,
      builder: (context, snapshot) {
        String profileImageUrl = '';
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists &&
            snapshot.data!.data() != null) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          profileImageUrl = userData['profileImageUrl'] ?? '';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (!isAnonymousComment && commentEmail != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OtherUserProfileScreen(
                                userEmail: commentEmail
                                    .replaceAll('@', '_at_')
                                    .replaceAll('.', '_dot_')),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(
                        (isAnonymousComment || profileImageUrl.isEmpty)
                            ? defaultProfileImageUrl
                            : profileImageUrl,
                      ),
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (!isAnonymousComment && commentEmail != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          OtherUserProfileScreen(
                                              userEmail: commentEmail
                                                  .replaceAll('@', '_at_')
                                                  .replaceAll('.', '_dot_')),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isAuthor ? Colors.cyan : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(_formatTimestamp(timestamp),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data['content'] ?? '',
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (!isMyComment)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    replyingToCommentId = doc.id;
                                    replyingToNickname = data['nickname'];
                                  });
                                  FocusScope.of(context)
                                      .requestFocus(_commentFocusNode);
                                },
                                child: Text(
                                  '답글',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            if (isMyComment ||
                                _hasPermission(
                                    AdminPermission.canManageFreeBoard))
                              Padding(
                                padding:
                                EdgeInsets.only(left: isMyComment ? 0 : 12),
                                child: GestureDetector(
                                  onTap: () async {
                                    final shouldDelete =
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(12)),
                                        title: const Text('댓글 삭제'),
                                        content: const Text(
                                            '정말 이 댓글을 삭제하시겠습니까?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('취소')),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: const Text('삭제',
                                                  style: TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (shouldDelete == true) {
                                      await commentsRef.doc(doc.id).delete();
                                    }
                                  },
                                  child: Text(
                                    '삭제',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}