import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    internal enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
        case multiCamNotSupported
    }
    internal var pipDevicePosition: AVCaptureDevice.Position = .front
    internal var normalizedPipFrame = CGRect.zero
    internal let backCameraVideoDataOutput = AVCaptureVideoDataOutput()
    internal weak var backCameraVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    internal var frontCameraDeviceInput: AVCaptureDeviceInput?
    internal let frontCameraVideoDataOutput = AVCaptureVideoDataOutput()
    internal weak var frontCameraVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    internal var microphoneDeviceInput: AVCaptureDeviceInput?
    internal let backMicrophoneAudioDataOutput = AVCaptureAudioDataOutput()
    internal let frontMicrophoneAudioDataOutput = AVCaptureAudioDataOutput()
    internal let session = AVCaptureMultiCamSession()
    internal let dataOutputQueue = DispatchQueue(label: "data output queue")
    internal var setupResult: SessionSetupResult = .success
    internal var movieRecorder: MovieRecorder?
    internal var currentPiPSampleBuffer: CMSampleBuffer?
    internal var renderingEnabled = true
    internal var videoMixer = PiPVideoMixer()
    internal var videoTrackSourceFormatDescription: CMFormatDescription?
    internal let frontCameraVideoPreviewView = PreviewView(frame: AppConstants().smallScreenPreviewFrame)
    private let backCameraVideoPreviewView = PreviewView(frame: AppConstants().fullScreenPreviewFrame)
    let helperClasss = HelperClass()
    private var timeOffset : CMTime!
    private var lastVideoTime : CMTime!
    private var lastAudioTime : CMTime!
    private var needToSetTimeOffset = false
    private var sessionRunningContext = 0
    private var keyValueObservations = [NSKeyValueObservation]()
    private var isSessionRunning = false
    var isRecordingPaused = false
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    @objc dynamic var backCameraDeviceInput: AVCaptureDeviceInput?
    
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        frontCameraVideoPreviewView.layer.masksToBounds = true
        frontCameraVideoPreviewView.layer.cornerRadius = 10
        backCameraVideoPreviewView.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.addSubview(backCameraVideoPreviewView)
        view.addSubview(frontCameraVideoPreviewView)
        
        
        // Set up the back and front video preview views.
        backCameraVideoPreviewView.videoPreviewLayer.setSessionWithNoConnection(session)
        frontCameraVideoPreviewView.videoPreviewLayer.setSessionWithNoConnection(session)
        
        // Store the back and front video preview layers so we can connect them to their inputs
        backCameraVideoPreviewLayer = backCameraVideoPreviewView.videoPreviewLayer
        frontCameraVideoPreviewLayer = frontCameraVideoPreviewView.videoPreviewLayer
        
        // Store the location of the pip's frame in relation to the full screen video preview
        updateNormalizedPiPFrame()
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        sessionQueue.async {
            self.configureSession()
        }
        // Keep the screen awake
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                
            case .notAuthorized:
                self.showAlert(message: "\(Bundle.main.applicationName) doesn't have permission to use the camera, please change privacy settings", actionButtonTitle: "OK", actionFirst: nil, secondButtonTitle: "Settings") { _ in
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                    }
                }
            case .configurationFailed:
                self.showAlert(message: "Unable to capture media", actionButtonTitle: "OK", actionFirst: nil)
            case .multiCamNotSupported:
                self.showAlert(message: "Multi Cam Not Supported", actionButtonTitle: "OK", actionFirst: nil)
            }
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
        super.viewWillDisappear(animated)
    }
    
}

//MARK: - AVCaptureOutput
extension ViewController {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let isVideo = (output as? AVCaptureVideoDataOutput != nil)
        DispatchQueue.main.async {
            var newSampleBuffer = sampleBuffer
            if(!(self.movieRecorder?.isRecording ?? false) || self.isRecordingPaused) {
                return
            }
            
            if (self.needToSetTimeOffset) {
                if (isVideo){
                    return
                }
                self.needToSetTimeOffset = false
                // Calc adjustment
                var sampleBufferTimeStamp = CMSampleBufferGetPresentationTimeStamp(newSampleBuffer)
                let lastTimeStamp = isVideo ? self.lastVideoTime: self.lastAudioTime
                if (lastTimeStamp!.isValid){
                    if(self.timeOffset.isValid){
                        sampleBufferTimeStamp = CMTimeSubtract(sampleBufferTimeStamp, self.timeOffset)
                    }
                    let offset = CMTimeSubtract(sampleBufferTimeStamp, lastTimeStamp!)
                    print("Setting offset from \(isVideo ? "video": "audio")")
                    
                    // This stops us having to set a scale for sampleBufferTimeStamp before we see the first video time
                    self.timeOffset = self.timeOffset.value == 0 ? offset : CMTimeAdd(self.timeOffset, offset)
                    self.lastAudioTime.flags = []
                    self.lastVideoTime.flags = []
                    return
                }
            }
            
            if (self.timeOffset.value > 0){
                if let unwrappedAdjustedBuffer = self.helperClasss.adjustTime(sampleBuffer: newSampleBuffer, by: self.timeOffset) {
                    newSampleBuffer = unwrappedAdjustedBuffer
                } else{
                    print("<<<<<<<< unable to adjust the buffer")
                }
            }
            
            // Record most recent time so we know the length of the pause
            var sampleBufferTimeStamp = CMSampleBufferGetPresentationTimeStamp(newSampleBuffer)
            let duration = CMSampleBufferGetDuration(newSampleBuffer)
            if duration.value > 0 {
                sampleBufferTimeStamp = CMTimeAdd(sampleBufferTimeStamp, duration)
            }
            if(isVideo) {
                self.lastVideoTime = sampleBufferTimeStamp
            } else {
                self.lastAudioTime = sampleBufferTimeStamp
            }
            // Process SampleBuffer
            if let videoDataOutput = output as? AVCaptureVideoDataOutput {
                self.processVideoSampleBuffer(newSampleBuffer, fromOutput: videoDataOutput)
            } else if let audioDataOutput = output as? AVCaptureAudioDataOutput {
                self.processsAudioSampleBuffer(newSampleBuffer, fromOutput: audioDataOutput)
            }
        }
    }
    
}

//MARK: Obj function
extension ViewController {
    
    
    @objc private func didEnterBackground(notification: NSNotification) {
        // Free up resources.
        dataOutputQueue.async {
            self.renderingEnabled = false
            self.videoMixer.reset()
            self.currentPiPSampleBuffer = nil
        }
    }
    
    @objc func willEnterForground(notification: NSNotification) {
        dataOutputQueue.async {
            self.renderingEnabled = true
        }
    }
    
    @objc private func sessionRuntimeError(notification: NSNotification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }
        
        let error = AVError(_nsError: errorValue)
        debugPrint("Capture session runtime error: \(error)")
        
        /*
         Automatically try to restart the session running if media services were
         reset and the last start running succeeded. Otherwise, enable the user
         to try to resume the session running.
         */
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                } else {
                    DispatchQueue.main.async {
                        //self.resumeButton.isHidden = false
                    }
                }
            }
        }
    }
    
}

// MARK: KVO and Notifications
extension ViewController {
    
    private func addObservers() {
        let systemPressureStateObservation = observe(\.self.backCameraDeviceInput?.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue as? AVCaptureDevice.SystemPressureState else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
    }
    
    private func removeObservers() {
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
    
}

// MARK: Video Preview PiP Management
extension ViewController {
    
    @objc // Expose to Objective-C for use with #selector()
    private func togglePiP() {
        // Disable animations so the views move immediately
        CATransaction.begin()
        UIView.setAnimationsEnabled(false)
        CATransaction.setDisableActions(true)
        if pipDevicePosition == .front {
            frontCameraVideoPreviewView.frame = AppConstants().fullScreenPreviewFrame
            backCameraVideoPreviewView.frame = AppConstants().smallScreenPreviewFrame
            backCameraVideoPreviewView.layer.cornerRadius = 10
            frontCameraVideoPreviewView.layer.cornerRadius = 0
            view.sendSubviewToBack(frontCameraVideoPreviewView)
            pipDevicePosition = .back
        } else {
            frontCameraVideoPreviewView.frame = AppConstants().smallScreenPreviewFrame
            backCameraVideoPreviewView.frame = AppConstants().fullScreenPreviewFrame
            frontCameraVideoPreviewView.layer.cornerRadius = 10
            backCameraVideoPreviewView.layer.cornerRadius = 0
            view.sendSubviewToBack(backCameraVideoPreviewView)
            pipDevicePosition = .front
        }
        CATransaction.commit()
        UIView.setAnimationsEnabled(true)
        CATransaction.setDisableActions(false)
    }
    
}

//MARK: - updateNormalizedPiPFrame
extension ViewController {
    
    private func updateNormalizedPiPFrame() {
        let fullScreenVideoPreviewView: PreviewView
        let pipVideoPreviewView: PreviewView
        switch pipDevicePosition {
        case .back:
            fullScreenVideoPreviewView = frontCameraVideoPreviewView
            pipVideoPreviewView = backCameraVideoPreviewView
        case .front:
            fullScreenVideoPreviewView = backCameraVideoPreviewView
            pipVideoPreviewView = frontCameraVideoPreviewView
        default:
            fatalError("Unexpected pip device position: \(pipDevicePosition)")
        }
        let pipFrameInFullScreenVideoPreview = pipVideoPreviewView.convert(pipVideoPreviewView.bounds, to: fullScreenVideoPreviewView)
        let normalizedTransform = CGAffineTransform(scaleX: 1.0 / fullScreenVideoPreviewView.frame.width, y: 1.0 / fullScreenVideoPreviewView.frame.height)
        normalizedPipFrame = pipFrameInFullScreenVideoPreview.applying(normalizedTransform)
    }
    
}

//MARK: - saveMovieToPhotoLibrary
extension ViewController {
    
    func saveMovieToPhotoLibrary(_ movieURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // Save the movie file to the photo library and clean up.
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .video, fileURL: movieURL, options: options)
                }, completionHandler: { success, error in
                    if !success {
                        debugPrint("\(Bundle.main.applicationName) couldn't save the movie to your photo library: \(String(describing: error))")
                    } else {
                        // Clean up
                        if FileManager.default.fileExists(atPath: movieURL.path) {
                            do {
                                try FileManager.default.removeItem(atPath: movieURL.path)
                            } catch {
                                debugPrint("Could not remove file at url: \(movieURL)")
                            }
                        }
                        if let currentBackgroundRecordingID = self.backgroundRecordingID {
                            self.backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                            if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                                UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                            }
                        }
                    }
                })
            } else {
                self.showAlert(message: "\(Bundle.main.applicationName) does not have permission to access the photo library", actionButtonTitle: "OK", actionFirst: nil)
            }
        }
    }
    
}

//MARK: Camera Control
extension ViewController {
    
    public func startVideoRecording() {
        dataOutputQueue.async {
        
            let isRecording = self.movieRecorder?.isRecording ?? false
            if !isRecording {
                if UIDevice.current.isMultitaskingSupported {
                    self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                }
                
                guard let audioSettings = self.helperClasss.createAudioSettings(backMicrophoneAudioDataOutput: self.backMicrophoneAudioDataOutput, frontMicrophoneAudioDataOutput: self.frontMicrophoneAudioDataOutput) else {
                    debugPrint("Could not create audio settings")
                    return
                }
                
                guard let videoSettings = self.helperClasss.createVideoSettings(backCameraVideoDataOutput: self.backCameraVideoDataOutput, frontCameraVideoDataOutput: self.frontCameraVideoDataOutput) else {
                    debugPrint("Could not create video settings")
                    return
                }
                
                guard let videoTransform = self.helperClasss.createVideoTransform(backCameraVideoDataOutput: self.backCameraVideoDataOutput) else {
                    debugPrint("Could not create video transform")
                    return
                }
                
                self.movieRecorder = MovieRecorder(audioSettings: audioSettings,
                                                   videoSettings: videoSettings,
                                                   videoTransform: videoTransform)
                self.timeOffset = CMTime(value: 0, timescale: 0)
                self.movieRecorder?.startRecording()
            } else {
                self.movieRecorder?.stopRecording { movieURL in
                    self.saveMovieToPhotoLibrary(movieURL)
                    
                }
            }
        }
    }
    
    public func switchCamera(){
            print("Toggling Camera")
            togglePiP();
        }
    
    public func pauseCapture() {
        DispatchQueue.main.async {
            if(self.movieRecorder?.isRecording ?? false) {
                debugPrint("<<<<<<<<< Initiating pause capture")
                self.isRecordingPaused = true
                self.needToSetTimeOffset = true
            }
        }
    }
    
    public func resumeCapture() {
        DispatchQueue.main.async {
            if(self.movieRecorder?.isRecording ?? false) {
                debugPrint("<<<<<<<<< resuming capture")
                self.isRecordingPaused = false
            }
        }
    }
    
}
