import SwiftUI
import AVFoundation

struct RecordView: View {
    @StateObject private var cameraService = CameraService()
    @ObservedObject private var videoStore = VideoStore.shared
    @StateObject private var subscription = SubscriptionService.shared
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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
    @State private var hasWarnedDuration = false
    @State private var isCameraSettingUp = true
    @State private var countdownTask: Task<Void, Never>?
    @State private var savedAnimationTask: Task<Void, Never>?

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
                .overlay {
                    if isCameraSettingUp {
                        ZStack {
                            Color.black.opacity(0.6)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))

                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(Color(hex: "ff3b30"))
                                    .scaleEffect(1.5)
                                Text("Setting up camera...")
                                    .font(BlinkFontStyle.callout.font)
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }
                        }
                    }
                }

            Spacer()

            recordButton
                .padding(.bottom, 24)

            bottomInfo
                .padding(.bottom, 40)
        }
    }

    private var viewfinderFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge)
                .stroke(Color(hex: "333333"), lineWidth: 1)

            CameraPreview(session: cameraService.session)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))

            // REC indicator
            VStack {
                HStack {
                    if cameraService.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: "ff3b30"))
                                .frame(width: 8, height: 8)
                            Text("REC")
                                .font(BlinkFontStyle.monospacedFootnote.font)
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
            // Wait for session to actually be running before hiding the loading overlay
            Task {
                await waitForSessionReady()
            }
        }
        .onDisappear {
            cameraService.stopSession()
            countdownTask?.cancel()
            savedAnimationTask?.cancel()
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
                        .font(BlinkFontStyle.timerText.font)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(showCountdown)
        .accessibilityLabel(cameraService.isRecording ? "Stop recording. Tap to stop." : "Start recording. Tap to begin.")
        .accessibilityHint(cameraService.isRecording ? "Stops recording and saves the clip." : "Starts a countdown, then begins recording.")
        .onChange(of: cameraService.recordedDuration) { oldValue, newValue in
            // Warn when 5 seconds remain
            if cameraService.isRecording {
                let remaining = maxDuration - newValue
                if remaining > 0 && remaining <= 5 && !hasWarnedDuration {
                    hasWarnedDuration = true
                    HapticService.shared.durationWarning()
                }
            }
        }
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
                        .font(BlinkFontStyle.subheadline.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
                .accessibilityLabel("Last clip from \(todayEntry.formattedDate)")
                .accessibilityHint("Double tap to view this clip")
            } else {
                Text("No clip recorded today")
                    .font(BlinkFontStyle.subheadline.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .accessibilityLabel("No clip recorded today")
                    .accessibilityHint("Record your first clip to start your Blink diary")
            }

            Text("This year: \(videoStore.clipCountThisYear()) clips")
                .font(BlinkFontStyle.subheadline.font)
                .foregroundColor(Color(hex: "f5f5f5"))
                .accessibilityLabel("\(videoStore.clipCountThisYear()) clips recorded this year")
        }
    }

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Recording starting in \(countdownValue)")

            Text("\(countdownValue)")
                .font(BlinkFontStyle.countdown.font)
                .foregroundColor(.white)
        }
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: countdownValue)
    }

    private var savedOverlay: some View {
        ZStack {
            Color.white.opacity(0.15)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(BlinkFontStyle.displayExtraLarge.font)
                    .foregroundColor(Color(hex: "ff3b30"))

                Text("Saved")
                    .font(BlinkFontStyle.title2.font)
                    .foregroundColor(Color(hex: "f5f5f5"))
            }
        }
        .transition(reduceMotion ? .opacity : .opacity)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: showSaved)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clip saved successfully")
    }

    private func handleRecordTap() {
        if cameraService.isRecording {
            HapticService.shared.recordingStopped()
            cameraService.stopRecording()
            showSavedAnimation()
        } else {
            // R5 Freemium: check daily limit before recording
            if let reason = subscription.blockReasonForRecording() {
                freemiumBlockReason = reason
                withAnimation {
                    showFreemiumEnforcement = true
                }
                HapticService.shared.error()
                return
            }
            startCountdown()
        }
    }

    private func startCountdown() {
        HapticService.shared.recordButtonTap()
        showCountdown = true
        countdownValue = 3
        hasWarnedDuration = false

        countdownTask = Task {
            for i in [3, 2, 1] {
                countdownValue = i
                HapticService.shared.countdownTick()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            showCountdown = false
            HapticService.shared.countdownComplete()
            _ = cameraService.startRecording()
            HapticService.shared.recordingStarted()
        }
    }

    private func showSavedAnimation() {
        withAnimation {
            showSaved = true
        }
        HapticService.shared.clipSaved()

        savedAnimationTask = Task {
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

    private func waitForSessionReady() async {
        let session = cameraService.session
        // Poll isRunning — this is the proper session-ready signal, not a fixed delay
        while !session.isRunning {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        await MainActor.run {
            isCameraSettingUp = false
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
