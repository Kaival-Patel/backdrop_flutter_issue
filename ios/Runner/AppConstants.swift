//
//  AppConstants.swift
//  AVMultiCamPiP
//
//  Created by Purvesh Dodiya on 01/03/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import UIKit

struct AppConstants {
    let fullScreenPreviewFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    let smallScreenPreviewFrame = CGRect(x: 20, y: UIScreen.main.bounds.height - 480 , width: UIScreen.main.bounds.width * 0.3, height: UIScreen.main.bounds.height * 0.25)
    
}
