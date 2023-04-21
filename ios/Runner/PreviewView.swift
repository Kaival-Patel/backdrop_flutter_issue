//
//  PreviewView.swift
//  AVMultiCamPiP
//
//  Created by Purvesh Dodiya on 01/03/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import UIKit
import AVFoundation

class PreviewView: UIView {
    
	var videoPreviewLayer: AVCaptureVideoPreviewLayer {
		guard let layer = layer as? AVCaptureVideoPreviewLayer else {
			fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
		}
		return layer
	}
	
	override class var layerClass: AnyClass {
		return AVCaptureVideoPreviewLayer.self
	}
}

