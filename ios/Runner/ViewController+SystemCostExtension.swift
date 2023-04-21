//
//  ViewController+Extension.swift
//  AVMultiCamPiP
//
//  Created by Purvesh Dodiya on 02/03/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import AVFoundation

// MARK: - Session Cost Check
extension ViewController {
    
    struct ExceededCaptureSessionCosts: OptionSet {
        let rawValue: Int
        static let systemPressureCost = ExceededCaptureSessionCosts(rawValue: 1 << 0)
        static let hardwareCost = ExceededCaptureSessionCosts(rawValue: 1 << 1)
    }
    
    func checkSystemCost() {
        var exceededSessionCosts: ExceededCaptureSessionCosts = []
        if session.systemPressureCost > 1.0 {
            exceededSessionCosts.insert(.systemPressureCost)
        }
        if session.hardwareCost > 1.0 {
            exceededSessionCosts.insert(.hardwareCost)
        }
        switch exceededSessionCosts {
            
        case .systemPressureCost:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) || reduceVideoInputPorts() || reduceResolutionForCamera(.back) || reduceFrameRateForCamera(.front) || reduceFrameRateForCamera(.back) {
                checkSystemCost()
            }
            
            else {
                debugPrint("Unable to further reduce session cost.")
            }
            
        case .hardwareCost:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) || reduceResolutionForCamera(.back) || reduceFrameRateForCamera(.front) || reduceFrameRateForCamera(.back) {
                checkSystemCost()
            }
             else {
                debugPrint("Unable to further reduce session cost.")
            }
            
        case [.systemPressureCost, .hardwareCost]:
            // Choice #1: Reduce front camera resolution
            if reduceResolutionForCamera(.front) || reduceResolutionForCamera(.back) || reduceFrameRateForCamera(.front) || reduceFrameRateForCamera(.back) {
                checkSystemCost()
            }
             else {
                debugPrint("Unable to further reduce session cost.")
            }
            
        default:
            break
        }
    }
    
    private func reduceResolutionForCamera(_ position: AVCaptureDevice.Position) -> Bool {
        for connection in session.connections {
            for inputPort in connection.inputPorts {
                if inputPort.mediaType == .video && inputPort.sourceDevicePosition == position {
                    guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput else {
                        return false
                    }
                    var dimensions: CMVideoDimensions
                    var width: Int32
                    var height: Int32
                    var activeWidth: Int32
                    var activeHeight: Int32
                    
                    dimensions = CMVideoFormatDescriptionGetDimensions(videoDeviceInput.device.activeFormat.formatDescription)
                    activeWidth = dimensions.width
                    activeHeight = dimensions.height
                    
                    if ( activeHeight <= 480 ) && ( activeWidth <= 640 ) {
                        return false
                    }
                    
                    let formats = videoDeviceInput.device.formats
                    if let formatIndex = formats.firstIndex(of: videoDeviceInput.device.activeFormat) {
                        for index in (0..<formatIndex).reversed() {
                            let format = videoDeviceInput.device.formats[index]
                            if format.isMultiCamSupported {
                                dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                                width = dimensions.width
                                height = dimensions.height
                                if width < activeWidth || height < activeHeight {
                                    do {
                                        try videoDeviceInput.device.lockForConfiguration()
                                        videoDeviceInput.device.activeFormat = format
                                        videoDeviceInput.device.unlockForConfiguration()
                                        debugPrint("reduced width = \(width), reduced height = \(height)")
                                        return true
                                    } catch {
                                        debugPrint("Could not lock device for configuration: \(error)")
                                        return false
                                    }
                                } else {
                                    continue
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    
    internal func setRecommendedFrameRateRangeForPressureState(_ systemPressureState: AVCaptureDevice.SystemPressureState) {
        // The frame rates used here are for demonstrative purposes only for this app.
        // Your frame rate throttling may be different depending on your app's camera configuration.
        let pressureLevel = systemPressureState.level
        if pressureLevel == .serious || pressureLevel == .critical {
            if self.movieRecorder == nil || self.movieRecorder?.isRecording == false {
                do {
                    try self.backCameraDeviceInput?.device.lockForConfiguration()
                    debugPrint("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                    self.backCameraDeviceInput?.device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 20 )
                    self.backCameraDeviceInput?.device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 15 )
                    self.backCameraDeviceInput?.device.unlockForConfiguration()
                } catch {
                    debugPrint("Could not lock device for configuration: \(error)")
                }
            }
        } else if pressureLevel == .shutdown {
            debugPrint("Session stopped running due to system pressure level.")
        }
    }
    
    private func reduceVideoInputPorts () -> Bool {
        var newConnection: AVCaptureConnection
        var result = false
        for connection in session.connections {
            for inputPort in connection.inputPorts where inputPort.sourceDeviceType == .builtInDualCamera {
                debugPrint("Changing input from dual to single camera")
                guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput,
                      let wideCameraPort: AVCaptureInput.Port = videoDeviceInput.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: videoDeviceInput.device.position).first else {
                    return false
                }
                if let previewLayer = connection.videoPreviewLayer {
                    newConnection = AVCaptureConnection(inputPort: wideCameraPort, videoPreviewLayer: previewLayer)
                } else if let savedOutput = connection.output {
                    newConnection = AVCaptureConnection(inputPorts: [wideCameraPort], output: savedOutput)
                } else {
                    continue
                }
                session.beginConfiguration()
                session.removeConnection(connection)
                if session.canAddConnection(newConnection) {
                    session.addConnection(newConnection)
                    session.commitConfiguration()
                    result = true
                } else {
                    debugPrint("Could not add new connection to the session")
                    session.commitConfiguration()
                    return false
                }
            }
        }
        return result
    }
    
    private func reduceFrameRateForCamera(_ position: AVCaptureDevice.Position) -> Bool {
        for connection in session.connections {
            for inputPort in connection.inputPorts {
                
                if inputPort.mediaType == .video && inputPort.sourceDevicePosition == position {
                    guard let videoDeviceInput: AVCaptureDeviceInput = inputPort.input as? AVCaptureDeviceInput else {
                        return false
                    }
                    let activeMinFrameDuration = videoDeviceInput.device.activeVideoMinFrameDuration
                    var activeMaxFrameRate: Double = Double(activeMinFrameDuration.timescale) / Double(activeMinFrameDuration.value)
                    activeMaxFrameRate -= 10.0
                    
                    // Cap the device frame rate to this new max, never allowing it to go below 15 fps
                    if activeMaxFrameRate >= 15.0 {
                        do {
                            try videoDeviceInput.device.lockForConfiguration()
                            videoDeviceInput.videoMinFrameDurationOverride = CMTimeMake(value: 1, timescale: Int32(activeMaxFrameRate))
                            videoDeviceInput.device.unlockForConfiguration()
                            debugPrint("reduced fps = \(activeMaxFrameRate)")
                            return true
                        } catch {
                            debugPrint("Could not lock device for configuration: \(error)")
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
        }
        return false
    }
    
}
