import 'package:flutter/material.dart';

/// 고스트런 트래킹 화면의 정보 표시 박스 (시간/거리/페이스 등)
class GhostRunInfoBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const GhostRunInfoBox(this.value, this.label, this.color, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black,
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

/// 고스트런 트래킹 화면의 하단 정보/컨트롤 패널
class GhostRunBottomPanel extends StatelessWidget {
  final String timeDisplay;
  final String distanceDisplay;
  final String paceDisplay;
  final String ghostTimeDisplay;
  final String ghostDistanceDisplay;
  final String ghostPaceDisplay;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const GhostRunBottomPanel({
    Key? key,
    required this.timeDisplay,
    required this.distanceDisplay,
    required this.paceDisplay,
    required this.ghostTimeDisplay,
    required this.ghostDistanceDisplay,
    required this.ghostPaceDisplay,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 유저 정보 표시 영역
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                const Text("Me", style: TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(width: 20),
                Expanded(child: GhostRunInfoBox(timeDisplay, "Time", Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: GhostRunInfoBox(distanceDisplay, "Km", Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: GhostRunInfoBox(paceDisplay, "min/km", Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            // 고스트 정보 표시 영역
            Row(
              children: [
                Image.asset(
                  'assets/images/ghostlogo.png',
                  width: 16,
                  height: 16,
                  color: Colors.purple,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 4),
                const Text("Ghost", style: TextStyle(color: Colors.purple, fontSize: 12)),
                const SizedBox(width: 20),
                Expanded(child: GhostRunInfoBox(ghostTimeDisplay, "Time", Colors.purple)),
                const SizedBox(width: 10),
                Expanded(child: GhostRunInfoBox(ghostDistanceDisplay, "Km", Colors.purple)),
                const SizedBox(width: 10),
                Expanded(child: GhostRunInfoBox(ghostPaceDisplay, "min/km", Colors.purple)),
              ],
            ),
            const SizedBox(height: 20),
            // 컨트롤 버튼 영역 (일시정지/재개)
            if (!isPaused)
              Center(
                child: GestureDetector(
                  onTap: onPause,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange),
                    child: const Icon(Icons.pause, color: Colors.white, size: 32),
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onResume,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
