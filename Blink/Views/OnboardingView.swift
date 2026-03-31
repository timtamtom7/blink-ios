import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var showCameraPermission = false
    @State private var permissionTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color(hex: "0a0a0a")
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingScreen1()
                    .tag(0)

                OnboardingScreen2()
                    .tag(1)

                OnboardingScreen3()
                    .tag(2)

                OnboardingScreen4(onComplete: {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                })
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            VStack {
                Spacer()

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color(hex: "ff3b30") : Color(hex: "333333"))
                            .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button {
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            Text("Back")
                                .font(BlinkFontStyle.body.font)
                                .foregroundColor(Color(hex: "8a8a8a"))
                                .frame(width: 80, height: 44)
                        }
                    } else {
                        Color.clear.frame(width: 80, height: 44)
                    }

                    Spacer()

                    if currentPage < 3 {
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Next")
                                    .font(BlinkFontStyle.body.font)
                                Image(systemName: "arrow.right")
                                    .font(BlinkFontStyle.callout.font)
                            }
                            .foregroundColor(.white)
                            .frame(width: 100, height: 44)
                            .background(Color(hex: "ff3b30"))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Screen 1: Your Year, One Moment

struct OnboardingScreen1: View {
    @ObservedObject private var videoStore = VideoStore.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            YearInReviewGraphic(clipCount: videoStore.entries.count)
                .frame(width: 240, height: 240)
                .padding(.bottom, 48)

            VStack(spacing: 16) {
                Text("Your year, one moment")
                    .font(BlinkFontStyle.largeTitle.font)
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .multilineTextAlignment(.center)

                Text("One short video. Every single day. At the end of the year, you'll have the only video diary that actually matters — yours.")
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Screen 2: 30 Seconds of Life

struct OnboardingScreen2: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ClipCompositionGraphic()
                .frame(width: 240, height: 240)
                .padding(.bottom, 48)

            VStack(spacing: 16) {
                Text("30 seconds of life")
                    .font(BlinkFontStyle.largeTitle.font)
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .multilineTextAlignment(.center)

                Text("Talk to the camera. Tell yourself something. A thought, a feeling, a moment. No editing, no filters, no performance. Just you.")
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Screen 3: Your Private Archive

struct OnboardingScreen3: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ViewfinderGraphic()
                .frame(width: 240, height: 240)
                .padding(.bottom, 48)

            VStack(spacing: 16) {
                Text("Your private archive")
                    .font(BlinkFontStyle.largeTitle.font)
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .multilineTextAlignment(.center)

                Text("Everything stays on your device. No cloud, no accounts, no algorithms. Your memories are yours alone — until you're ready to look back.")
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Screen 4: Camera Permission

struct OnboardingScreen4: View {
    let onComplete: () -> Void
    @State private var permissionStatus: PermissionStatus = .unknown
    @State private var permissionTask: Task<Void, Never>?

    enum PermissionStatus {
        case unknown, granted, denied
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated aperture graphic
            ApertureGraphic()
                .frame(width: 200, height: 200)
                .padding(.bottom, 48)

            VStack(spacing: 16) {
                Text("Start recording")
                    .font(BlinkFontStyle.largeTitle.font)
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .multilineTextAlignment(.center)

                Text("Blink needs your camera and microphone to work. Your videos never leave your device.")
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()

            if permissionStatus == .denied {
                VStack(spacing: 12) {
                    Text("Camera access denied")
                        .font(BlinkFontStyle.callout.font)
                        .foregroundColor(Color(hex: "ff3b30"))

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(BlinkFontStyle.body.font)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 44)
                            .background(Color(hex: "ff3b30"))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 40)
            } else if permissionStatus == .granted {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "ff3b30"))

                    Button {
                        onComplete()
                    } label: {
                        Text("Start Your Year")
                            .font(BlinkFontStyle.title3.font)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(hex: "ff3b30"))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 48)
            } else {
                Button {
                    requestPermissions()
                } label: {
                    Text("Enable Camera")
                        .font(BlinkFontStyle.title3.font)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "ff3b30"))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }

            Spacer()
        }
        .onAppear {
            checkPermissions()
        }
        .onDisappear {
            permissionTask?.cancel()
        }
    }

    private func checkPermissions() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if videoStatus == .authorized && audioStatus == .authorized {
            permissionStatus = .granted
        } else if videoStatus == .denied || audioStatus == .denied {
            permissionStatus = .denied
        }
    }

    private func requestPermissions() {
        permissionTask = Task {
            let cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
            let micGranted = await AVCaptureDevice.requestAccess(for: .audio)

            await MainActor.run {
                if cameraGranted && micGranted {
                    permissionStatus = .granted
                } else {
                    permissionStatus = .denied
                }
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .preferredColorScheme(.dark)
}
