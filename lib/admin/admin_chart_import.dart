import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/generated_pattern.dart';
import '../models/palette.dart';
import '../services/chart_import_service.dart';
import '../services/image_service.dart';
import '../services/palette_service.dart';
import 'admin_pattern_editor.dart';
import 'admin_preview_exporter.dart';
import 'admin_widgets.dart';

/// Converts an existing bead chart image into a [GeneratedPattern] so it can be
/// edited and published like a pattern the app generated itself.
///
/// The grid must fill the uploaded image: administrators crop the rulers and the
/// legend away first, so the cell pitch follows from the row and column counts
/// they type in. The grid overlay is how they confirm that crop lines up.
class AdminChartImportPanel extends StatefulWidget {
  final ValueChanged<GeneratedPattern> onUse;
  final ImageService imageService;
  final PaletteService paletteService;

  const AdminChartImportPanel({
    super.key,
    required this.onUse,
    required this.imageService,
    required this.paletteService,
  });

  @override
  State<AdminChartImportPanel> createState() => _AdminChartImportPanelState();
}

class _AdminChartImportPanelState extends State<AdminChartImportPanel> {
  static const _service = ChartImportService();
  static const _previewExporter = AdminPreviewExporter();

  final _colsController = TextEditingController();
  final _rowsController = TextEditingController();

  Uint8List? _sourceImage;
  ChartImportResult? _result;
  Uint8List? _resultPreview;
  Palette? _palette;
  double _cellInsetRatio = ChartImportService.defaultCellInsetRatio;
  double _confidenceThreshold = ChartImportService.defaultConfidenceThreshold;
  bool _treatWhiteAsEmpty = false;
  bool _parsing = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _colsController.dispose();
    _rowsController.dispose();
    super.dispose();
  }

  int? get _cols => int.tryParse(_colsController.text.trim());

  int? get _rows => int.tryParse(_rowsController.text.trim());

  void _setError(String message) {
    setState(() {
      _error = message;
      _success = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      // Full resolution: image_picker's maxWidth/maxHeight resampling also runs
      // on web and would blend grid lines into the cell colours.
      final picked = await widget.imageService.pickFullResolutionImage();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _sourceImage = bytes;
        _result = null;
        _resultPreview = null;
        _error = null;
        _success = null;
      });
    } catch (error) {
      _setError('选择图片失败：$error');
    }
  }

  Future<void> _parse() async {
    final sourceImage = _sourceImage;
    final cols = _cols;
    final rows = _rows;
    if (sourceImage == null) {
      _setError('请先选择一张裁剪好的图纸图片');
      return;
    }
    if (cols == null || rows == null || cols < 1 || rows < 1) {
      _setError('请填写正确的列数和行数');
      return;
    }

    setState(() {
      _parsing = true;
      _error = null;
      _success = null;
    });
    try {
      final palette =
          _palette ?? await widget.paletteService.loadByName('mard221');
      final result = _service.import(
        ChartImportRequest(
          imageBytes: sourceImage,
          cols: cols,
          rows: rows,
          palettes: [palette],
          cellInsetRatio: _cellInsetRatio,
          confidenceThreshold: _confidenceThreshold,
          treatWhiteAsEmpty: _treatWhiteAsEmpty,
        ),
      );
      final preview = await _previewExporter.exportGalleryThumbnailPng(
        result.pattern,
      );
      if (!mounted) return;
      setState(() {
        _palette = palette;
        _result = result;
        _resultPreview = preview;
        _success =
            '已解析 $cols×$rows，共 ${result.pattern.totalBeads} 颗豆子、'
            '${result.mappings.length} 种颜色。';
      });
    } catch (error) {
      _setError('解析失败：${error is ArgumentError ? error.message : error}');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _editPattern() async {
    final result = _result;
    if (result == null || _parsing) return;
    final edited = await Navigator.of(context).push<GeneratedPattern>(
      MaterialPageRoute(
        builder: (_) => AdminPatternEditorPage(pattern: result.pattern),
      ),
    );
    if (!mounted || edited == null) return;
    final preview = await _previewExporter.exportGalleryThumbnailPng(edited);
    if (!mounted) return;
    setState(() {
      _result = ChartImportResult(
        pattern: edited,
        mappings: result.mappings,
        lowConfidenceCells: result.lowConfidenceCells,
        warnings: result.warnings,
        sourceWidth: result.sourceWidth,
        sourceHeight: result.sourceHeight,
        cellPitchX: result.cellPitchX,
        cellPitchY: result.cellPitchY,
      );
      _resultPreview = preview;
      _success = '图纸编辑已保存，「用于发布」会使用最新版本。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1000;
        final controls = _buildControls(context);
        final preview = _buildPreview(context, compact: compact);
        return Column(
          children: [
            if (_error != null || _success != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AdminNotice(
                  message: _error ?? _success!,
                  isError: _error != null,
                ),
              ),
            Expanded(
              child: compact
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [controls, const SizedBox(height: 20), preview],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 350,
                            child: SingleChildScrollView(child: controls),
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: preview),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    final result = _result;
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '图纸导入',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('把现成的彩色格子图纸转成可编辑、可开拼的图纸。请先自行裁掉四周的行列标尺和色号表，让网格铺满整张图。'),
          const SizedBox(height: 20),
          const AdminSectionLabel(label: '图纸图片'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _parsing ? null : _pickImage,
            icon: const Icon(Icons.grid_on_outlined),
            label: Text(_sourceImage == null ? '选择图纸图片' : '更换图纸图片'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 8),
            Text(
              '源图 ${result.sourceWidth}×${result.sourceHeight} 像素，'
              '格边长 ${result.cellPitchX.toStringAsFixed(1)}×'
              '${result.cellPitchY.toStringAsFixed(1)} 像素',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          const AdminSectionLabel(label: '网格尺寸'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chart-import-cols'),
                  controller: _colsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '列数（横向格数）'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('chart-import-rows'),
                  controller: _rowsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '行数（纵向格数）'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const AdminSectionLabel(label: '采样设置'),
          const SizedBox(height: 4),
          _SliderRow(
            label: '格内收缩',
            value: _cellInsetRatio,
            min: 0,
            max: ChartImportService.maxCellInsetRatio,
            display: '${(_cellInsetRatio * 100).round()}%',
            hint: '向格子内部收缩后再取色，避开格线和格内的色号字',
            onChanged: _parsing
                ? null
                : (value) => setState(() => _cellInsetRatio = value),
          ),
          _SliderRow(
            label: '置信度阈值',
            value: _confidenceThreshold,
            min: 0,
            max: 1,
            display: '${(_confidenceThreshold * 100).round()}%',
            hint: '主色占比低于此值的格子会被标为可疑并高亮',
            onChanged: _parsing
                ? null
                : (value) => setState(() => _confidenceThreshold = value),
          ),
          SwitchListTile.adaptive(
            key: const ValueKey('chart-import-white-empty'),
            contentPadding: EdgeInsets.zero,
            value: _treatWhiteAsEmpty,
            onChanged: _parsing
                ? null
                : (value) => setState(() => _treatWhiteAsEmpty = value),
            title: const Text('白色格视为空'),
            subtitle: const Text('图纸用纯白当背景时打开；白色本身是豆子颜色时保持关闭'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('chart-import-parse'),
            onPressed: _parsing ? null : _parse,
            icon: _parsing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined),
            label: Text(_parsing ? '解析中…' : '解析为图纸'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _parsing ? null : _editPattern,
              icon: const Icon(Icons.brush_outlined),
              label: const Text('编辑图纸'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('chart-import-use'),
              onPressed: _parsing ? null : () => widget.onUse(result.pattern),
              icon: const Icon(Icons.publish_outlined),
              label: const Text('用于发布'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, {required bool compact}) {
    final sourceImage = _sourceImage;
    final result = _result;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '对齐校验',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('叠层的网格线要和图纸上的格子逐格对齐；对不上说明裁剪有偏差或行列数填错了。'),
        const SizedBox(height: 14),
        Expanded(
          child: sourceImage == null
              ? const Center(child: Text('请先选择一张图纸图片'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ChartGridOverlay(
                        imageBytes: sourceImage,
                        cols: _cols,
                        rows: _rows,
                        lowConfidenceCells: result?.lowConfidenceCells,
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 18),
                        ...result.warnings.map(
                          (warning) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AdminNotice(message: warning, isError: true),
                          ),
                        ),
                        const AdminSectionLabel(label: '解析结果'),
                        const SizedBox(height: 10),
                        if (_resultPreview != null)
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _resultPreview!,
                                width: 240,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        const AdminSectionLabel(label: '色号清单'),
                        const SizedBox(height: 10),
                        _ColorMappingList(mappings: result.mappings),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );

    final panel = AdminPanel(child: content);
    return compact ? SizedBox(height: 620, child: panel) : panel;
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String display;
  final String hint;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  const _SliderRow({
    required this.label,
    required this.display,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(display, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
        Text(hint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ColorMappingList extends StatelessWidget {
  final List<ChartColorMapping> mappings;

  const _ColorMappingList({required this.mappings});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mappings.map((mapping) {
        final entry = mapping.entry;
        final isFar = mapping.delta > ChartImportService.paletteDeltaWarning;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFDF6F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFar ? const Color(0xFFC6284A) : const Color(0xFFECE3EA),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(
                      255,
                      entry.color.rInt,
                      entry.color.gInt,
                      entry.color.bInt,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFD9CFD6)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.prefix}${entry.ref} · ${mapping.cellCount}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (isFar) ...[
                  const SizedBox(width: 6),
                  Text(
                    'ΔE ${mapping.delta.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Color(0xFFC6284A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Draws the sampling grid over the source image so a misaligned crop or a wrong
/// row/column count is visible before parsing.
class _ChartGridOverlay extends StatelessWidget {
  final Uint8List imageBytes;
  final int? cols;
  final int? rows;
  final List<ChartCellSample>? lowConfidenceCells;

  const _ChartGridOverlay({
    required this.imageBytes,
    required this.cols,
    required this.rows,
    required this.lowConfidenceCells,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Image.memory(
            imageBytes,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            filterQuality: FilterQuality.none,
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _GridOverlayPainter(
                cols: cols,
                rows: rows,
                lowConfidenceCells: lowConfidenceCells,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridOverlayPainter extends CustomPainter {
  final int? cols;
  final int? rows;
  final List<ChartCellSample>? lowConfidenceCells;

  /// Below this on-screen cell size the grid would paint as a solid wash, so
  /// only every Nth line is drawn.
  static const double _minVisiblePitch = 6;

  _GridOverlayPainter({
    required this.cols,
    required this.rows,
    required this.lowConfidenceCells,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cols = this.cols;
    final rows = this.rows;
    if (cols == null || rows == null || cols < 1 || rows < 1) return;
    if (size.width <= 0 || size.height <= 0) return;

    final pitchX = size.width / cols;
    final pitchY = size.height / rows;

    final cells = lowConfidenceCells;
    if (cells != null && cells.isNotEmpty) {
      final highlight = Paint()..color = const Color(0x99FFB300);
      for (final cell in cells) {
        canvas.drawRect(
          Rect.fromLTWH(cell.col * pitchX, cell.row * pitchY, pitchX, pitchY),
          highlight,
        );
      }
    }

    final line = Paint()
      ..color = const Color(0xAA00E5FF)
      ..strokeWidth = 1;
    final stepX = (_minVisiblePitch / pitchX).ceil();
    final stepY = (_minVisiblePitch / pitchY).ceil();

    for (var col = 0; col <= cols; col += stepX) {
      final x = (col * pitchX).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var row = 0; row <= rows; row += stepY) {
      final y = (row * pitchY).clamp(0.0, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_GridOverlayPainter oldDelegate) =>
      oldDelegate.cols != cols ||
      oldDelegate.rows != rows ||
      !identical(oldDelegate.lowConfidenceCells, lowConfidenceCells);
}
