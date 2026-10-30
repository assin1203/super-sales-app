import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 通用扫码页：全屏相机预览 + 取景框，扫到码后带着字符串回退。
///
/// 用法：`Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanPage()))`，
/// 返回值为 null 表示用户取消。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.title = '扫描条码'});

  final String title;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final MobileScannerController _controller = MobileScannerController(
    // 机器号常见的是条码（Code128/Code39）与二维码，一并支持
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.codabar,
      BarcodeFormat.itf14,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  /// 防抖：一次成功的扫码只回退一次
  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    if (!_controller.value.hasCameraPermission) return;
    await _controller.toggleTorch();
    if (!mounted) return;
    setState(() => _torchOn = !_torchOn);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      _handled = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            tapToFocus: true,
            errorBuilder: (context, error) => _errorView(error),
          ),
          _Overlay(title: widget.title, torchOn: _torchOn, onTorch: _toggleTorch),
        ],
      ),
    );
  }

  /// 相机不可用 / 未授权
  Widget _errorView(MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              denied
                  ? '未获得相机权限，请在 系统设置 → 应用权限 中允许相机后重试'
                  : '相机不可用，请稍后重试',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _controller.start(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶栏（关闭 + 手电筒）+ 居中取景框 + 底部提示
class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.title,
    required this.torchOn,
    required this.onTorch,
  });

  final String title;
  final bool torchOn;
  final VoidCallback onTorch;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                    color: Colors.white,
                  ),
                  tooltip: '手电筒',
                  onPressed: onTorch,
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(
              painter: _FramePainter(),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 32),
            child: Text(
              '将机器条码 / 二维码放入框内，即可自动识别',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// 四角高亮括号
class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 26.0;
    const stroke = 3.0;
    final paint = Paint()
      ..color = const Color(0xFF2E7BFF)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = BorderRadius.circular(12).topLeft.x;

    void corner(Offset from, Offset to) =>
        canvas.drawLine(from, to, paint);

    // 左上
    corner(Offset(0, r), const Offset(0, len));
    corner(Offset(r, 0), const Offset(len, 0));
    // 右上
    corner(Offset(w - r, 0), Offset(w - len, 0));
    corner(Offset(w, r), Offset(w, len));
    // 左下
    corner(Offset(0, h - r), Offset(0, h - len));
    corner(Offset(r, h), Offset(len, h));
    // 右下
    corner(Offset(w - r, h), Offset(w - len, h));
    corner(Offset(w, h - r), Offset(w, h - len));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
