import 'dart:collection';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../algorithms/color_reducer.dart';
import '../algorithms/matching.dart';
import '../models/color.dart';
import '../models/draft_project.dart';
import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../models/product_template.dart';

/// Parameters for turning an existing bead chart image into a pattern.
///
/// The grid is assumed to fill the whole image: administrators crop the rulers
/// and the legend away before uploading, so cell pitch follows directly from
/// [cols] and [rows]. The inset fields only exist to salvage a crop that is off
/// by a few pixels.
class ChartImportRequest {
  final Uint8List imageBytes;
  final int cols;
  final int rows;
  final List<Palette> palettes;
  final Matching matching;
  final double cellInsetRatio;
  final double confidenceThreshold;
  final bool treatWhiteAsEmpty;
  final int maxSamplesPerAxis;
  final int left;
  final int top;
  final int right;
  final int bottom;
  final String paletteBrandId;

  ChartImportRequest({
    required this.imageBytes,
    required this.cols,
    required this.rows,
    required this.palettes,
    Matching? matching,
    this.cellInsetRatio = ChartImportService.defaultCellInsetRatio,
    this.confidenceThreshold = ChartImportService.defaultConfidenceThreshold,
    this.treatWhiteAsEmpty = false,
    this.maxSamplesPerAxis = ChartImportService.defaultMaxSamplesPerAxis,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.paletteBrandId = 'mard221',
  }) : matching = matching ?? CIE2000Matching();
}

/// A cell whose sampled colour was not clearly dominant.
class ChartCellSample {
  final int col;
  final int row;
  final int r;
  final int g;
  final int b;
  final int a;
  final int sampled;
  final int modeCount;

  const ChartCellSample({
    required this.col,
    required this.row,
    required this.r,
    required this.g,
    required this.b,
    required this.a,
    required this.sampled,
    required this.modeCount,
  });

  double get confidence => sampled == 0 ? 0 : modeCount / sampled;
}

/// One distinct colour found in the chart and the palette entry it snapped to.
class ChartColorMapping {
  final int r;
  final int g;
  final int b;
  final PaletteEntry entry;
  final double delta;
  final int cellCount;

  const ChartColorMapping({
    required this.r,
    required this.g,
    required this.b,
    required this.entry,
    required this.delta,
    required this.cellCount,
  });
}

class ChartImportResult {
  final GeneratedPattern pattern;
  final List<ChartColorMapping> mappings;
  final List<ChartCellSample> lowConfidenceCells;
  final List<String> warnings;
  final int sourceWidth;
  final int sourceHeight;
  final double cellPitchX;
  final double cellPitchY;

  const ChartImportResult({
    required this.pattern,
    required this.mappings,
    required this.lowConfidenceCells,
    required this.warnings,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.cellPitchX,
    required this.cellPitchY,
  });
}

class ChartImportService {
  static const double defaultCellInsetRatio = 0.30;
  static const double defaultConfidenceThreshold = 0.6;
  static const int defaultMaxSamplesPerAxis = 16;
  static const double maxCellInsetRatio = 0.45;

  /// Above this CIE2000 distance the chart uses a colour the palette lacks.
  static const double paletteDeltaWarning = 10.0;

  /// Below this cell pitch there are too few pixels left to sample reliably.
  static const double minUsableCellPitch = 4.0;

  /// Cells smaller than this after insetting fall back to a single centre pixel.
  static const int _minInnerSpan = 3;

  const ChartImportService();

  ChartImportResult import(ChartImportRequest request) {
    _validate(request);

    final decoded = img.decodeImage(request.imageBytes);
    if (decoded == null) {
      throw ArgumentError('无法解码这张图片，请确认是 PNG/JPEG 等常见格式。');
    }

    final sourceWidth = decoded.width;
    final sourceHeight = decoded.height;
    final gridWidth = sourceWidth - request.left - request.right;
    final gridHeight = sourceHeight - request.top - request.bottom;
    if (gridWidth < request.cols || gridHeight < request.rows) {
      throw ArgumentError(
        '网格区域 ${gridWidth}x$gridHeight 像素放不下 ${request.cols}x${request.rows} 个格子。',
      );
    }

    final rgba = decoded.getBytes(order: img.ChannelOrder.rgba);
    final pitchX = gridWidth / request.cols;
    final pitchY = gridHeight / request.rows;

    final pixels = Uint8List(request.cols * request.rows * 4);
    final lowConfidenceCells = <ChartCellSample>[];
    final entryCache = <int, PaletteEntry>{};
    final deltaCache = <int, double>{};
    final cellCounts = <int, int>{};

    for (var row = 0; row < request.rows; row++) {
      for (var col = 0; col < request.cols; col++) {
        final sample = _sampleCell(
          rgba: rgba,
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          col: col,
          row: row,
          originX: request.left + col * pitchX,
          originY: request.top + row * pitchY,
          pitchX: pitchX,
          pitchY: pitchY,
          insetRatio: request.cellInsetRatio,
          maxSamplesPerAxis: request.maxSamplesPerAxis,
        );

        if (sample.confidence < request.confidenceThreshold) {
          lowConfidenceCells.add(sample);
        }

        // A fully transparent cell carries no colour to snap, and pure white is
        // background rather than a bead whenever the caller says so.
        final isEmpty =
            sample.a == 0 ||
            (request.treatWhiteAsEmpty &&
                sample.r == 255 &&
                sample.g == 255 &&
                sample.b == 255);
        if (isEmpty) continue;

        final key = _colorKey(sample.r, sample.g, sample.b);
        var entry = entryCache[key];
        if (entry == null) {
          final sampled = BeadColor.fromInt(sample.r, sample.g, sample.b, 255);
          entry = getClosestPaletteEntry(
            request.palettes,
            sampled,
            request.matching,
          );
          entryCache[key] = entry;
          deltaCache[key] = request.matching.delta(entry.color, sampled);
        }
        cellCounts[key] = (cellCounts[key] ?? 0) + 1;

        // The exact palette RGBA is mandatory: computeUsage and
        // PatternData.fromGeneratedPattern both recover the bead code by exact
        // RGBA equality, so an approximate colour would lose the bead code.
        final offset = (row * request.cols + col) * 4;
        pixels[offset] = entry.color.rInt;
        pixels[offset + 1] = entry.color.gInt;
        pixels[offset + 2] = entry.color.bInt;
        pixels[offset + 3] = entry.color.aInt;
      }
    }

    final mappings =
        cellCounts.entries
            .map(
              (item) => ChartColorMapping(
                r: _keyRed(item.key),
                g: _keyGreen(item.key),
                b: _keyBlue(item.key),
                entry: entryCache[item.key]!,
                delta: deltaCache[item.key]!,
                cellCount: item.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.cellCount.compareTo(a.cellCount));

    if (mappings.isEmpty) {
      throw ArgumentError('没有识别出任何豆子颜色，请检查行列数和「白色格视为空」设置。');
    }

    final pattern = GeneratedPattern(
      pixels: pixels,
      width: request.cols,
      height: request.rows,
      usage: computeUsage(pixels, request.cols, request.rows, request.palettes),
      // Only the entries actually used, mirroring the constrained palette the
      // generated flow stores, so the published payload stays lean. Distinct
      // source colours can snap to the same entry, hence the dedupe.
      paletteEntries: LinkedHashSet<PaletteEntry>.from(
        mappings.map((mapping) => mapping.entry),
      ).toList(),
      draft: DraftProject(
        originalImageBytes: request.imageBytes,
        croppedImageBytes: request.imageBytes,
        selectedTemplate: ProductTemplateCatalog.byId('custom'),
        customBeadWidth: request.cols,
        customBeadHeight: request.rows,
        paletteBrandId: request.paletteBrandId,
        smoothingEnabled: false,
        removeBackground: false,
      ),
    );

    return ChartImportResult(
      pattern: pattern,
      mappings: mappings,
      lowConfidenceCells: lowConfidenceCells,
      warnings: _buildWarnings(
        request: request,
        mappings: mappings,
        lowConfidenceCells: lowConfidenceCells,
        pitchX: pitchX,
        pitchY: pitchY,
      ),
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      cellPitchX: pitchX,
      cellPitchY: pitchY,
    );
  }

  ChartCellSample _sampleCell({
    required Uint8List rgba,
    required int sourceWidth,
    required int sourceHeight,
    required int col,
    required int row,
    required double originX,
    required double originY,
    required double pitchX,
    required double pitchY,
    required double insetRatio,
    required int maxSamplesPerAxis,
  }) {
    final insetX = pitchX * insetRatio;
    final insetY = pitchY * insetRatio;
    var startX = (originX + insetX).floor().clamp(0, sourceWidth - 1);
    var startY = (originY + insetY).floor().clamp(0, sourceHeight - 1);
    var endX = (originX + pitchX - insetX).ceil().clamp(
      startX + 1,
      sourceWidth,
    );
    var endY = (originY + pitchY - insetY).ceil().clamp(
      startY + 1,
      sourceHeight,
    );

    if (endX - startX < _minInnerSpan || endY - startY < _minInnerSpan) {
      startX = (originX + pitchX / 2).floor().clamp(0, sourceWidth - 1);
      startY = (originY + pitchY / 2).floor().clamp(0, sourceHeight - 1);
      endX = startX + 1;
      endY = startY + 1;
    }

    final spanX = endX - startX;
    final spanY = endY - startY;
    final samplesX = maxSamplesPerAxis < spanX ? maxSamplesPerAxis : spanX;
    final samplesY = maxSamplesPerAxis < spanY ? maxSamplesPerAxis : spanY;

    final counts = <int, int>{};
    var sampled = 0;
    for (var iy = 0; iy < samplesY; iy++) {
      final y = startY + ((iy + 0.5) * spanY / samplesY).floor();
      for (var ix = 0; ix < samplesX; ix++) {
        final x = startX + ((ix + 0.5) * spanX / samplesX).floor();
        final offset = (y * sourceWidth + x) * 4;
        final key = _colorKeyWithAlpha(
          rgba[offset],
          rgba[offset + 1],
          rgba[offset + 2],
          rgba[offset + 3],
        );
        counts[key] = (counts[key] ?? 0) + 1;
        sampled++;
      }
    }

    // The mode, not the mean: printed colour codes are a pixel minority inside
    // the cell, so the mode discards them while a mean would drag the colour
    // toward grey and break palette matching.
    var modeKey = 0;
    var modeCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > modeCount) {
        modeCount = entry.value;
        modeKey = entry.key;
      }
    }

    return ChartCellSample(
      col: col,
      row: row,
      r: _keyRed(modeKey ~/ 256),
      g: _keyGreen(modeKey ~/ 256),
      b: _keyBlue(modeKey ~/ 256),
      a: modeKey % 256,
      sampled: sampled,
      modeCount: modeCount,
    );
  }

  List<String> _buildWarnings({
    required ChartImportRequest request,
    required List<ChartColorMapping> mappings,
    required List<ChartCellSample> lowConfidenceCells,
    required double pitchX,
    required double pitchY,
  }) {
    final warnings = <String>[];

    final farMappings = mappings
        .where((mapping) => mapping.delta > paletteDeltaWarning)
        .toList();
    if (farMappings.isNotEmpty) {
      final worst = farMappings
          .map((mapping) => mapping.delta)
          .reduce((a, b) => a > b ? a : b);
      warnings.add(
        '有 ${farMappings.length} 种颜色在色卡里没有接近的对应色（最大色差 ΔE ${worst.toStringAsFixed(1)}），'
        '已就近替换，请在色号清单里核对。',
      );
    }

    if (lowConfidenceCells.isNotEmpty) {
      final total = request.cols * request.rows;
      warnings.add(
        '低置信格 ${lowConfidenceCells.length}/$total，'
        '可能是裁剪未对准、格线偏粗或格内文字过多，请对照网格叠层检查。',
      );
    }

    if (pitchX < minUsableCellPitch || pitchY < minUsableCellPitch) {
      warnings.add(
        '格边长仅 ${pitchX.toStringAsFixed(1)}x${pitchY.toStringAsFixed(1)} 像素，'
        '采样精度不足，建议换更高分辨率的图纸。',
      );
    }

    return warnings;
  }

  void _validate(ChartImportRequest request) {
    if (request.imageBytes.isEmpty) {
      throw ArgumentError('请先选择一张图纸图片。');
    }
    if (request.cols < 1 || request.rows < 1) {
      throw ArgumentError('行列数必须大于 0。');
    }
    if (request.palettes.isEmpty) {
      throw ArgumentError('缺少色卡数据。');
    }
    if (request.cellInsetRatio < 0 ||
        request.cellInsetRatio > maxCellInsetRatio) {
      throw ArgumentError('格内收缩比必须在 0 到 $maxCellInsetRatio 之间。');
    }
    if (request.confidenceThreshold < 0 || request.confidenceThreshold > 1) {
      throw ArgumentError('置信度阈值必须在 0 到 1 之间。');
    }
    if (request.maxSamplesPerAxis < 1) {
      throw ArgumentError('单格采样点数必须大于 0。');
    }
    if (request.left < 0 ||
        request.top < 0 ||
        request.right < 0 ||
        request.bottom < 0) {
      throw ArgumentError('边距不能为负数。');
    }
  }

  // Dart's bitwise operators are 32-bit on the web, so `r << 24` overflows into
  // a negative value. Plain arithmetic keeps these keys well-behaved there.
  static int _colorKey(int r, int g, int b) => (r * 256 + g) * 256 + b;

  static int _colorKeyWithAlpha(int r, int g, int b, int a) =>
      _colorKey(r, g, b) * 256 + a;

  static int _keyRed(int key) => key ~/ 65536;

  static int _keyGreen(int key) => (key ~/ 256) % 256;

  static int _keyBlue(int key) => key % 256;
}
