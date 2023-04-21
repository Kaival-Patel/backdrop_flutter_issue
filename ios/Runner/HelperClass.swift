//
//  HelperClass.swift
//  AVMultiCamPiP
//
//  Created by Purvesh Dodiya on 01/03/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import AVFoundation
import UIKit

class HelperClass {
    
    public var isFlashOn = false

    func createAudioSettings(backMicrophoneAudioDataOutput: AVCaptureAudioDataOutput, frontMicrophoneAudioDataOutput: AVCaptureAudioDataOutput) -> [String: NSObject]? {
        guard let backMicrophoneAudioSettings = backMicrophoneAudioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            debugPrint("Could not get back microphone audio settings")
            return nil
        }
        guard let frontMicrophoneAudioSettings = frontMicrophoneAudioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            debugPrint("Could not get front microphone audio settings")
            return nil
        }
        
        if backMicrophoneAudioSettings == frontMicrophoneAudioSettings {
            // The front and back microphone audio settings are equal, so return either one
            return backMicrophoneAudioSettings
        } else {
            debugPrint("Front and back microphone audio settings are not equal. Check your AVCaptureAudioDataOutput configuration.")
            return nil
        }
        
    }
    
    func createVideoSettings(backCameraVideoDataOutput: AVCaptureVideoDataOutput, frontCameraVideoDataOutput: AVCaptureVideoDataOutput) -> [String: NSObject]? {
        guard let backCameraVideoSettings = backCameraVideoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            debugPrint("Could not get back camera video settings")
            return nil
        }
        guard let frontCameraVideoSettings = frontCameraVideoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject] else {
            debugPrint("Could not get front camera video settings")
            return nil
        }
        
        if backCameraVideoSettings == frontCameraVideoSettings {
            // The front and back camera video settings are equal, so return either one
            return backCameraVideoSettings
        } else {
            debugPrint("Front and back camera video settings are not equal. Check your AVCaptureVideoDataOutput configuration.")
            return nil
        }
    }
    
    
    func createVideoTransform(backCameraVideoDataOutput: AVCaptureVideoDataOutput) -> CGAffineTransform? {
        guard let backCameraVideoConnection = backCameraVideoDataOutput.connection(with: .video) else {
            print("Could not find the back and front camera video connections")
            return nil
        }
        
        let deviceOrientation = UIDevice.current.orientation
        let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) ?? .portrait
        
        // Compute transforms from the back camera's video orientation to the device's orientation
        let backCameraTransform = backCameraVideoConnection.videoOrientationTransform(relativeTo: videoOrientation)
        
        return backCameraTransform
        
    }
    
    func adjustTime(sampleBuffer: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        var out:CMSampleBuffer?
        var count:CMItemCount = CMSampleBufferGetNumSamples(sampleBuffer)
        let pInfo = UnsafeMutablePointer<CMSampleTimingInfo>.allocate(capacity: count)
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, arrayToFill: pInfo, entriesNeededOut: &count)
        var i = 0
        while i<count {
            pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset)
            pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset)
            i+=1
        }
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sampleBuffer, sampleTimingEntryCount: count, sampleTimingArray: pInfo, sampleBufferOut: &out)
        return out
    }
    
    //MARK: toggleFlash
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            self.isFlashOn = !self.isFlashOn
            device.torchMode = self.isFlashOn ? .on : .off
            if self.isFlashOn {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            }
            device.unlockForConfiguration()
        } catch {
            debugPrint("Error: \(error)")
        }
    }
}
