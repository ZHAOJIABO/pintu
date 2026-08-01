import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionResult { granted, denied, permanentlyDenied }

class CameraPermissionService {
  const CameraPermissionService();

  Future<CameraPermissionResult> requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      return CameraPermissionResult.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermissionResult.permanentlyDenied;
    }
    return CameraPermissionResult.denied;
  }

  Future<bool> openSettings() => openAppSettings();
}
