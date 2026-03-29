import SwiftUI
import AVKit

struct PlaybackView: View {
    let entry: VideoEntry
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .background(Color(hex: "3A3A3A"))
            videoPlayer
            Divider()
                .background(Color(hex: "3A3A3A"))
            controls
        }
        .frame(width: 480, height: 520)
        .background(Color(hex: "0A0A0A"))
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(Color(hex: "A0A0A0"))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(entry.formattedDate)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "FAFAFA"))

            Spacer()

            Button(action: shareClip) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(Color(hex: "FF3B30"))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(hex: "141414"))
    }

    private var videoPlayer: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .disabled(true)
            } else {
                Color(hex: "141414")
                    .overlay {
                        ProgressView()
                            .tint(Color(hex: "FF3B30"))
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0A0A0A"))
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Button(action: { seek(by: -5) }) {
                Image(systemName: "gobackward.5")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "A0A0A0"))
            }
            .buttonStyle(.plain)

            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "FF3B30"))
            }
            .buttonStyle(.plain)

            Button(action: { seek(by: 5) }) {
                Image(systemName: "goforward.5")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "A0A0A0"))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(entry.formattedDuration)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "A0A0A0"))
        }
        .padding(16)
        .background(Color(hex: "141414"))
    }

    private func setupPlayer() {
        player = AVPlayer(url: entry.clipURL)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            isPlaying = false
        }
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func seek(by seconds: Double) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: seconds, preferredTimescale: 600))
        player.seek(to: newTime)
    }

    private func shareClip() {
        let activityVC = NSSharingServicePicker(items: [entry.clipURL])
        if let button = NSApp.keyWindow?.firstResponder {
            // Show share sheet near the button
        }
    }
}

#Preview {
    PlaybackView(entry: .preview)
}
