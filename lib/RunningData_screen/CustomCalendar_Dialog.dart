import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomCalendarDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  CustomCalendarDialog({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  _CustomCalendarDialogState createState() => _CustomCalendarDialogState();
}

class _CustomCalendarDialogState extends State<CustomCalendarDialog> {
  late DateTime _currentMonth;
  Map<String, num> monthlyCalories = {};
  Map<String, num> monthlyDistances = {};
  Map<String, Map<String, num>> monthlyGoals = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _fetchMonthlyData();
  }

  Future<void> _fetchMonthlyData() async {
    try {
      setState(() => isLoading = true);
      String userEmail = FirebaseAuth.instance.currentUser!.email!;
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

      QuerySnapshot workoutSnapshot = await FirebaseFirestore.instance
          .collection('userRunningData')
          .doc(userEmail)
          .collection('workouts')
          .where('date', isGreaterThanOrEqualTo: firstDay)
          .where('date', isLessThanOrEqualTo: lastDay)
          .get();

      Map<String, num> caloriesMap = {};
      Map<String, num> distancesMap = {};

      for (var doc in workoutSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate());

        caloriesMap[date] = (caloriesMap[date] ?? 0) + (data['calories'] ?? 0);
        distancesMap[date] = (distancesMap[date] ?? 0) + (data['kilometers'] ?? 0);
      }

      QuerySnapshot goalSnapshot = await FirebaseFirestore.instance
          .collection('userRunningGoals')
          .doc(userEmail)
          .collection('dailyGoals')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(firstDay))
          .where(FieldPath.documentId, isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(lastDay))
          .get();

      Map<String, Map<String, num>> goalsMap = {};

      for (var doc in goalSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        goalsMap[doc.id] = {
          'calorieGoal': (data['calorieGoal'] ?? 500) as num,
          'distanceGoal': (data['distanceGoal'] ?? 5.0) as num,
        };
      }

      setState(() {
        monthlyCalories = caloriesMap;
        monthlyDistances = distancesMap;
        monthlyGoals = goalsMap;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      setState(() => isLoading = false);
    }
  }


  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
      _fetchMonthlyData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellSize = screenWidth / 10.1;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(cellSize * 0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, size: cellSize * 0.6),
                  onPressed: () => _changeMonth(-1),
                ),
                Column(
                  children: [
                    Text('${_currentMonth.year}',
                        style: TextStyle(fontSize: cellSize * 0.5, fontWeight: FontWeight.w500)),
                    Text('${_currentMonth.month}월',
                        style: TextStyle(fontSize: cellSize * 0.6, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, size: cellSize * 0.6),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            SizedBox(height: cellSize * 0.4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['월', '화', '수', '목', '금', '토', '일']
                  .map((day) => SizedBox(
                width: cellSize,
                child: Text(
                  day,
                  style: TextStyle(color: Colors.grey[600], fontSize: cellSize * 0.35),
                  textAlign: TextAlign.center,
                ),
              ))
                  .toList(),
            ),
            SizedBox(height: cellSize * 0.2),
            isLoading
                ? Padding(
              padding: EdgeInsets.all(cellSize),
              child: CircularProgressIndicator(),
            )
                : _buildCalendarGrid(cellSize),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(double cellSize) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = firstDay.weekday - 1;
    if (firstWeekday < 0) firstWeekday = 6;

    List<Widget> dateWidgets = [];

    for (int i = 0; i < firstWeekday; i++) {
      dateWidgets.add(SizedBox(width: cellSize, height: cellSize));
    }

    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, i);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final isSelected = dateStr == DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      final calorie = monthlyCalories[dateStr] ?? 0;
      final distance = monthlyDistances[dateStr] ?? 0;
      final calorieGoal = monthlyGoals[dateStr]?['calorieGoal'] ?? 500;
      final distanceGoal = monthlyGoals[dateStr]?['distanceGoal'] ?? 5.0;

      final calorieProgress = (calorie / calorieGoal).clamp(0.0, 1.0);
      final distanceProgress = (distance / distanceGoal).clamp(0.0, 1.0);
      final hasData = calorie > 0 || distance > 0;
      final overallProgress = hasData ? ((calorieProgress + distanceProgress) / 2) : 0.0;

      dateWidgets.add(
        GestureDetector(
          onTap: () {
            if (hasData) {
              widget.onDateSelected(date);
              Navigator.of(context).pop();
            }
          },
          child: Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.deepOrange, width: 2) : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (hasData)
                  SizedBox(
                    width: cellSize * 0.9,
                    height: cellSize * 0.9,
                    child: CircularProgressIndicator(
                      value: overallProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepOrange.withOpacity(0.6),
                      ),
                      strokeWidth: 2,
                    ),
                  ),
                Text(
                  '$i',
                  style: TextStyle(
                    color: hasData ? Colors.black : Colors.grey[400],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: cellSize * 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final empty = (7 - (dateWidgets.length % 7)) % 7;
    for (int i = 0; i < empty; i++) {
      dateWidgets.add(SizedBox(width: cellSize, height: cellSize));
    }

    final rows = (dateWidgets.length / 7).ceil();
    return Column(
      children: List.generate(rows, (rowIndex) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: cellSize * 0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dateWidgets.skip(rowIndex * 7).take(7).toList(),
          ),
        );
      }),
    );
  }
}
