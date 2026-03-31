import SwiftUI

// MARK: - Trim Scrubber Graphic

struct TrimScrubberGraphic: View {
    @State private var startHandleOffset: CGFloat = 0
    @State private var endHandleOffset: CGFloat = 0
    @State private var playheadOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            // Static preview of the scrubber
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "1e1e1e"))
                    .frame(height: 56)

                // Selected range
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "ff3b30").opacity(0.25))
                    .frame(width: 200, height: 56)
                    .offset(x: 40)

                // Waveform bars
                HStack(spacing: 2) {
                    ForEach(0..<30, id: \.self) { i in
                        let height = barHeight(i)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i < 15 ? Color(hex: "ff3b30") : Color(hex: "444444"))
                            .frame(width: 4, height: height)
                    }
                }
                .padding(.horizontal, 8)

                // Start handle
                TrimHandlePreview(isStart: true)
                    .offset(x: startHandleOffset)

                // End handle
                TrimHandlePreview(isStart: false)
                    .offset(x: endHandleOffset + 240)

                // Playhead
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 64)
                    .offset(x: playheadOffset + 60)
            }
            .frame(width: 280, height: 64)

            // Time labels
            HStack {
                Text("0:00")
                    .font(BlinkFontStyle.monospacedTimerLabel.font)
                    .foregroundColor(Color(hex: "ff3b30"))
                Spacer()
                Text("0:30")
                    .font(BlinkFontStyle.monospacedTimerLabel.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                Spacer()
                Text("0:45")
                    .font(BlinkFontStyle.monospacedTimerLabel.font)
                    .foregroundColor(Color(hex: "ff3b30"))
            }
            .frame(width: 280)
        }
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let seed = sin(Double(index) * 0.7) * 0.5 + 0.5
        return CGFloat(8 + seed * 32)
    }
}

struct TrimHandlePreview: View {
    let isStart: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "ff3b30"))
                .frame(width: 20, height: 56)

            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 8, height: 2)
                }
            }
        }
    }
}

// MARK: - Clip Title Input Graphic

struct TitleInputGraphic: View {
    @State private var text = "Morning coffee ritual"
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clip Title")
                .font(BlinkFontStyle.footnote.font)
                .foregroundColor(Color(hex: "8a8a8a"))

            HStack {
                TextField("Add a title…", text: $text)
                    .font(BlinkFontStyle.body.font)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color(hex: "1e1e1e"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "ff3b30"), lineWidth: 1)
                    )

                Image(systemName: "checkmark.circle.fill")
                    .font(BlinkFontStyle.title.font)
                    .foregroundColor(Color(hex: "ff3b30"))
            }
        }
        .frame(width: 300)
    }
}

// MARK: - Month Browser Graphic

struct MonthBrowserGraphic: View {
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    var body: some View {
        VStack(spacing: 12) {
            // Month cards grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(months.enumerated()), id: \.offset) { idx, month in
                    VStack(spacing: 4) {
                        Text(month)
                            .font(BlinkFontStyle.footnote.font)
                            .foregroundColor(idx == 2 ? .white : Color(hex: "8a8a8a"))

                        if idx == 2 || idx == 5 {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color(hex: "ff3b30"))
                                    .frame(width: 4, height: 4)
                                Text("\(idx == 2 ? 7 : 12)")
                                    .font(BlinkFontStyle.microBold.font)
                                    .foregroundColor(Color(hex: "8a8a8a"))
                            }
                        } else {
                            Text("—")
                                .font(BlinkFontStyle.caption2.font)
                                .foregroundColor(Color(hex: "333333"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(idx == 2 ? Color(hex: "ff3b30").opacity(0.15) : Color(hex: "141414"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(idx == 2 ? Color(hex: "ff3b30") : Color(hex: "2a2a2a"), lineWidth: 1)
                    )
                }
            }
        }
        .frame(width: 280)
    }
}

// MARK: - Export Share Button Graphic

struct ExportShareButtonGraphic: View {
    var body: some View {
        HStack(spacing: 12) {
            // Export to Camera Roll button
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "ff3b30").opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: "square.and.arrow.down.fill")
                        .font(BlinkFontStyle.title2.font)
                        .foregroundColor(Color(hex: "ff3b30"))
                }

                Text("Save to\nCamera Roll")
                    .font(BlinkFontStyle.caption2.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)

            // Share button
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 52, height: 52)

                    Image(systemName: "square.and.arrow.up")
                        .font(BlinkFontStyle.title2.font)
                        .foregroundColor(.white)
                }

                Text("Share")
                    .font(BlinkFontStyle.caption2.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
            .frame(width: 80)

            // Trim button
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "1e1e1e"))
                        .frame(width: 52, height: 52)

                    Image(systemName: "scissors")
                        .font(BlinkFontStyle.title2.font)
                        .foregroundColor(.white)
                }

                Text("Trim")
                    .font(BlinkFontStyle.caption2.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
            .frame(width: 80)
        }
    }
}

// MARK: - Camera Viewfinder Graphic

struct ViewfinderGraphic: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Outer frame
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "333333"), lineWidth: 1.5)

            // Corner brackets
            VStack {
                HStack {
                    CornerBracket(rotation: 0)
                    Spacer()
                    CornerBracket(rotation: 90)
                }
                Spacer()
                HStack {
                    CornerBracket(rotation: 270)
                    Spacer()
                    CornerBracket(rotation: 180)
                }
            }
            .padding(12)

            // Center focus cross
            VStack(spacing: 4) {
                Rectangle()
                    .fill(Color(hex: "ff3b30").opacity(0.6))
                    .frame(width: 1, height: 16)
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color(hex: "ff3b30").opacity(0.6))
                        .frame(width: 16, height: 1)
                    Circle()
                        .fill(Color(hex: "ff3b30").opacity(0.6))
                        .frame(width: 4, height: 4)
                    Rectangle()
                        .fill(Color(hex: "ff3b30").opacity(0.6))
                        .frame(width: 16, height: 1)
                }
                Rectangle()
                    .fill(Color(hex: "ff3b30").opacity(0.6))
                    .frame(width: 1, height: 16)
            }
            .opacity(isAnimating ? 1 : 0.4)
        }
        .aspectRatio(9/16, contentMode: .fit)
        .onAppear {
            if !reduceMotion {
                isAnimating = true
            }
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
    }
}

struct CornerBracket: View {
    let rotation: Double

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 12, y: 0))
        }
        .stroke(Color(hex: "ff3b30"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: 12, height: 12)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Clip/Thumbnail Composition Graphic

struct ClipCompositionGraphic: View {
    @State private var animateClips = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Background film strip motif
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                Color(hex: row == 1 && col == 1 ? "ff3b30" : "1e1e1e")
                            )
                            .frame(width: 52, height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(hex: "2a2a2a"), lineWidth: 0.5)
                            )
                            .overlay(
                                // Sprocket holes
                                VStack {
                                    Circle()
                                        .fill(Color(hex: "0a0a0a"))
                                        .frame(width: 6, height: 6)
                                    Spacer()
                                    Circle()
                                        .fill(Color(hex: "0a0a0a"))
                                        .frame(width: 6, height: 6)
                                }
                                .frame(width: 52)
                            )
                    }
                }
                .offset(x: CGFloat(row - 1) * (animateClips ? 3 : 0))
            }

            // Play button overlay on center frame
            Circle()
                .fill(Color(hex: "ff3b30").opacity(0.9))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(BlinkFontStyle.footnote.font)
                        .foregroundColor(.white)
                        .offset(x: 1)
                )
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animateClips = true
                }
            }
        }
    }
}

// MARK: - Year-in-Review Abstract Visual

struct YearInReviewGraphic: View {
    let clipCount: Int
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Concentric rings representing time
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(
                        Color(hex: "1a1a1a"),
                        lineWidth: 1
                    )
                    .frame(width: CGFloat(40 + index * 40), height: CGFloat(40 + index * 40))
            }

            // Arc showing year progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "ff3b30"),
                            Color(hex: "ff6b60"),
                            Color(hex: "ff3b30").opacity(0.3)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 180, height: 180)

            // Day markers
            ForEach(0..<12, id: \.self) { month in
                Rectangle()
                    .fill(month < Int(progress * 12) ? Color(hex: "ff3b30") : Color(hex: "333333"))
                    .frame(width: 2, height: 8)
                    .offset(y: -100)
                    .rotationEffect(.degrees(Double(month) * 30))
            }

            // Center dot (today)
            Circle()
                .fill(Color(hex: "ff3b30"))
                .frame(width: 12, height: 12)

            // Dynamic clip count
            VStack(spacing: 2) {
                Text("\(clipCount)")
                    .font(BlinkFontStyle.largeTitle.font)
                    .foregroundColor(Color(hex: "f5f5f5"))
                Text("clips")
                    .font(BlinkFontStyle.caption.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
            .accessibilityLabel("\(clipCount) clips recorded this year")
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeOut(duration: 1.5)) {
                    progress = 0.23 // ~83/365 of the year
                }
            } else {
                progress = 0.23
            }
        }
    }
}

// MARK: - Aperture Graphic (for permission screen)

struct ApertureGraphic: View {
    @State private var isOpen = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { blade in
                ApertureBlade(rotation: Double(blade) * 45)
            }

            Circle()
                .fill(Color(hex: "0a0a0a"))
                .frame(width: 40, height: 40)

            Circle()
                .fill(Color(hex: "ff3b30").opacity(0.3))
                .frame(width: 20, height: 20)
        }
        .rotationEffect(.degrees(isOpen ? 0 : 30))
        .scaleEffect(isOpen ? 1 : 0.85)
        .onAppear {
            if !reduceMotion {
                isOpen = true
            }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.8, dampingFraction: 0.6).repeatForever(autoreverses: true), value: isOpen)
    }
}

struct ApertureBlade: View {
    let rotation: Double

    var body: some View {
        Path { path in
            let rad1 = Angle(degrees: rotation + 20).radians
            let rad2 = Angle(degrees: rotation + 10).radians
            let rad3 = Angle(degrees: rotation + 25).radians
            path.move(to: CGPoint(x: 100, y: 100))
            path.addQuadCurve(
                to: CGPoint(x: 100 + 80 * cos(rad1), y: 100 + 80 * sin(rad1)),
                control: CGPoint(x: 100 + 50 * cos(rad2), y: 100 + 50 * sin(rad2))
            )
            path.addLine(to: CGPoint(x: 100 + 80 * cos(rad3), y: 100 + 80 * sin(rad3)))
        }
        .fill(Color(hex: "1e1e1e"))
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Year in Review Screen (Full View)

struct YearInReviewView: View {
    let clipsThisYear: Int
    let totalDaysElapsed: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "0a0a0a")
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Large year ring
                ZStack {
                    Circle()
                        .stroke(Color(hex: "1e1e1e"), lineWidth: 2)
                        .frame(width: 260, height: 260)

                    Circle()
                        .trim(from: 0, to: CGFloat(clipsThisYear) / CGFloat(max(totalDaysElapsed, 1)))
                        .stroke(
                            Color(hex: "ff3b30"),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 260, height: 260)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(clipsThisYear)")
                            .font(BlinkFontStyle.display64BoldRounded.font)
                            .foregroundColor(Color(hex: "f5f5f5"))
                        Text("of \(totalDaysElapsed) days")
                            .font(BlinkFontStyle.body.font)
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                }

                VStack(spacing: 12) {
                    Text("Your year in Blink")
                        .font(BlinkFontStyle.bold24.font)
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Text(yearInsightText)
                        .font(BlinkFontStyle.body.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Month grid mini-overview
                MonthStripView(clipsThisYear: clipsThisYear)
                    .padding(.horizontal, 24)

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(BlinkFontStyle.title3.font)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "ff3b30"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var yearInsightText: String {
        let coverage = Double(clipsThisYear) / Double(max(totalDaysElapsed, 1))
        if coverage >= 0.8 {
            return "Remarkable. You've captured \(clipsThisYear) days. This is what a year actually looks like."
        } else if coverage >= 0.5 {
            return "Good. \(clipsThisYear) moments saved. Keep going — every clip is a day you'll never forget."
        } else if clipsThisYear > 0 {
            return "\(clipsThisYear) days recorded. That's \(clipsThisYear) seconds of your life, preserved forever."
        } else {
            return "Your Blink diary starts today. One moment at a time."
        }
    }
}

struct MonthStripView: View {
    let clipsThisYear: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...12, id: \.self) { month in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(monthColor(for: month))
                        .frame(width: 20, height: monthHeight(for: month))

                    Text(monthLabel(for: month))
                        .font(BlinkFontStyle.micro.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func monthHeight(for month: Int) -> CGFloat {
        // Simulate varying clip density per month
        let densities: [Int: CGFloat] = [
            1: 0.5, 2: 0.3, 3: 0.7, 4: 0.6, 5: 0.8, 6: 0.4,
            7: 0.9, 8: 0.7, 9: 0.5, 10: 0.6, 11: 0.8, 12: 0.4
        ]
        return (densities[month] ?? 0.5) * 60 + 10
    }

    private func monthColor(for month: Int) -> Color {
        let densities: [Int: CGFloat] = [
            1: 0.5, 2: 0.3, 3: 0.7, 4: 0.6, 5: 0.8, 6: 0.4,
            7: 0.9, 8: 0.7, 9: 0.5, 10: 0.6, 11: 0.8, 12: 0.4
        ]
        let density = densities[month] ?? 0.5
        return Color(hex: "ff3b30").opacity(0.3 + density * 0.7)
    }

    private func monthLabel(for month: Int) -> String {
        ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"][month - 1]
    }
}

// MARK: - macOS App Mockup

/// Mockup of the macOS Blink app — browse and export clips on desktop.
struct macOSAppMockup: View {
    var body: some View {
        ZStack {
            // Window chrome
            VStack(spacing: 0) {
                // Title bar
                HStack(spacing: 8) {
                    // Traffic lights
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "ff5f57")).frame(width: 12, height: 12)
                        Circle().fill(Color(hex: "ffbd2e")).frame(width: 12, height: 12)
                        Circle().fill(Color(hex: "28c840")).frame(width: 12, height: 12)
                    }
                    Spacer()
                    Text("Blink")
                        .font(BlinkFontStyle.subheadline.font)
                        .foregroundColor(Color(hex: "8a8a8a"))
                    Spacer()
                    Spacer().frame(width: 52)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "1e1e1e"))

                // Main content area
                HStack(spacing: 0) {
                    // Sidebar
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(["Recordings", "Calendar", "On This Day", "Highlights", "Settings"], id: \.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: sidebarIcon(for: item))
                                    .font(BlinkFontStyle.footnote.font)
                                    .frame(width: 16)
                                Text(item)
                                    .font(BlinkFontStyle.subheadline.font)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(item == "Recordings" ? Color(hex: "ff3b30").opacity(0.15) : Color.clear)
                            .foregroundColor(item == "Recordings" ? Color(hex: "ff3b30") : Color(hex: "c0c0c0"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(12)
                    .frame(width: 160)
                    .background(Color(hex: "141414"))

                    Divider()
                        .background(Color(hex: "2a2a2a"))

                    // Main content
                    VStack(spacing: 12) {
                        // Header
                        HStack {
                            Text("2025")
                                .font(BlinkFontStyle.title2.font)
                                .foregroundColor(Color(hex: "f5f5f5"))
                            Spacer()
                            Button {
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(BlinkFontStyle.footnote.font)
                                    Text("Export Year")
                                        .font(BlinkFontStyle.footnote.font)
                                }
                                .foregroundColor(Color(hex: "ff3b30"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "ff3b30").opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }

                        // Clips grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(0..<6, id: \.self) { i in
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "1e1e1e"), Color(hex: "2a2a2a")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .overlay(
                                            VStack {
                                                Spacer()
                                                HStack {
                                                    Text("Dec \(1 + i)")
                                                        .font(BlinkFontStyle.caption2.font)
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                    Text("14s")
                                                        .font(BlinkFontStyle.caption2.font)
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                                .padding(6)
                                            }
                                        )
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(Color(hex: "0a0a0a"))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "2a2a2a"), lineWidth: 1)
            )
        }
        .frame(width: 480, height: 320)
    }

    private func sidebarIcon(for item: String) -> String {
        switch item {
        case "Recordings": return "video.fill"
        case "Calendar": return "calendar"
        case "On This Day": return "clock.arrow.circlepath"
        case "Highlights": return "sparkles"
        case "Settings": return "gearshape.fill"
        default: return "video"
        }
    }
}

// MARK: - Year in Review Compilation Mockup (for R5 custom graphics)

struct YearInReviewCompilationMockup: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            // Dark background with radial gradient
            RadialGradient(
                colors: [Color(hex: "1a0a0a"), Color(hex: "0a0a0a")],
                center: .center,
                startRadius: 50,
                endRadius: 200
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 24) {
                // Animated rings
                ZStack {
                    ForEach(0..<4, id: \.self) { ring in
                        Circle()
                            .stroke(
                                Color(hex: "ff3b30").opacity(0.1 + Double(ring) * 0.05),
                                lineWidth: 1
                            )
                            .frame(width: CGFloat(60 + ring * 40), height: CGFloat(60 + ring * 40))
                    }

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color(hex: "ff3b30"),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("83")
                            .font(BlinkFontStyle.display48BoldRounded.font)
                            .foregroundColor(Color(hex: "f5f5f5"))
                        Text("clips")
                            .font(BlinkFontStyle.subheadline.font)
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                }

                // Year
                Text("2025")
                    .font(BlinkFontStyle.title.font)
                    .foregroundColor(Color(hex: "f5f5f5"))

                // Clips strip
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "ff3b30").opacity(0.6), Color(hex: "ff6b60").opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 32, height: 44)
                    }
                }

                Text("Your year, compiled.")
                    .font(BlinkFontStyle.callout.font)
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
            .padding(24)
        }
        .frame(width: 300, height: 380)
        .onAppear {
            withAnimation(.easeOut(duration: 2)) {
                progress = 0.23
            }
        }
    }
}

struct GraphicsPreviews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            ViewfinderGraphic()
                .frame(width: 160, height: 220)

            ClipCompositionGraphic()
                .frame(width: 200, height: 200)

            YearInReviewGraphic(clipCount: 83)
                .frame(width: 240, height: 240)

            ApertureGraphic()
                .frame(width: 120, height: 120)
        }
        .padding()
        .background(Color(hex: "0a0a0a"))
        .preferredColorScheme(.dark)
    }
}
