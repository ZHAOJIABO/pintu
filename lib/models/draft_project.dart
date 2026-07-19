import 'dart:convert';
import 'dart:typed_data';

import 'color_limit.dart';
import 'product_template.dart';

enum DraftImageSource {
  photo('照片'),
  illustration('插画');

  final String label;

  const DraftImageSource(this.label);
}

class DraftProject {
  final Uint8List originalImageBytes;
  final Uint8List? croppedImageBytes;
  final Uint8List? styledImageBytes;
  final DraftImageSource imageSource;
  final CropAspectRatio cropAspectRatio;
  final ProductTemplate? selectedTemplate;
  final int? customBeadWidth;
  final int? customBeadHeight;
  final String? paletteBrandId;
  final ColorLimit colorLimit;
  final bool smoothingEnabled;
  final bool removeBackground;

  const DraftProject({
    required this.originalImageBytes,
    this.croppedImageBytes,
    this.styledImageBytes,
    this.imageSource = DraftImageSource.photo,
    this.cropAspectRatio = CropAspectRatio.square,
    this.selectedTemplate,
    this.customBeadWidth,
    this.customBeadHeight,
    this.paletteBrandId,
    this.colorLimit = ColorLimit.unlimited,
    this.smoothingEnabled = true,
    this.removeBackground = true,
  });

  Uint8List get imageForGeneration =>
      styledImageBytes ?? croppedImageBytes ?? originalImageBytes;

  ProductTemplate get effectiveTemplate =>
      selectedTemplate ?? ProductTemplateCatalog.defaultTemplate;

  int get targetWidth => selectedTemplate?.custom == true
      ? customBeadWidth ?? effectiveTemplate.beadWidth
      : effectiveTemplate.beadWidth;

  int get targetHeight => selectedTemplate?.custom == true
      ? customBeadHeight ?? effectiveTemplate.beadHeight
      : effectiveTemplate.beadHeight;

  bool get hasValidCustomSize {
    if (selectedTemplate?.custom != true) return true;
    final width = customBeadWidth;
    final height = customBeadHeight;
    if (width == null || height == null) return false;
    return ProductTemplateCatalog.isValidCustomDimension(width) &&
        ProductTemplateCatalog.isValidCustomDimension(height);
  }

  bool get canChooseColors => croppedImageBytes != null && hasValidCustomSize;

  bool get canGenerate =>
      canChooseColors && paletteBrandId != null && paletteBrandId!.isNotEmpty;

  DraftProject copyWith({
    Uint8List? originalImageBytes,
    Uint8List? croppedImageBytes,
    Uint8List? styledImageBytes,
    DraftImageSource? imageSource,
    CropAspectRatio? cropAspectRatio,
    ProductTemplate? selectedTemplate,
    int? customBeadWidth,
    int? customBeadHeight,
    String? paletteBrandId,
    ColorLimit? colorLimit,
    bool? smoothingEnabled,
    bool? removeBackground,
  }) {
    return DraftProject(
      originalImageBytes: originalImageBytes ?? this.originalImageBytes,
      croppedImageBytes: croppedImageBytes ?? this.croppedImageBytes,
      styledImageBytes: styledImageBytes ?? this.styledImageBytes,
      imageSource: imageSource ?? this.imageSource,
      cropAspectRatio: cropAspectRatio ?? this.cropAspectRatio,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      customBeadWidth: customBeadWidth ?? this.customBeadWidth,
      customBeadHeight: customBeadHeight ?? this.customBeadHeight,
      paletteBrandId: paletteBrandId ?? this.paletteBrandId,
      colorLimit: colorLimit ?? this.colorLimit,
      smoothingEnabled: smoothingEnabled ?? this.smoothingEnabled,
      removeBackground: removeBackground ?? this.removeBackground,
    );
  }

  Map<String, Object?> toJson({bool includeImages = false}) => {
    if (includeImages) 'originalImageBytes': base64Encode(originalImageBytes),
    if (includeImages && croppedImageBytes != null)
      'croppedImageBytes': base64Encode(croppedImageBytes!),
    if (includeImages && styledImageBytes != null)
      'styledImageBytes': base64Encode(styledImageBytes!),
    'imageSource': imageSource.name,
    'cropAspectRatio': cropAspectRatio.name,
    'selectedTemplate': effectiveTemplate.toJson(),
    'customBeadWidth': customBeadWidth,
    'customBeadHeight': customBeadHeight,
    'paletteBrandId': paletteBrandId,
    'colorLimit': colorLimit.name,
    'smoothingEnabled': smoothingEnabled,
    'removeBackground': removeBackground,
  };
}
