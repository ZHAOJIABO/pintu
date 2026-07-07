import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "bobobeads/photo_library",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "savePng" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard let typedData = call.arguments as? FlutterStandardTypedData else {
          result(FlutterError(
            code: "invalid_args",
            message: "PNG bytes are required.",
            details: nil
          ))
          return
        }

        self.savePngToPhotoLibrary(typedData.data, result: result)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func savePngToPhotoLibrary(_ data: Data, result: @escaping FlutterResult) {
    guard UIImage(data: data) != nil else {
      result(FlutterError(
        code: "invalid_image",
        message: "Unable to decode PNG image.",
        details: nil
      ))
      return
    }

    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("bobobeads_pattern_\(UUID().uuidString).png")

    do {
      try data.write(to: fileURL, options: .atomic)
    } catch {
      result(FlutterError(
        code: "temp_file_failed",
        message: error.localizedDescription,
        details: nil
      ))
      return
    }

    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        self.saveImageIfAuthorized(fileURL: fileURL, status: status, result: result)
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        self.saveImageIfAuthorized(fileURL: fileURL, status: status, result: result)
      }
    }
  }

  private func saveImageIfAuthorized(
    fileURL: URL,
    status: PHAuthorizationStatus,
    result: @escaping FlutterResult
  ) {
    guard isPhotoAuthorizationGranted(status) else {
      removeTemporaryFile(fileURL)
      DispatchQueue.main.async {
        result(FlutterError(
          code: "permission_denied",
          message: "Photo library permission was denied.",
          details: nil
        ))
      }
      return
    }

    PHPhotoLibrary.shared().performChanges({
      PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
    }) { success, error in
      self.removeTemporaryFile(fileURL)
      DispatchQueue.main.async {
        if success {
          result(nil)
        } else {
          result(FlutterError(
            code: "save_failed",
            message: error?.localizedDescription ?? "Unable to save image.",
            details: nil
          ))
        }
      }
    }
  }

  private func removeTemporaryFile(_ fileURL: URL) {
    try? FileManager.default.removeItem(at: fileURL)
  }

  private func isPhotoAuthorizationGranted(_ status: PHAuthorizationStatus) -> Bool {
    if #available(iOS 14, *) {
      return status == .authorized || status == .limited
    }

    return status == .authorized
  }
}
