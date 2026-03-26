import SwiftUI
import AVKit

struct PlaybackView: View {
    let entry: VideoEntry
    let onDelete: () -> Void
    var onTrim: ((VideoEntry) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var showDeleteConfirm = false
    @State private var showTrim = false
    @State private var showShareSheet = false
    @State private var showSocialSheet = false
    @State private var showTitleEdit = false
    @State private var editedTitle = ""
    @State private var isExporting = false
    @State private var showExportError: ExportErrorState?
    @State private var playbackSpeed: Float = 1.0
    @State private var showSpeedPicker = false
    @ObservedObject private var videoStore = VideoStore.shared

    private let playbackSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    enum ExportErrorState: Identifiable {
        case failed
        case storageFull

        var id: String {
            switch self {
            case .failed: return "failed"
            case .storageFull: return "storageFull"
            }
        }
    }

    private var speedLabel: String {
        if playbackSpeed == 1.0 {
            return "1×"
        } else if playbackSpeed == floor(playbackSpeed) {
            return "\(Int(playbackSpeed))×"
        } else {
            return String(format: "%.2g×", playbackSpeed)
        }
    }

    private var daysAgoText: String {
        let days = Calendar.current.dateComponents([.day], from: entry.date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    private var currentEntry: VideoEntry {
        videoStore.entries.first { $0.id == entry.id } ?? entry
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Speed control overlay
            speedControlOverlay
        }
        .overlay(alignment: .top) {
            topBar
        }
        .overlay(alignment: .bottom) {
            bottomInfo
        }
        .onAppear {
            editedTitle = currentEntry.title ?? ""
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .confirmationDialog("Delete this clip?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                HapticService.shared.deleteAction()
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showTrim) {
            TrimView(
                entry: currentEntry,
                onSave: { newEntry in
                    onTrim?(newEntry)
                    showTrim = false
                },
                onCancel: {
                    showTrim = false
                }
            )
        }
        .sheet(isPresented: $showSocialSheet) {
            SocialShareSheet(entry: currentEntry) {
                showSocialSheet = false
            }
        }
        .sheet(isPresented: $showTitleEdit) {
            TitleEditSheet(
                currentTitle: currentEntry.title,
                defaultTitle: currentEntry.defaultTitle,
                onSave: { newTitle in
                    videoStore.updateTitle(for: currentEntry, title: newTitle)
                    editedTitle = newTitle
                    showTitleEdit = false
                },
                onCancel: {
                    showTitleEdit = false
                }
            )
        }
        .alert(item: $showExportError) { error in
            switch error {
            case .failed:
                return Alert(
                    title: Text("Export failed"),
                    message: Text("Couldn't save clip to Camera Roll. Make sure Blink has permission to save photos in Settings."),
                    dismissButton: .default(Text("OK"))
                )
            case .storageFull:
                return Alert(
                    title: Text("Storage full"),
                    message: Text("Your device is running out of space. Free up storage to export clips."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                HapticService.shared.buttonTap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")
            .accessibilityHint("Closes the video player and returns to the calendar.")

            Spacer()

            // Action buttons
            HStack(spacing: 0) {
                // Share / Export
                Button {
                    HapticService.shared.actionTap()
                    exportClip()
                } label: {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .accessibilityLabel("Export to Camera Roll")

                // Trim
                Button {
                    HapticService.shared.actionTap()
                    showTrim = true
                } label: {
                    Image(systemName: "scissors")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Trim clip")

                // Delete
                Button {
                    HapticService.shared.actionTap()
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Delete clip")

                // Social Share (R5)
                Button {
                    HapticService.shared.actionTap()
                    showSocialSheet = true
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share with friends")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        )
    }

    private var bottomInfo: some View {
        VStack(spacing: 8) {
            // Title
            Button {
                showTitleEdit = true
            } label: {
                HStack(spacing: 4) {
                    Text(currentEntry.displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }

            Text(currentEntry.formattedDate)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(hex: "8a8a8a"))

            Text(daysAgoText)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "666666"))

            // Duration
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(formatDuration(currentEntry.duration))
                    .font(.system(size: 11))
            }
            .foregroundColor(Color(hex: "666666"))
        }
        .padding(.bottom, 40)
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private func setupPlayer() {
        let player = AVPlayer(url: currentEntry.videoURL)
        self.player = player
        player.rate = playbackSpeed
        player.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }

    private func applyPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        player?.rate = speed
        HapticService.shared.speedChanged()
    }

    private var speedControlOverlay: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                // Speed picker button
                Button {
                    showSpeedPicker.toggle()
                    HapticService.shared.selectionChanged()
                } label: {
                    Text(speedLabel)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Playback speed: \(speedLabel)")
                .accessibilityHint("Double tap to change playback speed")
                .padding(.trailing, 16)
                .padding(.bottom, 140)
            }

            // Speed picker popover
            if showSpeedPicker {
                speedPicker
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
            }
        }
    }

    private var speedPicker: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Speed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "8a8a8a"))
                .padding(.trailing, 4)
                .padding(.bottom, 2)

            ForEach(playbackSpeeds, id: \.self) { speed in
                Button {
                    applyPlaybackSpeed(speed)
                    showSpeedPicker = false
                } label: {
                    HStack(spacing: 8) {
                        Text(speedLabelText(for: speed))
                            .font(.system(size: 14, weight: playbackSpeed == speed ? .bold : .medium))
                            .foregroundColor(playbackSpeed == speed ? Color(hex: "ff3b30") : .white)

                        if playbackSpeed == speed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "ff3b30"))
                        }
                    }
                    .frame(width: 90, alignment: .trailing)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(playbackSpeed == speed ? Color(hex: "ff3b30").opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("\(speedLabelText(for: speed)) playback speed")
                .accessibilityAddTraits(playbackSpeed == speed ? .isSelected : [])
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.trailing, 12)
        .padding(.bottom, 180)
    }

    private func speedLabelText(for speed: Float) -> String {
        if speed == 1.0 {
            return "Normal"
        } else if speed == 0.5 {
            return "0.5×"
        } else if speed == 0.75 {
            return "0.75×"
        } else if speed == floor(speed) {
            return "\(Int(speed))×"
        } else {
            return String(format: "%.2g×", speed)
        }
    }

    private func exportClip() {
        isExporting = true
        Task {
            do {
                try await videoStore.exportToCameraRoll(currentEntry)
                await MainActor.run {
                    isExporting = false
                    HapticService.shared.clipSaved()
                }
            } catch VideoStore.ExportError.saveFailed {
                await MainActor.run {
                    isExporting = false
                    showExportError = .failed
                    HapticService.shared.error()
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    showExportError = .failed
                    HapticService.shared.error()
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        if secs < 60 {
            return "\(secs)s"
        }
        let mins = secs / 60
        let rem = secs % 60
        return "\(mins)m \(rem)s"
    }
}

// MARK: - Title Edit Sheet

struct TitleEditSheet: View {
    let currentTitle: String?
    let defaultTitle: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clip Title")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "8a8a8a"))

                        TextField("Add a title…", text: $title)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(hex: "1e1e1e"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .tint(Color(hex: "ff3b30"))
                    }

                    Text("Default: \(defaultTitle)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "555555"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Edit Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "8a8a8a"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(title)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "ff3b30"))
                }
            }
        }
        .onAppear {
            title = currentTitle ?? ""
        }
    }
}

#Preview {
    PlaybackView(
        entry: VideoEntry(date: Date(), filename: "test.mov", duration: 15),
        onDelete: {},
        onTrim: nil
    )
}
