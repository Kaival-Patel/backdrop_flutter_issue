import Foundation
import Flutter
import UIKit

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    //OUR VIEW CONTROLLER (CAMERA VIEW CONTROLLER)
    var viewController = ViewController();
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            viewController: viewController,
            binaryMessenger: messenger)
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        viewController:ViewController,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        
        _view = viewController.view;
        super.init()
    }

    func view() -> UIView {
        return _view
    }
}
