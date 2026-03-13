import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RunningRecordsPage extends StatelessWidget {
  final String date;

  RunningRecordsPage({Key? key, required this.date}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchRecords() async {
    String userEmail = FirebaseAuth.instance.currentUser!.email!;
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('userRunningData')
        .doc(userEmail)
        .collection('workouts')
        .doc(date)
        .collection('records')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 상단 바
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),

              // 상태바 높이 반영
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Image.asset(
                        'assets/images/Back-Navs.png',
                        width: 70,
                        height: 70,
                      ),
                    ),
                  ),
                  Text(
                    '$date 기록',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Divider(thickness: 1, color: Colors.grey[300]),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchRecords(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                    return Center(child: Text('기록이 없습니다.'));
                  }

                  List<Map<String, dynamic>> records = snapshot.data!;
                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context, record);
                        },
                        child: Card(
                          color: Colors.grey[200],
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '거리: ${(record['kilometers'] as num).toStringAsFixed(2)} km',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '칼로리: ${(record['calories'] as num).round()} KCAL\n'
                                      '평균 페이스: ${record['pace']} /KM\n'
                                      '시간: ${_formatDuration(record['seconds'] as int)}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
  }
}
