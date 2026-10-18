import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/toast.dart';

/// 头像圆形裁切页（纯 Flutter 实现，替代原生 image_cropper）：
/// 拖动平移 + 双指缩放，圆形蒙层，确认后输出正方形 JPG 字节
class AvatarCropPage extends StatefulWidget {
  const AvatarCropPage({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  ui.Image? _image;
  double _userScale = 1;
  Offset _userOffset = Offset.zero;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _image = frame.image;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('[avatar] decode error: $e');
      if (!mounted) return;
      showToast(context, '图片解析失败，请换一张照片');
      Navigator.pop(context);
    }
  }

  // ---------- 几何：裁切框为边长 frameSize 的正方形，图像 cover 后叠加用户变换 ----------

  double get _baseScale {
    final img = _image!;
    return frameSize / math.min(img.width.toDouble(), img.height.toDouble());
  }

  late double frameSize;

  double get _totalScale => _baseScale * _userScale;

  Offset get _totalOffset {
    final img = _image!;
    final s = _totalScale;
    final baseX = (frameSize - img.width * s) / 2;
    final baseY = (frameSize - img.height * s) / 2;
    final off = Offset(baseX + _userOffset.dx, baseY + _userOffset.dy);
    // 钳制到图像始终覆盖裁切框
    return Offset(
      off.dx.clamp(frameSize - img.width * s, 0.0),
      off.dy.clamp(frameSize - img.height * s, 0.0),
    );
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _userOffset = _userOffset + d.delta);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final oldTotal = _totalScale;
    final newTotal = (oldTotal * d.scale).clamp(_baseScale, _baseScale * 4);
    final f = newTotal / oldTotal;
    final p = d.focalPoint; // 裁切框坐标系（手势面 = 裁切框）
    setState(() {
      _userScale = newTotal / _baseScale;
      final oldOffset = _totalOffset;
      _userOffset = Offset(
        p.dx - f * (p.dx - oldOffset.dx),
        p.dy - f * (p.dy - oldOffset.dy),
      );
    });
  }

  Future<void> _confirm() async {
    final img = _image;
    if (img == null) return;
    final s = _totalScale;
    final offset = _totalOffset;
    final side = frameSize / s;
    final x0 = (-offset.dx / s).clamp(0.0, img.width.toDouble() - side);
    final y0 = (-offset.dy / s).clamp(0.0, img.height.toDouble() - side);
    final outW = side.round().clamp(1, 1024);
    final outH = outW;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(x0, y0, side, side),
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint()..filterQuality = ui.FilterQuality.high,
    );
    final outImg = await recorder.endRecording().toImage(outW, outH);
    final data = await outImg.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    if (mounted) Navigator.pop(context, data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        title: const Text('裁剪头像'),
      ),
      body: _loaded && _image != null
          ? LayoutBuilder(
              builder: (context, c) {
                frameSize = math.min(c.maxWidth - 32, 340);
                final img = _image!;
                final s = _totalScale;
                final offset = _totalOffset;
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: frameSize + 8,
                      height: frameSize + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipOval(
                        child: GestureDetector(
                          onPanUpdate: _onPanUpdate,
                          onScaleUpdate: _onScaleUpdate,
                          child: CustomPaint(
                            size: Size(frameSize, frameSize),
                            painter: _CropPainter(img, Rect.fromLTWH(
                              offset.dx,
                              offset.dy,
                              img.width * s,
                              img.height * s,
                            )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('拖动调整位置 · 双指缩放',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                );
              },
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white70)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _confirm,
            child: const Text('确认裁剪', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.dstRect);

  final ui.Image image;
  final Rect dstRect;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dstRect,
      Paint()..filterQuality = ui.FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.dstRect != dstRect || old.image != image;
}
