import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/draft_project.dart';
import '../models/product_template.dart';
import '../services/crop_service.dart';
import 'size_selection_screen.dart';

const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];

class CropScreen extends StatefulWidget {
  final DraftProject draft;

  const CropScreen({super.key, required this.draft});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  static const _displayWidth = 390.0;
  static const _displayHeight = 706.0;
  static const _bottomBarHeight = 138.0;
  static const _ratioOptions = [
    CropAspectRatio.square,
    CropAspectRatio.landscape169,
    CropAspectRatio.landscape43,
    CropAspectRatio.portrait34,
    CropAspectRatio.portrait916,
  ];

  final CropService _cropService = CropService();
  CropAspectRatio _ratio = CropAspectRatio.square;
  bool _cropping = false;
  bool _flipped = false;
  double _scale = 1;
  double _gestureStartScale = 1;
  Offset _offset = Offset.zero;
  int _imageWidth = 1;
  int _imageHeight = 1;
  Color _backgroundColor = const Color(0xFF478EA1);

  @override
  void initState() {
    super.initState();
    _inspectImage();
  }

  void _inspectImage() {
    final decoded = img.decodeImage(widget.draft.originalImageBytes);
    if (decoded == null) return;
    _imageWidth = decoded.width;
    _imageHeight = decoded.height;
    _backgroundColor = _averageColor(decoded);
  }

  Color _averageColor(img.Image image) {
    final step = math.max(1, math.min(image.width, image.height) ~/ 40);
    var red = 0;
    var green = 0;
    var blue = 0;
    var count = 0;

    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);
        red += pixel.r.toInt();
        green += pixel.g.toInt();
        blue += pixel.b.toInt();
        count++;
      }
    }

    if (count == 0) return const Color(0xFF478EA1);
    final color = Color.fromARGB(
      255,
      (red / count).round(),
      (green / count).round(),
      (blue / count).round(),
    );
    return Color.lerp(color, Colors.black, 0.12) ?? color;
  }

  Size _cropFrameSize(CropAspectRatio ratio) {
    final value = ratio.value ?? 1;
    var width = _displayWidth - 60;
    var height = width / value;
    final maxHeight = _displayHeight - 60;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * value;
    }
    return Size(width, height);
  }

  double _baseFitScale(Size cropSize) {
    return math.max(
      cropSize.width / _imageWidth,
      cropSize.height / _imageHeight,
    );
  }

  Offset _clampOffset(Offset candidate, Size cropSize, double scale) {
    final renderScale = _baseFitScale(cropSize) * scale;
    final renderedWidth = _imageWidth * renderScale;
    final renderedHeight = _imageHeight * renderScale;
    final maxX = math.max(0.0, (renderedWidth - cropSize.width) / 2);
    final maxY = math.max(0.0, (renderedHeight - cropSize.height) / 2);
    return Offset(
      candidate.dx.clamp(-maxX, maxX).toDouble(),
      candidate.dy.clamp(-maxY, maxY).toDouble(),
    );
  }

  void _setRatio(CropAspectRatio ratio) {
    setState(() {
      _ratio = ratio;
      _offset = _clampOffset(_offset, _cropFrameSize(ratio), _scale);
    });
  }

  void _toggleFlip() {
    setState(() => _flipped = !_flipped);
  }

  Future<void> _confirmCrop() async {
    final cropSize = _cropFrameSize(_ratio);
    final offset = _clampOffset(_offset, cropSize, _scale);
    final renderScale = _baseFitScale(cropSize) * _scale;

    setState(() => _cropping = true);
    try {
      final cropped = await _cropService.cropToAspectRatioWithTransform(
        widget.draft.originalImageBytes,
        _ratio,
        renderScale: renderScale,
        displayOffsetX: offset.dx,
        displayOffsetY: offset.dy,
        cropDisplayWidth: cropSize.width,
        cropDisplayHeight: cropSize.height,
        flipped: _flipped,
      );
      if (!mounted) return;
      final nextDraft = widget.draft.copyWith(
        croppedImageBytes: cropped,
        cropAspectRatio: _ratio,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SizeSelectionScreen(draft: nextDraft),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('裁切失败：$error')));
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pageWidth = math.min(constraints.maxWidth, 430.0);
          final scale = pageWidth / _displayWidth;
          final scaledHeight = 844 * scale;

          return Center(
            child: SizedBox(
              width: pageWidth,
              height: math.max(scaledHeight, constraints.maxHeight),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: _displayWidth * scale,
                  height: scaledHeight,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: _displayWidth,
                      height: 844,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(color: _backgroundColor),
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            width: _displayWidth,
                            height: _displayHeight,
                            child: _buildCropStage(),
                          ),
                          const Positioned(
                            left: 0,
                            top: 0,
                            child: _CropStatusBar(),
                          ),
                          Positioned(
                            left: 0,
                            top: _displayHeight,
                            width: _displayWidth,
                            height: _bottomBarHeight,
                            child: _CropToolbar(
                              selectedRatio: _ratio,
                              ratioOptions: _ratioOptions,
                              flipped: _flipped,
                              cropping: _cropping,
                              onFlip: _toggleFlip,
                              onRatioSelected: _setRatio,
                              onCancel: () => Navigator.pop(context),
                              onConfirm: _cropping ? null : _confirmCrop,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCropStage() {
    final cropSize = _cropFrameSize(_ratio);
    final offset = _clampOffset(_offset, cropSize, _scale);
    final renderScale = _baseFitScale(cropSize) * _scale;
    final imageSize = Size(
      _imageWidth * renderScale,
      _imageHeight * renderScale,
    );
    final imageLeft = _displayWidth / 2 + offset.dx - imageSize.width / 2;
    final imageTop = _displayHeight / 2 + offset.dy - imageSize.height / 2;
    final cropLeft = (_displayWidth - cropSize.width) / 2;
    final cropTop = (_displayHeight - cropSize.height) / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) => _gestureStartScale = _scale,
      onScaleUpdate: (details) {
        final nextScale = (_gestureStartScale * details.scale)
            .clamp(1.0, 6.0)
            .toDouble();
        setState(() {
          _scale = nextScale;
          _offset = _clampOffset(
            _offset + details.focalPointDelta,
            cropSize,
            nextScale,
          );
        });
      },
      onScaleEnd: (_) {
        setState(() => _offset = _clampOffset(_offset, cropSize, _scale));
      },
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: imageLeft,
              top: imageTop,
              width: imageSize.width,
              height: imageSize.height,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: _TransformedCropImage(
                  bytes: widget.draft.originalImageBytes,
                  flipped: _flipped,
                  width: imageSize.width,
                  height: imageSize.height,
                ),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
            ),
            Positioned(
              left: cropLeft,
              top: cropTop,
              width: cropSize.width,
              height: cropSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Positioned(
                          left: imageLeft - cropLeft,
                          top: imageTop - cropTop,
                          width: imageSize.width,
                          height: imageSize.height,
                          child: _TransformedCropImage(
                            bytes: widget.draft.originalImageBytes,
                            flipped: _flipped,
                            width: imageSize.width,
                            height: imageSize.height,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransformedCropImage extends StatelessWidget {
  final Uint8List bytes;
  final bool flipped;
  final double width;
  final double height;

  const _TransformedCropImage({
    required this.bytes,
    required this.flipped,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(flipped ? -1.0 : 1.0, 1.0, 1.0, 1.0),
      child: Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      ),
    );
  }
}

class _CropStatusBar extends StatelessWidget {
  const _CropStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 390,
      height: 44,
      child: Stack(
        children: const [
          Positioned(
            left: 21,
            top: 15.5,
            width: 54,
            child: Text(
              '9:41',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.28,
                height: 1,
              ),
            ),
          ),
          Positioned(right: 14, top: 14, child: _CropStatusIcons()),
        ],
      ),
    );
  }
}

class _CropStatusIcons extends StatelessWidget {
  const _CropStatusIcons();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 67,
      height: 14,
      child: CustomPaint(painter: _CropStatusIconPainter()),
    );
  }
}

class _CropStatusIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 4; i++) {
      final h = 3.0 + i * 2.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0 + i * 4.3, 11 - h, 3, h),
          const Radius.circular(1),
        ),
        paint,
      );
    }

    final wifiPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final center = const Offset(30, 11);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 9),
      -2.25,
      1.35,
      false,
      wifiPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 6),
      -2.18,
      1.22,
      false,
      wifiPaint,
    );
    canvas.drawCircle(const Offset(30, 10.8), 1.5, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 3, 19, 9),
        const Radius.circular(2),
      ),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47, 5, 14, 5),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(65, 6, 2, 4),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CropToolbar extends StatelessWidget {
  final CropAspectRatio selectedRatio;
  final List<CropAspectRatio> ratioOptions;
  final bool flipped;
  final bool cropping;
  final VoidCallback onFlip;
  final ValueChanged<CropAspectRatio> onRatioSelected;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  const _CropToolbar({
    required this.selectedRatio,
    required this.ratioOptions,
    required this.flipped,
    required this.cropping,
    required this.onFlip,
    required this.onRatioSelected,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 24),
                _ToolButton(
                  label: '翻转',
                  selected: flipped,
                  onTap: onFlip,
                  icon: _FlipIcon(selected: flipped),
                ),
                const SizedBox(width: 33),
                Container(
                  width: 1,
                  height: 12,
                  margin: const EdgeInsets.only(top: 12),
                  color: Colors.black,
                ),
                const SizedBox(width: 32),
                for (var i = 0; i < ratioOptions.length; i++) ...[
                  _ToolButton(
                    label: ratioOptions[i].label,
                    selected: ratioOptions[i] == selectedRatio,
                    onTap: () => onRatioSelected(ratioOptions[i]),
                    icon: _AspectIcon(
                      ratio: ratioOptions[i],
                      selected: ratioOptions[i] == selectedRatio,
                    ),
                  ),
                  if (i < ratioOptions.length - 1) const SizedBox(width: 33),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
          const SizedBox(height: 15),
          SizedBox(
            height: 24,
            child: Stack(
              children: [
                Positioned(
                  left: 24,
                  top: 0,
                  child: GestureDetector(
                    onTap: onCancel,
                    child: const Icon(Icons.close, size: 24),
                  ),
                ),
                Center(
                  child: Text(
                    cropping ? '处理中' : '裁切',
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: _roundFontFamily,
                      fontFamilyFallback: _fontFallbacks,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 0,
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Icon(
                      Icons.check,
                      color: cropping ? Colors.black26 : Colors.black,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: 134,
            height: 5,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget icon;

  const _ToolButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 24,
        height: 36,
        child: Column(
          children: [
            SizedBox(width: 20, height: 20, child: icon),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? const Color(0xFFFF55BE) : Colors.black,
                fontFamily: _roundFontFamily,
                fontFamilyFallback: _fontFallbacks,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlipIcon extends StatelessWidget {
  final bool selected;

  const _FlipIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FlipIconPainter(selected: selected));
  }
}

class _FlipIconPainter extends CustomPainter {
  final bool selected;

  const _FlipIconPainter({required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final color = selected ? const Color(0xFFFF55BE) : Colors.black;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(10, 2.5), const Offset(10, 17.5), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(2, 15)
        ..lineTo(8, 10)
        ..lineTo(8, 20)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(18, 5)
        ..lineTo(12, 10)
        ..lineTo(12, 0)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FlipIconPainter oldDelegate) {
    return oldDelegate.selected != selected;
  }
}

class _AspectIcon extends StatelessWidget {
  final CropAspectRatio ratio;
  final bool selected;

  const _AspectIcon({required this.ratio, required this.selected});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AspectIconPainter(ratio, selected));
  }
}

class _AspectIconPainter extends CustomPainter {
  final CropAspectRatio ratio;
  final bool selected;

  const _AspectIconPainter(this.ratio, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final color = selected ? const Color(0xFFFF55BE) : Colors.black;
    final dimensions = switch (ratio) {
      CropAspectRatio.square => const Size(13.5, 13.5),
      CropAspectRatio.landscape169 => const Size(17, 10),
      CropAspectRatio.landscape43 => const Size(15.69, 12),
      CropAspectRatio.portrait34 => const Size(12, 15.69),
      CropAspectRatio.portrait916 => const Size(10, 17),
      CropAspectRatio.freeform => const Size(14, 14),
    };
    final rect = Rect.fromCenter(
      center: const Offset(10, 10),
      width: dimensions.width,
      height: dimensions.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(1.8));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, stroke);

    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(1.2)),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AspectIconPainter oldDelegate) {
    return oldDelegate.ratio != ratio || oldDelegate.selected != selected;
  }
}
