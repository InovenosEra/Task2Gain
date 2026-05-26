import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Report the current interface orientation so the UI can hug the edge
    // opposite the camera/Dynamic Island (Flutter can't tell left vs right).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OrientationChannel") {
      let channel = FlutterMethodChannel(
        name: "city/orientation", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "interfaceOrientation" {
          let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
          switch scene?.interfaceOrientation {
          case .landscapeLeft: result("landscapeLeft")
          case .landscapeRight: result("landscapeRight")
          case .portrait: result("portrait")
          case .portraitUpsideDown: result("portraitUpsideDown")
          default: result("unknown")
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
