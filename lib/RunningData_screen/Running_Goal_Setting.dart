import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoalSettingPage extends StatefulWidget {
  final DateTime selectedDate;
  final int initialCalorieGoal;
  final double initialDistanceGoal;

  const GoalSettingPage({
    Key? key,
    required this.selectedDate,
    required this.initialCalorieGoal,
    required this.initialDistanceGoal,
  }) : super(key: key);

  @override
  State<GoalSettingPage> createState() => _GoalSettingPageState();
}

class _GoalSettingPageState extends State<GoalSettingPage> {
  late TextEditingController _calorieController;
  late TextEditingController _distanceController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _calorieController = TextEditingController();
    _distanceController = TextEditingController();
    _loadInitialGoals(); // Firestore에서 불러오기
  }

  Future<void> _loadInitialGoals() async {
    try {
      String userEmail = FirebaseAuth.instance.currentUser!.email!;
      String dateKey =
          "${widget.selectedDate.year.toString().padLeft(4, '0')}-"
          "${widget.selectedDate.month.toString().padLeft(2, '0')}-"
          "${widget.selectedDate.day.toString().padLeft(2, '0')}";

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userRunningGoals')
          .doc(userEmail)
          .collection('dailyGoals')
          .doc(dateKey)
          .get();

      if (doc.exists) {
        int calorieGoal = doc['calorieGoal'] ?? widget.initialCalorieGoal;
        double distanceGoal = (doc['distanceGoal'] ?? widget.initialDistanceGoal).toDouble();

        _calorieController.text = calorieGoal.toString();
        _distanceController.text = distanceGoal.toString();
      } else {
        // 문서가 없으면 초기값 사용
        _calorieController.text = widget.initialCalorieGoal.toString();
        _distanceController.text = widget.initialDistanceGoal.toString();
      }
    } catch (e) {
      // 오류가 발생하면 기본값으로
      _calorieController.text = widget.initialCalorieGoal.toString();
      _distanceController.text = widget.initialDistanceGoal.toString();
      print('목표 로드 실패: $e');
    }
  }


  @override
  void dispose() {
    _calorieController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _saveGoals() async {
    setState(() {
      _isSaving = true;
    });

    try {
      int calorieGoal = int.parse(_calorieController.text);
      double distanceGoal = double.parse(_distanceController.text);

      if (calorieGoal <= 0 || distanceGoal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('목표값은 0보다 커야 합니다.')),
        );
        return;
      }

      String userEmail = FirebaseAuth.instance.currentUser!.email!;
      print("🔥 저장되는 이메일: $userEmail");
      String dateKey =
          "${widget.selectedDate.year.toString().padLeft(4, '0')}-"
          "${widget.selectedDate.month.toString().padLeft(2, '0')}-"
          "${widget.selectedDate.day.toString().padLeft(2, '0')}";

      await FirebaseFirestore.instance
          .collection('userRunningGoals')
          .doc(userEmail)
          .collection('dailyGoals')
          .doc(dateKey)
          .set({
        'calorieGoal': calorieGoal,
        'distanceGoal': distanceGoal,
        'goalType': distanceGoal >= calorieGoal ? 'distance' : 'calorie',
        'updatedAt': FieldValue.serverTimestamp(),
      });

// userRunningData에도 저장
      await FirebaseFirestore.instance
          .collection('userRunningData')
          .doc(userEmail)
          .set({
        'goals': {
          'calorieGoal': calorieGoal,
          'distanceGoal': distanceGoal,
          'goalType': distanceGoal >= calorieGoal ? 'distance' : 'calorie',
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));  // ← 이걸 꼭 써야 기존 workouts 유지됨

      if (!mounted) return;
      Navigator.pop(context, {
        'calorieGoal': calorieGoal,
        'distanceGoal': distanceGoal,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('목표 설정에 실패했습니다: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 바: 뒤로가기 + 중앙 텍스트
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Image.asset(
                      'assets/images/Back-Navs.png',
                      width: 70,
                      height: 70,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '목표 설정',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 60), // 뒤로가기와 균형 맞추기 위한 공간
                ],
              ),
              SizedBox(height: 40),

              Text(
                '매일 운동 목표를 설정하세요',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 30),

              // 칼로리 목표
              Text(
                '칼로리 목표 (KCAL)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _calorieController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '목표 칼로리 입력',
                  suffixText: 'KCAL',
                ),
              ),
              SizedBox(height: 24),

              // 거리 목표
              Text(
                '거리 목표 (KM)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _distanceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '목표 거리 입력',
                  suffixText: 'KM',
                ),
              ),
              SizedBox(height: 40),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveGoals,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    '저장하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
