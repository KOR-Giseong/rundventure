import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SharedPreferences prefs;

  // 현재 설정값들
  loc.LocationAccuracy selectedAccuracy = loc.LocationAccuracy.high;
  int interval = 1000;
  double distanceFilter = 5.0; // 기본값 변경

  final Map<String, loc.LocationAccuracy> accuracyOptions = {
    '가장 높음 (High)': loc.LocationAccuracy.high,
    '균형 (Balanced)': loc.LocationAccuracy.balanced,
    '배터리 절약 (Low)': loc.LocationAccuracy.low,
    '내비게이션 (Navigation)': loc.LocationAccuracy.navigation,
  };

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    prefs = await SharedPreferences.getInstance();

    String? savedAccuracyKey = prefs.getString('accuracy');
    if (savedAccuracyKey != null && accuracyOptions.containsKey(savedAccuracyKey)) {
      setState(() {
        selectedAccuracy = accuracyOptions[savedAccuracyKey]!;
      });
    }

    setState(() {
      interval = prefs.getInt('interval') ?? 1000;
      distanceFilter = prefs.getDouble('distanceFilter') ?? 5.0;
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
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      ),
    );
  }

  Future<void> _saveSettingsAndPop() async {
    await prefs.setString('accuracy', accuracyOptions.entries
        .firstWhere((entry) => entry.value == selectedAccuracy)
        .key);
    await prefs.setInt('interval', interval);
    await prefs.setDouble('distanceFilter', distanceFilter);

    _showCustomSnackBar('설정이 저장되었습니다.');
    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _resetToDefaults() async {
    bool? confirm = await _showResetConfirmationDialog(context);
    if (confirm == true) {
      setState(() {
        selectedAccuracy = loc.LocationAccuracy.high;
        interval = 1000;
        distanceFilter = 5.0;
      });
      await prefs.setString('accuracy', '가장 높음 (High)');
      await prefs.setInt('interval', 1000);
      await prefs.setDouble('distanceFilter', 5.0);
    }
  }

  Future<bool?> _showResetConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('설정 초기화', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('모든 설정을 기본값으로 되돌리시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('아니오', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('예', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDescriptionDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text('닫기', style: TextStyle(color: Colors.black)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/Back-Navs.png',
              width: 45,
              height: 45,
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text('러닝 설정', style: TextStyle(color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsCard(
              title: '위치 정확도',
              description:
              'GPS의 위치 감지 정확도를 설정합니다.\n'
                  '- 가장 높음: 가장 정밀한 위치 추적\n'
                  '- 균형: 일반적인 사용에 권장\n'
                  '- 배터리 절약: 배터리 소모 최소화\n'
                  '- 내비게이션: 최고 수준의 정밀도',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<loc.LocationAccuracy>(
                  value: selectedAccuracy,
                  isExpanded: true,
                  dropdownColor: Colors.white, // ✨ [수정] 드롭다운 메뉴 배경색 추가
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedAccuracy = value;
                      });
                    }
                  },
                  items: accuracyOptions.entries.map((entry) {
                    return DropdownMenuItem<loc.LocationAccuracy>(
                      value: entry.value,
                      child: Text(
                        entry.key,
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    );
                  }).toList(),
                  icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.redAccent),
                ),
              ),
            ),
            _buildSettingsCard(
              title: '업데이트 주기 (ms)',
              description:
              '위치 업데이트가 얼마나 자주 발생하는지를 설정합니다.\n'
                  '낮은 값일수록 실시간 반응성이 좋지만 배터리 소모가 큽니다.',
              child: Slider(
                min: 500,
                max: 5000,
                divisions: 9,
                label: '${interval}ms',
                value: interval.toDouble(),
                onChanged: (double value) {
                  setState(() => interval = value.toInt());
                },
                activeColor: Colors.redAccent,
                inactiveColor: Colors.grey.shade300,
              ),
            ),
            _buildSettingsCard(
              title: '이동 필터 (미터)',
              description:
              '사용자의 위치가 몇 미터 이상 변경되었을 때만 업데이트를 반영합니다.\n'
                  '값이 높을수록 배터리 소모는 줄어들지만, 정확도는 낮아질 수 있습니다.',
              child: Slider(
                min: 0.0,
                max: 10.0,
                divisions: 20,
                label: '${distanceFilter.toStringAsFixed(1)}m',
                value: distanceFilter,
                onChanged: (double value) {
                  setState(() => distanceFilter = value);
                },
                activeColor: Colors.redAccent,
                inactiveColor: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '  * 다음 러닝부터 적용됩니다!',
              style: TextStyle(color: Colors.redAccent.shade200, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _saveSettingsAndPop,
                child: const Text('적용하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _resetToDefaults,
              child: Text('설정 초기화', style: TextStyle(color: Colors.grey.shade600, decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required String title, required String description, required Widget child}) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: Colors.black.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showDescriptionDialog(title, description),
                  child: Icon(Icons.help_outline, color: Colors.grey.shade400, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}