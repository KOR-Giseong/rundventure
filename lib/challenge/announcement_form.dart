import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnnouncementForm extends StatefulWidget {
  const AnnouncementForm({Key? key}) : super(key: key);

  @override
  State<AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<AnnouncementForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  bool _isMainAnnouncement = false;

  final _contentFocusNode = FocusNode();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '로그인이 필요합니다.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      final authorEmail = user.email;
      final timestamp = FieldValue.serverTimestamp();

      // 1. 파이어스토어 배치(Batch) 시작
      final batch = FirebaseFirestore.instance.batch();

      // 2. (필수) 'announcements' (일반 공지 탭)에 항상 저장
      final generalAnnouncementRef =
      FirebaseFirestore.instance.collection('announcements').doc();
      batch.set(generalAnnouncementRef, {
        'title': title,
        'content': content, // 일반 공지는 'content' 필드를 사용
        'authorEmail': authorEmail,
        'timestamp': timestamp,
      });

      // 3. (선택) '메인 공지'가 체크된 경우 'mainAnnouncements' (팝업)에도 저장
      if (_isMainAnnouncement) {
        final mainAnnouncementRef =
        FirebaseFirestore.instance.collection('mainAnnouncements').doc();
        batch.set(mainAnnouncementRef, {
          'title': title,
          'message': content, // MainScreen 팝업은 'message' 필드를 사용
          'authorEmail': authorEmail,
          'timestamp': timestamp,
        });
      }

      // 4. 배치 작업 실행 (두 작업이 동시에 성공하거나 실패함)
      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '오류 발생: $e',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '공지사항 작성',
          style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Image.asset('assets/images/Back-Navs.png', width: 70, height: 70),
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.only(left: 8),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
            )
                : const Icon(Icons.check, color: Colors.black, size: 24),
            onPressed: _isLoading ? null : _submitAnnouncement,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // 화면의 다른 곳을 탭하면 키보드 포커스 해제
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '제목',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_contentFocusNode);
                    },
                    decoration: InputDecoration(
                      hintText: '공지사항 제목을 입력하세요',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.black, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '제목을 입력해주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '내용',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,

                    decoration: InputDecoration(
                      hintText: '공지사항 내용을 입력하세요',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.black, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 12,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '내용을 입력해주세요.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text(
                      '메인 공지사항(팝업)으로 등록',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    subtitle: Text(
                      '체크 시 앱 실행 시 팝업으로 노출됩니다.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    value: _isMainAnnouncement,
                    onChanged: (bool newValue) {
                      setState(() {
                        _isMainAnnouncement = newValue;
                      });
                    },
                    activeColor: Colors.blueAccent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}