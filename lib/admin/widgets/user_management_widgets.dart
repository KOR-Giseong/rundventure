import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// 현재 접속 중인 관리자 목록 위젯
class AdminOnlineList extends StatelessWidget {
  final Stream<DatabaseEvent> onlineAdminsStream;
  final Color primaryColor;

  const AdminOnlineList({
    Key? key,
    required this.onlineAdminsStream,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: StreamBuilder<DatabaseEvent>(
        stream: onlineAdminsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData)
            return Center(
                child: CircularProgressIndicator(color: primaryColor));
          if (snapshot.hasError) return Text("오류: ${snapshot.error}");
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null)
            return Center(
                child: Text("접속 중인 관리자가 없습니다.",
                    style: TextStyle(color: Colors.grey.shade600)));

          final dataObject = snapshot.data!.snapshot.value;
          if (dataObject is! Map) {
            return Center(
                child: Text("데이터 형식이 올바르지 않습니다.",
                    style: TextStyle(color: Colors.grey.shade600)));
          }
          final data = Map<String, dynamic>.from(dataObject);

          final onlineAdmins = data.entries
              .where((e) => (e.value as Map?)?['isOnline'] == true)
              .map((e) =>
                  (e.value as Map)['nickname'] as String? ?? '이름없음')
              .toList();
          if (onlineAdmins.isEmpty)
            return Center(
                child: Text("접속 중인 관리자가 없습니다.",
                    style: TextStyle(color: Colors.grey.shade600)));
          return ListView.builder(
            itemCount: onlineAdmins.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.circle, size: 10, color: Colors.green.shade600),
              title: Text(onlineAdmins[index],
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.black87)),
            ),
          );
        },
      ),
    );
  }
}

/// 전체 알림 발송 폼 위젯
class AdminNotificationForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController messageController;
  final VoidCallback onSend;
  final Color primaryColor;

  const AdminNotificationForm({
    Key? key,
    required this.titleController,
    required this.messageController,
    required this.onSend,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: '제목',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: messageController,
          decoration: InputDecoration(
            labelText: '내용',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: onSend,
          icon: const Icon(Icons.notifications_active_outlined, size: 20),
          label: const Text("알림 전송", style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 1,
          ),
        ),
      ],
    );
  }
}

/// 관리자 암호 변경 폼 위젯
class AdminPasswordChangeForm extends StatelessWidget {
  final TextEditingController passwordController;
  final VoidCallback onSave;

  const AdminPasswordChangeForm({
    Key? key,
    required this.passwordController,
    required this.onSave,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: passwordController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            labelText: '새 암호 (숫자 4자리 이상)',
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.key_outlined, size: 20),
          label: const Text('새 암호 저장', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            elevation: 1,
          ),
        ),
      ],
    );
  }
}

