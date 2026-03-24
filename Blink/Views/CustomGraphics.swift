import SwiftUI

// MARK: - Camera Viewfinder Graphic

struct ViewfinderGraphic: View {
    @State private var isAnimating = false

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
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
        }
        .aspectRatio(9/16, contentMode: .fit)
        .onAppear { isAnimating = true }
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
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .offset(x: 1)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateClips = true
            }
        }
    }
}

// MARK: - Year-in-Review Abstract Visual

struct YearInReviewGraphic: View {
    @State private var progress: CGFloat = 0

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

            // "83 clips" or similar
            VStack(spacing: 2) {
                Text("83")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "f5f5f5"))
                Text("clips")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                progress = 0.23 // ~83/365 of the year
            }
        }
    }
}

// MARK: - Aperture Graphic (for permission screen)

struct ApertureGraphic: View {
    @State private var isOpen = false

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
        .animation(.spring(response: 0.8, dampingFraction: 0.6).repeatForever(autoreverses: true), value: isOpen)
        .onAppear { isOpen = true }
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
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "f5f5f5"))
                        Text("of \(totalDaysElapsed) days")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                }

                VStack(spacing: 12) {
                    Text("Your year in Blink")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "f5f5f5"))

                    Text(yearInsightText)
                        .font(.system(size: 15))
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
                        .font(.system(size: 17, weight: .semibold))
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
                        .font(.system(size: 8))
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

#Preview("Graphics") {
    VStack(spacing: 40) {
        ViewfinderGraphic()
            .frame(width: 160, height: 220)

        ClipCompositionGraphic()
            .frame(width: 200, height: 200)

        YearInReviewGraphic()
            .frame(width: 240, height: 240)

        ApertureGraphic()
            .frame(width: 120, height: 120)
    }
    .padding()
    .background(Color(hex: "0a0a0a"))
    .preferredColorScheme(.dark)
}
