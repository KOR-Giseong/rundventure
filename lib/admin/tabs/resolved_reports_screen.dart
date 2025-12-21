import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rundventure/admin/dialogs/user_details_dialog.dart'; // UserDetailsDialog 경로

class ResolvedReportsScreen extends StatefulWidget {
  const ResolvedReportsScreen({Key? key}) : super(key: key);

  @override
  State<ResolvedReportsScreen> createState() => _ResolvedReportsScreenState();
}

class _ResolvedReportsScreenState extends State<ResolvedReportsScreen> {
  late final Stream<QuerySnapshot> _resolvedReportsStream;
  static const Color primaryColor = Color(0xFF1E88E5); // AdminScreen 테마색

  @override
  void initState() {
    super.initState();
    // 'resolved' 상태이고, 'resolvedAt' (처리 일시) 기준으로 최신순 정렬
    _resolvedReportsStream = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'resolved')
        .orderBy('resolvedAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5), // AdminScreen 배경색
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          "처리된 신고 내역",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _resolvedReportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text("오류: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  "처리 완료된 신고 내역이 없습니다.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                ),
              ),
            );
          }

          final reports = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final doc = reports[index];
              final data = doc.data() as Map<String, dynamic>;
              final nickname = data['reportedUserNickname'] ?? '알 수 없음';
              final category = data['category'] ?? '기타';
              final timestamp = data['timestamp'] as Timestamp?; // 신고 접수일
              final resolvedAt = data['resolvedAt'] as Timestamp?; // 처리 완료일

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      )
                    ]
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.check_circle_outline, color: Colors.green[700]),
                  ),
                  title: Text(
                    nickname,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  subtitle: Text(
                    "사유: $category\n처리일: ${resolvedAt != null ? DateFormat('yyyy.MM.dd HH:mm').format(resolvedAt.toDate()) : '알 수 없음'}",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
                  onTap: () {
                    _showResolvedReportDetailsDialog(doc);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 처리 완료된 신고 상세 내역 다이얼로그 (버튼 제외)
  void _showResolvedReportDetailsDialog(DocumentSnapshot reportDoc) {
    final data = reportDoc.data() as Map<String, dynamic>;

    final String reportedUserEmail = data['reportedUserEmail'] ?? '알 수 없음';
    final String reportedUserNickname = data['reportedUserNickname'] ?? '알 수 없음';
    final String reporterEmail = data['reporterEmail'] ?? '알 수 없음';
    final String category = data['category'] ?? '기타';
    final String details = data['details'] ?? '상세 사유 없음';
    final String? imageUrl = data['imageUrl'];
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final Timestamp resolvedAt = data['resolvedAt'] ?? Timestamp.now();
    final String formattedDate = DateFormat('yyyy.MM.dd HH:mm').format(timestamp.toDate());
    final String formattedResolvedDate = DateFormat('yyyy.MM.dd HH:mm').format(resolvedAt.toDate());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("처리 완료 내역", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)),
              const Divider(color: Colors.black12, height: 16, thickness: 1),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                _buildDetailRow("처리 상태:", "완료됨", valueColor: Colors.green.shade700),
                _buildDetailRow("처리 일시:", formattedResolvedDate),
                SizedBox(height: 10),
                Divider(height: 1, color: Colors.grey[300]),
                SizedBox(height: 10),
                _buildDetailRow("신고 대상:", "$reportedUserNickname ($reportedUserEmail)"),
                _buildDetailRow("신고자:", reporterEmail),
                _buildDetailRow("신고 접수:", formattedDate),
                _buildDetailRow("신고 사유:", category, valueColor: Colors.red.shade700),
                SizedBox(height: 16),
                Text("상세 내용:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(12),
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: Text(details.isEmpty ? "상세 사유 없음" : details, style: TextStyle(fontSize: 14, height: 1.5)),
                ),
                SizedBox(height: 16),
                if (imageUrl != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
                          body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
                        ),
                      ));
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("첨부 이미지:", style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: double.maxFinite,
                            fit: BoxFit.cover,
                            // (로딩/에러 빌더는 간결성을 위해 생략, 필요시 ReportManagementTab에서 복사)
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              icon: Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: Text('사용자 보기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop(); // 신고 창 닫기
                _showUserDetails(reportedUserEmail); // UserDetailsDialog 열기
              },
            ),
            TextButton(
              child: Text('닫기', style: TextStyle(color: Colors.black54)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  // --- (Helper Functions) ---

  /// 신고 대상자의 UserDetailsDialog 띄우기
  Future<void> _showUserDetails(String userEmail) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userEmail).get();
      if (userDoc.exists && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => UserDetailsDialog(userDoc: userDoc),
        );
      } else {
        _showCustomSnackBar("사용자 정보를 찾을 수 없습니다.", isError: true);
      }
    } catch (e) {
      _showCustomSnackBar("사용자 정보 로딩 실패: $e", isError: true);
    }
  }

  // 신고 상세 다이얼로그 내부에서 사용될 헬퍼
  Widget _buildDetailRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 스낵바
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
        backgroundColor: isError ? Colors.redAccent.shade400 : const Color(0xFFFF9F80), // 성공(주황)
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }
}