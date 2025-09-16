import Flutter
import UIKit
import UserNotifications
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.adbsmalltech.media",
                                      binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "saveVideoToPhotos" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing path", details: nil))
        return
      }
      self?.saveVideoToPhotos(path: path, result: result)
    }

    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  private func saveVideoToPhotos(path: String, result: @escaping FlutterResult) {
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    func performSave() {
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
      }) { (success, error) in
        if success {
          result(true)
        } else {
          result(FlutterError(code: "SAVE_FAILED", message: error?.localizedDescription ?? "Unknown error", details: nil))
        }
      }
    }
    switch status {
    case .authorized, .limited:
      performSave()
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
        if newStatus == .authorized || newStatus == .limited {
          performSave()
        } else {
          result(FlutterError(code: "PERMISSION_DENIED", message: "Photos permission denied", details: nil))
        }
      }
    default:
      result(FlutterError(code: "PERMISSION_DENIED", message: "Photos permission denied", details: nil))
    }
  }
}
