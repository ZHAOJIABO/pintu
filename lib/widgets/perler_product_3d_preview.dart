import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/perler_product_finish.dart';
import '../rendering/perler_product_3d_painter.dart';

/// A touch-driven 3D product preview with fused front and un-ironed back.
class PerlerProduct3dPreview extends StatefulWidget {
  final Uint8List pixels;
  final int imageWidth;
  final int imageHeight;
  final PerlerProductFinish finish;

  const PerlerProduct3dPreview({
    super.key,
    required this.pixels,
    required this.imageWidth,
    required this.imageHeight,
    required this.finish,
  });

  @override
  State<PerlerProduct3dPreview> createState() => _PerlerProduct3dPreviewState();
}

class _PerlerProduct3dPreviewState extends State<PerlerProduct3dPreview> {
  static const _initialYaw = -0.28;
  static const _initialPitch = 0.16;
  double _yaw = _initialYaw;
  double _pitch = _initialPitch;
  ui.Image? _finishTexture;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFinishTexture());
  }

  @override
  void didUpdateWidget(covariant PerlerProduct3dPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.finish != widget.finish) {
      _finishTexture?.dispose();
      _finishTexture = null;
      unawaited(_loadFinishTexture());
    }
  }

  Future<void> _loadFinishTexture() async {
    final finish = widget.finish;
    final textureAsset = _textureAssetFor(finish);
    if (textureAsset == null) return;
    final bytes = await rootBundle.load(textureAsset);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;
    if (!mounted || widget.finish != finish) {
      image.dispose();
      return;
    }
    setState(() => _finishTexture = image);
  }

  String? _textureAssetFor(PerlerProductFinish finish) => switch (finish) {
    PerlerProductFinish.bathTowel =>
      'assets/textures/bath_towel_ironed_face.jpg',
    PerlerProductFinish.linen => 'assets/textures/linen_ironed_face.jpg',
    _ => null,
  };

  @override
  void dispose() {
    _finishTexture?.dispose();
    super.dispose();
  }

  void _rotate(DragUpdateDetails details) {
    setState(() {
      _yaw += details.delta.dx * 0.012;
      _pitch = (_pitch + details.delta.dy * 0.008).clamp(-0.72, 0.72);
    });
  }

  void _reset() => setState(() {
    _yaw = _initialYaw;
    _pitch = _initialPitch;
  });

  @override
  Widget build(BuildContext context) {
    final nativeSceneKit =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Semantics(
      label: '可旋转的拼豆三维成品预览，拖动查看正面和背面',
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (nativeSceneKit)
            UiKitView(
              key: ValueKey(
                'result-finished-product-native-3d-${widget.imageWidth}x${widget.imageHeight}',
              ),
              viewType: 'bobobeads/perler_product_3d',
              layoutDirection: Directionality.of(context),
              creationParams: {
                'pixels': widget.pixels,
                'width': widget.imageWidth,
                'height': widget.imageHeight,
                'finish': widget.finish.name,
              },
              creationParamsCodec: const StandardMessageCodec(),
            )
          else
            GestureDetector(
              key: const ValueKey('result-finished-product-3d-preview'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: _rotate,
              onDoubleTap: _reset,
              child: CustomPaint(
                key: const ValueKey('result-finished-product-3d-canvas'),
                painter: PerlerProduct3dPainter(
                  pixels: widget.pixels,
                  imageWidth: widget.imageWidth,
                  imageHeight: widget.imageHeight,
                  yaw: _yaw,
                  pitch: _pitch,
                  finish: widget.finish,
                  finishTexture: _finishTexture,
                ),
              ),
            ),
          const IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _RotationHint(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RotationHint extends StatelessWidget {
  const _RotationHint();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB20E1721),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '拖动查看正反面 · 双击复位',
          style: TextStyle(color: Colors.white, fontSize: 10, height: 1.2),
        ),
      ),
    );
  }
}
