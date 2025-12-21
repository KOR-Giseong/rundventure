// SharePreviewScreen.dart (새 파일)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SharePreviewScreen extends StatelessWidget {
  final Uint8List imageBytes;

  const SharePreviewScreen({Key? key, required this.imageBytes}) : super(key: key);

  Future<void> _shareImage(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/ghost_run_share.png').create();
      await file.writeAsBytes(imageBytes);
      final xFile = XFile(file.path);

      await Share.shareXFiles([xFile], text: 'Rundventure 고스트런 결과! 👻');
    } catch (e) {
      print('Share error from preview: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("공유 실패: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('공유 미리보기'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.memory(imageBytes),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _shareImage(context),
        child: const Icon(Icons.share),
      ),
    );
  }
}