import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  bool _isSuperAdmin = false;
  String _currentUserRole = 'user';
  Map<String, dynamic> _currentAdminPermissions = {};

  bool get _isFormValid =>
      _titleController.text.trim().isNotEmpty &&
          _contentController.text.trim().isNotEmpty;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_updateState);
    _contentController.addListener(_updateState);
    _checkCurrentUserPermissions();
  }

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
        backgroundColor: isError ? Colors.redAccent.shade400 : (isSuccess ? Color(0xFFFF9F80) : Colors.black87),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : (isSuccess ? 2 : 3)),
      ),
    );
  }

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
    final String userUid = user.uid;

    setState(() => _isUploading = true);

    try {
      String imageUrl = '';
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('freeTalks')
            .child(userUid)
            .child('talk_${DateTime.now().millisecondsSinceEpoch}.jpg');

        UploadTask uploadTask = storageRef.putFile(_selectedImage!);
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      final postData = {
        'userEmail': userEmail,
        'title': _titleController.text,
        'content': _contentController.text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isNotice': _hasPermission(AdminPermission.canManageFreeBoard) ? _isNotice : false,
      };

      await FirebaseFirestore.instance.collection('freeTalks').add(postData);

      _showCustomSnackBar('게시물이 성공적으로 등록되었습니다.', isSuccess: true);
      if (mounted) Navigator.pop(context);

    } catch (e) {
      _showCustomSnackBar('저장 중 오류가 발생했습니다: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

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
      resizeToAvoidBottomInset: false,
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
      body: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Column(
          children: [
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
                  enabled: !_isUploading,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
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
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.contain,
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
                    onPressed: _isUploading ? null : _pickImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.poll_outlined, color: Colors.blueAccent),
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