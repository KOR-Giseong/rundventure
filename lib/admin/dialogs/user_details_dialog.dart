import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UserDetailsDialog extends StatefulWidget {
  final DocumentSnapshot userDoc;
  final bool canSendNotifications;

  const UserDetailsDialog({
    Key? key,
    required this.userDoc,
    this.canSendNotifications = false,
  }) : super(key: key);

  @override
  _UserDetailsDialogState createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<UserDetailsDialog> {
  bool _isEditing = false;
  late Map<String, dynamic> _userData;
  late Map<String, TextEditingController> _controllers;
  static const Color primaryColor = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _userData = widget.userDoc.data() as Map<String, dynamic>;

    _userData.putIfAbsent('isSuspended', () => false);
    _userData.putIfAbsent('suspensionReason', () => null);

    _controllers = {
      'nickname': TextEditingController(text: _userData['nickname']),
      'gender': TextEditingController(text: _userData['gender']),
      'birthdate': TextEditingController(text: _userData['birthdate']),
      'height': TextEditingController(text: _userData['height']?.toString()),
      'weight': TextEditingController(text: _userData['weight']?.toString()),
    };
  }
  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }
  Future<void> _saveChanges() async {
    final updatedData = {
      'nickname': _controllers['nickname']!.text,
      'gender': _controllers['gender']!.text,
      'birthdate': _controllers['birthdate']!.text,
      'height': _controllers['height']!.text,
      'weight': _controllers['weight']!.text,
    };
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userDoc.id).update(updatedData);
      if(mounted) {
        setState(() {
          _isEditing = false;
          _userData.addAll(updatedData);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '정보가 수정되었습니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9F80),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '수정 실패: $e',
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
    }
  }

  Future<void> _toggleSuspension(bool isCurrentlySuspended) async {
    if (isCurrentlySuspended) {
      // 정지 해제 로직
      await _unsuspendUser();
    } else {
      // 정지 시키기 로직
      await _showSuspensionDialog();
    }
  }

  Future<void> _unsuspendUser() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userDoc.id).update({
        'isSuspended': false,
        'suspensionReason': FieldValue.delete(), // 사유 삭제
      });
      if(mounted) {
        setState(() {
          _userData['isSuspended'] = false;
          _userData['suspensionReason'] = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '계정 정지가 해제되었습니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9F80),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '정지 해제 실패: $e',
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
    }
  }

  Future<void> _suspendUser(String reason) async {
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '정지 사유를 입력해야 합니다.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userDoc.id).update({
        'isSuspended': true,
        'suspensionReason': reason,
      });
      if(mounted) {
        setState(() {
          _userData['isSuspended'] = true;
          _userData['suspensionReason'] = reason;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '계정이 정지되었습니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9F80),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '정지 실패: $e',
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
    }
  }

  Future<void> _showSuspensionDialog() async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('계정 정지 사유', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("사용자에게 표시될 정지 사유를 입력하세요.", style: TextStyle(color: Colors.grey.shade700)),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: '정지 사유 (필수)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('취소', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('계정 정지', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _suspendUser(result);
    } else if (result != null && result.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '사유가 입력되지 않아 취소되었습니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
    }
  }

  Future<void> _showSendNotificationDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final targetEmail = _userData['email'] ?? widget.userDoc.id;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('개별 알림 전송', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("대상: $targetEmail", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: '알림 제목 (필수)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: '알림 내용 (필수)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('취소', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                print("제목과 내용을 모두 입력해야 합니다.");
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text('전송', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // '전송' 버튼을 눌렀다면
    if (confirmed == true) {
      final title = titleController.text.trim();
      final message = messageController.text.trim();
      await _sendNotification(targetEmail, title, message);
    }
  }

  Future<void> _sendNotification(String targetEmail, String title, String message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                '알림을 전송 중입니다...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: const Duration(seconds: 5),
      ),
    );

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('sendNotificationToUser');

      final result = await callable.call({
        'targetEmail': targetEmail,
        'title': title,
        'message': message,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '알림을 성공적으로 전송했습니다.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9F80),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '전송 실패: ${e.message}',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알 수 없는 오류 발생: $e'),
            backgroundColor: Colors.redAccent.shade400,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _userData['email'] ?? widget.userDoc.id;
    final role = _userData['role'] ?? 'user';
    String roleText;
    Color roleColor;
    switch (role) {
      case 'admin':
        roleText = '일반 관리자 🛡️';
        roleColor = primaryColor;
        break;
      case 'general_admin':
        roleText = '총괄 관리자 👑';
        roleColor = Colors.purple;
        break;
      case 'super_admin':
        roleText = '슈퍼 관리자 ✨';
        roleColor = Colors.orange;
        break;
      default:
        roleText = '일반 사용자';
        roleColor = Colors.grey;
    }

    final bool isSuspended = _userData['isSuspended'] == true;

    if (isSuspended) {
      roleText = '정지된 계정 🚫';
      roleColor = Colors.red.shade400;
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("사용자 상세 정보", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)),
          SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: roleColor.withOpacity(0.5))
                ),
                child: Text(roleText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
              ),
              SizedBox(width: 8),
              Text(email, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
          const Divider(color: Colors.black12, height: 16, thickness: 1),
        ],
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: _isEditing ? _buildEditingFields() : _buildDisplayFields(email, roleText),
        ),
      ),
      actions: _isEditing
          ? [
        TextButton(onPressed: () {
          _controllers['nickname']!.text = _userData['nickname'] ?? '';
          _controllers['gender']!.text = _userData['gender'] ?? '';
          _controllers['birthdate']!.text = _userData['birthdate'] ?? '';
          _controllers['height']!.text = _userData['height']?.toString() ?? '';
          _controllers['weight']!.text = _userData['weight']?.toString() ?? '';
          setState(() => _isEditing = false);
        }, child: Text('취소', style: TextStyle(color: Colors.black54))),
        ElevatedButton(
          onPressed: _saveChanges,
          child: Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
        ),
      ]
          : [

        if (widget.canSendNotifications)
          TextButton(
            onPressed: _showSendNotificationDialog,
            child: Text(
              '개별 알림',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
            ),
          ),

        TextButton(
          onPressed: () => _toggleSuspension(isSuspended),
          child: Text(
            isSuspended ? '정지 해제' : '계정 정지',
            style: TextStyle(color: isSuspended ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          ),
        ),

        TextButton(onPressed: () => setState(() => _isEditing = true), child: Text('수정', style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold))),

        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('닫기', style: TextStyle(color: Colors.black54))),
      ],
    );
  }

  List<Widget> _buildDisplayFields(String email, String roleText) {
    String bmiValue = '정보 없음';
    final dynamic bmiData = _userData['bmi'];
    if (bmiData != null) {
      if (bmiData is num) {
        bmiValue = bmiData.toStringAsFixed(2); // num이면 소수점 처리
      } else if (bmiData is String) {
        final parsedBmi = double.tryParse(bmiData.trim());
        bmiValue = parsedBmi?.toStringAsFixed(2) ?? bmiData.trim();
      } else {
        bmiValue = bmiData.toString(); // 기타 타입인 경우 toString() 처리
      }
    }


    return [
      _buildDetailRow("닉네임", _userData['nickname']),
      _buildDetailRow("성별", _userData['gender']),
      _buildDetailRow("생년월일", _userData['birthdate']),
      _buildDetailRow("키", _userData['height']?.toString(), unit: ' cm'),
      _buildDetailRow("몸무게", _userData['weight']?.toString(), unit: ' kg'),
      _buildDetailRow("BMI", bmiValue),

      _buildDetailRow(
        "계정 상태",
        _userData['isSuspended'] == true ? "정지됨" : "활성",
        valueColor: _userData['isSuspended'] == true ? Colors.red.shade400 : Colors.green.shade600,
      ),
      if (_userData['isSuspended'] == true)
        _buildDetailRow("정지 사유", _userData['suspensionReason'] ?? '없음', valueColor: Colors.red.shade400),

      SizedBox(height: 16),
      Text("FCM 토큰", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      SizedBox(height: 4),
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: SelectableText(_userData['fcmToken'] ?? '없음', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ),
    ];
  }
  List<Widget> _buildEditingFields() {
    return [
      _buildEditingField('nickname', '닉네임'),
      _buildEditingField('gender', '성별'),
      _buildEditingField('birthdate', '생년월일 (YYYY-MM-DD)'),
      _buildEditingField('height', '키 (숫자)', keyboardType: TextInputType.numberWithOptions(decimal: true)),
      _buildEditingField('weight', '몸무게 (숫자)', keyboardType: TextInputType.numberWithOptions(decimal: true)),
    ];
  }
  Widget _buildEditingField(String key, String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextField(
        controller: _controllers[key],
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String? value, {String unit = '', Color? valueColor}) {
    final TextStyle titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87);
    final TextStyle valueStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor ?? primaryColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text("$title", style: titleStyle),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "${value ?? '정보 없음'}$unit",
              style: valueStyle,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}