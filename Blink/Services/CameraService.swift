import AVFoundation
import UIKit
import Combine

final class CameraService: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var recordedDuration: TimeInterval = 0
    @Published var error: CameraError?

    let session = AVCaptureSession()
    private var movieOutput: AVCaptureMovieFileOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var currentRecordingURL: URL?
    private var durationTimer: Timer?

    private let sessionQueue = DispatchQueue(label: "com.blink.camera.session")

    /// Maximum recording duration allowed (set from SubscriptionService).
    var maxRecordingDuration: TimeInterval = 30

    enum CameraError: LocalizedError {
        case cameraUnavailable
        case microphoneUnavailable
        case setupFailed
        case recordingFailed
        case storageFull
        case clipSaveFailed

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "Camera is not available"
            case .microphoneUnavailable: return "Microphone is not available"
            case .setupFailed: return "Failed to set up camera"
            case .recordingFailed: return "Recording failed"
            case .storageFull: return "Not enough storage space"
            case .clipSaveFailed: return "Failed to save clip"
            }
        }
    }

    override init() {
        super.init()
    }

    func requestPermissions() async -> Bool {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        var cameraGranted = cameraStatus == .authorized
        var micGranted = micStatus == .authorized

        if cameraStatus == .notDetermined {
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        }
        if micStatus == .notDetermined {
            micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }

        return cameraGranted && micGranted
    }

    func setupSession() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            DispatchQueue.main.async {
                self.error = .cameraUnavailable
            }
            session.commitConfiguration()
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
            }
        } catch {
            DispatchQueue.main.async {
                self.error = .cameraUnavailable
            }
            session.commitConfiguration()
            return
        }

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    audioDeviceInput = audioInput
                }
            } catch {
                // Audio is optional
            }
        }

        // Movie output
        let movieOutput = AVCaptureMovieFileOutput()
        movieOutput.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 600)
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            self.movieOutput = movieOutput
        }

        session.commitConfiguration()
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    func startRecording() -> URL? {
        guard let movieOutput = movieOutput, !movieOutput.isRecording else { return nil }

        let outputURL = VideoStore.shared.generateVideoURL()
        currentRecordingURL = outputURL

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)

        DispatchQueue.main.async {
            self.isRecording = true
            self.recordedDuration = 0
            self.startDurationTimer()
        }

        return outputURL
    }

    func stopRecording() {
        guard let movieOutput = movieOutput, movieOutput.isRecording else { return }
        movieOutput.stopRecording()
        stopDurationTimer()
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordedDuration += 0.1
            if self.recordedDuration >= self.maxRecordingDuration {
                self.stopRecording()
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordedDuration = 0
            self.stopDurationTimer()
        }

        if let error = error as NSError? {
            // Check for disk full
            if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError {
                DispatchQueue.main.async {
                    self.error = .storageFull
                }
            } else {
                DispatchQueue.main.async {
                    self.error = .recordingFailed
                }
            }
            print("Recording error: \(error)")
            return
        }

        // Check disk space before saving
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: outputFileURL.path)
            if let freeSpace = attrs[.systemFreeSize] as? Int64, freeSpace < 50_000_000 { // 50MB minimum
                DispatchQueue.main.async {
                    self.error = .storageFull
                }
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }
        } catch {
            print("Could not check disk space: \(error)")
        }

        // Save the video
        Task {
            let success = await VideoStore.shared.addVideo(at: outputFileURL)
            if success {
                // R5: Record clip for freemium daily count
                await MainActor.run {
                    SubscriptionService.shared.recordClipRecorded()
                }
            } else {
                await MainActor.run {
                    self.error = .clipSaveFailed
                }
            }
        }
    }
}
