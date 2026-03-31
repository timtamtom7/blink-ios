import SwiftUI

/// R9: Anonymous community feed view
struct CommunityView: View {
    @StateObject private var communityService = CommunityService.shared
    @State private var selectedCategory: CommunityService.Category?

    var filteredMoments: [CommunityService.PublicMoment] {
        if let category = selectedCategory {
            return communityService.publicMoments.filter { $0.category == category }
        }
        return communityService.publicMoments
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if communityService.isLoading {
                    skeletonLoadingView
                } else {
                    communityContent
                }

                // Coming Soon overlay — this feature is not yet functional
                VStack {}
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "0a0a0a").opacity(0.85))
                    .overlay {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "333333"))
                            Text("Coming Soon")
                                .font(BlinkFontStyle.title2.font)
                                .foregroundColor(Color(hex: "f5f5f5"))
                            Text("The community feed is in development.")
                                .font(BlinkFontStyle.body.font)
                                .foregroundColor(Color(hex: "8a8a8a"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(32)
                    }
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await communityService.loadPublicFeed()
            }
        }
    }

    private var skeletonLoadingView: some View {
        VStack(spacing: 0) {
            // Category filter skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: "1e1e1e"))
                            .frame(width: 70, height: 30)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Feed skeleton
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonMomentCard()
                    }
                }
                .padding(16)
            }
        }
    }

    private var communityContent: some View {
        VStack(spacing: 0) {
            // Category filter
            categoryFilter

            // Feed
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredMoments) { moment in
                        momentCard(moment)
                    }
                }
                .padding(16)
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, label: "All")

                ForEach(CommunityService.Category.allCases, id: \.self) { category in
                    categoryChip(category, label: category.rawValue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(hex: "0a0a0a"))
    }

    private func categoryChip(_ category: CommunityService.Category?, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(label)
                .font(BlinkFontStyle.subheadline.font)
                .foregroundColor(selectedCategory == category ? .white : Color(hex: "8a8a8a"))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selectedCategory == category ? Color(hex: "ff3b30") : Color(hex: "1e1e1e"))
                .clipShape(Capsule())
        }
    }

    private func momentCard(_ moment: CommunityService.PublicMoment) -> some View {
        VStack(spacing: 0) {
            // Thumbnail
            ZStack {
                if let thumbURL = moment.thumbnailURL, let url = URL(string: thumbURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderGradient
                    }
                } else {
                    placeholderGradient
                }
            }
            .frame(height: 180)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill.questionmark")
                            .font(BlinkFontStyle.caption.font)
                        Text(moment.anonymousId)
                            .font(BlinkFontStyle.footnote.font)
                    }
                    .foregroundColor(Color(hex: "8a8a8a"))

                    Spacer()

                    Text(timeAgo(moment.createdAt))
                        .font(BlinkFontStyle.caption.font)
                        .foregroundColor(Color(hex: "AAAAAA"))
                }

                HStack(spacing: 8) {
                    categoryBadge(moment.category)

                    Text(moment.mood)
                        .font(BlinkFontStyle.subheadline.font)
                        .foregroundColor(Color(hex: "f5f5f5"))
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(BlinkFontStyle.footnote.font)
                        Text("\(moment.likes)")
                            .font(BlinkFontStyle.footnote.font)
                    }
                    .foregroundColor(Color(hex: "ff3b30"))

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(BlinkFontStyle.footnote.font)
                        Text("\(moment.views)")
                            .font(BlinkFontStyle.footnote.font)
                    }
                    .foregroundColor(Color(hex: "8a8a8a"))

                    HStack(spacing: 4) {
                        Image(systemName: "film.fill")
                            .font(BlinkFontStyle.footnote.font)
                        Text("\(moment.clipCount) clips")
                            .font(BlinkFontStyle.footnote.font)
                    }
                    .foregroundColor(Color(hex: "8a8a8a"))
                }
            }
            .padding(14)
        }
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [Color(hex: "1e1e1e"), Color(hex: "2a2a2a")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func categoryBadge(_ category: CommunityService.Category) -> some View {
        Text(category.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: "ff3b30"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "ff3b30").opacity(0.15))
            .clipShape(Capsule())
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Skeleton Loading Card

struct SkeletonMomentCard: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge)
                .fill(Color(hex: "1e1e1e"))
                .frame(height: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "1e1e1e"),
                                    Color(hex: "2a2a2a"),
                                    Color(hex: "1e1e1e")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isAnimating ? 200 : -200)
                        .animation(
                            reduceMotion ? .linear(duration: 0) : .linear(duration: 1.5).repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                )

            // Info skeleton
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 80, height: 12)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 50, height: 12)
                }

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 60, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 100, height: 16)
                }

                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 40, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 40, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 60, height: 14)
                }
            }
            .padding(14)
        }
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
        .onAppear {
            isAnimating = true
        }
        .accessibilityLabel("Loading community post")
        .accessibilityHidden(true)
    }
}

#Preview {
    CommunityView()
        .preferredColorScheme(.dark)
}
