import 'dart:io'; // 👈 [필수] File 클래스
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 👈 [필수] Firebase Storage
import 'package:image_picker/image_picker.dart'; // 👈 [필수] Image Picker

class ReportUserScreen extends StatefulWidget {
  final String reportedUserEmail;
  final String reportedUserNickname;

  const ReportUserScreen({
    Key? key,
    required this.reportedUserEmail,
    required this.reportedUserNickname,
  }) : super(key: key);

  @override
  _ReportUserScreenState createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // 신고 사유 목록
  final List<String> _reportReasons = [
    '욕설 / 비방 / 혐오 발언',
    '부적절한 프로필 (사진/닉네임)',
    '스팸 / 광고성 콘텐츠',
    '어뷰징 / 사기',
    '기타',
  ];
  String? _selectedReason;
  File? _pickedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  /// 스낵바 표시 (OtherUserProfileScreen과 동일)
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
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
        backgroundColor: isError ? Colors.redAccent.shade400 : Color(0xFFFF9F80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// 이미지 선택 (갤러리)
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 용량 절약을 위해 품질 압축
      );
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      _showCustomSnackBar("이미지를 불러오는 데 실패했습니다: $e", isError: true);
    }
  }

  /// 신고 제출
  Future<void> _submitReport() async {
    if (_isLoading) return;

    // 1. 유효성 검사
    if (_selectedReason == null) {
      _showCustomSnackBar("신고 사유를 선택해주세요.", isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return; // 상세 사유가 비어있는 경우
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.email == null) {
      _showCustomSnackBar("로그인이 필요합니다.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    String? uploadedImageUrl;

    try {
      // 2. (선택) 이미지 업로드
      if (_pickedImage != null) {

        // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
        // 저장 경로를 신고 '대상'이 아닌 신고 '자'의 UID로 변경 (보안 규칙 적용)
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('reports')
            .child(currentUser.uid) // 👈 widget.reportedUserEmail에서 변경
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲

        UploadTask uploadTask = storageRef.putFile(_pickedImage!);
        TaskSnapshot snapshot = await uploadTask;
        uploadedImageUrl = await snapshot.ref.getDownloadURL();
      }

      // 3. Firestore에 신고 데이터 저장
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterEmail': currentUser.email,
        'reportedUserEmail': widget.reportedUserEmail,
        'reportedUserNickname': widget.reportedUserNickname,
        'category': _selectedReason,
        'details': _detailsController.text.trim(),
        'imageUrl': uploadedImageUrl, // 이미지가 있으면 URL, 없으면 null
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // 👈 [중요] 관리자가 처리할 수 있도록 'pending' 상태로
      });

      _showCustomSnackBar("신고가 정상적으로 접수되었습니다.");
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      _showCustomSnackBar("신고 접수 중 오류 발생: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              'assets/images/Back-Navs.png', // TODO: 뒤로가기 버튼 경로 확인
              width: 50,
              height: 50,
            ),
          ),
        ),
        title: Text(
          '사용자 신고',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // 배경 탭 시 키보드 닫기
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 신고 대상 ---
                    Text(
                      '신고 대상',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.reportedUserNickname,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    SizedBox(height: 24),

                    // --- 신고 사유 (ChoiceChip) ---
                    Text(
                      '신고 사유 (필수)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0, // 좌우 간격
                      runSpacing: 8.0, // 상하 간격
                      children: _reportReasons.map((reason) {
                        final isSelected = _selectedReason == reason;
                        return ChoiceChip(
                          label: Text(reason),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedReason = selected ? reason : null;
                            });
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: Colors.redAccent.shade400,
                          pressElevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : Colors.grey[300]!,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 24),

                    // --- 상세 사유 (TextFormField) ---
                    Text(
                      '상세 내용 (필수)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _detailsController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: '신고 내용을 자세하게 작성해주세요.\n(예: OOO 채팅방에서 욕설 사용)',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '상세 신고 내용을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),

                    // --- 이미지 첨부 ---
                    Text(
                      '증거 자료 (선택)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 12),
                    _buildImagePicker(),
                    SizedBox(height: 32),

                    // --- 제출 버튼 ---
                    ElevatedButton(
                      onPressed: _submitReport,
                      child: Text(
                        '신고 접수',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade400,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- 전체 로딩 오버레이 ---
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  /// 이미지 피커 및 미리보기 위젯
  Widget _buildImagePicker() {
    if (_pickedImage == null) {
      // 이미지가 없을 때: [ + 사진 첨부 ] 버튼
      return InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: Colors.grey[600]),
              SizedBox(height: 8),
              Text('사진 첨부', style: TextStyle(color: Colors.grey[700])),
            ],
          ),
        ),
      );
    } else {
      // 이미지가 있을 때: 미리보기 및 삭제 버튼
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // 이미지 미리보기
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _pickedImage!,
              height: 150,
              width: 150,
              fit: BoxFit.cover,
            ),
          ),
          // 삭제(X) 버튼
          Positioned(
            top: -10,
            right: -10,
            child: IconButton(
              icon: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.7),
                radius: 12,
                child: Icon(Icons.close, color: Colors.white, size: 16),
              ),
              onPressed: () {
                setState(() {
                  _pickedImage = null;
                });
              },
            ),
          ),
        ],
      );
    }
  }
}
