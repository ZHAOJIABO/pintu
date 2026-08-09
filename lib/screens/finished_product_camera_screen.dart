import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../services/background_removal_service.dart';

const _cameraCancelAsset = 'assets/pin_icon/camera_cancel.svg';
const _cameraShutterAsset = 'assets/pin_icon/camera_shutter.svg';
const _cameraGalleryAsset = 'assets/pin_icon/camera_gallery.svg';
const _cameraRetakeAsset = 'assets/pin_icon/camera_retake.svg';
const _cameraConfirmAsset = 'assets/pin_icon/camera_confirm.svg';
const _cameraCropCornerAsset = 'assets/pin_icon/camera_crop_corner.svg';

/// Figma “记录一下”拍照页。
///
/// 拍摄和图库选择都会将原图交给调用方继续裁切和上传；拍摄后的预览可重来。
///
/// 成品上传暂不执行端侧去背景，避免模拟器和不支持 Vision 的设备在确认
/// 成品时进入无效的处理流程。恢复该能力时，将 [enableBackgroundRemoval] 设为
/// `true` 即可。
class FinishedProductCameraScreen extends StatefulWidget {
  final BackgroundRemovalService backgroundRemovalService;
  final bool enableBackgroundRemoval;

  const FinishedProductCameraScreen({
    super.key,
    this.backgroundRemovalService = const PlatformBackgroundRemovalService(),
    this.enableBackgroundRemoval = false,
  });

  @override
  State<FinishedProductCameraScreen> createState() =>
      _FinishedProductCameraScreenState();
}

class _FinishedProductCameraScreenState
    extends State<FinishedProductCameraScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  CameraController? _cameraController;
  XFile? _capturedPhoto;
  Uint8List? _backgroundRemovedPhoto;
  bool _takingPhoto = false;
  bool _removingBackground = false;
  Object? _cameraError;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
    } catch (error) {
      if (mounted) setState(() => _cameraError = error);
    }
  }

  Future<void> _takeProcessOrSavePhoto() async {
    final capturedPhoto = _capturedPhoto;
    if (capturedPhoto == null) {
      await _takePhoto();
      return;
    }

    if (!widget.enableBackgroundRemoval) {
      Navigator.of(context).pop(await capturedPhoto.readAsBytes());
      return;
    }

    final backgroundRemovedPhoto = _backgroundRemovedPhoto;
    if (backgroundRemovedPhoto != null) {
      Navigator.of(context).pop(backgroundRemovedPhoto);
      return;
    }

    if (_removingBackground) return;
    setState(() => _removingBackground = true);
    try {
      final result = await widget.backgroundRemovalService.removeBackground(
        await capturedPhoto.readAsBytes(),
      );
      if (mounted) setState(() => _backgroundRemovedPhoto = result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('去背景失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _removingBackground = false);
    }
  }

  Future<void> _takePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _takingPhoto) {
      return;
    }

    setState(() => _takingPhoto = true);
    try {
      final photo = await controller.takePicture();
      if (mounted) {
        setState(() {
          _capturedPhoto = photo;
          _backgroundRemovedPhoto = null;
        });
      }
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('拍照失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_takingPhoto) return;
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 95,
      requestFullMetadata: false,
    );
    if (photo != null && mounted) {
      setState(() {
        _capturedPhoto = photo;
        _backgroundRemovedPhoto = null;
      });
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedPhoto = null;
      _backgroundRemovedPhoto = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _CameraBackdrop(
              controller: _cameraController,
              capturedPhoto: _capturedPhoto,
              backgroundRemovedPhoto: _backgroundRemovedPhoto,
              error: _cameraError,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                  stops: [0, .3, .7, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cropSize = (constraints.maxWidth - 60)
                      .clamp(0, 330.0)
                      .toDouble();
                  final cropTop = (constraints.maxHeight * .18)
                      .clamp(104.0, 140.0)
                      .toDouble();
                  return Stack(
                    children: [
                      if (_capturedPhoto == null)
                        Positioned(
                          top: cropTop,
                          left: (constraints.maxWidth - cropSize) / 2,
                          child: Column(
                            children: [
                              _SquareCameraGuide(size: cropSize),
                              const SizedBox(height: 40),
                              const Text(
                                '请将成品置于取景框内',
                                style: TextStyle(
                                  color: Color(0x99FFFFFF),
                                  fontFamily: 'Alimama FangYuanTi VF',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 48,
                        child: _CameraControls(
                          hasCapturedPhoto: _capturedPhoto != null,
                          hasRemovedBackground:
                              widget.enableBackgroundRemoval &&
                              _backgroundRemovedPhoto != null,
                          backgroundRemovalEnabled:
                              widget.enableBackgroundRemoval,
                          takingPhoto: _takingPhoto,
                          removingBackground: _removingBackground,
                          onCancel: () => Navigator.of(context).pop(),
                          onShutter: _takeProcessOrSavePhoto,
                          onGallery: _pickFromGallery,
                          onRetake: _retakePhoto,
                        ),
                      ),
                      if (_removingBackground)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraBackdrop extends StatelessWidget {
  final CameraController? controller;
  final XFile? capturedPhoto;
  final Uint8List? backgroundRemovedPhoto;
  final Object? error;

  const _CameraBackdrop({
    required this.controller,
    required this.capturedPhoto,
    required this.backgroundRemovedPhoto,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final processedPhoto = backgroundRemovedPhoto;
    if (processedPhoto != null) {
      return Image.memory(processedPhoto, fit: BoxFit.contain);
    }

    final photo = capturedPhoto;
    if (photo != null) {
      return Image.file(File(photo.path), fit: BoxFit.contain);
    }

    final activeController = controller;
    if (activeController != null && activeController.value.isInitialized) {
      return _CoverCameraPreview(controller: activeController);
    }

    if (error != null) {
      return const Center(
        child: Text('无法打开相机，请检查权限后重试', style: TextStyle(color: Colors.white)),
      );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class _CoverCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _CoverCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewAspectRatio = controller.value.aspectRatio;
        final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;
        final scale = previewAspectRatio / screenAspectRatio;
        return ClipRect(
          child: Transform.scale(
            scale: scale < 1 ? 1 / scale : scale,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}

class _SquareCameraGuide extends StatelessWidget {
  final double size;

  const _SquareCameraGuide({required this.size});

  @override
  Widget build(BuildContext context) {
    const cornerSize = 36.0;
    Widget corner(Widget child, Alignment alignment) {
      return Align(
        alignment: alignment,
        child: SizedBox.square(dimension: cornerSize, child: child),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          corner(SvgPicture.asset(_cameraCropCornerAsset), Alignment.topLeft),
          corner(
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(-1, 1, 1),
              child: SvgPicture.asset(_cameraCropCornerAsset),
            ),
            Alignment.topRight,
          ),
          corner(
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(1, -1, 1),
              child: SvgPicture.asset(_cameraCropCornerAsset),
            ),
            Alignment.bottomLeft,
          ),
          corner(
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(-1, -1, 1),
              child: SvgPicture.asset(_cameraCropCornerAsset),
            ),
            Alignment.bottomRight,
          ),
        ],
      ),
    );
  }
}

class _CameraControls extends StatelessWidget {
  final bool hasCapturedPhoto;
  final bool hasRemovedBackground;
  final bool backgroundRemovalEnabled;
  final bool takingPhoto;
  final bool removingBackground;
  final VoidCallback onCancel;
  final VoidCallback onShutter;
  final VoidCallback onGallery;
  final VoidCallback onRetake;

  const _CameraControls({
    required this.hasCapturedPhoto,
    required this.hasRemovedBackground,
    required this.backgroundRemovalEnabled,
    required this.takingPhoto,
    required this.removingBackground,
    required this.onCancel,
    required this.onShutter,
    required this.onGallery,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CameraActionButton(
          asset: hasCapturedPhoto ? _cameraRetakeAsset : _cameraCancelAsset,
          semanticLabel: hasCapturedPhoto ? '重来' : '取消',
          onTap: hasCapturedPhoto ? onRetake : onCancel,
          iconSize: hasCapturedPhoto
              ? const Size(18.4, 19.2)
              : const Size.square(31.635),
        ),
        const SizedBox(width: 56),
        Semantics(
          button: true,
          label: hasRemovedBackground
              ? '保存成品'
              : (hasCapturedPhoto
                    ? (backgroundRemovalEnabled ? '去背景' : '保存成品')
                    : '拍照'),
          child: GestureDetector(
            onTap: takingPhoto || removingBackground ? null : onShutter,
            child: SizedBox.square(
              dimension: 84,
              child: SvgPicture.asset(
                hasCapturedPhoto ? _cameraConfirmAsset : _cameraShutterAsset,
              ),
            ),
          ),
        ),
        const SizedBox(width: 56),
        _CameraActionButton(
          asset: _cameraGalleryAsset,
          semanticLabel: '图库',
          onTap: onGallery,
          iconSize: const Size.square(26.813),
        ),
      ],
    );
  }
}

class _CameraActionButton extends StatelessWidget {
  final String asset;
  final String semanticLabel;
  final VoidCallback onTap;
  final Size iconSize;

  const _CameraActionButton({
    required this.asset,
    required this.semanticLabel,
    required this.onTap,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 48,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0x66000000),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox.square(
                dimension: 26,
                child: ClipRect(
                  child: Center(
                    child: SizedBox(
                      width: iconSize.width,
                      height: iconSize.height,
                      child: SvgPicture.asset(asset),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
