import 'dart:typed_data';

import 'package:bobobeads/algorithms/color_reducer.dart';
import 'package:bobobeads/algorithms/matching.dart';
import 'package:bobobeads/models/color.dart';
import 'package:bobobeads/models/palette.dart';
import 'package:bobobeads/services/api/api_models.dart';
import 'package:bobobeads/services/chart_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const service = ChartImportService();
  const cellSize = 24;

  PaletteEntry entry(String ref, int r, int g, int b) => PaletteEntry(
    name: ref,
    ref: ref,
    symbol: ref,
    color: BeadColor.fromInt(r, g, b, 255),
    prefix: 'M',
  );

  final white = entry('W', 255, 255, 255);
  final black = entry('K', 0, 0, 0);
  final red = entry('R', 230, 40, 50);
  // A darker red exists so the mode-vs-mean test can distinguish the two.
  final darkRed = entry('R2', 150, 30, 35);
  final green = entry('G', 40, 180, 90);
  final blue = entry('B', 40, 90, 210);

  final palette = Palette(
    name: 'Test',
    entries: [white, black, red, darkRed, green, blue],
  );

  /// Paints a chart the same way an exporter would, so the test has an exact
  /// ground truth for every cell.
  Uint8List chartPng(
    List<List<PaletteEntry>> grid, {
    int gridLineThickness = 0,
    PaletteEntry? gridLineColor,
    bool drawGlyph = false,
    bool gradientCells = false,
  }) {
    final rows = grid.length;
    final cols = grid.first.length;
    final image = img.Image(width: cols * cellSize, height: rows * cellSize);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final cell = grid[row][col];
        final x0 = col * cellSize;
        final y0 = row * cellSize;
        img.fillRect(
          image,
          x1: x0,
          y1: y0,
          x2: x0 + cellSize - 1,
          y2: y0 + cellSize - 1,
          color: img.ColorRgb8(
            cell.color.rInt,
            cell.color.gInt,
            cell.color.bInt,
          ),
        );

        if (gradientCells) {
          // Every pixel slightly different: no colour is dominant, which is
          // what an anti-aliased or gradient-filled export looks like.
          for (var y = 0; y < cellSize; y++) {
            for (var x = 0; x < cellSize; x++) {
              image.setPixelRgb(
                x0 + x,
                y0 + y,
                (cell.color.rInt + x) % 256,
                (cell.color.gInt + y) % 256,
                cell.color.bInt,
              );
            }
          }
        }

        if (gridLineThickness > 0) {
          final line = gridLineColor ?? black;
          img.fillRect(
            image,
            x1: x0,
            y1: y0,
            x2: x0 + gridLineThickness - 1,
            y2: y0 + cellSize - 1,
            color: img.ColorRgb8(
              line.color.rInt,
              line.color.gInt,
              line.color.bInt,
            ),
          );
          img.fillRect(
            image,
            x1: x0,
            y1: y0,
            x2: x0 + cellSize - 1,
            y2: y0 + gridLineThickness - 1,
            color: img.ColorRgb8(
              line.color.rInt,
              line.color.gInt,
              line.color.bInt,
            ),
          );
        }

        if (drawGlyph) {
          // A small printed colour code: 4x6 px inside a 24px cell.
          final gx = x0 + cellSize ~/ 2 - 2;
          final gy = y0 + cellSize ~/ 2 - 3;
          img.fillRect(
            image,
            x1: gx,
            y1: gy,
            x2: gx + 3,
            y2: gy + 5,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  ChartImportRequest request(
    Uint8List bytes, {
    required int cols,
    required int rows,
    double? cellInsetRatio,
    bool treatWhiteAsEmpty = false,
    double? confidenceThreshold,
    int left = 0,
    int top = 0,
    int right = 0,
    int bottom = 0,
  }) => ChartImportRequest(
    imageBytes: bytes,
    cols: cols,
    rows: rows,
    palettes: [palette],
    cellInsetRatio: cellInsetRatio ?? ChartImportService.defaultCellInsetRatio,
    confidenceThreshold:
        confidenceThreshold ?? ChartImportService.defaultConfidenceThreshold,
    treatWhiteAsEmpty: treatWhiteAsEmpty,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );

  void expectCell(
    ChartImportResult result,
    int col,
    int row,
    PaletteEntry expected,
  ) {
    final offset = (row * result.pattern.width + col) * 4;
    final pixels = result.pattern.pixels;
    expect(
      [
        pixels[offset],
        pixels[offset + 1],
        pixels[offset + 2],
        pixels[offset + 3],
      ],
      [
        expected.color.rInt,
        expected.color.gInt,
        expected.color.bInt,
        expected.color.aInt,
      ],
      reason: 'cell ($col,$row) must hold the exact palette RGBA',
    );
  }

  test('round-trips a clean chart into exact palette colours', () {
    final grid = [
      [red, green, blue],
      [blue, red, green],
    ];
    final result = service.import(request(chartPng(grid), cols: 3, rows: 2));

    expect(result.pattern.width, 3);
    expect(result.pattern.height, 2);
    expect(result.sourceWidth, 3 * cellSize);
    expect(result.cellPitchX, cellSize);
    expect(result.warnings, isEmpty);

    for (var row = 0; row < grid.length; row++) {
      for (var col = 0; col < grid[row].length; col++) {
        expectCell(result, col, row, grid[row][col]);
      }
    }

    expect(result.pattern.usage, {'R': 2, 'G': 2, 'B': 2});
    expect(result.pattern.totalBeads, 6);
    expect(result.mappings.every((mapping) => mapping.delta == 0), isTrue);
    expect(result.mappings.map((mapping) => mapping.entry.ref).toSet(), {
      'R',
      'G',
      'B',
    });
    expect(result.lowConfidenceCells, isEmpty);
  });

  test('stores only the palette entries the chart actually uses', () {
    final result = service.import(
      request(
        chartPng([
          [red, red],
          [green, green],
        ]),
        cols: 2,
        rows: 2,
      ),
    );

    expect(
      result.pattern.paletteEntries.map((entry) => entry.ref).toList(),
      unorderedEquals(['R', 'G']),
    );
  });

  test('thin grid lines do not disturb the sampled colours', () {
    final grid = [
      [red, green],
      [blue, white],
    ];
    final result = service.import(
      request(chartPng(grid, gridLineThickness: 1), cols: 2, rows: 2),
    );

    expect(result.warnings, isEmpty);
    for (var row = 0; row < grid.length; row++) {
      for (var col = 0; col < grid[row].length; col++) {
        expectCell(result, col, row, grid[row][col]);
      }
    }
  });

  test('the mode ignores a printed colour code that would skew a mean', () {
    final bytes = chartPng([
      [red],
    ], drawGlyph: true);

    final result = service.import(request(bytes, cols: 1, rows: 1));
    expectCell(result, 0, 0, red);
    expect(result.lowConfidenceCells, isEmpty);

    // A mean over the same inner region is dragged toward the glyph and snaps
    // to the darker red instead, which is exactly the failure the mode avoids.
    final decoded = img.decodeImage(bytes)!;
    final inset = (cellSize * ChartImportService.defaultCellInsetRatio).floor();
    var sumR = 0.0, sumG = 0.0, sumB = 0.0, count = 0;
    for (var y = inset; y < cellSize - inset; y++) {
      for (var x = inset; x < cellSize - inset; x++) {
        final pixel = decoded.getPixel(x, y);
        sumR += pixel.r;
        sumG += pixel.g;
        sumB += pixel.b;
        count++;
      }
    }
    final meanEntry = getClosestPaletteEntry(
      [palette],
      BeadColor(sumR / count, sumG / count, sumB / count, 255),
      CIE2000Matching(),
    );
    expect(meanEntry.ref, isNot('R'));
  });

  test('cell inset rescues cells whose borders are thick', () {
    final bytes = chartPng([
      [red, green],
      [blue, red],
    ], gridLineThickness: 6);

    final withoutInset = service.import(
      request(bytes, cols: 2, rows: 2, cellInsetRatio: 0),
    );
    expect(withoutInset.lowConfidenceCells, isNotEmpty);
    expect(
      withoutInset.warnings.any((warning) => warning.contains('低置信格')),
      isTrue,
    );

    final withInset = service.import(request(bytes, cols: 2, rows: 2));
    expect(withInset.lowConfidenceCells, isEmpty);
    expect(withInset.warnings, isEmpty);
    expectCell(withInset, 0, 0, red);
    expectCell(withInset, 1, 1, red);
  });

  test('aggregates low-confidence cells into a single warning', () {
    final result = service.import(
      request(
        chartPng([
          [red, green, blue],
          [green, blue, red],
        ], gradientCells: true),
        cols: 3,
        rows: 2,
      ),
    );

    expect(result.lowConfidenceCells, hasLength(6));
    expect(
      result.warnings.where((warning) => warning.contains('低置信格')),
      hasLength(1),
    );
  });

  test('warns when the chart uses a colour the palette lacks', () {
    final offPalette = entry('X', 18, 52, 86);
    final result = service.import(
      request(
        chartPng([
          [offPalette],
        ]),
        cols: 1,
        rows: 1,
      ),
    );

    expect(
      result.mappings.single.delta,
      greaterThan(ChartImportService.paletteDeltaWarning),
    );
    expect(result.warnings.any((warning) => warning.contains('ΔE')), isTrue);

    // Still byte-exact to whichever entry was chosen.
    expectCell(result, 0, 0, result.mappings.single.entry);
  });

  test('treats white as a bead by default and as empty when asked', () {
    final grid = [
      [white, red],
    ];

    final asBead = service.import(request(chartPng(grid), cols: 2, rows: 1));
    expect(asBead.pattern.usage, {'W': 1, 'R': 1});
    expectCell(asBead, 0, 0, white);

    final asEmpty = service.import(
      request(chartPng(grid), cols: 2, rows: 1, treatWhiteAsEmpty: true),
    );
    expect(asEmpty.pattern.usage, {'R': 1});
    final pixels = asEmpty.pattern.pixels;
    expect([pixels[0], pixels[1], pixels[2], pixels[3]], [0, 0, 0, 0]);
  });

  test('honours crop insets when the upload has leftover margins', () {
    final grid = [
      [red, green],
    ];
    final chart = img.decodeImage(chartPng(grid))!;
    final padded = img.Image(width: chart.width + 7, height: chart.height + 5);
    img.fill(padded, color: img.ColorRgb8(0, 0, 255));
    img.compositeImage(padded, chart, dstX: 4, dstY: 3);

    final result = service.import(
      request(
        Uint8List.fromList(img.encodePng(padded)),
        cols: 2,
        rows: 1,
        left: 4,
        top: 3,
        right: 3,
        bottom: 2,
      ),
    );

    expectCell(result, 0, 0, red);
    expectCell(result, 1, 0, green);
  });

  test('records the imported dimensions on the draft', () {
    final result = service.import(
      request(
        chartPng([
          [red, green, blue],
        ]),
        cols: 3,
        rows: 1,
      ),
    );

    expect(result.pattern.draft.targetWidth, 3);
    expect(result.pattern.draft.targetHeight, 1);
    expect(result.pattern.draft.selectedTemplate?.custom, isTrue);
  });

  test('produces no anonymous colours when converted for publishing', () {
    final result = service.import(
      request(
        chartPng([
          [red, green, blue],
          [white, black, red],
        ]),
        cols: 3,
        rows: 2,
      ),
    );

    final data = PatternData.fromGeneratedPattern(result.pattern);
    expect(data.colorPalette, isNotEmpty);
    for (final color in data.colorPalette) {
      expect(
        color.code,
        isNotEmpty,
        reason: 'every colour must keep its bead code',
      );
      expect(color.brand, isNotEmpty);
      expect(color.name, isNot(startsWith('Color ')));
    }
    expect(data.pixels.where((index) => index == 0), isEmpty);
  });

  group('rejects invalid input', () {
    final bytes = chartPng([
      [red],
    ]);

    test('empty bytes', () {
      expect(
        () => service.import(request(Uint8List(0), cols: 1, rows: 1)),
        throwsArgumentError,
      );
    });

    test('non-positive dimensions', () {
      expect(
        () => service.import(request(bytes, cols: 0, rows: 1)),
        throwsArgumentError,
      );
    });

    test('undecodable bytes', () {
      expect(
        () => service.import(
          request(Uint8List.fromList([1, 2, 3, 4]), cols: 1, rows: 1),
        ),
        throwsArgumentError,
      );
    });

    test('insets larger than the image', () {
      expect(
        () => service.import(
          request(bytes, cols: 1, rows: 1, left: cellSize, right: cellSize),
        ),
        throwsArgumentError,
      );
    });

    test('a chart that yields no beads at all', () {
      expect(
        () => service.import(
          request(
            chartPng([
              [white],
            ]),
            cols: 1,
            rows: 1,
            treatWhiteAsEmpty: true,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
