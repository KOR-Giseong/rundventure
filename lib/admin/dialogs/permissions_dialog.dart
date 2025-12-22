import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/admin_permissions.dart'; // 분리한 파일 임포트

// -----------------------------------------------------------------------------
// 관리자 권한 설정 다이얼로그
// -----------------------------------------------------------------------------
class PermissionsDialog extends StatefulWidget {
  final String userEmail;
  final bool isGeneralAdmin;
  const PermissionsDialog({Key? key, required this.userEmail, required this.isGeneralAdmin}) : super(key: key);
  @override
  _PermissionsDialogState createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<PermissionsDialog> {
  Map<AdminPermission, bool> _permissions = {};
  bool _isLoading = true;
  static const Color primaryColor = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    if (!widget.isGeneralAdmin) {
      for (var perm in AdminPermission.values) {
        _permissions[perm] = false;
      }
      _loadUserPermissions();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadUserPermissions() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userEmail).get();
      if (userDoc.exists && (userDoc.data() as Map<String, dynamic>).containsKey('adminPermissions')) {
        final loadedPermissions = (userDoc.data() as Map<String, dynamic>)['adminPermissions'] as Map<String, dynamic>;
        setState(() {
          for (var perm in AdminPermission.values) {
            _permissions[perm] = loadedPermissions[perm.name] ?? false;
          }
        });
      }
    } catch (e) {
      print("권한 로딩 실패: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePermissions() async {
    setState(() => _isLoading = true);
    try {
      final permissionsToSave = _permissions.map((key, value) => MapEntry(key.name, value));
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('setAdminRole');
      await callable.call({
        'email': widget.userEmail,
        'role': widget.isGeneralAdmin ? 'general_admin' : 'admin',
        'permissions': widget.isGeneralAdmin ? null : permissionsToSave,
      });

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userEmail).get();
      final nickname = userDoc.exists ? (userDoc.data() as Map<String, dynamic>)['nickname'] : widget.userEmail;
      final roleText = widget.isGeneralAdmin ? "총괄 관리자" : "관리자";

      await FirebaseFirestore.instance.collection('adminChat').add({
        'text': '$nickname 님이 $roleText로 임명되었습니다.',
        'userEmail': 'system',
        'nickname': '시스템 알림',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '권한이 저장되었습니다.',
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
        Navigator.of(context).pop();
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
                    '권한 저장 실패: $e',
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
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isGeneralAdmin ? '총괄 관리자 임명' : '${widget.userEmail} 권한 설정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)),
          const Divider(color: Colors.black12, height: 16, thickness: 1),
        ],
      ),
      content: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : widget.isGeneralAdmin
          ? Text('${widget.userEmail} 님을 총괄 관리자로 임명합니다.\n총괄 관리자는 일반 관리자를 관리할 수 있습니다.', style: TextStyle(color: Colors.grey.shade700))
          : SingleChildScrollView(
        child: ListBody(
          children: AdminPermission.values.map((permission) {
            return CheckboxListTile(
              title: Text(permissionLabels[permission]!, style: TextStyle(fontSize: 15, color: Colors.black87)),
              value: _permissions[permission],
              onChanged: (bool? value) => setState(() => _permissions[permission] = value!),
              controlAffinity: ListTileControlAffinity.leading, // 체크박스를 왼쪽에 배치
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: primaryColor,
            );
          }).toList(),
        ),
      ),
      actions: _isLoading
          ? []
          : [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('취소', style: TextStyle(color: Colors.black54))),
        ElevatedButton(
          onPressed: _savePermissions,
          child: Text(widget.isGeneralAdmin ? '임명' : '저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: widget.isGeneralAdmin ? Colors.purple : primaryColor,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
          ),
        ),
      ],
    );
  }
}