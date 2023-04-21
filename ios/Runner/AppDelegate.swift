import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    weak var registrar = self.registrar(forPlugin: "testing")
    let factory = FLNativeViewFactory(messenger: registrar!.messenger())
    self.registrar(forPlugin: "testing1")!.register( factory, withId: "id1")
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let cameraChannel = FlutterMethodChannel(name: "testing",
                                               binaryMessenger: controller.binaryMessenger);
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
