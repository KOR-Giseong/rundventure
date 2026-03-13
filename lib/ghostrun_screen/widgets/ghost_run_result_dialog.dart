import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'ghost_share_preview_overlay.dart';
import 'route_map_dialog.dart';

/// 고스트런 기록 목록을 보여주고, 기록 선택 / 공유 기능을 제공하는 다이얼로그입니다.
class GhostRunResultDialog extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Function(Map<String, dynamic>) onRecordSelected;
  final FirebaseFirestore firestore;
  final String currentUserEmail;

  const GhostRunResultDialog({
    super.key,
    required this.records,
    required this.onRecordSelected,
    required this.firestore,
    required this.currentUserEmail,
  });

  Future<void> _shareRecordAsImage(
      BuildContext context, Map<String, dynamic> userRecord) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    Map<String, dynamic>? ghostRecord;
    if (userRecord['isFirstRecord'] == false &&
        userRecord['ghostRecordId'] != null) {
      try {
        final ghostDoc = await firestore
            .collection('ghostRunRecords')
            .doc(currentUserEmail)
            .collection('records')
            .doc(userRecord['ghostRecordId'])
            .get();
        if (ghostDoc.exists) {
          ghostRecord = ghostDoc.data();
        }
      } catch (e) {
        print("공유를 위한 고스트 기록 로딩 실패: $e");
      }
    }

    if (!context.mounted) return;
    Navigator.pop(context); // 로딩 인디케이터 닫기

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => GhostSharePreviewOverlay(
        userResult: userRecord,
        ghostResult: ghostRecord,
        isWin: userRecord['raceResult'] == 'win',
        onShareComplete: () => overlayEntry.remove(),
      ),
    );
    overlay.insert(overlayEntry);
  }

  void _showOptionsDialog(BuildContext context, Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('작업 선택', style: TextStyle(color: Colors.white)),
        content: const Text('이 기록을 불러오거나 공유하시겠습니까?',
            style: TextStyle(color: Colors.white70)),
        actions: <Widget>[
          TextButton(
            child: const Text('공유하기',
                style: TextStyle(color: Colors.cyanAccent)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _shareRecordAsImage(context, record);
            },
          ),
          TextButton(
            child:
                const Text('불러오기', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRecordSelected(record);
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  void _showRouteMap(BuildContext context, Map<String, dynamic> record) async {
    List<LatLng> pointsToLatLng(List<dynamic> pointsData) {
      return pointsData.map((p) {
        if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
        if (p is Map)
          return LatLng((p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble());
        return const LatLng(0, 0);
      }).where((point) => point.latitude != 0 || point.longitude != 0).toList();
    }

    final userPointsData = record['locationPoints'] as List<dynamic>?;
    if (userPointsData == null || userPointsData.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('경로 데이터가 없습니다.')));
      return;
    }

    final List<LatLng> userRoutePoints = pointsToLatLng(userPointsData);
    List<LatLng>? ghostRoutePoints;

    if (record['isFirstRecord'] == false && record['ghostRecordId'] != null) {
      try {
        final ghostDoc = await firestore
            .collection('ghostRunRecords')
            .doc(currentUserEmail)
            .collection('records')
            .doc(record['ghostRecordId'])
            .get();
        if (ghostDoc.exists) {
          final ghostPointsData =
              ghostDoc.data()?['locationPoints'] as List<dynamic>?;
          if (ghostPointsData != null && ghostPointsData.isNotEmpty) {
            ghostRoutePoints = pointsToLatLng(ghostPointsData);
          }
        }
      } catch (e) {
        print("고스트 경로 로딩 실패: $e");
      }
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => RouteMapDialog(
        userRoutePoints: userRoutePoints,
        ghostRoutePoints: ghostRoutePoints,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('고스트런 기록 선택',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[800]),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  String dateText = "기록 없음";
                  if (record['date'] is Timestamp) {
                    dateText =
                        "지난기록 ${DateFormat('yy.MM.dd').format((record['date'] as Timestamp).toDate())}";
                  }
                  String timeText = "--:--";
                  if (record['time'] != null) {
                    final int timeInSeconds = (record['time'] as num).toInt();
                    timeText =
                        "${(timeInSeconds ~/ 60).toString().padLeft(2, '0')}:${(timeInSeconds % 60).toString().padLeft(2, '0')}";
                  }
                  String distanceText = "--";
                  if (record['distance'] != null) {
                    distanceText =
                        "${(record['distance'] as num).toStringAsFixed(2)}km";
                  }
                  String paceText = "--:--";
                  if (record['pace'] != null &&
                      (record['pace'] as num).isFinite &&
                      (record['pace'] as num) > 0) {
                    final double pace = (record['pace'] as num).toDouble();
                    final int paceMinutes = pace.floor();
                    final int paceSeconds =
                        ((pace - paceMinutes) * 60).round();
                    paceText =
                        "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
                  }

                  String resultText = "";
                  if (record['isFirstRecord'] == true) {
                    resultText = ' (첫 기록)';
                  } else if (record['raceResult'] != null) {
                    resultText = (record['raceResult'] == 'win'
                        ? ' (승리)'
                        : (record['raceResult'] == 'lose'
                            ? ' (패배)'
                            : ' (무승부)'));
                  }

                  return InkWell(
                    onTap: () => _showOptionsDialog(context, record),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$dateText$resultText",
                                style: TextStyle(
                                  color: record['raceResult'] == 'win'
                                      ? Colors.green[400]
                                      : (record['raceResult'] == 'lose'
                                          ? Colors.red[400]
                                          : Colors.grey[400]),
                                  fontSize: 13,
                                ),
                              ),
                              if (record['locationPoints'] != null &&
                                  (record['locationPoints'] as List).isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.map_outlined,
                                      color: Colors.white70, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      _showRouteMap(context, record),
                                )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildRecordCard(timeText, 'Time'),
                              _buildRecordCard(distanceText, 'Km'),
                              _buildRecordCard(paceText, 'min/km'),
                            ],
                          ),
                          if (index < records.length - 1)
                            Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Divider(color: Colors.grey[800])),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(String value, String label) {
    return Container(
      width: 90,
      height: 60,
      decoration: BoxDecoration(
          color: Colors.black, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}
