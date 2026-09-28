import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// 文件选择通道：与 Android MainActivity.kt 的 FILE_PICKER_CHANNEL 保持一致
  private static let filePickerChannelName = "com.qlapp.qinglong_app/file_picker"

  /// 等待 UIDocumentPickerViewController 回调的 FlutterResult
  private var filePickerResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let pickerChannel = FlutterMethodChannel(
        name: AppDelegate.filePickerChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      pickerChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(nil)
          return
        }
        if call.method == "pickFile" {
          self.presentFilePicker(from: controller, result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func presentFilePicker(from controller: UIViewController, result: @escaping FlutterResult) {
    // 上一次选择未结束，直接拒绝新的请求，避免 result 被覆盖导致挂起
    if filePickerResult != nil {
      result(nil)
      return
    }
    filePickerResult = result

    let picker: UIDocumentPickerViewController
    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [UTType.item],
        asCopy: true
      )
    } else {
      picker = UIDocumentPickerViewController(
        documentTypes: ["public.item"],
        in: .import
      )
    }
    picker.delegate = self
    picker.allowsMultipleSelection = false
    controller.present(picker, animated: true)
  }

  /// 将选中的文件拷贝到应用沙盒内的固定目录后回传，保证 Dart 侧后续始终可读
  private func copyToSandbox(_ url: URL) -> [String: String]? {
    let fileName = url.lastPathComponent
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("picked_files")
    do {
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      let destURL = tempDir.appendingPathComponent(fileName)
      if FileManager.default.fileExists(atPath: destURL.path) {
        try? FileManager.default.removeItem(at: destURL)
      }

      let scoped = url.startAccessingSecurityScopedResource()
      defer {
        if scoped { url.stopAccessingSecurityScopedResource() }
      }

      try FileManager.default.copyItem(at: url, to: destURL)
      return ["path": destURL.path, "name": fileName]
    } catch {
      return nil
    }
  }

  private func finishPicker(_ payload: [String: String]?) {
    let result = filePickerResult
    filePickerResult = nil
    result?(payload)
  }
}

extension AppDelegate: UIDocumentPickerDelegate {
  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let url = urls.first else {
      finishPicker(nil)
      return
    }
    finishPicker(copyToSandbox(url))
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishPicker(nil)
  }
}