import SwiftUI

/// Privacy controls for clip sharing
struct PrivacySettingsView: View {
    @StateObject private var service = SharedAlbumService.shared
    @State private var neverShareAutomatically = false
    @State private var defaultFaceBlur = false
    @State private var selectedClipID: UUID?
    @State private var sharingHistory: [SharingSettings.ShareHistoryEntry] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Never Share Automatically", isOn: $neverShareAutomatically)
                    Toggle("Blur Faces by Default", isOn: $defaultFaceBlur)
                } header: {
                    Text("Default Settings")
                } footer: {
                    Text("These defaults apply to new clips. You can override per-clip.")
                }
                
                Section {
                    NavigationLink("Sharing History") {
                        SharingHistoryView()
                    }
                } header: {
                    Text("Privacy Tools")
                }
                
                Section {
                    NavigationLink("Close Circles") {
                        CloseCircleView()
                    }
                    NavigationLink("Collaborative Albums") {
                        CollaborativeAlbumView()
                    }
                } header: {
                    Text("Sharing Destinations")
                }
            }
            .navigationTitle("Privacy & Sharing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SharingHistoryView: View {
    @State private var entries: [SharingHistoryEntry] = []
    
    struct SharingHistoryEntry: Identifiable {
        let id = UUID()
        let viewerID: String
        let viewedAt: Date
        let shareType: String
        let clipID: UUID
    }
    
    var body: some View {
        List {
            if entries.isEmpty {
                Text("No sharing history yet").foregroundColor(Theme.textTertiary).font(.caption)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        Image(systemName: "eye.fill").foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(entry.viewerID.prefix(12) + "...")
                                .font(.caption)
                            Text(entry.shareType).font(.caption2).foregroundColor(Theme.textTertiary)
                        }
                        Spacer()
                        Text(entry.viewedAt, style: .relative)
                            .font(.caption2)
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
        }
        .navigationTitle("Sharing History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadHistory()
        }
    }
    
    private func loadHistory() {
        // Load from service
        entries = []
    }
}

/// Per-clip sharing settings sheet
struct ClipSharingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let clipID: UUID
    @State private var settings: SharingSettings = SharingSettings()
    @StateObject private var service = SharedAlbumService.shared
    @State private var showCirclePicker = false
    @State private var showPeoplePicker = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Share With", selection: $settings.target) {
                        ForEach(SharingSettings.ShareTarget.allCases, id: \.self) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                }
                
                Section {
                    Toggle("Blur Faces", isOn: $settings.faceBlurEnabled)
                    Toggle("Never Share Automatically", isOn: $settings.autoShareEnabled)
                } header: {
                    Text("Privacy")
                }
                
                if settings.target == .closeCircleOnly {
                    Section("Circle") {
                        if service.circles.isEmpty {
                            Text("No circles yet").foregroundColor(Theme.textTertiary).font(.caption)
                        } else {
                            ForEach(service.circles) { circle in
                                HStack {
                                    Text(circle.name)
                                    Spacer()
                                    if settings.circleIDs.contains(circle.id) {
                                        Image(systemName: "checkmark").foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if settings.circleIDs.contains(circle.id) {
                                        settings.circleIDs.removeAll { $0 == circle.id }
                                    } else {
                                        settings.circleIDs.append(circle.id)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Share")
                        Spacer()
                        Button("Public (Anonymous)") {
                            settings.target = .publicMoment
                            dismiss()
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Quick Share")
                } footer: {
                    Text("Public moments are anonymous — no names, faces auto-blurred.")
                }
            }
            .navigationTitle("Sharing Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        // Persist settings for this clip
        NotificationCenter.default.post(name: .clipSharingSettingsUpdated, object: nil, userInfo: ["clipID": clipID, "settings": settings])
    }
}

extension Notification.Name {
    static let clipSharingSettingsUpdated = Notification.Name("clipSharingSettingsUpdated")
}
