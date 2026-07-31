import Flutter
import Photos
import Security
import UIKit
import Vision
import Darwin

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

      let deviceIdentifiersChannel = FlutterMethodChannel(
        name: "bobobeads/device_identifiers",
        binaryMessenger: controller.binaryMessenger
      )
      deviceIdentifiersChannel.setMethodCallHandler { call, result in
        guard call.method == "getDeviceInfo" else {
          result(FlutterMethodNotImplemented)
          return
        }
        var device: [String: Any] = [
          "deviceType": UIDevice.current.userInterfaceIdiom == .pad ? 1 : 0,
          "brand": "Apple",
          "model": self.hardwareModel(),
          "os": 2,
          "osv": UIDevice.current.systemVersion,
          "width": Int(UIScreen.main.nativeBounds.width),
          "height": Int(UIScreen.main.nativeBounds.height),
          "orientation": UIScreen.main.bounds.height >= UIScreen.main.bounds.width ? 1 : 2,
          "language": self.protoLanguage(Locale.current.languageCode),
          "timezone": TimeZone.current.identifier,
        ]
        if let idfv = UIDevice.current.identifierForVendor?.uuidString,
           !idfv.isEmpty {
          device["idfv"] = idfv
        }
        // IDFA requires App Tracking Transparency authorization. It is not
        // requested by authentication and is intentionally omitted here.
        result(device)
      }

      let guestCredentialChannel = FlutterMethodChannel(
        name: "bobobeads/guest_credential",
        binaryMessenger: controller.binaryMessenger
      )
      guestCredentialChannel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(
            code: "unavailable",
            message: "Guest credential storage is unavailable.",
            details: nil
          ))
          return
        }
        do {
          switch call.method {
          case "readGuestCredential":
            result(try self.readGuestCredential())
          case "writeGuestCredential":
            guard let arguments = call.arguments as? [String: Any],
                  let value = arguments["value"] as? String,
                  !value.isEmpty else {
              result(FlutterError(
                code: "invalid_args",
                message: "A guest credential is required.",
                details: nil
              ))
              return
            }
            try self.writeGuestCredential(value)
            result(nil)
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(
            code: "keychain_error",
            message: "Unable to access anonymous account storage.",
            details: nil
          ))
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var guestCredentialKeychainQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "cn.appbobo.bobobeads.guest-identity",
      kSecAttrAccount as String: "guest-credential",
    ]
  }

  private func hardwareModel() -> String {
    var size = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    return String(cString: machine)
  }

  private func protoLanguage(_ languageCode: String?) -> String {
    switch languageCode?.lowercased() {
    case "zh": return "CHINESE"
    case "en": return "ENGLISH"
    case "ru": return "RUSSIAN"
    case "vi": return "VIETNAMESE"
    case "pt": return "PORTUGUESE"
    case "id": return "INDONESIAN"
    case "ms": return "MALAY"
    case "th": return "THAI"
    case "fil", "tl": return "FILIPINO"
    default: return "ENGLISH"
    }
  }

  private func readGuestCredential() throws -> String? {
    var query = guestCredentialKeychainQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess,
          let data = result as? Data,
          let credential = String(data: data, encoding: .utf8),
          !credential.isEmpty else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
    return credential
  }

  private func writeGuestCredential(_ credential: String) throws {
    let data = Data(credential.utf8)
    var attributes = guestCredentialKeychainQuery
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    let addStatus = SecItemAdd(attributes as CFDictionary, nil)
    if addStatus == errSecSuccess {
      return
    }
    guard addStatus == errSecDuplicateItem else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
    }
    // A competing first-use request won the race. Leave its credential in
    // place; Flutter reads it back after this call and uses the same account.
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
