import 'package:flutter/material.dart';

class RunningLockScreen extends StatelessWidget {
  final double kilometers;
  final int seconds;
  final double pace;
  final double calories;

  const RunningLockScreen({
    Key? key,
    required this.kilometers,
    required this.seconds,
    required this.pace,
    required this.calories,
  }) : super(key: key);

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatPace(double pace) {
    if (pace.isNaN || pace.isInfinite || pace == 0) return '0:00';
    int min = pace.floor();
    int sec = ((pace - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RUNNING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 40),
              Text(
                _formatTime(seconds),
                style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                '${kilometers.toStringAsFixed(2)} KM',
                style: TextStyle(color: Colors.white70, fontSize: 36),
              ),
              SizedBox(height: 20),
              Text(
                'PACE: ${_formatPace(pace)} /km',
                style: TextStyle(color: Colors.white70, fontSize: 24),
              ),
              SizedBox(height: 20),
              Text(
                'CALORIES: ${calories.toStringAsFixed(0)} kcal',
                style: TextStyle(color: Colors.white70, fontSize: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
