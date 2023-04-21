//
//  UIViewContrller.swift
//  AVMultiCamPiP
//
//  Created by Purvesh Dodiya on 01/03/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import UIKit

extension UIViewController {
    
    func showAlert(message: String, actionButtonTitle: String?, actionFirst: ((UIAlertAction) -> ())?, secondButtonTitle: String? = nil, secondAction: ((UIAlertAction) -> ())? = nil) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: Bundle.main.applicationName, message: message, preferredStyle: .alert)
            if let actionButtonTitle = actionButtonTitle {
                alertController.addAction(UIAlertAction(title: actionButtonTitle, style: .cancel, handler: actionFirst))
            }
            if let secondButtonTitle = secondButtonTitle {
                alertController.addAction(UIAlertAction(title: secondButtonTitle, style: .`default`, handler: secondAction))
            }
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
}
