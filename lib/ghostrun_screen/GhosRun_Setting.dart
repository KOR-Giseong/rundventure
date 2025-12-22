import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GhostRunSettingsPage extends StatefulWidget {
  const GhostRunSettingsPage({Key? key}) : super(key: key);

  @override
  State<GhostRunSettingsPage> createState() => _GhostRunSettingsPageState();
}

class _GhostRunSettingsPageState extends State<GhostRunSettingsPage> {
  bool _autoSaveEnabled = true;
  int _autoSaveMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSaveEnabled = prefs.getBool('autoSaveEnabled') ?? true;
      _autoSaveMinutes = prefs.getInt('autoSaveMinutes') ?? 30;
    });
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade400 : Colors.blueGrey.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSaveEnabled', _autoSaveEnabled);
    await prefs.setInt('autoSaveMinutes', _autoSaveMinutes);
    _showCustomSnackBar('설정이 저장되었습니다.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Image.asset('assets/images/Back-Navs.png',
              width: 40,
              height: 40,
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        title: const Text(
          '고스트런 설정',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SwitchListTile(
                title: const Text('자동 저장', style: TextStyle(color: Colors.black, fontSize: 16)),
                value: _autoSaveEnabled,
                onChanged: (value) {
                  setState(() => _autoSaveEnabled = value);
                },
                activeColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
            ),
            if (_autoSaveEnabled)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Text("자동 저장 시간: ", style: TextStyle(color: Colors.black, fontSize: 16)),
                    Expanded(
                      child: Slider(
                        value: _autoSaveMinutes.toDouble(),
                        min: 5,
                        max: 60,
                        divisions: 11,
                        label: "$_autoSaveMinutes분",
                        onChanged: (value) {
                          setState(() {
                            _autoSaveMinutes = value.toInt();
                          });
                        },
                        activeColor: Colors.redAccent,
                        inactiveColor: Colors.grey.shade300,
                        thumbColor: Colors.redAccent,
                      ),
                    ),
                    Text("$_autoSaveMinutes분", style: const TextStyle(color: Colors.black, fontSize: 16)),
                  ],
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}