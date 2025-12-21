// admin_auth_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


import 'admin/admin_screen.dart'; // 실제 AdminScreen 경로로 수정하세요.

class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({Key? key}) : super(key: key);

  @override
  _AdminAuthScreenState createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _checkPassword() async {
    if (_passwordController.text.isEmpty) {
      _showErrorSnackbar('암호를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('admin_config')
          .get();

      if (doc.exists) {
        final correctPassword = doc.data()?['password'];
        if (_passwordController.text == correctPassword) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminScreen()),
            );
          }
        } else {
          _showErrorSnackbar('암호가 올바르지 않습니다.');
        }
      } else {
        _showErrorSnackbar('관리자 설정을 찾을 수 없습니다.');
      }
    } catch (e) {
      _showErrorSnackbar('인증 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Text(
          '관리자 인증',
          style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shadowColor: Colors.grey.shade200,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '관리자 암호를 입력하세요.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                      ),
                      labelText: '암호',
                    ),
                    onSubmitted: (_) => _isLoading ? null : _checkPassword(),
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    onPressed: _checkPassword,
                    label: const Text('확인'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}