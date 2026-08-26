import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import 'app_toast.dart';
import 'rounded_confirmation_dialog.dart';

Future<void> showForceUpdateDialog(
  NavigatorState navigator, {
  required AppUpdatePolicy policy,
}) {
  return showDialog<void>(
    context: navigator.context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: RoundedConfirmationDialog(
        title: '发现新版本',
        message: policy.releaseNotes.isEmpty ? null : policy.releaseNotes,
        primaryLabel: '立即更新',
        onPrimary: () async {
          final opened = await const AppStoreUpdateService().open(policy);
          if (!opened && navigator.mounted) {
            showAppToast(navigator.context, '暂时无法打开更新页面');
          }
        },
      ),
    ),
  );
}
