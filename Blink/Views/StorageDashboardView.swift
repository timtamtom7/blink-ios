import SwiftUI

/// R11: Storage Dashboard — shows storage saved via compression and deduplication
struct StorageDashboardView: View {
    @StateObject private var dashboardService = StorageDashboardService.shared
    @ObservedObject private var videoStore = VideoStore.shared
    @StateObject private var compressionService = AdaptiveCompressionService.shared
    @StateObject private var deduplicationService = DeduplicationService.shared
    @State private var isRunningAnalysis = false
    @State private var showDeduplicationSheet = false
    @State private var selectedDuplicate: DeduplicationService.DuplicateGroup?
    @State private var deduplicationTask: Task<Void, Never>?
    @State private var compressionTask: Task<Void, Never>?
    @State private var duplicateDeleteTask: Task<Void, Never>?
    @State private var sheetRefreshTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if dashboardService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color(hex: "ff3b30"))
                        Text("Analyzing storage…")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                } else if let stats = dashboardService.stats {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Hero savings card
                            heroSavingsCard(stats)

                            // Storage breakdown
                            storageBreakdownCard(stats)

                            // Duplicate detection section
                            duplicateSection

                            // Compression section
                            compressionSection(stats)
                        }
                        .padding(16)
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await dashboardService.refresh(entries: videoStore.entries)
            }
            .refreshable {
                await dashboardService.refresh(entries: videoStore.entries)
            }
            .sheet(item: $selectedDuplicate) { group in
                DuplicateDetailSheet(group: group) {
                    selectedDuplicate = nil
                    sheetRefreshTask = Task {
                        await dashboardService.refresh(entries: videoStore.entries)
                    }
                }
            }
            .onDisappear {
                deduplicationTask?.cancel()
                compressionTask?.cancel()
                duplicateDeleteTask?.cancel()
                sheetRefreshTask?.cancel()
            }
        }
    }

    private func heroSavingsCard(_ stats: StorageDashboardService.StorageStats) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Blink has saved you")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8a8a8a"))

                Text(stats.formattedTotalSaved)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "ff3b30"))

                Text("in storage")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(stats.compressedCount)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "f5f5f5"))
                    Text("Compressed")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }

                Divider()
                    .frame(height: 30)
                    .background(Color(hex: "333333"))

                VStack(spacing: 4) {
                    Text("\(stats.duplicatesRemoved)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "f5f5f5"))
                    Text("Duplicates Removed")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }

                Divider()
                    .frame(height: 30)
                    .background(Color(hex: "333333"))

                VStack(spacing: 4) {
                    Text(stats.formattedDuration)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "f5f5f5"))
                    Text("Total Footage")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge)
                .stroke(Color(hex: "ff3b30").opacity(0.3), lineWidth: 1)
        )
    }

    private func storageBreakdownCard(_ stats: StorageDashboardService.StorageStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Breakdown")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "f5f5f5"))

            VStack(spacing: 8) {
                storageRow(label: "Total clips", value: "\(stats.totalClips)")
                storageRow(label: "Current size", value: stats.formattedEffective)
                storageRow(label: "Original size (before savings)", value: stats.formattedOriginalSize)
                storageRow(label: "Saved by compression", value: ByteCountFormatter.string(fromByteCount: stats.savedByCompression, countStyle: .file))
                storageRow(label: "Saved by deduplication", value: ByteCountFormatter.string(fromByteCount: stats.savedByDeduplication, countStyle: .file))

                Divider()
                    .background(Color(hex: "333333"))

                storageRow(label: "Oldest clip", value: stats.formattedOldest)
                storageRow(label: "Newest clip", value: stats.formattedNewest)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }

    private func storageRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "8a8a8a"))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "f5f5f5"))
        }
    }

    private var duplicateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duplicates")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "f5f5f5"))

                    if deduplicationService.duplicates.isEmpty {
                        Text("No duplicates detected")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    } else {
                        Text("\(deduplicationService.duplicates.count) groups found")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "ff3b30"))
                    }
                }

                Spacer()

                if deduplicationService.isAnalyzing {
                    ProgressView()
                        .tint(Color(hex: "ff3b30"))
                } else {
                    Button {
                        deduplicationTask = Task {
                            await deduplicationService.findDuplicates(entries: videoStore.entries)
                            await dashboardService.refresh(entries: videoStore.entries)
                        }
                    } label: {
                        Text("Scan")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "ff3b30"))
                    }
                }
            }

            if !deduplicationService.duplicates.isEmpty {
                ForEach(deduplicationService.duplicates.prefix(3), id: \.id) { group in
                    Button {
                        selectedDuplicate = group
                    } label: {
                        HStack {
                            Text("\(group.entries.count) similar clips")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "f5f5f5"))

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "8a8a8a"))
                        }
                        .padding(10)
                        .background(Color(hex: "1e1e1e"))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }

    private func compressionSection(_ stats: StorageDashboardService.StorageStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Compression")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Text("Clips older than 90 days are compressed automatically")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8a8a8a"))
                        .lineLimit(2)
                }

                Spacer()

                if compressionService.isCompressing {
                    VStack(spacing: 4) {
                        ProgressView()
                            .tint(Color(hex: "ff3b30"))
                        Text("\(Int(compressionService.compressionProgress * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                } else {
                    Button {
                        compressionTask = Task {
                            await compressionService.compressEligibleEntries(entries: videoStore.entries)
                            await dashboardService.refresh(entries: videoStore.entries)
                        }
                    } label: {
                        Text("Compress Now")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "ff3b30"))
                    }
                }
            }

            let candidates = compressionService.analyzeCompressionCandidates(entries: videoStore.entries)
            if !candidates.isEmpty {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "ff3b30"))
                    Text("\(candidates.count) clips eligible for compression")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            } else if stats.compressedCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("All eligible clips are compressed")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "333333"))

            Text("No clips yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: "f5f5f5"))

            Text("Record your first clip to see storage stats")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "8a8a8a"))
        }
    }
}

// MARK: - Duplicate Detail Sheet

struct DuplicateDetailSheet: View {
    let group: DeduplicationService.DuplicateGroup
    let onDismiss: () -> Void

    @StateObject private var deduplicationService = DeduplicationService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Similarity: \(Int(group.similarity * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "ff3b30"))

                    ForEach(group.entries, id: \.id) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.displayTitle)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "f5f5f5"))

                                Text("\(Int(entry.duration))s")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }

                            Spacer()

                            if entry.id == group.suggested?.id {
                                Text("Keep")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.2))
                                    .clipShape(Capsule())
                            } else {
                                Button {
                                    duplicateDeleteTask = Task {
                                        await deduplicationService.removeEntry(entry)
                                        onDismiss()
                                    }
                                } label: {
                                    Text("Delete")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "ff3b30"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(hex: "ff3b30").opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(hex: "141414"))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Duplicate Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(Color(hex: "ff3b30"))
                }
            }
        }
    }
}

#Preview {
    StorageDashboardView()
        .preferredColorScheme(.dark)
}
