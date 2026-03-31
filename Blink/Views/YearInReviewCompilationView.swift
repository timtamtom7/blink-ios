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
            YearInReviewGraphic(clipCount: entries.count)
                .frame(width: 220, height: 220)

            VStack(spacing: 10) {
                Text("\(year) in Blink")
                    .font(BlinkFontStyle.largeTitle.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("\(entries.count) moments captured")
                    .font(BlinkFontStyle.body.font)
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
                            .font(BlinkFontStyle.body.font)
                        Text("Generate My Reel")
                            .font(BlinkFontStyle.title3.font)
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
                        .font(BlinkFontStyle.body.font)
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
                        .accessibilityLabel("Clip thumbnail")
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var generatingView: some View {
        VStack(spacing: 24) {
            // Animated progress ring (no fake percentage — tied to real work)
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

                Image(systemName: "film")
                    .font(BlinkFontStyle.lockIconMedium.font)
                    .foregroundColor(Color(hex: "ff3b30"))
            }

            VStack(spacing: 6) {
                Text("Creating your reel…")
                    .font(BlinkFontStyle.title3.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Selecting the best \(topEntries.count) moments")
                    .font(BlinkFontStyle.callout.font)
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
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                Text("\(year) in Blink")
                    .font(BlinkFontStyle.title3.font)
                    .foregroundColor(.white)

                Text("\(entries.count) moments, compiled")
                    .font(BlinkFontStyle.subheadline.font)
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
            generationTask?.cancel()
        }
    }

    private func generateReel() {
        guard !topEntries.isEmpty else { return }
        isGenerating = true
        generationProgress = 0

        generationTask = Task {
            do {
                // Analyze all entries and track real progress
                let total = entries.count
                for (index, _) in entries.enumerated() {
                    if Task.isCancelled { return }
                    await aiService.analyzeHighlights(entries: [entries[index]])
                    await MainActor.run {
                        generationProgress = 0.3 * Double(index + 1) / Double(max(total, 1))
                    }
                }

                // Then generate reel from top entries
                let urls = topEntries.map { AIHighlightsService.AIHighlight(
                    id: UUID(),
                    entry: $0,
                    score: 0.5,
                    insightText: "",
                    insightType: .milestone,
                    timestamp: 0
                )}

                await MainActor.run {
                    generationProgress = 0.7
                }

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
                    .font(BlinkFontStyle.callout.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                Spacer()
                Text("\(clipsThisYear)/\(totalDays) days")
                    .font(BlinkFontStyle.footnote.font)
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
