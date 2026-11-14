import SwiftUI

/// A glass jar with a lid, filled with one paper slip per task (up to `maxSlips`).
struct JarGraphic: View {
    /// Number of slips to show inside the jar.
    let slipCount: Int
    /// When true the jar is drawn faded (e.g. nothing to draw).
    var isEmpty: Bool = false

    static let maxSlips = 16

    private static let slipColors: [Color] = [
        .orange, .pink, .yellow, .mint, .cyan, .purple, .green, .indigo
    ]
    /// Fixed tilts so the pile looks hand-tossed but stays stable between redraws.
    private static let slipAngles: [Double] = [-18, 12, -6, 22, 8, -24, 15, -10, 4, -16, 20, -3, 10, -20, 6, 14]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let lidHeight = size.height * 0.1
            let jarHeight = size.height - lidHeight * 0.8

            VStack(spacing: -lidHeight * 0.2) {
                lid(width: size.width * 0.62, height: lidHeight)
                    .zIndex(1)

                ZStack {
                    JarShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.18), Color.blue.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    slips(in: CGSize(width: size.width, height: jarHeight))
                        .clipShape(JarShape())

                    // Glass highlight.
                    JarShape()
                        .stroke(Color.cyan.opacity(0.55), lineWidth: 3)
                    Capsule()
                        .fill(.white.opacity(0.35))
                        .frame(width: size.width * 0.05, height: jarHeight * 0.4)
                        .offset(x: -size.width * 0.34, y: -jarHeight * 0.08)
                }
                .frame(width: size.width, height: jarHeight)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .opacity(isEmpty ? 0.55 : 1)
        .accessibilityHidden(true)
    }

    private func lid(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.3)
            .fill(
                LinearGradient(
                    colors: [Color.brown.opacity(0.9), Color.brown],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                // Lid ridges.
                VStack(spacing: height * 0.18) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(.black.opacity(0.12)).frame(height: 1)
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(width: width, height: height)
    }

    private func slips(in size: CGSize) -> some View {
        let count = min(slipCount, Self.maxSlips)
        let slipWidth = size.width * 0.22
        let slipHeight = slipWidth * 0.5
        let perRow = 4

        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let row = index / perRow
                let column = index % perRow
                // Stagger alternate rows so slips nestle into each other.
                let stagger = row.isMultiple(of: 2) ? 0 : slipWidth * 0.45
                let x = size.width * 0.2 + CGFloat(column) * slipWidth * 0.95 + stagger - slipWidth * 0.2
                let y = size.height * 0.88 - CGFloat(row) * slipHeight * 1.15

                RoundedRectangle(cornerRadius: 3)
                    .fill(Self.slipColors[index % Self.slipColors.count].gradient)
                    .frame(width: slipWidth, height: slipHeight)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .rotationEffect(.degrees(Self.slipAngles[index % Self.slipAngles.count]))
                    .position(x: x, y: y)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.spring(duration: 0.4), value: count)
    }
}

/// Jar body outline: a short neck, rounded shoulders and a rounded base.
struct JarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let neckWidth = w * 0.56
        let neckX = rect.minX + (w - neckWidth) / 2
        let neckHeight = h * 0.07
        let shoulderY = rect.minY + h * 0.22
        let baseRadius = w * 0.18

        var path = Path()
        path.move(to: CGPoint(x: neckX, y: rect.minY))
        path.addLine(to: CGPoint(x: neckX + neckWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: neckX + neckWidth, y: rect.minY + neckHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: shoulderY),
            control: CGPoint(x: rect.maxX, y: rect.minY + neckHeight)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - baseRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - baseRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + baseRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - baseRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: neckX, y: rect.minY + neckHeight),
            control: CGPoint(x: rect.minX, y: rect.minY + neckHeight)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        JarGraphic(slipCount: 9).frame(width: 220)
        JarGraphic(slipCount: 0, isEmpty: true).frame(width: 120)
    }
}
