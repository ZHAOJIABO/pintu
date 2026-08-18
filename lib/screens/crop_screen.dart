import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/draft_project.dart';
import '../models/product_template.dart';
import '../services/crop_service.dart';
import 'parameter_config_screen.dart';
import 'style_conversion_screen.dart';

const _roundFontFamily = 'Alimama FangYuanTi VF';
const _fontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _accentColor = Color(0xFFFF55BE);

class CropScreen extends StatefulWidget {
  final DraftProject draft;
  final bool returnCroppedImage;
  final List<CropAspectRatio>? ratioOptions;
  final String? cropHint;

  const CropScreen({
    super.key,
    required this.draft,
    this.returnCroppedImage = false,
    this.ratioOptions,
    this.cropHint,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen>
    with SingleTickerProviderStateMixin {
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
  CropAspectRatio? _ratio;
  bool _cropping = false;
  bool _flipped = false;
  double _imageScale = 1;
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;
  Offset _offset = Offset.zero;
  int _imageWidth = 1;
  int _imageHeight = 1;
  double _maxFixedMinImageScale = 0;
  Color _backgroundColor = const Color(0xFF478EA1);
  late final AnimationController _reboundController;
  double _reboundStartScale = 1;
  double _reboundTargetScale = 1;
  Offset _reboundStartOffset = Offset.zero;
  Offset _reboundTargetOffset = Offset.zero;

  List<CropAspectRatio> get _availableRatioOptions =>
      widget.ratioOptions ?? _ratioOptions;

  @override
  void initState() {
    super.initState();
    _reboundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(_handleReboundTick);
    _inspectImage();
  }

  @override
  void dispose() {
    _reboundController.dispose();
    super.dispose();
  }

  void _inspectImage() {
    final decoded = img.decodeImage(widget.draft.originalImageBytes);
    if (decoded == null) return;
    _imageWidth = decoded.width;
    _imageHeight = decoded.height;
    _backgroundColor = _averageColor(decoded);
    _maxFixedMinImageScale = _availableRatioOptions
        .map((ratio) => _minImageScale(_cropFrameSize(ratio)))
        .fold(0.0, math.max);
    _freeformCropRect = _initialFreeformCropRect();
    _imageScale = _minImageScale(_cropFrameRect().size);
    _offset = _clampOffset(Offset.zero, _cropFrameRect().size, _imageScale);
  }

  void _handleReboundTick() {
    final t = Curves.easeOutCubic.transform(_reboundController.value);
    setState(() {
      _imageScale =
          ui.lerpDouble(_reboundStartScale, _reboundTargetScale, t) ??
          _reboundTargetScale;
      _offset =
          Offset.lerp(_reboundStartOffset, _reboundTargetOffset, t) ??
          _reboundTargetOffset;
    });
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

  static const _cropFrameInset = 30.0;
  static const _minFreeformCropSize = 128.0;

  Rect _freeformCropRect = const Rect.fromLTWH(30, 188, 330, 330);

  Rect get _cropStageBounds => Rect.fromLTWH(
    _cropFrameInset,
    _cropFrameInset,
    _displayWidth - _cropFrameInset * 2,
    _displayHeight - _cropFrameInset * 2,
  );

  Rect _initialFreeformCropRect() {
    final bounds = _cropStageBounds;
    final size = applyBoxFit(
      BoxFit.contain,
      Size(_imageWidth.toDouble(), _imageHeight.toDouble()),
      bounds.size,
    ).destination;
    return Rect.fromCenter(
      center: bounds.center,
      width: size.width,
      height: size.height,
    );
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

  Rect _fixedCropFrameRect(CropAspectRatio ratio) {
    final size = _cropFrameSize(ratio);
    return Rect.fromCenter(
      center: const Offset(_displayWidth / 2, _displayHeight / 2),
      width: size.width,
      height: size.height,
    );
  }

  Rect _cropFrameRect() {
    final ratio = _ratio;
    return ratio == null ? _freeformCropRect : _fixedCropFrameRect(ratio);
  }

  double _minImageScale(Size cropSize) {
    return math.max(
      cropSize.width / _imageWidth,
      cropSize.height / _imageHeight,
    );
  }

  double _maxImageScale(Size cropSize) {
    final largestRequiredScale = math.max(
      _maxFixedMinImageScale,
      math.max(
        _minImageScale(_freeformCropRect.size),
        _minImageScale(cropSize),
      ),
    );
    return largestRequiredScale * 8;
  }

  double _clampImageScale(
    double candidate,
    Size cropSize, {
    bool allowRubberBand = false,
  }) {
    final minScale = _minImageScale(cropSize);
    final maxScale = _maxImageScale(cropSize);
    final minLimit = allowRubberBand ? minScale * 0.86 : minScale;
    final maxLimit = allowRubberBand ? maxScale * 1.03 : maxScale;
    return candidate.clamp(minLimit, maxLimit).toDouble();
  }

  Offset _clampOffset(Offset candidate, Size cropSize, double scale) {
    final renderedWidth = _imageWidth * scale;
    final renderedHeight = _imageHeight * scale;
    final maxX = math.max(0.0, (renderedWidth - cropSize.width) / 2);
    final maxY = math.max(0.0, (renderedHeight - cropSize.height) / 2);
    return Offset(
      candidate.dx.clamp(-maxX, maxX).toDouble(),
      candidate.dy.clamp(-maxY, maxY).toDouble(),
    );
  }

  void _settleImageTransform({bool animate = true}) {
    final cropSize = _cropFrameRect().size;
    final targetScale = _clampImageScale(_imageScale, cropSize);
    final targetOffset = _clampOffset(_offset, cropSize, targetScale);
    final alreadySettled =
        (targetScale - _imageScale).abs() < 0.001 &&
        (targetOffset - _offset).distance < 0.001;

    if (alreadySettled) return;

    if (!animate) {
      setState(() {
        _imageScale = targetScale;
        _offset = targetOffset;
      });
      return;
    }

    _reboundStartScale = _imageScale;
    _reboundTargetScale = targetScale;
    _reboundStartOffset = _offset;
    _reboundTargetOffset = targetOffset;
    _reboundController.forward(from: 0);
  }

  Offset _stageFocalPoint(Offset localFocalPoint) {
    return localFocalPoint -
        const Offset(_displayWidth / 2, _displayHeight / 2);
  }

  void _setRatio(CropAspectRatio ratio) {
    _reboundController.stop();
    setState(() {
      if (_ratio == ratio) {
        _ratio = null;
      } else {
        _ratio = ratio;
        _freeformCropRect = _fixedCropFrameRect(ratio);
      }
    });
    _settleImageTransform();
  }

  void _startCropResize() {
    _reboundController.stop();
  }

  void _updateCropResize(_CropHandle handle, Offset delta) {
    final start = _freeformCropRect;

    final bounds = _cropStageBounds;
    var left = start.left;
    var top = start.top;
    var right = start.right;
    var bottom = start.bottom;

    if (handle.movesLeft) {
      left = (start.left + delta.dx)
          .clamp(bounds.left, start.right - _minFreeformCropSize)
          .toDouble();
    }
    if (handle.movesRight) {
      right = (start.right + delta.dx)
          .clamp(start.left + _minFreeformCropSize, bounds.right)
          .toDouble();
    }
    if (handle.movesTop) {
      top = (start.top + delta.dy)
          .clamp(bounds.top, start.bottom - _minFreeformCropSize)
          .toDouble();
    }
    if (handle.movesBottom) {
      bottom = (start.bottom + delta.dy)
          .clamp(start.top + _minFreeformCropSize, bounds.bottom)
          .toDouble();
    }

    final nextRect = Rect.fromLTRB(left, top, right, bottom);
    final nextScale = _clampImageScale(_imageScale, nextRect.size);
    setState(() {
      _freeformCropRect = nextRect;
      _imageScale = nextScale;
      _offset = _clampOffset(_offset, nextRect.size, nextScale);
    });
  }

  void _endCropResize() {
    _settleImageTransform();
  }

  void _toggleFlip() {
    setState(() => _flipped = !_flipped);
  }

  Future<void> _confirmCrop() async {
    final cropRect = _cropFrameRect();
    final cropSize = cropRect.size;
    final renderScale = _clampImageScale(_imageScale, cropSize);
    final offset = _clampOffset(_offset, cropSize, renderScale);
    final cropCenterOffset =
        cropRect.center - const Offset(_displayWidth / 2, _displayHeight / 2);

    setState(() => _cropping = true);
    try {
      final cropped = await _cropService.cropToAspectRatioWithTransform(
        widget.draft.originalImageBytes,
        _ratio ?? CropAspectRatio.freeform,
        renderScale: renderScale,
        displayOffsetX: offset.dx - cropCenterOffset.dx,
        displayOffsetY: offset.dy - cropCenterOffset.dy,
        cropDisplayWidth: cropSize.width,
        cropDisplayHeight: cropSize.height,
        flipped: _flipped,
      );
      if (!mounted) return;
      if (widget.returnCroppedImage) {
        Navigator.of(context).pop(cropped);
        return;
      }
      final nextDraft = widget.draft.copyWith(
        croppedImageBytes: cropped,
        cropAspectRatio: _ratio ?? CropAspectRatio.freeform,
      );
      final nextScreen = nextDraft.imageSource == DraftImageSource.photo
          ? StyleConversionScreen(draft: nextDraft)
          : ParameterConfigScreen(draft: nextDraft);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
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
          final widthScale =
              math.min(constraints.maxWidth, 430.0) / _displayWidth;
          final heightScale = constraints.maxHeight / 844;
          final scale = math.min(widthScale, heightScale);
          final pageWidth = _displayWidth * scale;
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
                          Positioned(
                            left: 0,
                            top: _displayHeight,
                            width: _displayWidth,
                            height: _bottomBarHeight,
                            child: _CropToolbar(
                              selectedRatio: _ratio,
                              ratioOptions: _availableRatioOptions,
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
    final cropRect = _cropFrameRect();
    final cropSize = cropRect.size;
    final renderScale = _imageScale;
    final offset = _clampOffset(_offset, cropSize, renderScale);
    final imageSize = Size(
      _imageWidth * renderScale,
      _imageHeight * renderScale,
    );
    final imageLeft = _displayWidth / 2 + offset.dx - imageSize.width / 2;
    final imageTop = _displayHeight / 2 + offset.dy - imageSize.height / 2;
    final cropLeft = cropRect.left;
    final cropTop = cropRect.top;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        _reboundController.stop();
        _gestureStartScale = _imageScale;
        _gestureStartOffset = _offset;
        _gestureStartFocal = _stageFocalPoint(details.localFocalPoint);
      },
      onScaleUpdate: (details) {
        final nextScale = _clampImageScale(
          _gestureStartScale * details.scale,
          cropSize,
          allowRubberBand: true,
        );
        final focal = _stageFocalPoint(details.localFocalPoint);
        final scaleDelta = nextScale / _gestureStartScale;
        final nextOffset =
            focal - (_gestureStartFocal - _gestureStartOffset) * scaleDelta;
        setState(() {
          _imageScale = nextScale;
          _offset = _clampOffset(nextOffset, cropSize, nextScale);
        });
      },
      onScaleEnd: (_) => _settleImageTransform(),
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
                  if (_ratio == null) ...[
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                          child: CustomPaint(painter: _CropGridPainter()),
                        ),
                      ),
                    ),
                    for (final handle in _CropHandle.values)
                      _FreeformCropHandle(
                        handle: handle,
                        onStart: _startCropResize,
                        onUpdate: (delta) => _updateCropResize(handle, delta),
                        onEnd: _endCropResize,
                      ),
                  ],
                  if (widget.cropHint case final hint? when hint.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: _roundFontFamily,
                                fontFamilyFallback: _fontFallbacks,
                                fontSize: 13,
                              ),
                            ),
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

enum _CropHandle {
  topLeft(movesLeft: true, movesTop: true, alignment: Alignment.topLeft),
  top(movesTop: true, alignment: Alignment.topCenter),
  topRight(movesRight: true, movesTop: true, alignment: Alignment.topRight),
  right(movesRight: true, alignment: Alignment.centerRight),
  bottomRight(
    movesRight: true,
    movesBottom: true,
    alignment: Alignment.bottomRight,
  ),
  bottom(movesBottom: true, alignment: Alignment.bottomCenter),
  bottomLeft(
    movesLeft: true,
    movesBottom: true,
    alignment: Alignment.bottomLeft,
  ),
  left(movesLeft: true, alignment: Alignment.centerLeft);

  final bool movesLeft;
  final bool movesRight;
  final bool movesTop;
  final bool movesBottom;
  final Alignment alignment;

  const _CropHandle({
    this.movesLeft = false,
    this.movesRight = false,
    this.movesTop = false,
    this.movesBottom = false,
    required this.alignment,
  });
}

class _FreeformCropHandle extends StatelessWidget {
  final _CropHandle handle;
  final VoidCallback onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  const _FreeformCropHandle({
    required this.handle,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: handle.alignment,
      child: Transform.translate(
        offset: Offset(
          handle.movesLeft
              ? -28
              : handle.movesRight
              ? 28
              : 0,
          handle.movesTop
              ? -28
              : handle.movesBottom
              ? 28
              : 0,
        ),
        child: GestureDetector(
          key: ValueKey('crop-handle-${handle.name}'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onStart(),
          onPanUpdate: (details) => onUpdate(details.delta),
          onPanEnd: (_) => onEnd(),
          onPanCancel: onEnd,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Container(
                width: handle.movesLeft || handle.movesRight
                    ? (handle.movesTop || handle.movesBottom ? 15 : 22)
                    : 22,
                height: handle.movesTop || handle.movesBottom
                    ? (handle.movesLeft || handle.movesRight ? 15 : 22)
                    : 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _accentColor, width: 2),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x59000000), blurRadius: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CropGridPainter extends CustomPainter {
  const _CropGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (final fraction in [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(size.width * fraction, 0),
        Offset(size.width * fraction, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * fraction),
        Offset(size.width, size.height * fraction),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropGridPainter oldDelegate) => false;
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

class _CropToolbar extends StatelessWidget {
  final CropAspectRatio? selectedRatio;
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
                      fontWeight: FontWeight.w500,
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
            SizedBox(
              width: 24,
              height: 14,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
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
    final sx = size.width / 20;
    final sy = size.height / 20;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(8.6 * sx, 2.3 * sy, 11.4 * sx, 17.7 * sy),
        Radius.circular(1.4 * sx),
      ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(2.4 * sx, 15.2 * sy)
        ..lineTo(6.9 * sx, 5.0 * sy)
        ..lineTo(6.9 * sx, 15.2 * sy)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(13.1 * sx, 5.0 * sy)
        ..lineTo(17.6 * sx, 15.2 * sy)
        ..lineTo(13.1 * sx, 15.2 * sy)
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
