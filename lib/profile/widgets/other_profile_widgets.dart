import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 비공개 프로필 메시지 위젯
class ProfilePrivateMessage extends StatelessWidget {
  const ProfilePrivateMessage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 40, color: Colors.grey[500]),
            const SizedBox(height: 16),
            Text('비공개 프로필입니다.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('사용자가 프로필 정보를 공개하지 않았습니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// 탈퇴한 사용자 메시지 위젯
class ProfileWithdrawnMessage extends StatelessWidget {
  const ProfileWithdrawnMessage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 40, color: Colors.grey[500]),
            const SizedBox(height: 16),
            Text('탈퇴한 사용자입니다.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('요청한 프로필을 찾을 수 없습니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// 레벨 정보 비공개 바 위젯
class ProfilePrivateLevelBar extends StatelessWidget {
  const ProfilePrivateLevelBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      margin: const EdgeInsets.only(top: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            "레벨 정보가 비공개입니다.",
            style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// W/L 통계 열 위젯
Widget buildWLStatColumn(String label, String value,
    {Color color = Colors.black87}) {
  return Column(
    children: [
      Text(
        label,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

/// 프로필 정보 행 위젯
Widget buildProfileInfoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0),
    child: Row(
      children: [
        Icon(icon, size: 22, color: Colors.grey[800]),
        const SizedBox(width: 16),
        Text('$label:',
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}

/// 명예의 전당 목록 항목 위젯
Widget buildHallOfFameListItem(
    {required int rank, required String title, required int exp}) {
  final expFormatter = NumberFormat('#,###');
  IconData rankIcon;
  Color rankColor;
  double iconSize = 28;

  switch (rank) {
    case 1:
      rankIcon = Icons.emoji_events;
      rankColor = Colors.amber.shade700;
      break;
    case 2:
      rankIcon = Icons.emoji_events;
      rankColor = Colors.grey.shade500;
      break;
    case 3:
      rankIcon = Icons.emoji_events;
      rankColor = Colors.brown.shade400;
      break;
    default:
      rankIcon = Icons.military_tech_outlined;
      rankColor = Colors.grey.shade400;
      iconSize = 24;
  }

  return ListTile(
    dense: false,
    leading: Container(
      width: 40,
      alignment: Alignment.center,
      child: Icon(rankIcon, color: rankColor, size: iconSize),
    ),
    title: Text(
      title,
      style: const TextStyle(
          fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
    ),
    subtitle: Text(
      '$rank 위',
      style: TextStyle(
          fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey[600]),
    ),
    trailing: Text(
      '${expFormatter.format(exp)} EXP',
      style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFFEF6C00)),
    ),
  );
}
