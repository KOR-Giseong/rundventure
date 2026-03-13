import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../admin/utils/admin_permissions.dart';
import '../profile/other_user_profile.dart';


class ChatRoomScreen extends StatefulWidget {
  final String challengeId;
  const ChatRoomScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final picker = ImagePicker();
  final uuid = Uuid();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FocusNode _commentFocusNode = FocusNode();
  final FocusNode _dummyFocusNode = FocusNode();

  bool _isSuperAdmin = false;
  String _currentUserRole = 'user';
  Map<String, dynamic> _currentAdminPermissions = {};

  File? _selectedImage;
  final Map<String, Map<String, dynamic>> _userCache = {};

  bool _isProcessingParticipation = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUserPermissions();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    _dummyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUserPermissions() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    if (user.email == 'ghdrltjd244142@gmail.com') {
      if (mounted) setState(() => _isSuperAdmin = true);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.email!).get();
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
      print("관리자 권한 확인 오류(ChatRoom): $e");
    }
  }

  Future<Map<String, dynamic>> _getUserDetails(String email) async {
    if (_userCache.containsKey(email)) {
      return _userCache[email]!;
    }
    try {
      final doc = await _firestore.collection('users').doc(email).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userCache[email] = {
              'nickname': data['nickname'] ?? '알 수 없음',
              'profileImageUrl': data['profileImageUrl'] ?? 'https://cdn-icons-png.flaticon.com/512/847/847969.png',
            };
          });
        }
        return _userCache[email]!;
      }
    } catch (e) {
      print("사용자 정보 로딩 오류: $e");
    }
    return {
      'nickname': '알 수 없음',
      'profileImageUrl': 'https://cdn-icons-png.flaticon.com/512/847/847969.png',
    };
  }

  bool _hasPermission(AdminPermission permission) {
    if (_isSuperAdmin || _currentUserRole == 'general_admin') return true;
    return _currentAdminPermissions[permission.name] ?? false;
  }

  String decodeEmail(String encodedEmail) {
    return encodedEmail.replaceAll('_at_', '@').replaceAll('_dot_', '.');
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    final imageFile = _selectedImage;
    if (message.isEmpty && imageFile == null) return;

    _messageController.clear();
    if (mounted) {
      setState(() {
        _selectedImage = null;
      });
    }
    _scrollToBottom();
    _performSendInBackground(message, imageFile);
  }

  // 메시지 전송 - 보안 규칙 위반으로 인해 알림 로직 제거, 단일 set 사용
  Future<void> _performSendInBackground(String message, File? imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      final userDoc = await _firestore.collection('users').doc(user.email!).get();
      final userName = (userDoc.exists && userDoc.data() != null) ? (userDoc.data() as Map<String, dynamic>)['nickname'] ?? '알 수 없음' : '알 수 없음';
      final userEmail = user.email!;
      final docId = "${userEmail}_${DateTime.now().millisecondsSinceEpoch}_${uuid.v4()}";

      final challengeDocRef = _firestore.collection('challenges').doc(widget.challengeId);

      String imageUrl = '';
      if (imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child('chat_images').child('$docId.jpg');
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
      }

      final commentRef = challengeDocRef.collection('comments').doc(docId);

      await commentRef.set({
        'comment': message,
        'timestamp': FieldValue.serverTimestamp(),
        'userName': userName,
        'userEmail': userEmail,
        'imageUrl': imageUrl,
      });

    } catch (e) {
      print("백그라운드 메시지 전송 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메시지 전송에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<void> _toggleParticipation(bool join, DocumentSnapshot challengeDoc) async {
    if (_isProcessingParticipation) return;
    if (mounted) setState(() => _isProcessingParticipation = true);

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      if (mounted) setState(() => _isProcessingParticipation = false);
      return;
    }

    final userEmail = user.email!;
    final data = challengeDoc.data() as Map<String, dynamic>;
    final challengeRef = challengeDoc.reference;

    final List<String> currentParticipants = List<String>.from(data['participants'] ?? []);
    final Map<String, dynamic> participantMap = Map<String, dynamic>.from(data['participantMap'] ?? {});
    final Timestamp? challengeStartTime = data['timestamp'] as Timestamp?;
    final DateTime endDate = (challengeStartTime?.toDate() ?? DateTime.now()).add(Duration(days: int.tryParse(data['duration'] ?? '0') ?? 0));
    final now = DateTime.now();

    if (join) {
      final int participantLimit = data['participantLimit'] ?? 0;
      final int currentCount = currentParticipants.length;

      if (participantLimit > 0 && currentCount >= participantLimit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("참여 인원이 마감되었습니다. (최대 ${participantLimit}명)"),
            backgroundColor: Colors.orange,
          ));
        }
        setState(() => _isProcessingParticipation = false);
        return;
      }
    }

    if (!join && endDate.difference(now).inDays <= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("목표 달성까지 3일 전에는 참여 취소가 불가능합니다."),
          backgroundColor: Colors.red,
        ));
      }
      setState(() => _isProcessingParticipation = false);
      return;
    }

    if (!join && endDate.difference(now).inDays > 3) {
      bool? shouldCancel = await _showCancelDialog();
      if (shouldCancel == null || !shouldCancel) {
        if (mounted) setState(() => _isProcessingParticipation = false);
        return;
      }
    }

    try {
      double userTotalDistance = 0.0;

      Timestamp? userJoinTimestamp;
      if (participantMap.containsKey(userEmail)) {
        try {
          final joinDate = DateTime.parse(participantMap[userEmail]);
          userJoinTimestamp = Timestamp.fromDate(joinDate);
        } catch (e) {
          print("Error parsing user join date: $e");
          userJoinTimestamp = challengeStartTime;
        }
      }

      if (!join && userJoinTimestamp != null) {
        final workoutsSnapshot = await _firestore
            .collection('userRunningData')
            .doc(userEmail)
            .collection('workouts')
            .where('date', isGreaterThanOrEqualTo: userJoinTimestamp)
            .get();

        for (var workoutDoc in workoutsSnapshot.docs) {
          final recordsSnapshot = await workoutDoc.reference.collection('records')
              .where('date', isGreaterThanOrEqualTo: userJoinTimestamp)
              .get();

          for (var recordDoc in recordsSnapshot.docs) {
            final recordData = recordDoc.data();
            userTotalDistance += (recordData['kilometers'] as num? ?? 0.0).toDouble();
          }
        }
        print("User $userEmail total distance to remove: $userTotalDistance km");
      }

      List<String> updatedParticipants = List<String>.from(currentParticipants);
      WriteBatch batch = _firestore.batch();

      if (join) {
        if (!updatedParticipants.contains(userEmail)) {
          updatedParticipants.add(userEmail);
          participantMap[userEmail] = DateTime.now().toUtc().toIso8601String();

          batch.update(challengeRef, {
            'participants': updatedParticipants,
            'participantMap': participantMap,
          });
        }
      } else {
        if (updatedParticipants.contains(userEmail)) {
          updatedParticipants.remove(userEmail);
          participantMap.remove(userEmail);

          batch.update(challengeRef, {
            'participants': updatedParticipants,
            'participantMap': participantMap,
            'totalDistance': FieldValue.increment(-userTotalDistance),
          });
        }
      }
      await batch.commit();

      final updatedDoc = await challengeRef.get();
      final updatedData = updatedDoc.data() as Map<String, dynamic>?;
      if (updatedData != null) {

        final totalDistance = ((updatedData['totalDistance'] as num? ?? 0.0).toDouble()).clamp(0.0, double.infinity);
        final targetDistance = double.tryParse(updatedData['distance'] ?? '0') ?? 0;
        final progress = (targetDistance > 0) ? (totalDistance / targetDistance).clamp(0.0, 1.0) : 0.0;

        await challengeRef.update({
          'progress': progress,
          'totalDistance': totalDistance,
        });
      }

    } catch (e) {
      print("참여/취소 처리 중 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('처리 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessingParticipation = false);
    }
  }

  Future<bool?> _showCancelDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('참여 취소'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('참여를 취소하시겠습니까?'),
              SizedBox(height: 8),
              Text(
                '※ 챌린지 참여 기간 동안의 러닝 기록이 총 거리에서 제외됩니다.',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('아니오', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('예', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('yyyy.MM.dd HH:mm').format(date);
  }

  Widget _buildChallengeInfo(DocumentSnapshot challengeDoc) {
    if (!challengeDoc.exists || challengeDoc.data() == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('이 챌린지는 삭제되었습니다.'),
      );
    }
    final data = challengeDoc.data() as Map<String, dynamic>;
    final writerEmail = decodeEmail(data['userEmail'] ?? '');

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserDetails(writerEmail),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            margin: EdgeInsets.all(16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator())),
          );
        }

        final writerNickname = snapshot.data?['nickname'] ?? '알 수 없음';
        final title = data['name'] ?? '제목 없음';
        final targetDistance = double.tryParse(data['distance'] ?? '0') ?? 0;
        final duration = data['duration'] ?? '';
        final slogan = data['slogan'] ?? '🔥 목표를 향해 함께 달려요!';
        final timestamp = data['timestamp'] as Timestamp?;
        final startDate = timestamp?.toDate() ?? DateTime.now();
        final formattedDate = timestamp != null ? _formatTimestamp(timestamp) : '';
        final participants = List<String>.from(data['participants'] ?? []);

        final int participantLimit = data['participantLimit'] ?? 0;

        final endDate = startDate.add(Duration(days: int.tryParse(duration) ?? 7));
        final now = DateTime.now();
        final daysLeft = endDate.difference(now).inDays;
        final currentUser = _auth.currentUser;
        final isOwner = currentUser?.email == writerEmail;
        final canDeleteChallenge = isOwner || _hasPermission(AdminPermission.canManageChallenges);
        final hasJoined = currentUser?.email != null && participants.contains(currentUser!.email);

        final totalDistance = (data['totalDistance'] as num? ?? 0.0).toDouble().clamp(0.0, double.infinity);
        final distanceProgress = (data['progress'] as num? ?? 0.0).toDouble();

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ),
                    if (canDeleteChallenge)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final confirmed = await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: Text('삭제 확인'),
                              content: Text('정말로 이 챌린지를 삭제하시겠습니까?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: TextStyle(color: Colors.blue))),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('삭제', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await _firestore.collection('challenges').doc(widget.challengeId).delete();
                            if (!mounted) return;
                            navigator.pop();
                          }
                        },
                      ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  slogan,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 16),

                _buildInfoText("🏁 목표 거리", "$targetDistance km"),
                SizedBox(height: 8),
                _buildInfoText("⏱️ 기간", "$duration일"),
                SizedBox(height: 8),
                _buildInfoText("⏳ 남은 기간", daysLeft >= 0 ? '$daysLeft일' : '완료됨'),

                SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "🏃 달성 거리",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          "${totalDistance.toStringAsFixed(2)} / $targetDistance km (${(distanceProgress * 100).toStringAsFixed(1)}%)",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (distanceProgress >= 1.0)
                      Text("🎉 목표 달성! 축하합니다!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green))
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: distanceProgress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          minHeight: 10,
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 12),
                Text(
                  '⚠ 종료 3일 전에는 참여 취소가 불가능합니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "👥 참여 인원: ${participants.length}명${participantLimit > 0 ? ' / $participantLimit명' : ''}",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[800]),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasJoined ? Colors.grey[200] : Colors.blueAccent,
                        foregroundColor: hasJoined ? Colors.redAccent : Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _isProcessingParticipation ? null : () => _toggleParticipation(!hasJoined, challengeDoc),
                      child: _isProcessingParticipation
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: hasJoined ? Colors.redAccent : Colors.white))
                          : Text(hasJoined ? '참여 취소' : '참여하기'),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
                SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("글쓴이: $writerNickname", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoText(String title, String value) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[800]),
        ),
        SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildComment(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final comment = data['comment'] ?? '';
    final userEmail = data['userEmail'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final imageUrl = data['imageUrl'];
    final timeText = timestamp != null ? _formatTimestamp(timestamp) : '';
    final isMyComment = _auth.currentUser?.email == userEmail;
    final canDelete = isMyComment || _hasPermission(AdminPermission.canManageChallenges);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserDetails(userEmail),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row( /* ... 로딩 중 UI ... */ ),
          );
        }

        final userName = snapshot.data?['nickname'] ?? '알 수 없음';
        final profileImageUrl = snapshot.data?['profileImageUrl'] ??
            'https://cdn-icons-png.flaticon.com/512/847/847969.png';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final encodedEmail = userEmail.replaceAll('@', '_at_').replaceAll('.', '_dot_');
                      Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfileScreen(userEmail: encodedEmail)));
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(profileImageUrl),
                      radius: 16,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final encodedEmail = userEmail.replaceAll('@', '_at_').replaceAll('.', '_dot_');
                      Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfileScreen(userEmail: encodedEmail)));
                    },
                    child: Text(
                      userName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[800], decoration: TextDecoration.underline),
                    ),
                  ),
                  Spacer(),
                  if (canDelete)
                    GestureDetector(
                      onTap: () async {
                        _dummyFocusNode.requestFocus();

                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text('댓글 삭제'),
                            content: const Text('정말 이 댓글을 삭제하시겠습니까?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (shouldDelete == true) {
                          await _firestore
                              .collection('challenges')
                              .doc(widget.challengeId)
                              .collection('comments')
                              .doc(doc.id)
                              .delete();
                          _dummyFocusNode.requestFocus();
                        }
                      },
                      child: Text(
                        '삭제',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
              if (imageUrl != null && imageUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: EdgeInsets.all(16),
                          color: Colors.grey[200],
                          child: Center(child: Text("이미지를 불러올 수 없습니다.", style: TextStyle(color: Colors.grey[600]))),
                        );
                      },
                    ),
                  ),
                ),
              if (comment.isNotEmpty)
                Text(comment, style: TextStyle(fontSize: 15, height: 1.4)),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(timeText, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
              Divider(height: 24, thickness: 0.5, color: Colors.grey[300]),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.only(left: 8),
        ),
        title: Text("챌린지",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('challenges').doc(widget.challengeId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Card(
                            margin: EdgeInsets.all(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text("오류가 발생했습니다"));
                        }
                        final challengeDoc = snapshot.data;
                        if (challengeDoc == null || !challengeDoc.exists) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(child: Text("챌린지가 존재하지 않습니다.")),
                          );
                        }

                        return Column(
                          children: [
                            _buildChallengeInfo(challengeDoc),
                            StreamBuilder<QuerySnapshot>(
                              stream: challengeDoc.reference
                                  .collection('comments')
                                  .orderBy('timestamp', descending: false)
                                  .snapshots(),
                              builder: (context, commentSnapshot) {
                                if (commentSnapshot.connectionState == ConnectionState.waiting) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                if (commentSnapshot.hasError) {
                                  return Center(child: Text("댓글을 불러오는 중 오류가 발생했습니다"));
                                }
                                final allDocs = commentSnapshot.data?.docs ?? [];

                                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: allDocs.length,
                                  itemBuilder: (context, index) {
                                    return _buildComment(allDocs[index]);
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _commentFocusNode,
                      decoration: InputDecoration(
                        hintText: '댓글을 입력하세요',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(left: 8, bottom: -8),
                        isDense: true,
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) {
                        _sendMessage();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      icon: const Icon(Icons.send, size: 20),
                      color: Colors.blue,
                      onPressed: _sendMessage,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}