import SwiftUI
import AVFoundation

struct RecordView: View {
    @StateObject private var cameraService = CameraService()
    @ObservedObject private var videoStore = VideoStore.shared
    @StateObject private var subscription = SubscriptionService.shared

    @State private var showCountdown = false
    @State private var countdownValue = 3
    @State private var showSaved = false
    @State private var cameraPermissionGranted = false
    @State private var microphonePermissionGranted = false
    @State private var showCameraPermissionAlert = false
    @State private var showMicrophonePermissionAlert = false
    @State private var showStorageFullError = false
    @State private var showClipSaveFailedError = false
    @State private var selectedPlaybackEntry: VideoEntry?
    @State private var showFreemiumEnforcement = false
    @State private var freemiumBlockReason = ""
    @State private var showPricing = false

    private var maxDuration: TimeInterval {
        subscription.maxRecordingDuration
    }
    private let recordButtonSize: CGFloat = 80

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if !cameraPermissionGranted {
                    CameraPermissionDeniedView()
                } else if !microphonePermissionGranted {
                    MicrophonePermissionDeniedView()
                } else if showStorageFullError {
                    StorageFullView(onDismiss: {
                        showStorageFullError = false
                    })
                } else if showClipSaveFailedError {
                    ClipSaveFailedView(
                        onRetry: {
                            showClipSaveFailedError = false
                            // Retry would require re-recording - just reset state
                        },
                        onDiscard: {
                            showClipSaveFailedError = false
                        }
                    )
                } else {
                    cameraView
                }

                if showCountdown {
                    countdownOverlay
                }

                if showSaved {
                    savedOverlay
                }

                if showFreemiumEnforcement {
                    FreemiumEnforcementView(
                        reason: freemiumBlockReason,
                        onUpgrade: {
                            showFreemiumEnforcement = false
                            showPricing = true
                        },
                        onDismiss: {
                            showFreemiumEnforcement = false
                        }
                    )
                    .transition(.opacity)
                }
            }
            .navigationTitle("Blink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await checkPermissions()
        }
        .onChange(of: cameraService.error) { _, error in
            if let error = error {
                handleCameraError(error)
            }
        }
        .fullScreenCover(item: $selectedPlaybackEntry) { entry in
            PlaybackView(entry: entry, onDelete: {
                videoStore.deleteEntry(entry)
                selectedPlaybackEntry = nil
            })
        }
        .sheet(isPresented: $showPricing) {
            PricingView()
        }
    }

    private var cameraView: some View {
        VStack(spacing: 0) {
            // Viewfinder frame
            viewfinderFrame
                .padding(.horizontal, 16)
                .padding(.top, 20)

            Spacer()

            recordButton
                .padding(.bottom, 24)

            bottomInfo
                .padding(.bottom, 40)
        }
    }

    private var viewfinderFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "333333"), lineWidth: 1)

            CameraPreview(session: cameraService.session)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // REC indicator
            VStack {
                HStack {
                    if cameraService.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: "ff3b30"))
                                .frame(width: 8, height: 8)
                            Text("REC")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "ff3b30"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(12)

                Spacer()
            }
        }
        .aspectRatio(9/16, contentMode: .fit)
        .onAppear {
            cameraService.maxRecordingDuration = subscription.maxRecordingDuration
            cameraService.setupSession()
            cameraService.startSession()
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }

    private var recordButton: some View {
        Button {
            handleRecordTap()
        } label: {
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Color(hex: "333333"), lineWidth: 4)
                    .frame(width: recordButtonSize, height: recordButtonSize)

                // Progress fill
                Circle()
                    .trim(from: 0, to: CGFloat(cameraService.recordedDuration / maxDuration))
                    .stroke(Color(hex: "ff3b30"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: recordButtonSize, height: recordButtonSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: cameraService.recordedDuration)

                // Main button
                Circle()
                    .fill(cameraService.isRecording ? Color(hex: "ff3b30") : Color.white)
                    .frame(width: recordButtonSize - 16, height: recordButtonSize - 16)

                // Timer text
                if cameraService.isRecording {
                    Text(timerText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(showCountdown)
    }

    private var timerText: String {
        let elapsed = Int(cameraService.recordedDuration)
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var bottomInfo: some View {
        VStack(spacing: 16) {
            if let todayEntry = videoStore.entryForDate(Date()) {
                Button {
                    selectedPlaybackEntry = todayEntry
                } label: {
                    Text("Last clip: \(todayEntry.formattedDate)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            } else {
                Text("No clip recorded today")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            Text("This year: \(videoStore.clipCountThisYear()) clips")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "f5f5f5"))
        }
    }

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            Text("\(countdownValue)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .transition(.scale.combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: countdownValue)
    }

    private var savedOverlay: some View {
        ZStack {
            Color.white.opacity(0.15)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "ff3b30"))

                Text("Saved")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))
            }
        }
        .transition(.opacity)
    }

    private func handleRecordTap() {
        if cameraService.isRecording {
            cameraService.stopRecording()
            showSavedAnimation()
        } else {
            // R5 Freemium: check daily limit before recording
            if let reason = subscription.blockReasonForRecording() {
                freemiumBlockReason = reason
                withAnimation {
                    showFreemiumEnforcement = true
                }
                return
            }
            startCountdown()
        }
    }

    private func startCountdown() {
        showCountdown = true
        countdownValue = 3

        Task {
            for i in [3, 2, 1] {
                countdownValue = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            showCountdown = false
            _ = cameraService.startRecording()
        }
    }

    private func showSavedAnimation() {
        withAnimation {
            showSaved = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation {
                showSaved = false
            }
        }
    }

    private func checkPermissions() async {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        var cameraGranted = videoStatus == .authorized
        var micGranted = audioStatus == .authorized

        if videoStatus == .notDetermined {
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        }
        if audioStatus == .notDetermined {
            micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }

        await MainActor.run {
            cameraPermissionGranted = cameraGranted
            microphonePermissionGranted = micGranted
        }
    }

    private func handleCameraError(_ error: CameraService.CameraError) {
        switch error {
        case .recordingFailed:
            showClipSaveFailedError = true
        case .cameraUnavailable:
            cameraPermissionGranted = false
        case .microphoneUnavailable:
            microphonePermissionGranted = false
        case .setupFailed:
            showClipSaveFailedError = true
        case .storageFull:
            showStorageFullError = true
        case .clipSaveFailed:
            showClipSaveFailedError = true
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    RecordView()
        .preferredColorScheme(.dark)
}
