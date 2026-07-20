import Flutter
import Photos
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let photoLibraryChannel = FlutterMethodChannel(
        name: "bobobeads/photo_library",
        binaryMessenger: controller.binaryMessenger
      )
      photoLibraryChannel.setMethodCallHandler { call, result in
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

      let backgroundRemovalChannel = FlutterMethodChannel(
        name: "bobobeads/background_removal",
        binaryMessenger: controller.binaryMessenger
      )
      backgroundRemovalChannel.setMethodCallHandler { call, result in
        if call.method == "isSimulator" {
          #if targetEnvironment(simulator)
          result(true)
          #else
          result(false)
          #endif
          return
        }

        guard call.method == "removeBackground" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard let typedData = call.arguments as? FlutterStandardTypedData else {
          result(FlutterError(
            code: "invalid_args",
            message: "Image bytes are required.",
            details: nil
          ))
          return
        }

        self.removeBackground(typedData.data, result: result)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func removeBackground(_ data: Data, result: @escaping FlutterResult) {
    guard #available(iOS 17.0, *) else {
      NSLog("[BackgroundRemoval] unsupported iOS version.")
      result(FlutterError(
        code: "unsupported",
        message: "Background removal requires iOS 17 or later.",
        details: nil
      ))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        NSLog("[BackgroundRemoval] Vision request started (\(data.count) bytes).")
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(data: data, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first,
              !observation.allInstances.isEmpty else {
          NSLog("[BackgroundRemoval] Vision found no foreground subject.")
          self.finishBackgroundRemoval(
            result,
            error: FlutterError(
              code: "no_subject",
              message: "No foreground subject was found.",
              details: nil
            )
          )
          return
        }

        NSLog(
          "[BackgroundRemoval] Vision found \(observation.allInstances.count) foreground instance(s)."
        )
        let maskedBuffer = try observation.generateMaskedImage(
          ofInstances: observation.allInstances,
          from: handler,
          croppedToInstancesExtent: false
        )
        let image = CIImage(cvPixelBuffer: maskedBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent),
              let pngData = UIImage(cgImage: cgImage).pngData() else {
          NSLog("[BackgroundRemoval] failed to encode the masked PNG.")
          self.finishBackgroundRemoval(
            result,
            error: FlutterError(
              code: "encoding_failed",
              message: "Unable to encode the foreground image.",
              details: nil
            )
          )
          return
        }

        NSLog("[BackgroundRemoval] masked PNG produced (\(pngData.count) bytes).")
        self.finishBackgroundRemoval(result, data: pngData)
      } catch {
        NSLog("[BackgroundRemoval] Vision request failed: %@", error.localizedDescription)
        self.finishBackgroundRemoval(
          result,
          error: FlutterError(
            code: "removal_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private func finishBackgroundRemoval(
    _ result: @escaping FlutterResult,
    data: Data? = nil,
    error: FlutterError? = nil
  ) {
    DispatchQueue.main.async {
      if let error {
        result(error)
      } else {
        result(FlutterStandardTypedData(bytes: data!))
      }
    }
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
