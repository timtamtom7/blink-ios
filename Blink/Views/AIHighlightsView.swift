import SwiftUI
import AVKit

/// AI Highlights view: shows the top meaningful moments with AI-generated insights.
struct AIHighlightsView: View {
    @StateObject private var aiService = AIHighlightsService.shared
    @ObservedObject private var videoStore = VideoStore.shared
    @State private var showReelGeneration = false
    @State private var isGeneratingReel = false
    @State private var reelURL: URL?
    @State private var showReelError: String?
    @State private var selectedHighlight: AIHighlightsService.AIHighlight?
    @State private var analyzeTask: Task<Void, Never>?
    @State private var reelTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if aiService.isAnalyzing {
                    analyzingView
                } else if aiService.highlights.isEmpty {
                    emptyState
                } else {
                    highlightsList
                }

                if showReelGeneration {
                    reelGenerationOverlay
                }
            }
            .navigationTitle("AI Highlights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !aiService.highlights.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            generateReel()
                        } label: {
                            Image(systemName: "film")
                                .font(BlinkFontStyle.body.font)
                                .foregroundColor(Color(hex: "ff3b30"))
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedHighlight) { highlight in
                HighlightPlaybackView(highlight: highlight)
            }
            .sheet(item: Binding(
                get: { reelURL.map { ReelSheetItem(url: $0) } },
                set: { reelURL = $0?.url }
            )) { item in
                HighlightReelView(reelURL: item.url) {
                    reelURL = nil
                }
            }
            .alert("Reel Error", isPresented: Binding(
                get: { showReelError != nil },
                set: { if !$0 { showReelError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(showReelError ?? "")
            }
            .task {
                if aiService.highlights.isEmpty {
                    await aiService.analyzeHighlights(entries: videoStore.entries)
                }
            }
            .onDisappear {
                analyzeTask?.cancel()
                reelTask?.cancel()
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(Color(hex: "ff3b30"))
                .scaleEffect(1.5)

            VStack(spacing: 6) {
                Text("Analyzing your clips…")
                    .font(BlinkFontStyle.title3.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Finding your most meaningful moments")
                    .font(BlinkFontStyle.callout.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(BlinkFontStyle.displayHero.font)
                .foregroundColor(Color(hex: "333333"))

            VStack(spacing: 6) {
                Text("No highlights yet")
                    .font(BlinkFontStyle.title3.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Record more clips to discover\nyour most meaningful moments.")
                    .font(BlinkFontStyle.callout.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
            }

            Button {
                analyzeTask = Task {
                    await aiService.analyzeHighlights(entries: videoStore.entries)
                }
            } label: {
                Text("Analyze Now")
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(.white)
                    .frame(width: 160, height: 44)
                    .background(Color(hex: "ff3b30"))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
            }
            .padding(.top, 8)
        }
        .padding(40)
    }

    private var highlightsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Year insights header
                yearInsightsHeader

                // Top highlight (hero card)
                if let topHighlight = aiService.highlights.first {
                    heroHighlightCard(topHighlight)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }

                // All highlights
                VStack(spacing: 12) {
                    ForEach(Array(aiService.highlights.dropFirst().enumerated()), id: \.element.id) { index, highlight in
                        highlightRow(highlight, rank: index + 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    private var yearInsightsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Year")
                .font(BlinkFontStyle.title2.font)
                .foregroundColor(Color(hex: "f5f5f5"))

            let insights = aiService.yearInsights(entries: videoStore.entries)
            ForEach(insights, id: \.self) { insight in
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(BlinkFontStyle.caption.font)
                        .foregroundColor(Color(hex: "ff3b30"))
                    Text(insight)
                        .font(BlinkFontStyle.subheadline.font)
                        .foregroundColor(Color(hex: "c0c0c0"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func heroHighlightCard(_ highlight: AIHighlightsService.AIHighlight) -> some View {
        Button {
            selectedHighlight = highlight
        } label: {
            VStack(spacing: 0) {
                // Thumbnail
                ZStack {
                    if let thumbURL = highlight.entry.thumbnailURL {
                        AsyncImage(url: thumbURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color(hex: "1e1e1e"))
                        }
                        .frame(height: 200)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(hex: "1e1e1e"))
                            .frame(height: 200)
                    }

                    // Top badge
                    VStack {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(BlinkFontStyle.footnote.font)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "ff3b30"))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(12)

                        Spacer()
                    }

                    // Play button
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(BlinkFontStyle.title2.font)
                                .foregroundColor(Color(hex: "0a0a0a"))
                                .offset(x: 1)
                        )
                }

                // AI insight
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: highlight.insightType.icon)
                            .font(BlinkFontStyle.callout.font)
                            .foregroundColor(Color(hex: "ff3b30"))

                        Text(highlight.insightText)
                            .font(BlinkFontStyle.body.font)
                            .foregroundColor(Color(hex: "f5f5f5"))
                            .lineLimit(2)
                    }

                    HStack {
                        Text(highlight.entry.displayTitle)
                            .font(BlinkFontStyle.footnote.font)
                            .foregroundColor(Color(hex: "8a8a8a"))

                        Spacer()

                        Text("Tap to watch")
                            .font(BlinkFontStyle.caption.font)
                            .foregroundColor(Color(hex: "ff3b30"))
                    }
                }
                .padding(14)
                .background(Color(hex: "141414"))
            }
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge)
                    .stroke(Color(hex: "ff3b30").opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func highlightRow(_ highlight: AIHighlightsService.AIHighlight, rank: Int) -> some View {
        Button {
            selectedHighlight = highlight
        } label: {
            HStack(spacing: 12) {
                // Rank
                Text("#\(rank)")
                    .font(BlinkFontStyle.monospacedFootnote.font)
                    .foregroundColor(Color(hex: "ff3b30"))
                    .frame(width: 28)

                // Thumbnail
                if let thumbURL = highlight.entry.thumbnailURL {
                    AsyncImage(url: thumbURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color(hex: "1e1e1e"))
                    }
                    .frame(width: 56, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                } else {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 56, height: 40)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: highlight.insightType.icon)
                            .font(BlinkFontStyle.caption2.font)
                            .foregroundColor(Color(hex: "ff3b30"))
                        Text(highlight.insightText)
                            .font(BlinkFontStyle.subheadline.font)
                            .foregroundColor(Color(hex: "f5f5f5"))
                            .lineLimit(1)
                    }

                    Text(highlight.entry.formattedDate)
                        .font(BlinkFontStyle.caption.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                }

                Spacer()

                // Score indicator
                Circle()
                    .trim(from: 0, to: highlight.score)
                    .stroke(Color(hex: "ff3b30"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                    .overlay(
                        Text("\(Int(highlight.score * 100))")
                            .font(BlinkFontStyle.microBold.font)
                            .foregroundColor(Color(hex: "f5f5f5"))
                    )
            }
            .padding(10)
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        }
    }

    private var reelGenerationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if isGeneratingReel {
                    ProgressView()
                        .tint(Color(hex: "ff3b30"))
                        .scaleEffect(1.5)

                    VStack(spacing: 6) {
                        Text("Creating your reel…")
                            .font(BlinkFontStyle.title3.font)
                            .foregroundColor(Color(hex: "f5f5f5"))

                        Text("Compiling your best moments")
                            .font(BlinkFontStyle.callout.font)
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                }
            }
        }
    }

    private func generateReel() {
        showReelGeneration = true
        isGeneratingReel = true

        reelTask = Task {
            do {
                let url = try await aiService.generateHighlightReel(clips: aiService.highlights)
                await MainActor.run {
                    isGeneratingReel = false
                    showReelGeneration = false
                    reelURL = url
                }
            } catch {
                await MainActor.run {
                    isGeneratingReel = false
                    showReelGeneration = false
                    showReelError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Highlight Reel View (full-screen player)

struct HighlightReelView: View {
    let reelURL: URL
    let onDismiss: () -> Void

    @State private var player: AVPlayer?

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
        .onAppear {
            let player = AVPlayer(url: reelURL)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}

// MARK: - Highlight Playback View

struct HighlightPlaybackView: View {
    let highlight: AIHighlightsService.AIHighlight
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var loopObserverToken: NSObjectProtocol?

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
        }
        .overlay(alignment: .top) {
            VStack {
                HStack {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(BlinkFontStyle.body.font)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    // AI insight badge
                    HStack(spacing: 6) {
                        Image(systemName: highlight.insightType.icon)
                            .font(BlinkFontStyle.caption.font)
                        Text(highlight.insightText)
                            .font(BlinkFontStyle.subheadline.font)
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())

                    Spacer()

                    // Placeholder for balance
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                    .allowsHitTesting(false)
                )

                Spacer()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            if let token = loopObserverToken {
                NotificationCenter.default.removeObserver(token)
                loopObserverToken = nil
            }
        }
    }

    private func setupPlayer() {
        let videoURL = highlight.entry.videoURL
        let playerItem = AVPlayerItem(url: videoURL)
        let player = AVPlayer(playerItem: playerItem)

        // Seek to the insight timestamp
        let seekTime = CMTime(seconds: highlight.timestamp, preferredTimescale: 600)
        player.seek(to: seekTime)

        self.player = player
        player.play()

        loopObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player.seek(to: seekTime)
            player.play()
        }
    }
}

// MARK: - Reel Sheet Item (for sheet binding)

private struct ReelSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    AIHighlightsView()
        .preferredColorScheme(.dark)
}
