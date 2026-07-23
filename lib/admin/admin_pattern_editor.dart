import 'package:flutter/material.dart';

import '../models/generated_pattern.dart';
import '../screens/pattern_editor_screen.dart';

enum AdminPatternEditingMode { brush, palette }

/// Web-backend entry point for the same editor used by the client.
///
/// Keeping this as a small adapter makes the publishing and template-library
/// flows share the complete editing contract: brush, picker, eraser, palette
/// replacement, undo/redo and the final [GeneratedPattern] result. The
/// consumer-oriented onboarding overlays are intentionally omitted here.
class AdminPatternEditorPage extends StatelessWidget {
  final GeneratedPattern pattern;
  final AdminPatternEditingMode initialMode;

  const AdminPatternEditorPage({
    super.key,
    required this.pattern,
    this.initialMode = AdminPatternEditingMode.brush,
  });

  @override
  Widget build(BuildContext context) => PatternEditorScreen(
    pattern: pattern,
    showBrushGuide: false,
    showPaletteGuide: false,
    initialPanel: switch (initialMode) {
      AdminPatternEditingMode.brush => PatternEditorPanel.brush,
      AdminPatternEditingMode.palette => PatternEditorPanel.palette,
    },
  );
}
