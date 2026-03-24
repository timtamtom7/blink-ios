import SwiftUI

/// Public feed view: "Today's most meaningful clips" (anonymized).
struct PublicFeedView: View {
    @StateObject private var socialService = SocialShareService.shared
    @State private var feedItems: [SocialShareService.PublicFeedItem] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedItem: SocialShareService.PublicFeedItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(Color(hex: "ff3b30"))
                } else if let error = loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "8a8a8a"))
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "8a8a8a"))
                        Button("Retry") {
                            loadFeed()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "ff3b30"))
                    }
                } else if feedItems.isEmpty {
                    emptyState
                } else {
                    feedList
                }
            }
            .navigationTitle("Today's Moments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await refreshFeed()
            }
            .task {
                loadFeed()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "333333"))

            VStack(spacing: 6) {
                Text("No moments yet today")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Be the first to share a meaningful moment\nwith the Blink community.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(feedItems) { item in
                    FeedCard(item: item) {
                        selectedItem = item
                    }
                }
            }
            .padding(16)
        }
    }

    private func loadFeed() {
        isLoading = true
        loadError = nil

        Task {
            do {
                let items = try await socialService.fetchPublicFeed()
                await MainActor.run {
                    feedItems = items
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = "Couldn't load the feed. Check your connection."
                    isLoading = false
                }
            }
        }
    }

    private func refreshFeed() async {
        do {
            let items = try await socialService.fetchPublicFeed()
            await MainActor.run {
                feedItems = items
            }
        } catch {
            // Keep existing items on refresh failure
        }
    }
}

// MARK: - Feed Card

struct FeedCard: View {
    let item: SocialShareService.PublicFeedItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Preview thumbnail
                ZStack {
                    if let thumbFilename = item.previewThumbnail {
                        let url = VideoStore.shared.videosDirectory.appendingPathComponent(thumbFilename)
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(hex: "1e1e1e"))
                        }
                        .frame(height: 160)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(hex: "1e1e1e"))
                            .frame(height: 160)
                            .overlay(
                                Image(systemName: "video.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: "333333"))
                            )
                    }

                    // Gradient overlay
                    VStack {
                        Spacer()
                        HStack {
                            Text(item.monthYearText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Capsule())

                            Spacer()
                        }
                        .padding(12)
                    }
                }

                // Insight text
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "ff3b30"))

                    Text(item.insightText)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "c0c0c0"))
                        .lineLimit(2)

                    Spacer()
                }
                .padding(12)
                .background(Color(hex: "141414"))
            }
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "2a2a2a"), lineWidth: 1)
            )
        }
    }
}

#Preview {
    PublicFeedView()
        .preferredColorScheme(.dark)
}
