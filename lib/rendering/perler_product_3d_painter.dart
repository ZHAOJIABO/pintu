import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/perler_product_finish.dart';

/// Draws a rotatable, perspective projection of a finished perler-bead board.
///
/// The front is a continuous heat-fused surface. The reverse is intentionally
/// made from separate hollow beads, so turning the board communicates which
/// face has been ironed without requiring a platform-specific 3D engine.
class PerlerProduct3dPainter extends CustomPainter {
  final Uint8List pixels;
  final int imageWidth;
  final int imageHeight;
  final double yaw;
  final double pitch;
  final PerlerProductFinish finish;
  final ui.Image? finishTexture;

  const PerlerProduct3dPainter({
    required this.pixels,
    required this.imageWidth,
    required this.imageHeight,
    required this.yaw,
    required this.pitch,
    this.finish = PerlerProductFinish.holeless,
    this.finishTexture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF1F4F8), BlendMode.src);
    if (imageWidth <= 0 || imageHeight <= 0) return;

    final longestSide = math.max(imageWidth, imageHeight).toDouble();
    final boardWidth = imageWidth / longestSide;
    final boardHeight = imageHeight / longestSide;
    final thickness = math.min(boardWidth, boardHeight) * 0.16;
    final scene = _ProductScene(
      size: size,
      boardWidth: boardWidth,
      boardHeight: boardHeight,
      yaw: yaw,
      pitch: pitch,
    );

    _drawGroundShadow(canvas, scene, boardWidth, boardHeight);
    _drawSides(canvas, scene, boardWidth, boardHeight, thickness);

    final frontFacing = math.cos(yaw) * math.cos(pitch) >= 0;
    if (frontFacing) {
      _drawFusedFront(canvas, scene, boardWidth, boardHeight, thickness);
    } else {
      _drawBeadedBack(canvas, scene, boardWidth, boardHeight, thickness);
    }
  }

  void _drawGroundShadow(
    Canvas canvas,
    _ProductScene scene,
    double boardWidth,
    double boardHeight,
  ) {
    final shadowCenter = scene
        .project(_ProductPoint(0, boardHeight * 0.56, -scene.boardDepth * 0.75))
        .offset;
    final shadowWidth = scene.scale * boardWidth * 0.86;
    final shadowHeight = scene.scale * boardHeight * 0.16;
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: shadowWidth,
        height: shadowHeight,
      ),
      Paint()
        ..color = const Color(0x1E1B2735)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawSides(
    Canvas canvas,
    _ProductScene scene,
    double boardWidth,
    double boardHeight,
    double thickness,
  ) {
    final left = -boardWidth / 2;
    final right = boardWidth / 2;
    final top = -boardHeight / 2;
    final bottom = boardHeight / 2;
    final front = thickness / 2;
    final back = -thickness / 2;
    final faces = <_SideFace>[
      _SideFace(const Color(0xFFAEB8C4), [
        _ProductPoint(left, top, front),
        _ProductPoint(left, bottom, front),
        _ProductPoint(left, bottom, back),
        _ProductPoint(left, top, back),
      ]),
      _SideFace(const Color(0xFFCAD1D9), [
        _ProductPoint(right, top, front),
        _ProductPoint(right, top, back),
        _ProductPoint(right, bottom, back),
        _ProductPoint(right, bottom, front),
      ]),
      _SideFace(const Color(0xFFD8DEE5), [
        _ProductPoint(left, top, front),
        _ProductPoint(left, top, back),
        _ProductPoint(right, top, back),
        _ProductPoint(right, top, front),
      ]),
      _SideFace(const Color(0xFF9DA8B4), [
        _ProductPoint(left, bottom, front),
        _ProductPoint(right, bottom, front),
        _ProductPoint(right, bottom, back),
        _ProductPoint(left, bottom, back),
      ]),
    ];

    faces.sort((a, b) {
      final aDepth =
          a.points
              .map(scene.project)
              .fold<double>(0, (sum, point) => sum + point.depth) /
          a.points.length;
      final bDepth =
          b.points
              .map(scene.project)
              .fold<double>(0, (sum, point) => sum + point.depth) /
          b.points.length;
      return aDepth.compareTo(bDepth);
    });

    for (final face in faces) {
      final path = Path();
      final projected = face.points.map(scene.project).toList();
      path.moveTo(projected.first.offset.dx, projected.first.offset.dy);
      for (final point in projected.skip(1)) {
        path.lineTo(point.offset.dx, point.offset.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = face.color);
    }
  }

  void _drawFusedFront(
    Canvas canvas,
    _ProductScene scene,
    double boardWidth,
    double boardHeight,
    double thickness,
  ) {
    final cellWidth = boardWidth / imageWidth;
    final cellHeight = boardHeight / imageHeight;
    final z = thickness / 2;
    final topLeft = _ProductPoint(-boardWidth / 2, -boardHeight / 2, z);
    final bottomRight = _ProductPoint(boardWidth / 2, boardHeight / 2, z);
    final faceBounds = Rect.fromPoints(
      scene.project(topLeft).offset,
      scene.project(bottomRight).offset,
    );

    for (var y = 0; y < imageHeight; y++) {
      for (var x = 0; x < imageWidth; x++) {
        final color = _colorAt(x, y);
        if (color == null) continue;
        final points = _cellPoints(
          scene,
          x: x,
          y: y,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          boardWidth: boardWidth,
          boardHeight: boardHeight,
          z: z,
        );
        canvas.drawPath(_polygon(points), Paint()..color = color);

        final beadRadius = _projectedCellRadius(points);
        if (beadRadius > 1.4) {
          // Several very shallow impressions read as pressed plastic, instead
          // of a single, bead-sized hole in every pixel cell.
          for (final impression in const [
            Offset(-0.23, -0.23),
            Offset(0.23, -0.23),
            Offset(-0.23, 0.23),
            Offset(0.23, 0.23),
          ]) {
            final center = scene
                .project(
                  _ProductPoint(
                    -boardWidth / 2 + (x + 0.5 + impression.dx) * cellWidth,
                    -boardHeight / 2 + (y + 0.5 + impression.dy) * cellHeight,
                    z,
                  ),
                )
                .offset;
            canvas.drawCircle(
              center + Offset(beadRadius * 0.045, beadRadius * 0.055),
              beadRadius * 0.06,
              Paint()..color = const Color(0x1A000000),
            );
            canvas.drawCircle(
              center - Offset(beadRadius * 0.04, beadRadius * 0.05),
              beadRadius * 0.043,
              Paint()..color = const Color(0x1AFFFFFF),
            );
          }
        }
      }
    }

    // A gentle diagonal sheen ties all cells into one heat-fused plastic face.
    canvas.save();
    canvas.clipPath(
      _polygon([
        scene.project(_ProductPoint(-boardWidth / 2, -boardHeight / 2, z)),
        scene.project(_ProductPoint(boardWidth / 2, -boardHeight / 2, z)),
        scene.project(_ProductPoint(boardWidth / 2, boardHeight / 2, z)),
        scene.project(_ProductPoint(-boardWidth / 2, boardHeight / 2, z)),
      ]),
    );
    canvas.drawRect(
      faceBounds.inflate(scene.scale * 0.06),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x20FFFFFF), Color(0x00FFFFFF), Color(0x150A1420)],
          stops: [0, 0.5, 1],
        ).createShader(faceBounds.inflate(scene.scale * 0.06)),
    );
    canvas.restore();

    if (finishTexture != null) {
      _drawFinishTexture(canvas, scene, boardWidth, boardHeight, z);
    }
  }

  void _drawFinishTexture(
    Canvas canvas,
    _ProductScene scene,
    double boardWidth,
    double boardHeight,
    double z,
  ) {
    final texture = finishTexture!;
    final face = _polygon([
      scene.project(_ProductPoint(-boardWidth / 2, -boardHeight / 2, z)),
      scene.project(_ProductPoint(boardWidth / 2, -boardHeight / 2, z)),
      scene.project(_ProductPoint(boardWidth / 2, boardHeight / 2, z)),
      scene.project(_ProductPoint(-boardWidth / 2, boardHeight / 2, z)),
    ]);
    final bounds = face.getBounds();
    canvas.save();
    canvas.clipPath(face);
    canvas.drawImageRect(
      texture,
      Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
      bounds,
      Paint()
        ..blendMode = BlendMode.multiply
        ..color = const Color(0x59FFFFFF),
    );
    canvas.restore();
  }

  void _drawBeadedBack(
    Canvas canvas,
    _ProductScene scene,
    double boardWidth,
    double boardHeight,
    double thickness,
  ) {
    final cellWidth = boardWidth / imageWidth;
    final cellHeight = boardHeight / imageHeight;
    final z = -thickness / 2;
    final beads = <_BackBead>[];

    for (var y = 0; y < imageHeight; y++) {
      for (var x = 0; x < imageWidth; x++) {
        final color = _colorAt(x, y);
        if (color == null) continue;
        final points = _cellPoints(
          scene,
          x: x,
          y: y,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          boardWidth: boardWidth,
          boardHeight: boardHeight,
          z: z,
        );
        beads.add(
          _BackBead(
            color: color,
            center: scene.project(
              _ProductPoint(
                -boardWidth / 2 + (x + 0.5) * cellWidth,
                -boardHeight / 2 + (y + 0.5) * cellHeight,
                z,
              ),
            ),
            radius: _projectedCellRadius(points),
          ),
        );
      }
    }

    beads.sort((a, b) => a.center.depth.compareTo(b.center.depth));
    for (final bead in beads) {
      if (bead.radius <= 0.45) continue;
      final width = bead.radius * 1.78;
      final height = bead.radius * 1.62;
      final rect = Rect.fromCenter(
        center: bead.center.offset + Offset(0, bead.radius * 0.1),
        width: width,
        height: height,
      );
      canvas.drawOval(rect, Paint()..color = _darken(bead.color, 0.32));
      canvas.drawOval(
        rect.shift(Offset(-bead.radius * 0.07, -bead.radius * 0.13)),
        Paint()..color = bead.color,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: bead.center.offset,
          width: width * 0.34,
          height: height * 0.34,
        ),
        Paint()..color = _darken(bead.color, 0.48),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center:
              bead.center.offset -
              Offset(bead.radius * 0.035, bead.radius * 0.045),
          width: width * 0.19,
          height: height * 0.19,
        ),
        Paint()..color = const Color(0x8C111922),
      );
    }
  }

  List<_ProjectedPoint> _cellPoints(
    _ProductScene scene, {
    required int x,
    required int y,
    required double cellWidth,
    required double cellHeight,
    required double boardWidth,
    required double boardHeight,
    required double z,
  }) {
    final left = -boardWidth / 2 + x * cellWidth;
    final top = -boardHeight / 2 + y * cellHeight;
    return [
      scene.project(_ProductPoint(left, top, z)),
      scene.project(_ProductPoint(left + cellWidth, top, z)),
      scene.project(_ProductPoint(left + cellWidth, top + cellHeight, z)),
      scene.project(_ProductPoint(left, top + cellHeight, z)),
    ];
  }

  Path _polygon(List<_ProjectedPoint> points) {
    final path = Path()..moveTo(points.first.offset.dx, points.first.offset.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.offset.dx, point.offset.dy);
    }
    return path..close();
  }

  double _projectedCellRadius(List<_ProjectedPoint> points) {
    final horizontal = (points[1].offset - points[0].offset).distance;
    final vertical = (points[3].offset - points[0].offset).distance;
    return math.min(horizontal, vertical) / 2;
  }

  Color? _colorAt(int x, int y) {
    if (x < 0 || y < 0 || x >= imageWidth || y >= imageHeight) return null;
    final offset = (y * imageWidth + x) * 4;
    if (offset + 3 >= pixels.length || pixels[offset + 3] == 0) return null;
    return Color.fromARGB(
      pixels[offset + 3],
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
    );
  }

  Color _darken(Color color, double amount) =>
      Color.lerp(color, const Color(0xFF111922), amount)!;

  @override
  bool shouldRepaint(covariant PerlerProduct3dPainter oldDelegate) {
    return oldDelegate.pixels != pixels ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.finish != finish ||
        oldDelegate.finishTexture != finishTexture;
  }
}

class _ProductScene {
  final Size size;
  final double boardWidth;
  final double boardHeight;
  final double yaw;
  final double pitch;

  const _ProductScene({
    required this.size,
    required this.boardWidth,
    required this.boardHeight,
    required this.yaw,
    required this.pitch,
  });

  double get boardDepth => math.min(boardWidth, boardHeight) * 0.16;
  double get scale =>
      math.min(
        size.width / (boardWidth + boardDepth),
        size.height / (boardHeight + boardDepth),
      ) *
      0.8;

  _ProjectedPoint project(_ProductPoint point) {
    final yawCos = math.cos(yaw);
    final yawSin = math.sin(yaw);
    final pitchCos = math.cos(pitch);
    final pitchSin = math.sin(pitch);
    final yawX = point.x * yawCos + point.z * yawSin;
    final yawZ = -point.x * yawSin + point.z * yawCos;
    final pitchY = point.y * pitchCos - yawZ * pitchSin;
    final depth = point.y * pitchSin + yawZ * pitchCos;
    return _ProjectedPoint(
      Offset(size.width / 2 + yawX * scale, size.height / 2 + pitchY * scale),
      depth,
    );
  }
}

class _ProductPoint {
  final double x;
  final double y;
  final double z;

  const _ProductPoint(this.x, this.y, this.z);
}

class _ProjectedPoint {
  final Offset offset;
  final double depth;

  const _ProjectedPoint(this.offset, this.depth);
}

class _SideFace {
  final Color color;
  final List<_ProductPoint> points;

  const _SideFace(this.color, this.points);
}

class _BackBead {
  final Color color;
  final _ProjectedPoint center;
  final double radius;

  const _BackBead({
    required this.color,
    required this.center,
    required this.radius,
  });
}
