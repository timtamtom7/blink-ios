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
                    ProgressView()
                        .tint(Color(hex: "ff3b30"))
                        .scaleEffect(1.5)
                } else {
                    communityContent
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
                .font(.system(size: 13, weight: .medium))
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
                            .font(.system(size: 11))
                        Text(moment.anonymousId)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "8a8a8a"))

                    Spacer()

                    Text(timeAgo(moment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "555555"))
                }

                HStack(spacing: 8) {
                    categoryBadge(moment.category)

                    Text(moment.mood)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "f5f5f5"))
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                        Text("\(moment.likes)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "ff3b30"))

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12))
                        Text("\(moment.views)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "8a8a8a"))

                    HStack(spacing: 4) {
                        Image(systemName: "film.fill")
                            .font(.system(size: 12))
                        Text("\(moment.clipCount) clips")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "8a8a8a"))
                }
            }
            .padding(14)
        }
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

#Preview {
    CommunityView()
        .preferredColorScheme(.dark)
}
