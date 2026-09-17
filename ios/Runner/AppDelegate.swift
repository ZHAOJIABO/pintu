import Flutter
import Photos
import Security
import SceneKit
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
      let perlerProduct3dFactory = PerlerProduct3dViewFactory()
      registrar(forPlugin: "bobobeads_perler_product_3d")?.register(
        perlerProduct3dFactory,
        withId: "bobobeads/perler_product_3d"
      )

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

        let request = call.arguments as? [String: Any]
        let typedData = request?["image"] as? FlutterStandardTypedData ??
          call.arguments as? FlutterStandardTypedData
        guard let typedData else {
          result(FlutterError(
            code: "invalid_args",
            message: "Image bytes are required.",
            details: nil
          ))
          return
        }

        self.removeBackground(
          typedData.data,
          selection: ForegroundSelectionHint(request?["selection"]),
          result: result
        )
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

  private func removeBackground(
    _ data: Data,
    selection: ForegroundSelectionHint?,
    result: @escaping FlutterResult
  ) {
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
        let selectedInstances = try self.selectedForegroundInstances(
          observation: observation,
          requestHandler: handler,
          selection: selection
        )
        let maskedBuffer = try observation.generateMaskedImage(
          ofInstances: selectedInstances,
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

  @available(iOS 17.0, *)
  private func selectedForegroundInstances(
    observation: VNInstanceMaskObservation,
    requestHandler: VNImageRequestHandler,
    selection: ForegroundSelectionHint?
  ) throws -> IndexSet {
    guard let selection else { return observation.allInstances }

    var best: (
      identifier: Int,
      containsGuideCenter: Bool,
      overlap: Int,
      distance: Double
    )?
    for identifier in observation.allInstances {
      let mask = try observation.generateScaledMaskForImage(
        forInstances: IndexSet(integer: identifier),
        from: requestHandler
      )
      let stats = try maskStatistics(mask, selection: selection.rect)
      guard stats.pixelCount > 0 else { continue }
      if let current = best {
        if stats.containsGuideCenter != current.containsGuideCenter {
          if stats.containsGuideCenter {
            best = (identifier, true, stats.overlap, stats.distance)
          }
        } else if stats.distance < current.distance - 0.002 ||
          (abs(stats.distance - current.distance) <= 0.002 &&
            stats.overlap > current.overlap) {
          best = (
            identifier,
            stats.containsGuideCenter,
            stats.overlap,
            stats.distance
          )
        }
      } else {
        best = (
          identifier,
          stats.containsGuideCenter,
          stats.overlap,
          stats.distance
        )
      }
    }

    guard let best else { return observation.allInstances }
    NSLog(
      "[BackgroundRemoval] selected instance %d (guide center: %@, overlap: %d).",
      best.identifier,
      best.containsGuideCenter ? "yes" : "no",
      best.overlap
    )
    return IndexSet(integer: best.identifier)
  }

  @available(iOS 17.0, *)
  private func maskStatistics(
    _ pixelBuffer: CVPixelBuffer,
    selection: CGRect
  ) throws -> ForegroundMaskStatistics {
    let image = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(image, from: image.extent) else {
      throw NSError(domain: "BackgroundRemoval", code: 1)
    }
    let width = cgImage.width
    let height = cgImage.height
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue |
      CGBitmapInfo.byteOrder32Big.rawValue
    guard let bitmap = CGContext(
      data: &rgba,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: bitmapInfo
    ) else {
      throw NSError(domain: "BackgroundRemoval", code: 2)
    }
    bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let startX = max(0, min(width, Int((selection.minX * CGFloat(width)).rounded(.down))))
    let endX = max(0, min(width, Int((selection.maxX * CGFloat(width)).rounded(.up))))
    let startY = max(0, min(height, Int((selection.minY * CGFloat(height)).rounded(.down))))
    let endY = max(0, min(height, Int((selection.maxY * CGFloat(height)).rounded(.up))))
    var pixelCount = 0
    var overlap = 0
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1

    for y in 0..<height {
      for x in 0..<width {
        if rgba[(y * width + x) * 4 + 3] < 16 { continue }
        pixelCount += 1
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
        if x >= startX && x < endX && y >= startY && y < endY {
          overlap += 1
        }
      }
    }
    let centerX = pixelCount == 0 ? 0.5 : CGFloat(minX + maxX) / 2 / CGFloat(width)
    let centerY = pixelCount == 0 ? 0.5 : CGFloat(minY + maxY) / 2 / CGFloat(height)
    let selectionCenter = CGPoint(x: selection.midX, y: selection.midY)
    let guideCenterX = max(0, min(width - 1, Int(selectionCenter.x * CGFloat(width))))
    let guideCenterY = max(0, min(height - 1, Int(selectionCenter.y * CGFloat(height))))
    let containsGuideCenter = rgba[(guideCenterY * width + guideCenterX) * 4 + 3] >= 16
    let distance = hypot(centerX - selectionCenter.x, centerY - selectionCenter.y)
    return ForegroundMaskStatistics(
      pixelCount: pixelCount,
      containsGuideCenter: containsGuideCenter,
      overlap: overlap,
      distance: Double(distance)
    )
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

private struct ForegroundSelectionHint {
  let rect: CGRect

  init?(_ value: Any?) {
    guard
      let values = value as? [String: Any],
      let left = (values["left"] as? NSNumber)?.doubleValue,
      let top = (values["top"] as? NSNumber)?.doubleValue,
      let width = (values["width"] as? NSNumber)?.doubleValue,
      let height = (values["height"] as? NSNumber)?.doubleValue,
      width > 0,
      height > 0
    else {
      return nil
    }
    let normalized = CGRect(x: left, y: top, width: width, height: height)
      .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    guard !normalized.isNull, !normalized.isEmpty else { return nil }
    rect = normalized
  }
}

private struct ForegroundMaskStatistics {
  let pixelCount: Int
  let containsGuideCenter: Bool
  let overlap: Int
  let distance: Double
}

private final class PerlerProduct3dViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    PerlerProduct3dPlatformView(frame: frame, arguments: args as? [String: Any])
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol) {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A two-sided perler product: the front is a continuous ironed plastic face;
/// the reverse remains an array of physical, hollow beads.
private final class PerlerProduct3dPlatformView: NSObject, FlutterPlatformView {
  private let sceneView: SCNView

  init(frame: CGRect, arguments: [String: Any]?) {
    sceneView = SCNView(frame: frame)
    super.init()
    configureScene(arguments: arguments)
  }

  func view() -> UIView { sceneView }

  private func configureScene(arguments: [String: Any]?) {
    sceneView.backgroundColor = UIColor(red: 0.945, green: 0.957, blue: 0.973, alpha: 1)
    sceneView.antialiasingMode = .multisampling4X
    sceneView.allowsCameraControl = true
    // SceneKit's default orbit response is designed for large desktop scenes.
    // A small product card needs a calmer, deliberate one-finger rotation.
    sceneView.cameraControlConfiguration.rotationSensitivity = 0.15
    sceneView.defaultCameraController.interactionMode = .orbitTurntable
    sceneView.defaultCameraController.inertiaEnabled = false
    sceneView.rendersContinuously = false

    let scene = SCNScene()
    sceneView.scene = scene
    scene.rootNode.addChildNode(makeAmbientLight())
    scene.rootNode.addChildNode(makeKeyLight())

    guard
      let arguments,
      let width = arguments["width"] as? Int,
      let height = arguments["height"] as? Int,
      width > 0,
      height > 0,
      let pixelData = arguments["pixels"] as? FlutterStandardTypedData
    else {
      return
    }

    let root = SCNNode()
    root.name = "PerlerProduct"
    scene.rootNode.addChildNode(root)
    let finish = arguments["finish"] as? String ?? "holeless"
    buildProduct(
      root: root,
      pixels: pixelData.data,
      width: width,
      height: height,
      finish: finish
    )
    addCamera(to: scene, span: max(width, height))
  }

  private func buildProduct(
    root: SCNNode,
    pixels: Data,
    width: Int,
    height: Int,
    finish: String
  ) {
    let spacing: Float = 0.7
    let topGroup = SCNNode()
    let backGroup = SCNNode()
    root.addChildNode(topGroup)
    root.addChildNode(backGroup)

    var fusedGeometryByColor: [UInt32: SCNGeometry] = [:]
    var beadGeometryByColor: [UInt32: SCNGeometry] = [:]
    let horizontalCenter = Float(width - 1) / 2
    let verticalCenter = Float(height - 1) / 2
    let rawPixels = [UInt8](pixels)

    addIronedFaceMask(
      to: topGroup,
      pixels: rawPixels,
      width: width,
      height: height,
      spacing: spacing,
      finish: finish
    )

    for index in 0..<(width * height) {
      let offset = index * 4
      guard offset + 3 < rawPixels.count, rawPixels[offset + 3] > 0 else { continue }
      let colorKey = UInt32(rawPixels[offset]) << 16 |
        UInt32(rawPixels[offset + 1]) << 8 |
        UInt32(rawPixels[offset + 2])
      let color = UIColor(
        red: CGFloat(rawPixels[offset]) / 255,
        green: CGFloat(rawPixels[offset + 1]) / 255,
        blue: CGFloat(rawPixels[offset + 2]) / 255,
        alpha: 1
      )
      let x = Float(index % width)
      let z = Float(index / width)
      let position = SCNVector3(
        (x - horizontalCenter) * spacing,
        0,
        (z - verticalCenter) * spacing
      )

      // There is intentionally no full-canvas carrier plate. Each occupied
      // cell contributes to the fused face, so transparent canvas pixels stay
      // genuinely empty while touching cells read as a continuous surface.
      let fusedGeometry: SCNGeometry
      if let cached = fusedGeometryByColor[colorKey] {
        fusedGeometry = cached
      } else {
        let tile = SCNBox(
          width: CGFloat(spacing),
          height: CGFloat(spacing * 0.4),
          length: CGFloat(spacing),
          chamferRadius: CGFloat(spacing * 0.1)
        )
        tile.materials = [fusedPlasticMaterial(color: color)]
        fusedGeometryByColor[colorKey] = tile
        fusedGeometry = tile
      }
      let fusedNode = SCNNode(geometry: fusedGeometry)
      fusedNode.position = SCNVector3(position.x, spacing * 0.14, position.z)
      topGroup.addChildNode(fusedNode)

      let beadGeometry: SCNGeometry
      if let cached = beadGeometryByColor[colorKey] {
        beadGeometry = cached
      } else {
        let tube = SCNTube(
          innerRadius: CGFloat(spacing * 0.16),
          outerRadius: CGFloat(spacing * 0.45),
          height: CGFloat(spacing * 0.58)
        )
        tube.materials = [plasticMaterial(color: color, roughness: 0.42)]
        beadGeometryByColor[colorKey] = tube
        beadGeometry = tube
      }
      let beadNode = SCNNode(geometry: beadGeometry)
      beadNode.position = SCNVector3(position.x, -spacing * 0.29, position.z)
      backGroup.addChildNode(beadNode)
    }
  }

  private func addIronedFaceMask(
    to group: SCNNode,
    pixels: [UInt8],
    width: Int,
    height: Int,
    spacing: Float,
    finish: String
  ) {
    guard let faceTextures = makeIronedFaceTextures(
      pixels: pixels,
      width: width,
      height: height
    ) else {
      return
    }

    // This zero-thickness plane is the ironed skin. Its alpha mask is black
    // outside occupied cells, so the full-size plane never renders as a clear
    // carrier board. It sits just above the bead geometry and hides the real
    // seams from the front without affecting the physical back face.
    let plane = SCNPlane(
      width: CGFloat(Float(width + 1) * spacing),
      height: CGFloat(Float(height + 1) * spacing)
    )
    let material = fusedPlasticMaterial(color: .white)
    // The ironed face is a colour-accurate preview, not a light-reactive
    // sculpture. Constant lighting preserves the chart's pinks and whites at
    // every camera angle; the supplied multiply texture still adds its local
    // neutral grooves on top.
    material.lightingModel = .constant
    material.diffuse.contents = faceTextures.color
    material.diffuse.magnificationFilter = .nearest
    material.diffuse.minificationFilter = .linear
    // The mask is a flat ironed skin, not a height map. It uses the supplied
    // neutral texture asset, so it adds no green, yellow, or other fixed hue.
    material.normal.contents = nil
    material.multiply.contents = ironedFaceTextureAsset(for: finish)
    material.multiply.intensity = 1
    material.roughness.contents = 0.56
    material.specular.contents = UIColor(white: 0.46, alpha: 1)
    material.transparent.contents = faceTextures.alphaMask
    material.transparent.magnificationFilter = .linear
    material.transparent.minificationFilter = .linear
    // The supplied texture is one fixed 100×100-bead field. Mapping its UV
    // scale to the grid dimensions means smaller charts sample (crop) that
    // field, while larger charts repeat it every 100 cells at the exact same
    // per-bead texture size.
    let textureScale = SCNMatrix4MakeScale(
      Float(width) / 100,
      Float(height) / 100,
      1
    )
    material.multiply.contentsTransform = textureScale
    material.blendMode = .alpha
    material.isDoubleSided = false
    material.writesToDepthBuffer = false
    plane.materials = [material]

    let maskNode = SCNNode(geometry: plane)
    maskNode.eulerAngles.x = -Float.pi / 2
    maskNode.position = SCNVector3(0, spacing * 0.345, 0)
    maskNode.renderingOrder = 10
    group.addChildNode(maskNode)
  }

  private func makeIronedFaceTextures(
    pixels: [UInt8],
    width: Int,
    height: Int
  ) -> (color: UIImage, alphaMask: UIImage)? {
    let expectedLength = width * height * 4
    guard width > 0, height > 0, pixels.count >= expectedLength else { return nil }
    let rasterScale: CGFloat = 8
    let padding = rasterScale / 2
    let outputSize = CGSize(
      width: CGFloat(width) * rasterScale + padding * 2,
      height: CGFloat(height) * rasterScale + padding * 2
    )
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = 1

    func isOpaque(_ x: Int, _ y: Int) -> Bool {
      guard x >= 0, x < width, y >= 0, y < height else { return false }
      return pixels[(y * width + x) * 4 + 3] > 0
    }

    func drawScallopedCell(
      _ context: CGContext,
      rect: CGRect,
      x: Int,
      y: Int,
      color: UIColor
    ) {
      context.setFillColor(color.cgColor)
      context.fill(rect)
      // The cell diagonal is the circle's diameter, so its radius is half the
      // diagonal. We only reveal the small circular segment outside an exposed
      // side—not a full semicircle with the side as its diameter.
      let radius = min(rect.width, rect.height) * CGFloat(2).squareRoot() / 2
      let circle = CGRect(
        x: rect.midX - radius,
        y: rect.midY - radius,
        width: radius * 2,
        height: radius * 2
      )
      func drawOuterSegment(in clipRect: CGRect) {
        context.saveGState()
        context.clip(to: clipRect)
        context.fillEllipse(in: circle)
        context.restoreGState()
      }
      if !isOpaque(x, y - 1) {
        drawOuterSegment(in: CGRect(
          x: rect.minX,
          y: rect.minY - radius,
          width: rect.width,
          height: radius
        ))
      }
      if !isOpaque(x, y + 1) {
        drawOuterSegment(in: CGRect(
          x: rect.minX,
          y: rect.maxY,
          width: rect.width,
          height: radius
        ))
      }
      if !isOpaque(x - 1, y) {
        drawOuterSegment(in: CGRect(
          x: rect.minX - radius,
          y: rect.minY,
          width: radius,
          height: rect.height
        ))
      }
      if !isOpaque(x + 1, y) {
        drawOuterSegment(in: CGRect(
          x: rect.maxX,
          y: rect.minY,
          width: radius,
          height: rect.height
        ))
      }
    }

    let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
    let color = renderer.image { rendererContext in
      for y in 0..<height {
        for x in 0..<width where isOpaque(x, y) {
          let offset = (y * width + x) * 4
          let rect = CGRect(
            x: padding + CGFloat(x) * rasterScale,
            y: padding + CGFloat(y) * rasterScale,
            width: rasterScale,
            height: rasterScale
          )
          drawScallopedCell(
            rendererContext.cgContext,
            rect: rect,
            x: x,
            y: y,
            color: UIColor(
              red: CGFloat(pixels[offset]) / 255,
              green: CGFloat(pixels[offset + 1]) / 255,
              blue: CGFloat(pixels[offset + 2]) / 255,
              alpha: 1
            )
          )
        }
      }
    }
    let alphaMask = renderer.image { rendererContext in
      for y in 0..<height {
        for x in 0..<width where isOpaque(x, y) {
          let rect = CGRect(
            x: padding + CGFloat(x) * rasterScale,
            y: padding + CGFloat(y) * rasterScale,
            width: rasterScale,
            height: rasterScale
          )
          drawScallopedCell(
            rendererContext.cgContext,
            rect: rect,
            x: x,
            y: y,
            color: .white
          )
        }
      }
    }
    // Reinforce only the outer silhouette. The fused colour sits beneath the
    // untouched artwork, so adjacent edge arcs join while every interior
    // colour block remains exactly as rendered above.
    let edgeColor = fuseIronedFaceEdge(
      color,
      expansion: 0.9,
      softness: 0.35
    ) ?? color
    let fusedColor = overlayOriginalFace(color, onto: edgeColor) ?? edgeColor
    let fusedAlphaMask = fuseIronedFaceEdge(
      alphaMask,
      expansion: 0.9,
      softness: 0.35
    ) ?? alphaMask
    return (fusedColor, fusedAlphaMask)
  }

  private func overlayOriginalFace(_ original: UIImage, onto base: UIImage) -> UIImage? {
    guard original.size == base.size else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = 1
    return UIGraphicsImageRenderer(size: original.size, format: format).image { _ in
      base.draw(in: CGRect(origin: .zero, size: base.size))
      original.draw(in: CGRect(origin: .zero, size: original.size))
    }
  }

  private func fuseIronedFaceEdge(
    _ source: UIImage,
    expansion: CGFloat,
    softness: CGFloat
  ) -> UIImage? {
    guard let sourceImage = source.cgImage else { return nil }
    let input = CIImage(cgImage: sourceImage)
    guard let maximum = CIFilter(name: "CIMorphologyMaximum"),
          let blur = CIFilter(name: "CIGaussianBlur") else {
      return nil
    }
    maximum.setValue(input, forKey: kCIInputImageKey)
    maximum.setValue(expansion, forKey: kCIInputRadiusKey)
    guard let expanded = maximum.outputImage else { return nil }
    blur.setValue(expanded, forKey: kCIInputImageKey)
    blur.setValue(softness, forKey: kCIInputRadiusKey)
    guard let softened = blur.outputImage?.cropped(to: input.extent),
          let image = CIContext().createCGImage(softened, from: input.extent) else {
      return nil
    }
    return UIImage(cgImage: image)
  }

  private func ironedFaceTextureAsset(for finish: String) -> UIImage? {
    let assetName: String
    switch finish {
    case "bathTowel":
      assetName = "bath_towel_ironed_face.jpg"
    case "linen":
      assetName = "linen_ironed_face.jpg"
    default:
      assetName = "ironed_face_neutral.png"
    }
    let assetPath = "flutter_assets/assets/textures/\(assetName)"
    let candidates = [
      Bundle.main.bundleURL
        .appendingPathComponent("Frameworks/App.framework")
        .appendingPathComponent(assetPath),
      Bundle.main.bundleURL.appendingPathComponent(assetPath),
    ]
    for url in candidates where FileManager.default.fileExists(atPath: url.path) {
      guard let image = UIImage(contentsOfFile: url.path) else { continue }
      return makeNeutralMultiplyTexture(from: image) ?? image
    }
    NSLog("[Perler3D] ironed face texture asset is unavailable.")
    return nil
  }

  private func makeNeutralMultiplyTexture(from source: UIImage) -> UIImage? {
    guard let image = source.cgImage else { return nil }
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }
    let bitmapInfo = CGBitmapInfo(
      rawValue: CGImageAlphaInfo.premultipliedLast.rawValue |
        CGBitmapInfo.byteOrder32Big.rawValue
    )
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let didDraw = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(
        data: buffer.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo.rawValue
      ) else {
        return false
      }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard didDraw else { return nil }

    for offset in stride(from: 0, to: pixels.count, by: 4) {
      let luminance = Float(pixels[offset]) * 0.2126 +
        Float(pixels[offset + 1]) * 0.7152 +
        Float(pixels[offset + 2]) * 0.0722
      // Preserve the supplied pattern but compress it toward white. A source
      // black line becomes 51 rather than 0, so the supplied texture retains
      // its visible grey relief while still avoiding pure black holes.
      // groove without turning the entire colour block dark.
      let neutralValue = UInt8(max(0, min(255, (255 - (255 - luminance) * 0.80).rounded())))
      pixels[offset] = neutralValue
      pixels[offset + 1] = neutralValue
      pixels[offset + 2] = neutralValue
      pixels[offset + 3] = 255
    }
    return makeTextureImage(pixels: pixels, width: width, height: height)
  }

  private func fusedPlasticMaterial(color: UIColor) -> SCNMaterial {
    let material = plasticMaterial(color: color, roughness: 0.43)
    // A repeated normal map creates pressed texture without using alpha or a
    // bead-sized hole. The multiply map keeps that texture visible even under
    // the broad ambient light used by the preview scene.
    material.normal.contents = makePressedTextureNormalMap()
    material.normal.wrapS = .repeat
    material.normal.wrapT = .repeat
    material.normal.magnificationFilter = .linear
    material.normal.minificationFilter = .linear
    material.normal.intensity = 0.85
    material.normal.contentsTransform = SCNMatrix4MakeScale(1.6, 1.6, 1)
    material.multiply.contents = makePressedTextureColorMap()
    material.multiply.wrapS = .repeat
    material.multiply.wrapT = .repeat
    material.multiply.magnificationFilter = .linear
    material.multiply.minificationFilter = .linear
    material.multiply.contentsTransform = SCNMatrix4MakeScale(1.6, 1.6, 1)
    return material
  }

  private func makePressedTextureNormalMap() -> UIImage? {
    let size = 24
    let center = Float(size - 1) / 2
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    for y in 0..<size {
      for x in 0..<size {
        let dx = (Float(x) - center) / center
        let dy = (Float(y) - center) / center
        let distance = sqrt(dx * dx + dy * dy)
        let falloff = max(0, 1 - distance)
        // Vectors point into a shallow, rounded pressed dimple.
        let strength = falloff * falloff * 38
        let offset = (y * size + x) * 4
        pixels[offset] = UInt8(max(0, min(255, 128 - dx * strength)))
        pixels[offset + 1] = UInt8(max(0, min(255, 128 - dy * strength)))
        pixels[offset + 2] = 255
        pixels[offset + 3] = 255
      }
    }
    let data = Data(pixels)
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }
    let bitmapInfo = CGBitmapInfo(
      rawValue: CGImageAlphaInfo.premultipliedLast.rawValue |
        CGBitmapInfo.byteOrder32Big.rawValue
    )
    guard let image = CGImage(
      width: size,
      height: size,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    ) else {
      return nil
    }
    return UIImage(cgImage: image)
  }

  private func makePressedTextureColorMap() -> UIImage? {
    let size = 24
    let center = Float(size - 1) / 2
    var pixels = [UInt8](repeating: 255, count: size * size * 4)
    for y in 0..<size {
      for x in 0..<size {
        let dx = (Float(x) - center) / center
        let dy = (Float(y) - center) / center
        let distance = sqrt(dx * dx + dy * dy)
        let falloff = max(0, 1 - distance)
        // A subtle lower-right shadow and upper-left highlight make a pressed
        // dimple readable even when the scene is viewed nearly head-on.
        let shade = 255 - Int(falloff * falloff * 36) + Int((dx + dy) * falloff * 8)
        let value = UInt8(max(0, min(255, shade)))
        let offset = (y * size + x) * 4
        pixels[offset] = value
        pixels[offset + 1] = value
        pixels[offset + 2] = value
        pixels[offset + 3] = 255
      }
    }
    return makeTextureImage(pixels: pixels, width: size, height: size)
  }

  private func makeTextureImage(
    pixels: [UInt8],
    width: Int,
    height: Int,
    shouldInterpolate: Bool = true
  ) -> UIImage? {
    let expectedLength = width * height * 4
    guard width > 0, height > 0, pixels.count >= expectedLength else { return nil }
    let data = Data(pixels.prefix(expectedLength))
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }
    let bitmapInfo = CGBitmapInfo(
      rawValue: CGImageAlphaInfo.premultipliedLast.rawValue |
        CGBitmapInfo.byteOrder32Big.rawValue
    )
    guard let image = CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: shouldInterpolate,
      intent: .defaultIntent
    ) else {
      return nil
    }
    return UIImage(cgImage: image)
  }

  private func plasticMaterial(color: UIColor, roughness: CGFloat) -> SCNMaterial {
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.diffuse.contents = color
    material.roughness.contents = roughness
    material.metalness.contents = 0
    material.specular.contents = UIColor(white: 0.82, alpha: 1)
    return material
  }

  private func makeAmbientLight() -> SCNNode {
    let node = SCNNode()
    let light = SCNLight()
    light.type = .ambient
    light.intensity = 700
    light.color = UIColor(red: 0.78, green: 0.84, blue: 0.92, alpha: 1)
    node.light = light
    return node
  }

  private func makeKeyLight() -> SCNNode {
    let node = SCNNode()
    let light = SCNLight()
    light.type = .omni
    light.intensity = 1200
    light.color = UIColor.white
    node.light = light
    node.position = SCNVector3(18, 28, 22)
    return node
  }

  private func addCamera(to scene: SCNScene, span: Int) {
    let distance = max(Float(span) * 0.78, 16)
    let cameraNode = SCNNode()
    let camera = SCNCamera()
    camera.fieldOfView = 38
    camera.usesOrthographicProjection = false
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(distance * 0.48, distance * 0.82, distance * 0.9)
    cameraNode.look(at: SCNVector3(0, 0, 0))
    scene.rootNode.addChildNode(cameraNode)
    sceneView.pointOfView = cameraNode
  }
}
