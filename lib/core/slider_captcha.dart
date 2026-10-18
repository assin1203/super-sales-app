import 'dart:math';

import 'package:flutter/material.dart';

/// 拼图滑块验证码：拖动底部滑块，把拼图块滑进背景缺口，对准即通过。
///
/// 纯自绘实现（绘制背景 + 拼图块），不依赖任何图片资源；验证通过时回调 [onComplete]。
/// 每次实例（或更换 [SliderCaptcha.key]）都会随机生成一个新的缺口位置。
class SliderCaptcha extends StatefulWidget {
  const SliderCaptcha({super.key, this.onComplete, this.height});

  /// 验证通过时触发（只触发一次）。
  final VoidCallback? onComplete;

  /// 图片区高度（默认 = 宽度 * 0.5）。
  final double? height;

  @override
  State<SliderCaptcha> createState() => _SliderCaptchaState();
}

class _SliderCaptchaState extends State<SliderCaptcha> with TickerProviderStateMixin {
  final Random _rand = Random();

  /// 缺口位置（归一化 0~1，映射到拼图块可移动范围）
  double _targetRatio = 0.45;
  double _pieceX = 0; // 拼图块当前横移（0 = 最左）
  double _fromX = 0; // 失败回弹动画起点
  double _lastWidth = 0;
  bool _verified = false;
  bool _snapping = false;
  late final AnimationController _snap;

  // 拼图块几何
  static const double _pieceW = 44;
  static const double _pieceH = 44;
  static const double _knobR = 11;
  static const double _imageRatio = 0.5;
  static const double _trackH = 44;
  static const double _tolerance = 6; // 判定对准的像素容差

  @override
  void initState() {
    super.initState();
    _targetRatio = _rand.nextDouble() * 0.8 + 0.05;
    _snap = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _snap.addListener(() {
      if (_snapping) {
        _pieceX = _fromX * (1 - _snap.value);
        setState(() {});
      }
    });
    _snap.addStatusListener((s) {
      if (s == AnimationStatus.completed && _snapping) {
        _snapping = false;
        _pieceX = 0;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _onDragStart() {
    if (_verified) return;
    _snapping = false;
    _snap.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_verified) return;
    final max = (_lastWidth - _pieceW).clamp(0.0, double.infinity);
    _pieceX = (_pieceX + d.delta.dx).clamp(0.0, max);
    setState(() {});
  }

  void _onDragEnd() {
    if (_verified) return;
    final max = (_lastWidth - _pieceW).clamp(0.0, double.infinity);
    final targetX = _targetRatio * max;
    if ((_pieceX - targetX).abs() <= _tolerance) {
      _verified = true;
      _pieceX = targetX;
      setState(() {});
      widget.onComplete?.call();
    } else {
      // 失败：回弹并换一个新缺口
      _fromX = _pieceX;
      _snapping = true;
      _targetRatio = _rand.nextDouble() * 0.8 + 0.05;
      _snap.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final W = c.maxWidth;
      _lastWidth = W;
      final imageH = widget.height ?? W * _imageRatio;
      final max = (W - _pieceW).clamp(0.0, double.infinity);
      final targetX = _targetRatio * max;
      final y0 = imageH * 0.28;

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6EAF2)),
          boxShadow: const [
            BoxShadow(color: Color(0x0F2B5BFF), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图片区 + 拼图块
            SizedBox(
              height: imageH,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CaptchaPainter(
                        w: W,
                        h: imageH,
                        pieceX: _pieceX,
                        targetX: targetX,
                        y0: y0,
                        pieceW: _pieceW,
                        pieceH: _pieceH,
                        knobR: _knobR,
                        verified: _verified,
                      ),
                    ),
                  ),
                  if (_verified)
                    Positioned(right: 10, top: 10, child: _successBadge()),
                ],
              ),
            ),
            // 滑块轨道
            SizedBox(
              height: _trackH,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Color(0xFFF3F5FA))),
                  // 进度填充
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _pieceX + _pieceW,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _verified
                              ? [const Color(0xFF2FCC70).withValues(alpha: 0.14), const Color(0xFF2FCC70).withValues(alpha: 0.05)]
                              : [const Color(0xFF2B5BFF).withValues(alpha: 0.14), const Color(0xFF00CFFF).withValues(alpha: 0.05)],
                        ),
                      ),
                    ),
                  ),
                  // 提示文案
                  Center(
                    child: Text(
                      _verified ? '验证成功' : '拖动滑块，完成拼图',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _verified ? const Color(0xFF2FCC70) : const Color(0xFF8A93A6),
                      ),
                    ),
                  ),
                  // 滑块
                  Positioned(
                    left: _pieceX.clamp(0.0, max),
                    top: 3,
                    bottom: 3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _verified ? null : (_) => _onDragStart(),
                      onHorizontalDragUpdate: _verified ? null : _onDragUpdate,
                      onHorizontalDragEnd: _verified ? null : (_) => _onDragEnd(),
                      child: Container(
                        width: _pieceW,
                        decoration: BoxDecoration(
                          color: _verified ? const Color(0xFF2FCC70) : null,
                          gradient: _verified
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF2B5BFF), Color(0xFF00A9E8)],
                                ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Color(0x2E2B5BFF), blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(_verified ? Icons.check : Icons.chevron_right, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _successBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2FCC70),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 3),
          Text('验证成功', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 验证码画布：绘制背景场景、缺口阴影、以及随滑块移动的拼图块。
class _CaptchaPainter extends CustomPainter {
  _CaptchaPainter({
    required this.w,
    required this.h,
    required this.pieceX,
    required this.targetX,
    required this.y0,
    required this.pieceW,
    required this.pieceH,
    required this.knobR,
    required this.verified,
  });

  final double w, h, pieceX, targetX, y0, pieceW, pieceH, knobR;
  final bool verified;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 背景场景
    _paintBackground(canvas, size);

    // 2. 缺口阴影（未验证时显示）
    if (!verified) {
      canvas.save();
      canvas.translate(targetX, y0);
      final slot = _puzzlePath(pieceW, pieceH, knobR);
      canvas.drawPath(slot, Paint()..color = const Color(0x55000000));
      canvas.drawPath(
        slot,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xAAFFFFFF),
      );
      canvas.restore();
    }

    // 3. 拼图块投影
    canvas.drawPath(
      _puzzlePath(pieceW, pieceH, knobR).shift(Offset(pieceX, y0)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 4. 拼图块内容：裁剪背景，使拼图块呈现其所在位置的图像内容
    canvas.save();
    canvas.clipPath(_puzzlePath(pieceW, pieceH, knobR).shift(Offset(pieceX, y0)));
    _paintBackground(canvas, size);
    canvas.restore();

    // 5. 拼图块描边
    canvas.save();
    canvas.translate(pieceX, y0);
    canvas.drawPath(
      _puzzlePath(pieceW, pieceH, knobR),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.restore();
  }

  /// 拼图块路径：矩形 + 顶部凸起 + 右侧凸起（经典拼图块外形）
  Path _puzzlePath(double pw, double ph, double r) {
    final p = Path();
    p.moveTo(0, 0);
    p.lineTo(pw / 2 - r, 0);
    p.arcTo(Rect.fromCenter(center: Offset(pw / 2, 0), width: r * 2, height: r * 2), pi, pi, false);
    p.lineTo(pw, 0);
    p.lineTo(pw, ph / 2 - r);
    p.arcTo(
      Rect.fromCenter(center: Offset(pw, ph / 2), width: r * 2, height: r * 2),
      -pi / 2,
      pi,
      false,
    );
    p.lineTo(pw, ph);
    p.lineTo(0, ph);
    p.close();
    return p;
  }

  /// 绘制一张"风景"背景（天空 + 太阳 + 云 + 山丘），让拼图看起来像一张图片
  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final W = size.width;
    final H = size.height;

    // 天空渐变
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9EC1FF), Color(0xFF6E97F5), Color(0xFF3565EC)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );

    // 太阳
    canvas.drawCircle(Offset(W * 0.8, H * 0.26), 20, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawCircle(Offset(W * 0.8, H * 0.26), 13, Paint()..color = const Color(0xFFFFF59D));

    // 云（半透明白色圆组合）
    final cloud = Paint()..color = const Color(0xC8FFFFFF);
    canvas.drawCircle(Offset(W * 0.18, H * 0.30), 11, cloud);
    canvas.drawCircle(Offset(W * 0.25, H * 0.28), 14, cloud);
    canvas.drawCircle(Offset(W * 0.31, H * 0.30), 10, cloud);
    canvas.drawCircle(Offset(W * 0.60, H * 0.42), 9, cloud);
    canvas.drawCircle(Offset(W * 0.66, H * 0.40), 11, cloud);

    // 远山
    final far = Path()
      ..moveTo(0, H)
      ..lineTo(0, H * 0.72)
      ..quadraticBezierTo(W * 0.3, H * 0.5, W * 0.55, H * 0.68)
      ..quadraticBezierTo(W * 0.78, H * 0.82, W, H * 0.66)
      ..lineTo(W, H)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF4666E6));

    // 近山
    final near = Path()
      ..moveTo(0, H)
      ..lineTo(0, H * 0.86)
      ..quadraticBezierTo(W * 0.4, H * 0.7, W * 0.7, H * 0.84)
      ..quadraticBezierTo(W * 0.88, H * 0.92, W, H * 0.82)
      ..lineTo(W, H)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF2B47D4));
  }

  @override
  bool shouldRepaint(_CaptchaPainter old) =>
      old.pieceX != pieceX ||
      old.targetX != targetX ||
      old.verified != verified ||
      old.y0 != y0 ||
      old.w != w ||
      old.h != h;
}
