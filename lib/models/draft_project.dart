import 'dart:convert';
import 'dart:typed_data';

import 'color_limit.dart';
import 'product_template.dart';

class DraftProject {
  final Uint8List originalImageBytes;
  final Uint8List? croppedImageBytes;
  final CropAspectRatio cropAspectRatio;
  final ProductTemplate? selectedTemplate;
  final int? customBeadWidth;
  final int? customBeadHeight;
  final String? paletteBrandId;
  final ColorLimit colorLimit;
  final bool smoothingEnabled;

  const DraftProject({
    required this.originalImageBytes,
    this.croppedImageBytes,
    this.cropAspectRatio = CropAspectRatio.square,
    this.selectedTemplate,
    this.customBeadWidth,
    this.customBeadHeight,
    this.paletteBrandId,
    this.colorLimit = ColorLimit.sixteen,
    this.smoothingEnabled = true,
  });

  Uint8List get imageForGeneration => croppedImageBytes ?? originalImageBytes;

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
    CropAspectRatio? cropAspectRatio,
    ProductTemplate? selectedTemplate,
    int? customBeadWidth,
    int? customBeadHeight,
    String? paletteBrandId,
    ColorLimit? colorLimit,
    bool? smoothingEnabled,
  }) {
    return DraftProject(
      originalImageBytes: originalImageBytes ?? this.originalImageBytes,
      croppedImageBytes: croppedImageBytes ?? this.croppedImageBytes,
      cropAspectRatio: cropAspectRatio ?? this.cropAspectRatio,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      customBeadWidth: customBeadWidth ?? this.customBeadWidth,
      customBeadHeight: customBeadHeight ?? this.customBeadHeight,
      paletteBrandId: paletteBrandId ?? this.paletteBrandId,
      colorLimit: colorLimit ?? this.colorLimit,
      smoothingEnabled: smoothingEnabled ?? this.smoothingEnabled,
    );
  }

  Map<String, Object?> toJson({bool includeImages = false}) => {
    if (includeImages) 'originalImageBytes': base64Encode(originalImageBytes),
    if (includeImages && croppedImageBytes != null)
      'croppedImageBytes': base64Encode(croppedImageBytes!),
    'cropAspectRatio': cropAspectRatio.name,
    'selectedTemplate': effectiveTemplate.toJson(),
    'customBeadWidth': customBeadWidth,
    'customBeadHeight': customBeadHeight,
    'paletteBrandId': paletteBrandId,
    'colorLimit': colorLimit.name,
    'smoothingEnabled': smoothingEnabled,
  };
}
