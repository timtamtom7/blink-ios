import SwiftUI

struct CloseCircleView: View {
    @StateObject private var service = SharedAlbumService.shared
    @State private var showCreateCircle = false
    @State private var newCircleName = ""
    @State private var selectedCircle: CloseCircle?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(service.circles) { circle in
                        NavigationLink(value: circle) {
                            CircleRowView(circle: circle)
                        }
                    }
                    .onDelete(perform: deleteCircle)
                    
                    Button {
                        showCreateCircle = true
                    } label: {
                        Label("Create Close Circle", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Your Circles")
                } footer: {
                    Text("Up to 10 trusted people. Anyone in the circle can share clips to the shared album.")
                }
            }
            .navigationTitle("Close Circles")
            .navigationDestination(for: CloseCircle.self) { circle in
                SharedAlbumView(circle: circle)
            }
            .alert("Create Close Circle", isPresented: $showCreateCircle) {
                TextField("Circle Name", text: $newCircleName)
                Button("Cancel", role: .cancel) { newCircleName = "" }
                Button("Create") {
                    if !newCircleName.isEmpty {
                        _ = service.createCircle(name: newCircleName)
                        newCircleName = ""
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func deleteCircle(at offsets: IndexSet) {
        for index in offsets {
            let circle = service.circles[index]
            service.leaveCircle(circle.id)
        }
    }
}

struct CircleRowView: View {
    let circle: CloseCircle
    @ObservedObject private var service = SharedAlbumService.shared
    
    private var sharedAlbum: SharedAlbum? {
        service.sharedAlbum(for: circle.id)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "person.2.fill").foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(circle.name).font(.headline)
                Text("\(circle.memberIDs.count)/10 members").font(.caption).foregroundColor(Theme.textTertiary)
            }
            Spacer()
            if let album = sharedAlbum {
                Text("\(album.clipIDs.count) clips").font(.caption2).foregroundColor(Theme.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SharedAlbumView: View {
    let circle: CloseCircle
    @ObservedObject private var service = SharedAlbumService.shared
    @State private var selectedAlbum: SharedAlbum?
    
    private var sharedAlbum: SharedAlbum? {
        service.sharedAlbum(for: circle.id)
    }
    
    var body: some View {
        List {
            if let album = sharedAlbum {
                Section("On This Day") {
                    if album.onThisDayClipIDs.isEmpty {
                        Text("No memories from today yet").foregroundColor(Theme.textTertiary).font(.caption)
                    } else {
                        Text("\(album.onThisDayClipIDs.count) On This Day clips")
                            .font(.caption).foregroundColor(Theme.textTertiary)
                    }
                }
                
                Section("Monthly Reel") {
                    if album.monthlyReelClipIDs.isEmpty {
                        Text("No monthly reel yet").foregroundColor(Theme.textTertiary).font(.caption)
                    } else {
                        Text("\(album.monthlyReelClipIDs.count) clips for this month")
                            .font(.caption).foregroundColor(Theme.textTertiary)
                    }
                }
                
                Section("Circle Members") {
                    ForEach(circle.memberIDs, id: \.self) { memberID in
                        HStack {
                            Image(systemName: "person.circle.fill").foregroundColor(.blue)
                            Text(memberID == circle.ownerID ? "\(memberID.prefix(8)) (Owner)" : memberID.prefix(8))
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
