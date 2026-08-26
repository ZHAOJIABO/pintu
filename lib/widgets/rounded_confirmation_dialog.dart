import 'package:flutter/material.dart';

const _dialogFontFamily = 'Alimama FangYuanTi VF';
const _dialogFontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
const _dialogSecondaryBackground = Color(0xFFEEF0F6);

/// The shared confirmation dialog style used by client-side destructive and
/// save decisions. It follows the clear-cache dialog's rounded white surface
/// and paired pill buttons.
class RoundedConfirmationDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String? secondaryLabel;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback onPrimary;
  final Key? dialogKey;
  final Key? secondaryButtonKey;
  final Key? primaryButtonKey;

  const RoundedConfirmationDialog({
    super.key,
    required this.title,
    this.message,
    this.secondaryLabel,
    required this.primaryLabel,
    this.onSecondary,
    required this.onPrimary,
    this.dialogKey,
    this.secondaryButtonKey,
    this.primaryButtonKey,
  }) : assert(
         (secondaryLabel == null) == (onSecondary == null),
         'secondaryLabel and onSecondary must be provided together.',
       );

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Dialog(
      key: dialogKey,
      insetPadding: const EdgeInsets.symmetric(horizontal: 21),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 333),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: _dialogFontFamily,
                  fontFamilyFallback: _dialogFontFallbacks,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: _dialogFontFamily,
                    fontFamilyFallback: _dialogFontFallbacks,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 20 / 15,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (secondaryLabel != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _RoundedConfirmationDialogButton(
                        key: secondaryButtonKey,
                        label: secondaryLabel!,
                        backgroundColor: _dialogSecondaryBackground,
                        foregroundColor: Colors.black,
                        onTap: onSecondary!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoundedConfirmationDialogButton(
                        key: primaryButtonKey,
                        label: primaryLabel,
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        onTap: onPrimary,
                      ),
                    ),
                  ],
                ),
              ] else
                _RoundedConfirmationDialogButton(
                  key: primaryButtonKey,
                  label: primaryLabel,
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  onTap: onPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundedConfirmationDialogButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _RoundedConfirmationDialogButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(44)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(44)),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontFamily: _dialogFontFamily,
                  fontFamilyFallback: _dialogFontFallbacks,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
