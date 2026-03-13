import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

// ===================================================================
// 공통 포맷 유틸 함수
// ===================================================================

/// 초(int)를 HH:MM:SS 문자열로 변환
String formatBattleTime(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// 오프라인 대결용 정밀 시간 포맷 (double seconds → MM:SS.cc 또는 HH:MM:SS.cc)
String formatAsyncBattleTime(double seconds) {
  final int totalSec = seconds.floor();
  final int hours = totalSec ~/ 3600;
  final int minutes = (totalSec % 3600) ~/ 60;
  final int secs = totalSec % 60;
  final int centi = ((seconds - totalSec) * 100).floor();
  String timeStr =
      '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${centi.toString().padLeft(2, '0')}';
  if (hours > 0) timeStr = '${hours.toString().padLeft(2, '0')}:$timeStr';
  return timeStr;
}

/// 페이스(double, 분/km)를 "M:SS" 문자열로 변환
String formatBattlePace(double pace) {
  if (pace.isInfinite || pace.isNaN || pace == 0) return '--:--';
  int min = pace.floor();
  int sec = ((pace - min) * 60).round();
  return '$min:${sec.toString().padLeft(2, '0')}';
}

// ===================================================================
// 공통 위젯 (양쪽 대결 화면에서 사용)
// ===================================================================

/// 러닝 통계 컬럼 (값 + 레이블)
class BattleStatColumn extends StatelessWidget {
  final String label;
  final String value;

  const BattleStatColumn(this.label, this.value, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
      ],
    );
  }
}

/// 취소/중단 로딩 오버레이
class BattleCancellingOverlay extends StatelessWidget {
  const BattleCancellingOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// ===================================================================
// 실시간 대결 전용 위젯 (FriendBattleRunningScreen)
// ===================================================================

/// 상대방 상태 배지 텍스트
class OpponentStatusBadge extends StatelessWidget {
  final String opponentStatus;
  const OpponentStatusBadge({Key? key, required this.opponentStatus}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    switch (opponentStatus) {
      case 'stopping':
        text = '중단 중...';
        color = Colors.redAccent;
        break;
      case 'paused':
        text = '일시정지';
        color = Colors.orange;
        break;
      case 'finished':
        text = '완주!';
        color = Colors.green;
        break;
      default:
        text = '러닝 중';
        color = Colors.deepPurple[600]!;
    }
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }
}

/// 꾹 누르기 힌트 토스트
class LongPressHint extends StatelessWidget {
  final bool showHint;
  const LongPressHint({Key? key, required this.showHint}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: showHint ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: showHint
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[800]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.info_outline, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    '중단하려면 버튼을 3초간 꾹 누르세요.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            )
          : const SizedBox(height: 46),
    );
  }
}

/// 실시간 대결 상단 플레이어 정보 헤더
class FriendBattlePlayerHeader extends StatelessWidget {
  final String myNickname;
  final double myKilometers;
  final String opponentNickname;
  final double opponentKilometers;
  final String opponentStatus;

  const FriendBattlePlayerHeader({
    Key? key,
    required this.myNickname,
    required this.myKilometers,
    required this.opponentNickname,
    required this.opponentKilometers,
    required this.opponentStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '나 ($myNickname)',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${myKilometers.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OpponentStatusBadge(opponentStatus: opponentStatus),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        opponentNickname,
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${opponentKilometers.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 실시간 대결 거리 비교 프로그레스 위젯
class BattleDistanceComparator extends StatelessWidget {
  final double myKilometers;
  final double opponentKilometers;
  final double targetDistanceKm;
  final bool isMyRunFinished;

  const BattleDistanceComparator({
    Key? key,
    required this.myKilometers,
    required this.opponentKilometers,
    required this.targetDistanceKm,
    required this.isMyRunFinished,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double myProgress = (myKilometers / targetDistanceKm).clamp(0.0, 1.0);
    final double opponentProgress = (opponentKilometers / targetDistanceKm).clamp(0.0, 1.0);
    final double diff = myKilometers - opponentKilometers;

    String diffText;
    Color diffColor;
    if (isMyRunFinished) {
      diffText = '완주!';
      diffColor = Colors.green;
    } else if (diff.abs() < 0.01) {
      diffText = '박빙';
      diffColor = Colors.black87;
    } else if (diff > 0) {
      diffText = '${(diff * 1000).toStringAsFixed(0)}m 리드';
      diffColor = Colors.blueAccent;
    } else {
      diffText = '${(diff.abs() * 1000).toStringAsFixed(0)}m 낙오';
      diffColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            diffText,
            style: TextStyle(
              color: diffColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 10,
                  width: constraints.maxWidth * opponentProgress,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[300]!,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 10,
                  width: constraints.maxWidth * myProgress,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0km', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(
                '${targetDistanceKm.toStringAsFixed(0)}km',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 러닝 핵심 통계 (페이스 + 시간 + 칼로리)
class BattleMainStats extends StatelessWidget {
  final double myPace;
  final int mySeconds;
  final double myCalories;

  const BattleMainStats({
    Key? key,
    required this.myPace,
    required this.mySeconds,
    required this.myCalories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          formatBattlePace(myPace),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 72,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '현재 페이스 (/km)',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BattleStatColumn('시간', formatBattleTime(mySeconds)),
              BattleStatColumn('칼로리', '${myCalories.toStringAsFixed(0)} kcal'),
            ],
          ),
        ),
      ],
    );
  }
}

/// 실시간 대결 완주 오버레이
class FriendBattleFinishOverlay extends StatelessWidget {
  final int mySeconds;
  final String opponentStatus;
  final String opponentNickname;

  const FriendBattleFinishOverlay({
    Key? key,
    required this.mySeconds,
    required this.opponentStatus,
    required this.opponentNickname,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag, color: Colors.white, size: 80),
            const SizedBox(height: 20),
            Text(
              formatBattleTime(mySeconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              '완주!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              opponentStatus == 'finished'
                  ? '상대방도 완주! 잠시 후 결과가 표시됩니다...'
                  : '$opponentNickname 님을 기다리는 중...',
              style: TextStyle(color: Colors.grey[300], fontSize: 16),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// 오프라인(비동기) 대결 전용 위젯 (AsyncBattleRunningScreen)
// ===================================================================

/// 오프라인 대결 상단 플레이어 헤더
class AsyncBattlePlayerHeader extends StatelessWidget {
  final double myKilometers;
  final double targetDistanceKm;

  const AsyncBattlePlayerHeader({
    Key? key,
    required this.myKilometers,
    required this.targetDistanceKm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '오프라인 대결',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${myKilometers.toStringAsFixed(2)} km',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '목표',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${targetDistanceKm.toStringAsFixed(0)} km',
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 오프라인 대결 핵심 통계 (double 초 사용)
class AsyncBattleMainStats extends StatelessWidget {
  final double myPace;
  final double mySeconds;
  final double myCalories;

  const AsyncBattleMainStats({
    Key? key,
    required this.myPace,
    required this.mySeconds,
    required this.myCalories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          formatBattlePace(myPace),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 72,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '현재 페이스 (/km)',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BattleStatColumn('시간', formatAsyncBattleTime(mySeconds)),
              BattleStatColumn('칼로리', '${myCalories.toStringAsFixed(0)} kcal'),
            ],
          ),
        ),
      ],
    );
  }
}

/// 오프라인 대결 완주/전송 오버레이
class AsyncBattleFinishOverlay extends StatelessWidget {
  final bool isProcessing;
  final double mySeconds;
  final VoidCallback onExit;

  const AsyncBattleFinishOverlay({
    Key? key,
    required this.isProcessing,
    required this.mySeconds,
    required this.onExit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isProcessing) ...[
              const Text(
                '기록 전송 중...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.white),
            ] else ...[
              const Icon(Icons.flag, color: Colors.white, size: 80),
              const SizedBox(height: 20),
              Text(
                formatAsyncBattleTime(mySeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '완주!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '기록 전송에 실패했습니다.\n(컨트롤 버튼을 눌러 중단하거나 앱 재시작)',
                style: TextStyle(color: Colors.grey[300], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: onExit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  '나가기 (기록 미저장)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
