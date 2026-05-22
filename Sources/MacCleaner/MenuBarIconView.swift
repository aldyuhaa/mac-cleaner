import SwiftUI
import AppKit

struct MenuBarIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.50, green: 0.39, blue: 0.92),
                            Color(red: 0.82, green: 0.20, blue: 0.84),
                            Color(red: 0.58, green: 0.18, blue: 0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ZStack {
                SparkleShape(points: 4, innerScale: 0.32)
                    .fill(.white.opacity(0.96))
                    .frame(width: 11, height: 11)

                SparkleShape(points: 4, innerScale: 0.32)
                    .fill(.white.opacity(0.92))
                    .frame(width: 5, height: 5)
                    .offset(x: -5.5, y: -4.5)

                SparkleShape(points: 4, innerScale: 0.32)
                    .fill(.white.opacity(0.92))
                    .frame(width: 4, height: 4)
                    .offset(x: 5, y: -5)
            }
        }
        .frame(width: 18, height: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.6)
        )
    }
}

enum MenuBarIconRenderer {
    @MainActor
    static func statusImage(size: CGFloat = 18) -> NSImage {
        let hostingView = NSHostingView(rootView: MenuBarIconView())
        hostingView.frame = NSRect(x: 0, y: 0, width: size, height: size)
        hostingView.layoutSubtreeIfNeeded()

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds).map { rep in
            hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
            rep.draw(in: hostingView.bounds)
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private struct SparkleShape: Shape {
    let points: Int
    let innerScale: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerScale
        let totalPoints = points * 2

        var path = Path()
        for index in 0..<totalPoints {
            let angle = (CGFloat(index) * .pi / CGFloat(points)) - (.pi / 2)
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
