import AVFoundation
import Foundation

@MainActor
class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentClipURL: URL?

    @Published var isAuthorized = false
    @Published var isRecording = false

    override init() {
        super.init()
        checkAuthorization()
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }

    func requestAuthorization() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.isAuthorized = granted
                if granted {
                    self?.setupSession()
                }
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(videoInput)

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Video output
        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            videoOutput = output
        }

        session.commitConfiguration()

        Task.detached { [session] in
            session.startRunning()
        }
    }

    func startRecording() {
        guard let output = videoOutput, !output.isRecording else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "blink_clip_\(Date().timeIntervalSince1970).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        currentClipURL = fileURL

        output.startRecording(to: fileURL, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() {
        videoOutput?.stopRecording()
        isRecording = false
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            if error == nil {
                // Save to VideoStore
                let entry = VideoEntry(
                    id: UUID().uuidString,
                    clipURL: outputFileURL,
                    recordedAt: Date(),
                    duration: output.recordedDuration
                )
                VideoStore.shared.addEntry(entry)
            }
            isRecording = false
        }
    }
}
