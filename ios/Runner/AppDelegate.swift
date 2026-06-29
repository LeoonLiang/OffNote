import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var resourcePickerDelegate: ResourceFilePickerDelegate?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let resourceChannel = FlutterMethodChannel(
        name: "offnote/resource_files",
        binaryMessenger: controller.binaryMessenger
      )
      resourceChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "pickImageResourceFile":
          self.pickResourceFile(contentTypes: [.image], result: result)
        case "pickVideoResourceFile":
          self.pickResourceFile(contentTypes: [.movie, .video], result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func pickResourceFile(contentTypes: [UTType], result: @escaping FlutterResult) {
    if resourcePickerDelegate != nil {
      result(FlutterError(
        code: "already_picking",
        message: "A resource file picker is already open",
        details: nil
      ))
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
    let delegate = ResourceFilePickerDelegate { [weak self] path, error in
      self?.resourcePickerDelegate = nil
      if let error = error {
        result(FlutterError(code: "copy_failed", message: error.localizedDescription, details: nil))
      } else {
        result(path)
      }
    }
    resourcePickerDelegate = delegate
    picker.delegate = delegate
    picker.allowsMultipleSelection = false
    window?.rootViewController?.present(picker, animated: true)
  }
}

private final class ResourceFilePickerDelegate: NSObject, UIDocumentPickerDelegate {
  private let completion: (String?, Error?) -> Void

  init(completion: @escaping (String?, Error?) -> Void) {
    self.completion = completion
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completion(nil, nil)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let url = urls.first else {
      completion(nil, nil)
      return
    }
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }
    do {
      let importsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("resource-imports", isDirectory: true)
      try FileManager.default.createDirectory(
        at: importsDirectory,
        withIntermediateDirectories: true
      )
      let fileName = sanitizeFileName(url.lastPathComponent)
      let target = importsDirectory.appendingPathComponent(
        "\(Int(Date().timeIntervalSince1970 * 1000))-\(fileName)"
      )
      if FileManager.default.fileExists(atPath: target.path) {
        try FileManager.default.removeItem(at: target)
      }
      try FileManager.default.copyItem(at: url, to: target)
      completion(target.path, nil)
    } catch {
      completion(nil, error)
    }
  }

  private func sanitizeFileName(_ name: String) -> String {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
    let scalars = name.unicodeScalars.map { scalar -> Character in
      allowed.contains(scalar) ? Character(scalar) : "_"
    }
    let sanitized = String(scalars)
    return sanitized.isEmpty ? "resource" : sanitized
  }
}
