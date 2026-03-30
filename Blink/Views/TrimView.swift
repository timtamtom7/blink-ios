import SwiftUI
import AVKit
import AVFoundation

// MARK: - Trim View

struct TrimView: View {
    let entry: VideoEntry
    let onSave: (VideoEntry) -> Void
    let onCancel: () -> Void

    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 30
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var isSaving = false
    @State private var showError: TrimErrorState?
    @State private var saveMode: SaveMode = .new
    @State private var setupTask: Task<Void, Never>?
    @State private var saveTask: Task<Void, Never>?

    enum SaveMode {
        case new
        case overwrite
    }

    enum TrimErrorState: Identifiable {
        case exportFailed
        case storageFull
        case sourceNotFound

        var id: String {
            switch self {
            case .exportFailed: return "exportFailed"
            case .storageFull: return "storageFull"
            case .sourceNotFound: return "sourceNotFound"
            }
        }
    }

    private var trimmedDuration: Double {
        max(0, endTime - startTime)
    }

    private var trimmedDurationText: String {
        let secs = Int(trimmedDuration)
        if secs < 60 {
            return "\(secs)s"
        }
        let mins = secs / 60
        let rem = secs % 60
        return "\(mins)m \(rem)s"
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.top, 8)

                // Video preview
                videoPreview
                    .frame(maxHeight: .infinity)

                // Timeline scrubber
                timelineScrubber
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                // Time labels
                timeLabels
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
            setupTask?.cancel()
            saveTask?.cancel()
        }
        .alert(item: $showError) { error in
            switch error {
            case .exportFailed:
                return Alert(
                    title: Text("Trim failed"),
                    message: Text("Something went wrong saving your trimmed clip. Try again or save as a new clip."),
                    dismissButton: .default(Text("OK"))
                )
            case .storageFull:
                return Alert(
                    title: Text("Storage full"),
                    message: Text("Your device is running out of space. Free up storage and try again."),
                    dismissButton: .default(Text("OK"))
                )
            case .sourceNotFound:
                return Alert(
                    title: Text("Clip not found"),
                    message: Text("The original clip could not be found. It may have been deleted."),
                    dismissButton: .default(Text("OK")) {
                        onCancel()
                    }
                )
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                HapticService.shared.buttonTap()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
            .accessibilityLabel("Cancel trim")

            Spacer()

            Text("Trim")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button {
                HapticService.shared.actionTap()
                saveTrimmed()
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "ff3b30"))
                }
            }
            .disabled(isSaving)
            .accessibilityLabel("Save trimmed clip")
        }
        .padding(.horizontal, 16)
    }

    private var videoPreview: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                Color(hex: "1a1a1a")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        .padding(.horizontal, 16)
    }

    private var timelineScrubber: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let handleWidth: CGFloat = 20

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(Color(hex: "1e1e1e"))
                    .frame(height: 48)

                // Selected range
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(Color(hex: "ff3b30").opacity(0.3))
                    .frame(
                        width: max(0, xForTime(endTime, width: width, handleWidth: handleWidth) - xForTime(startTime, width: width, handleWidth: handleWidth)),
                        height: 48
                    )
                    .offset(x: xForTime(startTime, width: width, handleWidth: handleWidth))

                // Waveform / progress bar
                WaveformBar(duration: duration, currentTime: currentTime)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))

                // Start handle
                TrimHandle(isStart: true)
                    .frame(width: handleWidth, height: 48)
                    .offset(x: xForTime(startTime, width: width, handleWidth: handleWidth) - handleWidth / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingStart = true
                                let newTime = timeForX(value.location.x, width: width, handleWidth: handleWidth)
                                startTime = max(0, min(newTime, endTime - 1))
                                player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                                HapticService.shared.trimHandleMoved()
                            }
                            .onEnded { _ in
                                isDraggingStart = false
                            }
                    )
                    .accessibilityLabel("Trim start handle")
                    .accessibilityValue("Currently at \(formatTime(startTime))")

                // End handle
                TrimHandle(isStart: false)
                    .frame(width: handleWidth, height: 48)
                    .offset(x: xForTime(endTime, width: width, handleWidth: handleWidth) - handleWidth / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingEnd = true
                                let newTime = timeForX(value.location.x, width: width, handleWidth: handleWidth)
                                endTime = max(startTime + 1, min(newTime, duration))
                                player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                                HapticService.shared.trimHandleMoved()
                            }
                            .onEnded { _ in
                                isDraggingEnd = false
                            }
                    )
                    .accessibilityLabel("Trim end handle")
                    .accessibilityValue("Currently at \(formatTime(endTime))")

                // Playhead
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 56)
                    .offset(x: xForTime(currentTime, width: width, handleWidth: handleWidth) - 1)
                    .opacity(isDraggingStart || isDraggingEnd ? 0 : 1)
            }
        }
        .frame(height: 48)
        .onTapGesture { location in
            // Tap to seek
        }
    }

    private var timeLabels: some View {
        HStack {
            Text(formatTime(startTime))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "ff3b30"))

            Spacer()

            Text("Selected: \(trimmedDurationText)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "8a8a8a"))

            Spacer()

            Text(formatTime(endTime))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "ff3b30"))
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Playback controls
            HStack(spacing: 40) {
                Button {
                    let newTime = max(0, startTime - 5)
                    startTime = newTime
                    endTime = min(newTime + 30, duration)
                    seekToStart()
                    HapticService.shared.buttonTap()
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Skip back 5 seconds")

                Button {
                    HapticService.shared.buttonTap()
                    togglePlayback()
                } label: {
                    Image(systemName: player?.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .accessibilityLabel(player?.timeControlStatus == .playing ? "Pause" : "Play")

                Button {
                    let newTime = min(duration, endTime + 5)
                    endTime = newTime
                    startTime = max(0, newTime - 30)
                    seekToEnd()
                    HapticService.shared.buttonTap()
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Skip forward 5 seconds")
            }

            // Save mode picker
            HStack(spacing: 12) {
                Button {
                    HapticService.shared.selectionChanged()
                    saveMode = .new
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: saveMode == .new ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                        Text("Save as new clip")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(saveMode == .new ? Color(hex: "ff3b30") : Color(hex: "8a8a8a"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(saveMode == .new ? Color(hex: "ff3b30").opacity(0.15) : Color(hex: "1e1e1e"))
                    .clipShape(Capsule())
                }
                .accessibilityAddTraits(saveMode == .new ? .isSelected : [])

                Button {
                    HapticService.shared.selectionChanged()
                    saveMode = .overwrite
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: saveMode == .overwrite ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                        Text("Replace original")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(saveMode == .overwrite ? Color(hex: "ff3b30") : Color(hex: "8a8a8a"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(saveMode == .overwrite ? Color(hex: "ff3b30").opacity(0.15) : Color(hex: "1e1e1e"))
                    .clipShape(Capsule())
                }
                .accessibilityAddTraits(saveMode == .overwrite ? .isSelected : [])
            }
        }
    }

    // MARK: - Helpers

    private func setupPlayer() {
        let player = AVPlayer(url: entry.videoURL)
        self.player = player

        setupTask = Task {
            let asset = AVURLAsset(url: entry.videoURL)
            let d = try? await asset.load(.duration).seconds
            await MainActor.run {
                self.duration = d ?? entry.duration
                self.endTime = min(self.duration, 30)
            }
        }

        // Update current time
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { time in
            let secs = time.seconds
            self.currentTime = secs

            // Loop within trim range
            if secs >= self.endTime - 0.1 {
                self.seekToStart()
            }
        }

        player.play()
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            if currentTime >= endTime - 0.1 {
                seekToStart()
            }
            player.play()
        }
    }

    private func seekToStart() {
        player?.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
    }

    private func seekToEnd() {
        player?.seek(to: CMTime(seconds: max(startTime, endTime - 1), preferredTimescale: 600))
    }

    private func xForTime(_ time: Double, width: CGFloat, handleWidth: CGFloat) -> CGFloat {
        let trackWidth = width - handleWidth
        return (CGFloat(time / max(duration, 1)) * trackWidth) + handleWidth / 2
    }

    private func timeForX(_ x: CGFloat, width: CGFloat, handleWidth: CGFloat) -> Double {
        let trackWidth = width - handleWidth
        let clampedX = max(handleWidth / 2, min(x, width - handleWidth / 2))
        return Double((clampedX - handleWidth / 2) / trackWidth) * duration
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func saveTrimmed() {
        isSaving = true
        saveTask = Task {
            do {
                let newEntry = try await VideoStore.shared.trimClip(
                    entry,
                    startTime: startTime,
                    endTime: endTime,
                    saveAsNew: saveMode == .new
                )
                await MainActor.run {
                    isSaving = false
                    HapticService.shared.trimSaved()
                    onSave(newEntry)
                }
            } catch VideoStore.TrimError.storageFull {
                await MainActor.run {
                    isSaving = false
                    HapticService.shared.error()
                    showError = .storageFull
                }
            } catch VideoStore.TrimError.sourceNotFound {
                await MainActor.run {
                    isSaving = false
                    HapticService.shared.error()
                    showError = .sourceNotFound
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    HapticService.shared.error()
                    showError = .exportFailed
                }
            }
        }
    }
}

// MARK: - Trim Handle

struct TrimHandle: View {
    let isStart: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                .fill(Color(hex: "ff3b30"))

            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 2)
                }
            }
        }
    }
}

// MARK: - Waveform Bar (simplified visualization)

struct WaveformBar: View {
    let duration: Double
    let currentTime: Double

    private let barCount = 60

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let progress = Double(i) / Double(barCount)
                    let isPast = progress <= (currentTime / max(duration, 1))

                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPast ? Color(hex: "ff3b30") : Color(hex: "444444"))
                        .frame(height: barHeight(for: i, totalWidth: geometry.size.width))
                }
            }
        }
    }

    private func barHeight(for index: Int, totalWidth: CGFloat) -> CGFloat {
        let seed = sin(Double(index) * 0.7) * 0.5 + 0.5
        let seed2 = cos(Double(index) * 1.3) * 0.5 + 0.5
        return CGFloat(10 + seed * 28 + seed2 * 10)
    }
}

#Preview {
    TrimView(
        entry: VideoEntry(date: Date(), filename: "test.mov", duration: 30),
        onSave: { _ in },
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
