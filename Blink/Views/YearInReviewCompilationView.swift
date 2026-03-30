import SwiftUI
import AVKit

/// Year in Review compilation view:
/// Auto-generates a highlight reel (30-second best moments compilation).
struct YearInReviewCompilationView: View {
    let year: Int
    let entries: [VideoEntry]
    let onDismiss: () -> Void

    @StateObject private var aiService = AIHighlightsService.shared
    @State private var isGenerating = false
    @State private var reelURL: URL?
    @State private var generationProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var player: AVPlayer?
    @State private var progressTimer: Timer?
    @State private var generationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var topEntries: [VideoEntry] {
        entries
            .filter { !$0.isLocked }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            Color(hex: "0a0a0a")
                .ignoresSafeArea()

            if isGenerating {
                generatingView
            } else if let url = reelURL {
                reelPlayerView(url: url)
            } else {
                setupView
            }
        }
    }

    private var setupView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Year ring
            YearInReviewGraphic()
                .frame(width: 220, height: 220)

            VStack(spacing: 10) {
                Text("\(year) in Blink")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("\(entries.count) moments captured")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            // Clips preview strip
            clipsPreviewStrip

            Spacer()

            VStack(spacing: 12) {
                Button {
                    generateReel()
                } label: {
                    HStack {
                        Image(systemName: "film")
                            .font(.system(size: 15))
                        Text("Generate My Reel")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "ff3b30"))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
                }
                .disabled(topEntries.isEmpty)
                .opacity(topEntries.isEmpty ? 0.5 : 1)

                Button {
                    onDismiss()
                } label: {
                    Text("Maybe Later")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var clipsPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(topEntries) { entry in
                    if let thumbURL = entry.thumbnailURL {
                        AsyncImage(url: thumbURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color(hex: "1e1e1e"))
                        }
                        .frame(width: 60, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var generatingView: some View {
        VStack(spacing: 24) {
            // Animated progress ring
            ZStack {
                Circle()
                    .stroke(Color(hex: "2a2a2a"), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: generationProgress)
                    .stroke(
                        Color(hex: "ff3b30"),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? .none : .linear(duration: 0.5), value: generationProgress)

                VStack(spacing: 2) {
                    Text("\(Int(generationProgress * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "f5f5f5"))
                    Text("compiling")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }

            VStack(spacing: 6) {
                Text("Creating your year in review…")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Selecting the best \(topEntries.count) moments")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
        }
    }

    private func reelPlayerView(url: URL) -> some View {
        VStack(spacing: 0) {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(Color.black)
                    .ignoresSafeArea()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                player?.pause()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                Text("\(year) in Blink")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(entries.count) moments, compiled")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 60)
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
        .onAppear {
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
            progressTimer?.invalidate()
            generationTask?.cancel()
        }
    }

    private func generateReel() {
        guard !topEntries.isEmpty else { return }
        isGenerating = true
        generationProgress = 0

        // Animate progress with stored timer
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if generationProgress < 0.9 {
                generationProgress += 0.05
            }
        }

        generationTask = Task {
            do {
                // First analyze to get highlights
                await aiService.analyzeHighlights(entries: entries)

                // Then generate reel from top entries
                let urls = topEntries.map { AIHighlightsService.AIHighlight(
                    id: UUID(),
                    entry: $0,
                    score: 0.5,
                    insightText: "",
                    insightType: .milestone,
                    timestamp: 0
                )}

                let url = try await aiService.generateHighlightReel(clips: urls, title: "\(year) in Blink")

                await MainActor.run {
                    generationProgress = 1.0
                }

                try? await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    isGenerating = false
                    reelURL = url
                    let player = AVPlayer(url: url)
                    self.player = player
                    player.play()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Year Progress Card (for year-end summary)

struct YearProgressCard: View {
    let clipsThisYear: Int
    let totalDays: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Year Progress")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "8a8a8a"))
                Spacer()
                Text("\(clipsThisYear)/\(totalDays) days")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "ff3b30"))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(Color(hex: "2a2a2a"))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "ff3b30"), Color(hex: "ff6b60")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
    }

    private var progress: CGFloat {
        CGFloat(clipsThisYear) / CGFloat(max(totalDays, 1))
    }
}

#Preview {
    YearInReviewCompilationView(
        year: 2025,
        entries: [],
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
