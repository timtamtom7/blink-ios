import SwiftUI

struct CollaborativeAlbumView: View {
    @StateObject private var service = SharedAlbumService.shared
    @State private var showCreateAlbum = false
    @State private var newAlbumTitle = ""
    @State private var joinLink = ""
    @State private var showJoinSheet = false
    @State private var selectedAlbum: CollaborativeAlbum?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(service.collaborativeAlbums) { album in
                        NavigationLink(value: album) {
                            CollaborativeAlbumRowView(album: album)
                        }
                    }
                    
                    Button {
                        showCreateAlbum = true
                    } label: {
                        Label("Create Collaborative Album", systemImage: "plus.circle.fill")
                    }
                    
                    Button {
                        showJoinSheet = true
                    } label: {
                        Label("Join via Link", systemImage: "link")
                    }
                } header: {
                    Text("Collaborative Albums")
                } footer: {
                    Text("Anyone with the link can view. Blink users can contribute clips.")
                }
            }
            .navigationTitle("Collaborate")
            .navigationDestination(for: CollaborativeAlbum.self) { album in
                CollaborativeAlbumDetailView(album: album)
            }
            .alert("Create Album", isPresented: $showCreateAlbum) {
                TextField("Album Title", text: $newAlbumTitle)
                Button("Cancel", role: .cancel) { newAlbumTitle = "" }
                Button("Create") {
                    if !newAlbumTitle.isEmpty {
                        _ = service.createCollaborativeAlbum(title: newAlbumTitle)
                        newAlbumTitle = ""
                    }
                }
            }
            .sheet(isPresented: $showJoinSheet) {
                NavigationStack {
                    Form {
                        Section("Invite Link") {
                            TextField("Paste invite link", text: $joinLink)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }
                    }
                    .navigationTitle("Join Album")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showJoinSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Join") {
                                if let _ = service.joinCollaborativeAlbum(via: joinLink) {
                                    showJoinSheet = false
                                    joinLink = ""
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct CollaborativeAlbumRowView: View {
    let album: CollaborativeAlbum
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall).fill(Color.purple.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "person.3.fill").foregroundColor(.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title).font(.headline)
                Text("\(album.contributorIDs.count) contributors · \(album.clipIDs.count) clips").font(.caption).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: album.isActive ? "link" : "link.badge.plus").foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct CollaborativeAlbumDetailView: View {
    let album: CollaborativeAlbum
    @ObservedObject private var service = SharedAlbumService.shared
    @State private var showInvite = false
    
    private var currentAlbum: CollaborativeAlbum? {
        service.collaborativeAlbums.first { $0.id == album.id }
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Invite Link")
                    Spacer()
                    Button("Copy") {
                        if let link = currentAlbum?.inviteLink {
                            UIPasteboard.general.string = link
                        }
                    }
                    .font(.caption)
                }
                if let link = currentAlbum?.inviteLink {
                    Text(link).font(.caption2).foregroundColor(Theme.textTertiary).lineLimit(1)
                }
            } header: {
                Text("Share")
            }
            
            Section("Contributors") {
                ForEach(currentAlbum?.contributorIDs ?? []) { contributor in
                    HStack {
                        Image(systemName: "person.circle.fill").foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text(contributor.displayName)
                            Text("\(contributor.contributedClipIDs.count) clips").font(.caption2).foregroundColor(Theme.textTertiary)
                        }
                        Spacer()
                        if contributor.deviceID == album.creatorID {
                            Text("Creator").font(.caption2).foregroundColor(Theme.accent)
                        }
                    }
                }
            }
            
            Section("Clips (\(currentAlbum?.clipIDs.count ?? 0))") {
                if currentAlbum?.clipIDs.isEmpty ?? true {
                    Text("No clips yet").foregroundColor(Theme.textTertiary).font(.caption)
                } else {
                    ForEach(currentAlbum?.clipIDs ?? [], id: \.self) { clipID in
                        HStack {
                            Image(systemName: "video.fill").foregroundColor(.purple)
                            Text(clipID.uuidString.prefix(8))
                                .font(.caption).foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
