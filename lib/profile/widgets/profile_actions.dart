import 'package:flutter/material.dart';

class ProfileActions extends StatelessWidget {
  const ProfileActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ActionButton(
              label: '취소',
              isOutlined: true,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ActionButton(
              label: '저장',
              isOutlined: false,
              onPressed: () {
                // Handle save action
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final bool isOutlined;
  final VoidCallback onPressed;

  const ActionButton({
    Key? key,
    required this.label,
    required this.isOutlined,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: isOutlined ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOutlined
                ? const BorderSide(color: Colors.black)
                : BorderSide.none,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isOutlined ? Colors.black : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }
}