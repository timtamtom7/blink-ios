import SwiftUI

// MARK: - Camera Permission Denied View

struct CameraPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "video.slash.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "ff3b30").opacity(0.8))

            VStack(spacing: 12) {
                Text("Camera access required")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Blink needs your camera to record daily moments. Without it, there's nothing to Blink.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open Settings")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: 200, height: 48)
                .background(Color(hex: "ff3b30"))
                .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0a0a0a"))
    }
}

// MARK: - Microphone Permission Denied View

struct MicrophonePermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.slash.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "ff3b30").opacity(0.8))

            VStack(spacing: 12) {
                Text("Microphone access required")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Sound matters. Blink needs your microphone so your voice — not silence — becomes the memory.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open Settings")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: 200, height: 48)
                .background(Color(hex: "ff3b30"))
                .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0a0a0a"))
    }
}

// MARK: - Storage Full View

struct StorageFullView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(hex: "333333"), lineWidth: 3)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 1.0)
                    .stroke(Color(hex: "ff3b30"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "ff3b30"))
            }

            VStack(spacing: 12) {
                Text("Storage full")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Your device has run out of space. Delete some files or apps to continue recording your moments.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "ff3b30"))
                    Text("Tip: Upgrade to Archive for cloud backup")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }

            Button {
                onDismiss()
            } label: {
                Text("OK")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(Color(hex: "333333"))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0a0a0a"))
    }
}

// MARK: - Clip Save Failed View

struct ClipSaveFailedView: View {
    let onRetry: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "ff3b30").opacity(0.8))

            VStack(spacing: 12) {
                Text("Couldn't save clip")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Something went wrong saving your moment. This can happen if storage is tight or an app update interrupted things.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text("Try Again")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 200, height: 48)
                    .background(Color(hex: "ff3b30"))
                    .clipShape(Capsule())
                }

                Button {
                    onDiscard()
                } label: {
                    Text("Discard clip")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0a0a0a"))
    }
}

// MARK: - Trim Save Failed View

struct TrimSaveFailedView: View {
    let onRetry: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "scissors")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "ff3b30").opacity(0.8))

            VStack(spacing: 12) {
                Text("Trim failed")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Something went wrong saving your trimmed clip. Try again — your original clip is safe until you confirm the save.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text("Try Again")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 200, height: 48)
                    .background(Color(hex: "ff3b30"))
                    .clipShape(Capsule())
                }

                Button {
                    onDiscard()
                } label: {
                    Text("Go back")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0a0a0a"))
    }
}

// MARK: - Trim Storage Full View

struct TrimStorageFullView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(hex: "333333"), lineWidth: 3)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 1.0)
                    .stroke(Color(hex: "ff3b30"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "scissors")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "ff3b30"))
            }

            VStack(spacing: 12) {
                Text("Not enough space")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Your device is running out of space. Free up storage to save your trimmed clip.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "ff3b30"))
                    Text("Tip: Export clips to Camera Roll to free space")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }

            Button {
                onDismiss()
            } label: {
                Text("OK")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(Color(hex: "333333"))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0a0a0a"))
    }
}

// MARK: - Export to Camera Roll Failed View

struct ExportFailedView: View {
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.and.arrow.down.trianglebadge.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "ff3b30").opacity(0.8))

            VStack(spacing: 12) {
                Text("Couldn't save to Camera Roll")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Blink needs permission to save photos to your Camera Roll. Go to Settings > Blink > Photos and select \"All Photos\" or \"Selected.\"")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 14, weight: .medium))
                        Text("Open Settings")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 200, height: 48)
                    .background(Color(hex: "ff3b30"))
                    .clipShape(Capsule())
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0a0a0a"))
    }
}

// MARK: - Empty Calendar State View

struct EmptyCalendarView: View {
    let year: Int
    let onRecordFirst: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Abstract empty state graphic
            ZStack {
                Circle()
                    .stroke(Color(hex: "2a2a2a"), lineWidth: 1)
                    .frame(width: 120, height: 120)

                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .stroke(Color(hex: "1e1e1e"), lineWidth: 1)
                        .frame(width: CGFloat(60 + i * 20), height: CGFloat(60 + i * 20))
                }

                Circle()
                    .fill(Color(hex: "1e1e1e"))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    )
            }

            VStack(spacing: 12) {
                Text("No clips yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                Text("Your \(String(year)) Blink diary is blank. Every day you don't record is a day you'll never quite remember the same way.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            // Example of what to record
            VStack(alignment: .leading, spacing: 12) {
                Text("What would you record today?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))

                VStack(alignment: .leading, spacing: 8) {
                    ExampleMomentRow(icon: "sun.max.fill", text: "\"It's Tuesday, and I just realized I've been here for three months.\"")
                    ExampleMomentRow(icon: "cup.and.saucer.fill", text: "\"The coffee this morning was perfect. I want to remember that.\"")
                    ExampleMomentRow(icon: "heart.fill", text: "\"Had the best phone call with Mom today.\"")
                }
            }
            .padding(16)
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            .padding(.horizontal, 24)

            Button {
                onRecordFirst()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                    Text("Record your first moment")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "ff3b30"))
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "0a0a0a"))
    }
}

struct ExampleMomentRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "ff3b30"))
                .frame(width: 16)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "c0c0c0"))
                .italic()
        }
    }
}

// MARK: - Unified Error View (Dispatcher)

enum BlinkError: Equatable {
    case cameraPermission
    case microphonePermission
    case storageFull
    case clipSaveFailed
    case trimSaveFailed
    case trimStorageFull
    case exportFailed
    case emptyCalendar(year: Int)

    @ViewBuilder
    var view: some View {
        switch self {
        case .cameraPermission:
            CameraPermissionDeniedView()
        case .microphonePermission:
            MicrophonePermissionDeniedView()
        case .storageFull:
            StorageFullView(onDismiss: {})
        case .clipSaveFailed:
            ClipSaveFailedView(onRetry: {}, onDiscard: {})
        case .trimSaveFailed:
            TrimSaveFailedView(onRetry: {}, onDiscard: {})
        case .trimStorageFull:
            TrimStorageFullView(onDismiss: {})
        case .exportFailed:
            ExportFailedView(onRetry: {}, onDismiss: {})
        case .emptyCalendar(let year):
            EmptyCalendarView(year: year, onRecordFirst: {})
        }
    }
}

#Preview("Error States") {
    VStack {
        CameraPermissionDeniedView()
            .frame(height: 400)

        Divider()

        EmptyCalendarView(year: 2026, onRecordFirst: {})
            .frame(height: 500)
    }
    .preferredColorScheme(.dark)
}
