import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main_screens/game_running/game_running_section.dart';
import 'ghostrunpage.dart'; // 파일명에 맞게 조정하세요

class GhostRunReadyPage extends StatefulWidget {
  const GhostRunReadyPage({super.key});

  @override
  State<GhostRunReadyPage> createState() => _GhostRunReadyPageState();
}

class _GhostRunReadyPageState extends State<GhostRunReadyPage> {
  static int _imageIndex = 0;
  Timer? _timer;
  bool isLoading = false;

  final List<List<String>> _imageSets = [
    ['ghostrunpage1.png', 'ghostrunpage1-2.png'],
    ['ghostrunpage2.png', 'ghostrunpage2-1.png'],
    ['ghostrunpage3.png', 'ghostrunpage3-1.png'],
  ];

  final List<Map<String, dynamic>> _ghostStyles = [
    {
      'alignment': const Alignment(0, 0.4),
      'width': 500.0,
      'height': 400.0,
    },
    {
      'alignment': const Alignment(0, 0.85),
      'width': 600.0,
      'height': 600.0,
    },
    {
      'alignment': const Alignment(0, 0.8),
      'width': 450.0,
      'height': 450.0,
    },
  ];

  final List<Alignment> _backgroundAlignments = [
    Alignment.center,
    const Alignment(0, -1.0),
    Alignment.center,
  ];

  @override
  void initState() {
    super.initState();

    _imageIndex = (_imageIndex + 1) % _imageSets.length;

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() {
        _imageIndex = (_imageIndex + 1) % _imageSets.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Firestore에서 이전 기록 가져오기
  // Firestore에서 승리한 기록 중 가장 최신 기록 가져오기
  Future<Map<String, dynamic>?> _loadPreviousRecord(String userEmail) async {
    setState(() {
      isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. 우선 승리한 기록 중 가장 최신 기록 찾기
      final winRecordsSnapshot = await firestore
          .collection('ghostRunRecords')
          .doc(userEmail)
          .collection('records')
          .where('raceResult', isEqualTo: 'win') // 승리한 기록만 필터링
          .orderBy('date', descending: true) // 날짜 내림차순 (최신순)
          .limit(1)
          .get();

      // 1.1 승리 기록이 있는 경우 해당 기록 반환
      if (winRecordsSnapshot.docs.isNotEmpty) {
        final data = winRecordsSnapshot.docs.first.data();
        // ID도 함께 저장 (필요시 사용)
        data['id'] = winRecordsSnapshot.docs.first.id;

        // 사용자 문서에 최신 승리 기록 ID 저장 (다음 사용을 위해)
        await firestore
            .collection('ghostRunRecords')
            .doc(userEmail)
            .set({
          'latestWinRecordId': winRecordsSnapshot.docs.first.id,
          'latestWinRecordDate': data['date'],
        }, SetOptions(merge: true));

        print('최근 승리 기록을 성공적으로 불러왔습니다: $data');

        setState(() {
          isLoading = false;
        });
        return data;
      }
      // 1.2 승리 기록이 없는 경우, 무승부 기록 확인
      else {
        final drawRecordsSnapshot = await firestore
            .collection('ghostRunRecords')
            .doc(userEmail)
            .collection('records')
            .where('raceResult', isEqualTo: 'draw') // 무승부 기록 필터링
            .orderBy('date', descending: true) // 날짜 내림차순
            .limit(1)
            .get();

        // 1.2.1 무승부 기록이 있는 경우
        if (drawRecordsSnapshot.docs.isNotEmpty) {
          final data = drawRecordsSnapshot.docs.first.data();
          data['id'] = drawRecordsSnapshot.docs.first.id;

          print('최근 무승부 기록을 불러왔습니다 (승리 기록 없음): $data');

          setState(() {
            isLoading = false;
          });
          return data;
        }
        // 1.3 승리/무승부 기록이 없는 경우, 가장 최근 기록 (패배 포함)
        else {
          final anyRecordSnapshot = await firestore
              .collection('ghostRunRecords')
              .doc(userEmail)
              .collection('records')
              .orderBy('date', descending: true)
              .limit(1)
              .get();

          if (anyRecordSnapshot.docs.isNotEmpty) {
            final data = anyRecordSnapshot.docs.first.data();
            data['id'] = anyRecordSnapshot.docs.first.id;

            print('승리/무승부 기록이 없어 최근 기록을 불러왔습니다: $data');

            setState(() {
              isLoading = false;
            });
            return data;
          }
        }
      }

      // 기록이 전혀 없는 경우
      print('사용자의 이전 기록이 없습니다.');
      setState(() {
        isLoading = false;
      });
      return null;

    } catch (e) {
      print("Error loading ghost run records: $e");
      setState(() {
        isLoading = false;
      });
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImages = _imageSets[_imageIndex];
    final ghostStyle = _ghostStyles[_imageIndex];
    final currentBackgroundAlignment = _backgroundAlignments[_imageIndex];

    // FirebaseAuth를 통해 현재 로그인된 사용자의 이메일을 가져옵니다.
    final String userEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const GameSelectionPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(5),
            child: Image.asset(
              'assets/images/Back-Navs-Black.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          '고스트런',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/${currentImages[0]}',
              fit: BoxFit.cover,
              alignment: currentBackgroundAlignment,
            ),
          ),

          Positioned.fill(
            child: Align(
              alignment: ghostStyle['alignment'],
              child: Image.asset(
                'assets/images/${currentImages[1]}',
                width: ghostStyle['width'],
                height: ghostStyle['height'],
                fit: BoxFit.contain,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 20),
                const Text(
                  '나의 과거이력보다 향상된\n변화를 느껴보세요!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '고스트런은 자신의 과거 최고기록과 대결하는\n나의 기록 향상에 최적화된 게임입니다.\n과거 나를 이겨 접전하는 목표와 변화를 느껴보세요!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                      // 이전 기록 가져오기
                      final ghostRecord = await _loadPreviousRecord(userEmail);

                      // 화면 이동
                      if (!mounted) return;

                      // 이제 GhostRunPage로 이동합니다
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GhostRunPage(ghostRecord: ghostRecord),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                        : const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}