import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rundventure/admin/dialogs/user_details_dialog.dart'; // UserDetailsDialog 임포트
import 'resolved_reports_screen.dart'; // ✅ [신규 추가] 처리된 내역 페이지 임포트

// -----------------------------------------------------------------------------
// 탭 3: 신고 관리
// -----------------------------------------------------------------------------
class ReportManagementTab extends StatefulWidget {
  final Stream<QuerySnapshot> reportsStream;
  final Widget Function({required String title, required Widget child}) buildPanel;

  const ReportManagementTab({
    Key? key,
    required this.reportsStream,
    required this.buildPanel,
  }) : super(key: key);

  @override
  _ReportManagementTabState createState() => _ReportManagementTabState();
}

class _ReportManagementTabState extends State<ReportManagementTab>
    with AutomaticKeepAliveClientMixin {

  static const Color primaryColor = Color(0xFF1E88E5);

  // ▼▼▼▼▼ [신규 추가] ▼▼▼▼▼
  // 누적 신고 횟수를 캐시하여 불필요한 DB 조회를 줄입니다.
  final Map<String, int> _reportCountCache = {};
  // ▲▲▲▲▲ [신규 추가] ▲▲▲▲▲

  @override
  bool get wantKeepAlive => true; // 탭 상태 유지

  /// 신고 상세 내역 및 처리 다이얼로그
  void _showReportDetailsDialog(DocumentSnapshot reportDoc) {
    final data = reportDoc.data() as Map<String, dynamic>;
    final reportId = reportDoc.id;

    final String reportedUserEmail = data['reportedUserEmail'] ?? '알 수 없음';
    final String reportedUserNickname = data['reportedUserNickname'] ?? '알 수 없음';
    final String reporterEmail = data['reporterEmail'] ?? '알 수 없음';
    final String category = data['category'] ?? '기타';
    final String details = data['details'] ?? '상세 사유 없음';
    final String? imageUrl = data['imageUrl'];
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final String formattedDate = DateFormat('yyyy.MM.dd HH:mm').format(timestamp.toDate());

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
              Text("신고 상세 내역", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)),
              const Divider(color: Colors.black12, height: 16, thickness: 1),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                _buildDetailRow("신고 대상:", "$reportedUserNickname ($reportedUserEmail)"),
                _buildDetailRow("신고자:", reporterEmail),
                _buildDetailRow("신고 일시:", formattedDate),
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
                      // 이미지 확대 보기 (FullScreen)
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
                            loadingBuilder: (context, child, progress) {
                              return progress == null ? child : Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stack) {
                              return Container(
                                  height: 100,
                                  color: Colors.grey[200],
                                  child: Center(child: Icon(Icons.broken_image, color: Colors.grey[600]))
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('닫기', style: TextStyle(color: Colors.black54)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
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
            ElevatedButton(
              child: Text('완료 처리', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // 완료는 초록색
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _resolveReport(reportId); // 신고 완료 처리
              },
            ),
          ],
        );
      },
    );
  }

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

  /// 신고 '완료' 처리 (상태를 'resolved'로 변경)
  Future<void> _resolveReport(String reportId) async {
    try {
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      _showCustomSnackBar("신고를 '완료' 처리했습니다.");
    } catch (e) {
      _showCustomSnackBar("처리 중 오류 발생: $e", isError: true);
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
                fontSize: 14, // 👈 다이얼로그 내 폰트 크기
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 스낵바 (신규 추가)
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

  // ▼▼▼▼▼ [수정된 함수] 누적 신고 횟수 가져오기 (캐시 적용) ▼▼▼▼▼
  Future<int> _getReportCount(String userEmail) async {
    // 캐시에 이미 값이 있으면 DB 조회 없이 즉시 반환
    if (_reportCountCache.containsKey(userEmail)) {
      return _reportCountCache[userEmail]!;
    }

    // 캐시에 없으면 DB 조회
    try {
      // 'reports' 컬렉션에서 해당 이메일로 접수된 *모든* 신고를 조회
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportedUserEmail', isEqualTo: userEmail)
          .count() // .get() 대신 .count()를 사용하여 효율적으로 개수만 가져옴
          .get();

      // ▼▼▼▼▼ [수정된 부분] ▼▼▼▼▼
      final count = querySnapshot.count ?? 0; // 👈 null일 경우 0을 할당
      // ▲▲▲▲▲ [수정된 부분] ▲▲▲▲▲

      // 캐시에 저장
      if (mounted) {
        setState(() {
          _reportCountCache[userEmail] = count;
        });
      }
      return count;

    } catch (e) {
      print("신고 횟수 조회 오류 ($userEmail): $e");
      return 0; // 오류 발생 시 0 반환
    }
  }
  // ▲▲▲▲▲ [수정된 함수] ▲▲▲▲▲


  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // ▼▼▼▼▼ [신규 추가] 안내 문구 배너 ▼▼▼▼▼
        Container(
          padding: const EdgeInsets.all(12.0),
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "관리자 안내: 사용자 개인정보 및 신고 내역은 서비스 운영과 분쟁 해결을 위한 중요 자료입니다. 임의로 삭제하거나 유출하는 것을 금합니다.",
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ▲▲▲▲▲ [신규 추가] 안내 문구 배너 ▲▲▲▲▲

        // [기존] 미처리 신고
        widget.buildPanel(
          title: "접수된 신고 내역 (미처리)",
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.reportsStream,
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
                      "처리 대기 중인 신고 내역이 없습니다.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                  ),
                );
              }

              final reports = snapshot.data!.docs;

              return ListView.builder(
                shrinkWrap: true, // ListView in Column
                physics: NeverScrollableScrollPhysics(), // Parent scroll
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final doc = reports[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final nickname = data['reportedUserNickname'] ?? '알 수 없음';
                  final email = data['reportedUserEmail'] ?? ''; // 👈 이메일 가져오기
                  final category = data['category'] ?? '기타';
                  final timestamp = data['timestamp'] as Timestamp?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200)
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade100,
                        child: Icon(Icons.report_problem_outlined, color: Colors.red.shade700),
                      ),
                      title: Row(
                        children: [
                          Text(
                            nickname,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          // 누적 신고 횟수를 FutureBuilder로 표시
                          FutureBuilder<int>(
                            future: _getReportCount(email), // 👈 이메일로 신고 횟수 조회
                            builder: (context, countSnapshot) {
                              if (countSnapshot.connectionState == ConnectionState.waiting || !countSnapshot.hasData || countSnapshot.data == 0) {
                                // 로딩 중이거나 0회면 표시 안 함
                                return SizedBox.shrink();
                              }
                              // 1회 이상이면 뱃지 표시
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "누적 ${countSnapshot.data}회",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      subtitle: Text(
                        "사유: $category\n${timestamp != null ? DateFormat('MM.dd HH:mm').format(timestamp.toDate()) : ''}",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.4,
                          fontSize: 13, // 👈 [수정] 원하는 크기로 조절 (예: 13)
                        ),
                      ),
                      isThreeLine: true,
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
                      onTap: () {
                        _showReportDetailsDialog(doc);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ▼▼▼▼▼ [신규 추가] 처리된 신고 패널 ▼▼▼▼▼
        const SizedBox(height: 16),
        widget.buildPanel(
          title: "접수된 신고 내역 (처리)",
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[50],
              child: Icon(Icons.history_rounded, color: Colors.green[700]),
            ),
            title: Text(
              "처리 완료된 신고 내역 보기",
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
            ),
            subtitle: Text("이미 '완료' 처리한 신고 기록을 확인합니다."),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResolvedReportsScreen(),
                ),
              );
            },
          ),
        ),
        // ▲▲▲▲▲ [신규 추가] 처리된 신고 패널 ▲▲▲▲▲
      ],
    );
  }
}