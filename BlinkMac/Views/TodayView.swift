import SwiftUI
import AVFoundation

struct TodayView: View {
    let onEntrySelected: (VideoEntry) -> Void
    @State private var isRecording = false
    @State private var recentClips: [VideoEntry] = []
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        VStack(spacing: 0) {
            cameraViewfinder
                .frame(height: 200)
                .clipped()
            Divider()
                .background(Color(hex: "3A3A3A"))
            clipsList
        }
        .background(Color(hex: "0A0A0A"))
        .onAppear {
            loadRecentClips()
        }
    }

    private var cameraViewfinder: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
                .background(Color(hex: "141414"))

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    recordButton
                        .padding(16)
                }
            }

            if !cameraManager.isAuthorized {
                Color(hex: "141414")
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "A0A0A0"))
                            Text("Camera Access Required")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "A0A0A0"))
                            Button("Enable Camera") {
                                cameraManager.requestAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "FF3B30"))
                        }
                    }
            }
        }
    }

    private var recordButton: some View {
        Button(action: { toggleRecording() }) {
            ZStack {
                Circle()
                    .fill(Color(hex: "FF3B30"))
                    .frame(width: 56, height: 56)
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var clipsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Clips")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "A0A0A0"))
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if recentClips.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recentClips) { entry in
                            ClipRowView(entry: entry)
                                .onTapGesture {
                                    onEntrySelected(entry)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "video.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "3A3A3A"))
            Text("No clips yet")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "A0A0A0"))
            Text("Tap the record button to capture your first moment")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "5A5A5A"))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func toggleRecording() {
        if isRecording {
            cameraManager.stopRecording()
        } else {
            cameraManager.startRecording()
        }
        isRecording.toggle()
    }

    private func loadRecentClips() {
        // Load from shared VideoStore
        recentClips = VideoStore.shared.entries.prefix(5).map { $0 }
    }
}

struct ClipRowView: View {
    let entry: VideoEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "1A1A1A"))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "play.fill")
                        .foregroundColor(Color(hex: "FF3B30"))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.formattedDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "FAFAFA"))
                Text(entry.formattedDuration)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "A0A0A0"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "5A5A5A"))
        }
        .padding(8)
        .background(Color(hex: "141414"))
        .cornerRadius(8)
    }
}

#Preview {
    TodayView(onEntrySelected: { _ in })
        .frame(width: 360, height: 400)
}
