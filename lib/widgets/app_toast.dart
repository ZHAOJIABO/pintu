import 'package:flutter/material.dart';

enum AppToastPlacement { fixed, floating }

/// Displays the app-wide bottom toast style defined in Figma.
void showAppToast(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 2),
  AppToastPlacement placement = AppToastPlacement.fixed,
}) {
  final isFloating = placement == AppToastPlacement.floating;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: isFloating
            ? SnackBarBehavior.floating
            : SnackBarBehavior.fixed,
        backgroundColor: const Color(0xCC000000),
        elevation: 0,
        duration: duration,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        margin: isFloating ? const EdgeInsets.fromLTRB(16, 0, 16, 24) : null,
        shape: RoundedRectangleBorder(
          borderRadius: isFloating
              ? BorderRadius.circular(20)
              : const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        content: Text(
          message,
          textAlign: action == null ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Alimama FangYuanTi VF',
            fontFamilyFallback: ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'],
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.16,
          ),
        ),
        action: action,
      ),
    );
}
