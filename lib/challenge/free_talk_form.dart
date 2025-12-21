import 'dart:async';
import 'dart:io';
// import 'dart:convert'; // 👈 [제거]
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http; // 👈 [제거]
import 'package:firebase_storage/firebase_storage.dart'; // 👈 [신규 추가]
import '../admin/admin_screen.dart';
import '../admin/utils/admin_permissions.dart';

class FreeTalkForm extends StatefulWidget {
  const FreeTalkForm({Key? key}) : super(key: key);

  @override
  State<FreeTalkForm> createState() => _FreeTalkFormState();
}

class _FreeTalkFormState extends State<FreeTalkForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  File? _selectedImage;

  bool _showContentHint = true;
  bool _isNotice = false;

  // [수정] 관리자 권한 상태 변수들
  bool _isSuperAdmin = false;
  String _currentUserRole = 'user';
  Map<String, dynamic> _currentAdminPermissions = {};

  bool get _isFormValid =>
      _titleController.text.trim().isNotEmpty &&
          _contentController.text.trim().isNotEmpty;

  // ▼▼▼▼▼ [신규 추가] ▼▼▼▼▼
  bool _isUploading = false; // 업로드 중복 방지
  // ▲▲▲▲▲ [신규 추가] ▲▲▲▲▲

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_updateState);
    _contentController.addListener(_updateState);
    _checkCurrentUserPermissions(); // [수정] 권한 확인 함수 호출
  }

  // [수정] 세분화된 관리자 권한 확인 함수
  Future<void> _checkCurrentUserPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    if (user.email == 'ghdrltjd244142@gmail.com') {
      if (mounted) setState(() => _isSuperAdmin = true);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email!).get();
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
      print("권한 확인 오류(FreeTalkForm): $e");
    }
  }

  // [추가] 특정 권한이 있는지 확인하는 헬퍼 함수
  bool _hasPermission(AdminPermission permission) {
    if (_isSuperAdmin || _currentUserRole == 'general_admin') return true;
    return _currentAdminPermissions[permission.name] ?? false;
  }


  void _updateState() {
    if(mounted) {
      setState(() {
        _showContentHint = _contentController.text.trim().isEmpty;
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateState);
    _contentController.removeListener(_updateState);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // [추가] 디자인이 적용된 커스텀 SnackBar 함수
  void _showCustomSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : (isSuccess ? Icons.check_circle_outline : Icons.info_outline),
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
        // [수정] 성공 스낵바 색상 변경
        backgroundColor: isError ? Colors.redAccent.shade400 : (isSuccess ? Color(0xFFFF9F80) : Colors.black87),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : (isSuccess ? 2 : 3)),
      ),
    );
  }

  // ▼▼▼▼▼ [수정된 함수] _submitPost (Firebase Storage 사용) ▼▼▼▼▼
  void _submitPost() async {
    if (_isUploading) return; // 업로드 중복 방지

    if (!_isFormValid) {
      _showCustomSnackBar('제목과 내용을 모두 입력해주세요.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.uid == null) {
      _showCustomSnackBar('사용자 정보를 찾을 수 없습니다.', isError: true);
      return;
    }

    final String userEmail = user.email!;
    final String userUid = user.uid; // 👈 Storage 경로에 사용

    setState(() => _isUploading = true); // 로딩 시작

    try {
      String imageUrl = '';
      if (_selectedImage != null) {
        // 1. Firebase Storage에 업로드
        // (storage.rules에 /freeTalks/{userId}/{fileName} 경로 규칙이 필요합니다)
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('freeTalks') // 1. freeTalks 폴더
            .child(userUid)       // 2. {userId} (본인 UID)
            .child('talk_${DateTime.now().millisecondsSinceEpoch}.jpg'); // 3. {fileName}

        UploadTask uploadTask = storageRef.putFile(_selectedImage!);
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL(); // 4. 다운로드 URL 가져오기
      }

      final postData = {
        'userEmail': userEmail,
        'title': _titleController.text,
        'content': _contentController.text,
        'imageUrl': imageUrl, // Firebase Storage URL
        'timestamp': FieldValue.serverTimestamp(),
        'isNotice': _hasPermission(AdminPermission.canManageFreeBoard) ? _isNotice : false,
      };

      await FirebaseFirestore.instance.collection('freeTalks').add(postData);

      _showCustomSnackBar('게시물이 성공적으로 등록되었습니다.', isSuccess: true); // 성공 스낵바
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showCustomSnackBar('저장 중 오류가 발생했습니다: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false); // 로딩 종료
    }
  }
  // ▲▲▲▲▲ [수정된 함수] _submitPost ▲▲▲▲▲

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  // ▼▼▼▼▼ [제거된 함수] uploadImageToCloudinary ▼▼▼▼▼
  /*
  Future<String> uploadImageToCloudinary(File image) async {
    // ... (Cloudinary 로직 제거됨) ...
  }
  */
  // ▲▲▲▲▲ [제거된 함수] uploadImageToCloudinary ▲▲▲▲▲

  void _openPollDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 30, horizontal: 16),
          child: Text('투표 기능은 아직 개발 중입니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 👈 키보드 오버플로우 방지
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('글쓰기', style: TextStyle(color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
        actions: [
          // [수정] 업로드 중일 때는 버튼 비활성화
          TextButton(
            onPressed: (_isFormValid && !_isUploading) ? _submitPost : null,
            child: _isUploading
                ? Container( // 업로드 중일 때 로더 표시
                width: 20,
                height: 20,
                margin: EdgeInsets.only(right: 12),
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.grey,)
            )
                : Text(
              '완료',
              style: TextStyle(
                color: _isFormValid ? Colors.red : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      // ▼▼▼▼▼ [신규 추가] ▼▼▼▼▼
      // 빈 화면 클릭 시 키보드를 내리기 위해 GestureDetector로 감쌉니다.
      body: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        // ▲▲▲▲▲ [신규 추가] ▲▲▲▲▲
        child: Column( // 👈 기존 body
          children: [
            // ✨ [디자인 수정] 제목 입력 필드
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _titleController,
                enabled: !_isUploading, // 업로드 중 비활성화
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: '제목을 입력하세요',
                  border: InputBorder.none,
                ),
              ),
            ),

            if (_hasPermission(AdminPermission.canManageFreeBoard))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isNotice,
                      onChanged: _isUploading ? null : (value) { // 업로드 중 비활성화
                        setState(() {
                          _isNotice = value ?? false;
                        });
                      },
                      activeColor: Colors.redAccent,
                    ),
                    const Text('공지사항으로 등록'),
                  ],
                ),
              ),

            // ✨ [디자인 수정] 내용 입력 필드
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _contentController,
                  enabled: !_isUploading, // 업로드 중 비활성화
                  maxLines: null,
                  expands: true,
                  // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
                  keyboardType: TextInputType.multiline, // 👈 멀티라인 키보드
                  textInputAction: TextInputAction.newline,   // 👈 [수정] '완료' 대신 '줄바꿈'으로 변경
                  // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    // ✨ [문구 수정] 경고 메시지 추가
                    hintText: '자유롭게 얘기해보세요.\n\n욕설, 비방 등 부적절한 언어 사용 시 게시물이 삭제되거나 서비스 이용이 제한될 수 있습니다.',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),

            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container( // ✅ Container로 감싸서 이미지의 최대 너비를 제한하고 높이를 유연하게 만듭니다.
                      width: double.infinity, // 부모 너비를 최대로 사용
                      constraints: const BoxConstraints(maxHeight: 250), // ✅ 최대 높이 설정 (원하는 값으로 조절 가능)
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey[200], // 이미지가 없는 부분을 채울 배경색 (선택 사항)
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _selectedImage!,
                          // height: 150, // ❌ [제거] 고정된 높이 대신, 컨테이너의 maxHeight를 따르도록 합니다.
                          fit: BoxFit.contain, // ✅ [수정] 이미지가 잘리지 않고 전체가 보이도록 변경
                          // width: double.infinity, // ❌ [제거] Container가 이미 처리합니다.
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black, size: 20),
                        onPressed: _isUploading ? null : () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.redAccent),
                    // [수정] 업로드 중일 때 비활성화
                    onPressed: _isUploading ? null : _pickImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.poll_outlined, color: Colors.blueAccent),
                    // [수정] 업로드 중일 때 비활성화
                    onPressed: _isUploading ? null : _openPollDialog,
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