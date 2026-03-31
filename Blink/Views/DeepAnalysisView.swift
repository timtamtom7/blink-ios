import SwiftUI

/// R7: Deep AI Analysis view - shows advanced insights, scene categorization, life patterns
struct DeepAnalysisView: View {
    @StateObject private var analysisService = DeepAnalysisService.shared
    @ObservedObject private var videoStore = VideoStore.shared
    @State private var selectedScene: DeepAnalysisService.SceneType?
    @State private var showSceneEntries = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if analysisService.isAnalyzing {
                    analyzingView
                } else if analysisService.analyzedEntries.isEmpty {
                    emptyState
                } else {
                    analysisContent
                }
            }
            .navigationTitle("Deep Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !analysisService.analyzedEntries.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            refreshTask = Task {
                                await analysisService.analyzeAll(entries: videoStore.entries)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(BlinkFontStyle.body.font)
                                .foregroundColor(Color(hex: "ff3b30"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showSceneEntries) {
                if let scene = selectedScene {
                    SceneEntriesView(scene: scene)
                }
            }
            .onDisappear {
                analysisTask?.cancel()
                refreshTask?.cancel()
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "1e1e1e"), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: analysisService.analysisProgress)
                    .stroke(Color(hex: "ff3b30"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: analysisService.analysisProgress)

                Text("\(Int(analysisService.analysisProgress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "f5f5f5"))
            }

            VStack(spacing: 6) {
                Text("Analyzing your memories…")
                    .font(BlinkFontStyle.title3.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Discovering patterns in your life")
                    .font(BlinkFontStyle.callout.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "333333"))

            VStack(spacing: 6) {
                Text("Ready to discover")
                    .font(BlinkFontStyle.title3.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Analyze your clips to uncover\npatterns and insights about your life.")
                    .font(BlinkFontStyle.callout.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
            }

            Button {
                analysisTask = Task {
                    await analysisService.analyzeAll(entries: videoStore.entries)
                }
            } label: {
                Text("Start Analysis")
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

    private var analysisContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Life insights
                if !analysisService.insights.isEmpty {
                    insightsSection
                }

                // Scene breakdown
                sceneBreakdownSection

                // Quality overview
                qualitySection

                // Face detection stats
                faceSection
            }
            .padding(.vertical, 16)
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Life Insights")
                .font(BlinkFontStyle.title3.font)
                .foregroundColor(Color(hex: "f5f5f5"))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(analysisService.insights) { insight in
                        insightCard(insight)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func insightCard(_ insight: DeepAnalysisService.LifeInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: insight.icon)
                    .font(BlinkFontStyle.title2.font)
                    .foregroundColor(Color(hex: "ff3b30"))

                Spacer()

                Text(insightTypeLabel(insight.type))
                    .font(BlinkFontStyle.caption2.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "1e1e1e"))
                    .clipShape(Capsule())
            }

            Text(insight.title)
                .font(BlinkFontStyle.body.font)
                .foregroundColor(Color(hex: "f5f5f5"))

            Text(insight.description)
                .font(BlinkFontStyle.footnote.font)
                .foregroundColor(Color(hex: "8a8a8a"))
                .lineLimit(3)
        }
        .frame(width: 180)
        .padding(14)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }

    private func insightTypeLabel(_ type: DeepAnalysisService.InsightType) -> String {
        switch type {
        case .pattern: return "Pattern"
        case .milestone: return "Milestone"
        case .trend: return "Trend"
        case .discovery: return "Discovery"
        }
    }

    private var sceneBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scene Breakdown")
                .font(BlinkFontStyle.title3.font)
                .foregroundColor(Color(hex: "f5f5f5"))
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(DeepAnalysisService.SceneType.allCases, id: \.self) { sceneType in
                    let count = sceneCount(for: sceneType)
                    if count > 0 {
                        sceneRow(sceneType, count: count)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sceneRow(_ scene: DeepAnalysisService.SceneType, count: Int) -> some View {
        Button {
            selectedScene = scene
            showSceneEntries = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: sceneIcon(scene))
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(Color(hex: "ff3b30"))
                    .frame(width: 28)

                Text(scene.rawValue)
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                Spacer()

                Text("\(count) clips")
                    .font(BlinkFontStyle.subheadline.font)
                    .foregroundColor(Color(hex: "8a8a8a"))

                Image(systemName: "chevron.right")
                    .font(BlinkFontStyle.footnote.font)
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(12)
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
        }
    }

    private func sceneIcon(_ scene: DeepAnalysisService.SceneType) -> String {
        switch scene {
        case .outdoor: return "sun.max.fill"
        case .indoor: return "house.fill"
        case .travel: return "airplane"
        case .family: return "figure.2.and.child.holdinghands"
        case .friends: return "person.3.fill"
        case .food: return "fork.knife"
        case .nature: return "leaf.fill"
        case .urban: return "building.2.fill"
        case .celebration: return "party.popper.fill"
        case .quiet: return "moon.fill"
        case .activity: return "figure.run"
        case .unknown: return "questionmark.circle"
        }
    }

    private func sceneCount(for scene: DeepAnalysisService.SceneType) -> Int {
        analysisService.analyzedEntries.values.filter { analysis in
            analysis.scenes.contains { $0.type == scene }
        }.count
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Overview")
                .font(BlinkFontStyle.title3.font)
                .foregroundColor(Color(hex: "f5f5f5"))
                .padding(.horizontal, 16)

            let avgQuality = analysisService.analyzedEntries.values.map { $0.quality }.reduce(0, +) / Double(max(1, analysisService.analyzedEntries.count))
            let avgBrightness = analysisService.analyzedEntries.values.map { $0.brightness }.reduce(0, +) / Double(max(1, analysisService.analyzedEntries.count))

            HStack(spacing: 12) {
                qualityCard(title: "Avg Quality", value: "\(Int(avgQuality * 100))%", icon: "star.fill", color: avgQuality > 0.6 ? Color(hex: "34c759") : Color(hex: "ff9500"))
                qualityCard(title: "Brightness", value: avgBrightness > 0.5 ? "Well Lit" : "Low Light", icon: "sun.max.fill", color: Color(hex: "ffcc00"))
            }
            .padding(.horizontal, 16)
        }
    }

    private func qualityCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(BlinkFontStyle.title3.font)
                    .foregroundColor(color)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(BlinkFontStyle.title2.font)
                        .foregroundColor(Color(hex: "f5f5f5"))
                    Text(title)
                        .font(BlinkFontStyle.footnote.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }

    private var faceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People")
                .font(BlinkFontStyle.title3.font)
                .foregroundColor(Color(hex: "f5f5f5"))
                .padding(.horizontal, 16)

            let faceCount = analysisService.analyzedEntries.values.filter { $0.hasFaces }.count
            let totalCount = analysisService.analyzedEntries.count
            let percentage = totalCount > 0 ? Double(faceCount) / Double(totalCount) : 0

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(BlinkFontStyle.body.font)
                        .foregroundColor(Color(hex: "ff3b30"))

                    Text("Clips with people")
                        .font(BlinkFontStyle.body.font)
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Spacer()

                    Text("\(faceCount) of \(totalCount)")
                        .font(BlinkFontStyle.subheadline.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(Color(hex: "1e1e1e"))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                            .fill(Color(hex: "ff3b30"))
                            .frame(width: geometry.size.width * percentage, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(14)
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Scene Entries View

struct SceneEntriesView: View {
    let scene: DeepAnalysisService.SceneType
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analysisService = DeepAnalysisService.shared
    @ObservedObject private var videoStore = VideoStore.shared

    var entries: [VideoEntry] {
        let ids = analysisService.entriesForScene(scene)
        return videoStore.entries.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    entriesList
                }
            }
            .navigationTitle(scene.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "ff3b30"))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "333333"))

            Text("No clips found")
                .font(BlinkFontStyle.body.font)
                .foregroundColor(Color(hex: "8a8a8a"))
        }
    }

    private var entriesList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(entries) { entry in
                    entryThumbnail(entry)
                }
            }
            .padding(16)
        }
    }

    private func entryThumbnail(_ entry: VideoEntry) -> some View {
        VStack(spacing: 0) {
            if let thumbURL = entry.thumbnailURL {
                AsyncImage(url: thumbURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(hex: "1e1e1e"))
                }
                .frame(height: 100)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color(hex: "1e1e1e"))
                    .frame(height: 100)
            }

            Text(entry.formattedDate)
                .font(BlinkFontStyle.caption.font)
                .foregroundColor(Color(hex: "8a8a8a"))
                .padding(.vertical, 6)
        }
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
    }
}

#Preview {
    DeepAnalysisView()
        .preferredColorScheme(.dark)
}
