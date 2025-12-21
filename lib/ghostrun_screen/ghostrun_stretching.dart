import 'package:flutter/material.dart';
import 'StretchingGuidePage.dart';
import 'ghostrun_ready.dart';

class StretchingPage extends StatelessWidget {
  const StretchingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const StretchingPageBody();
  }
}

class StretchingPageBody extends StatefulWidget {
  const StretchingPageBody({Key? key}) : super(key: key);

  @override
  State<StretchingPageBody> createState() => _StretchingPageBodyState();
}

class _StretchingPageBodyState extends State<StretchingPageBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // 배경 이미지
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                child: Image.asset('assets/images/ghostrunpage2.png'),
              ),
            ),

            // 스트레칭 이미지
            Positioned(
              top: 300,
              left: -20,
              right: 70,
              child: Image.asset(
                'assets/images/stretching.png',
                width: double.infinity,
                height: 500,
                fit: BoxFit.contain,
              ),
            ),

            // 본문 텍스트
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              bottom: 100,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "러닝하기 전",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      "몸을 잘 풀어주세요!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "러닝할 때는 항상 조심하며\n몸을 충분히 풀어준 뒤 운동해주세요!\n준비가 되면 아래 시작버튼을 눌러주세요!",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 시작 버튼
            Positioned(
              bottom: 30,
              left: 30,
              right: 30,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const GhostRunReadyPage()),
                  );

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("시작하기"),
              ),
            ),

            // ✅ (1) 말풍선 애니메이션
            Positioned(
              top: MediaQuery.of(context).padding.top - 10,
              right: 10,
              child: FadeTransition(
                opacity: _controller,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.1).animate(_controller),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 1.2),
                        ),
                        child: const Text(
                          "스트레칭!",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -10,
                        left: 50,
                        child: CustomPaint(
                          size: const Size(14, 14),
                          painter: TrianglePainter(paintColor: Colors.yellow),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ (2) 뒤로가기 + 타이틀 + 아이콘 맨 위로 이동
            Positioned(
              top: MediaQuery.of(context).padding.top - 60,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          'assets/images/Back-Navs-Black.png',
                          width: 46,
                          height: 46,
                        ),
                      ),
                    ),
                    const Text(
                      "고스트런",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sports_gymnastics, color: Colors.white, size: 28),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StretchingGuidePage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 삼각형 화살표 페인터
class TrianglePainter extends CustomPainter {
  final Color paintColor;
  TrianglePainter({required this.paintColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = paintColor;
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
