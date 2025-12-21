import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final bool isPassword;
  final Widget? prefixIcon;
  final TextEditingController? controller; // 추가된 부분

  const CustomTextField({
    Key? key,
    required this.hintText,
    this.isPassword = false,
    this.prefixIcon,
    this.controller, // 추가된 부분
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF7F8F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFF7F8F8)),
      ),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            prefixIcon!, // 아이콘이 있을 경우 표시
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextFormField(
              controller: controller, // 추가된 부분
              obscureText: isPassword,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Color(0xFFADA4A5),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}