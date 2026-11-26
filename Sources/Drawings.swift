import SwiftUI

/// Drawings of the JBL Tune Flex 2 earbuds and case, ported from design/tasarim-onerileri.html.
/// Each drawing works in its own design space (earbud 60x90, case 90x90) and scales to fit.

private let gaugeGradient = Gradient(colors: [Color(hex: 0xFF8550), Color(hex: 0xEC4A10)])
private let outline = Color.primary.opacity(0.22)

private func rotatedEllipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, degrees: CGFloat) -> Path {
    let transform = CGAffineTransform(rotationAngle: degrees * .pi / 180)
        .concatenating(CGAffineTransform(translationX: cx, y: cy))
    return Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)).applying(transform)
}

/// Scales the context so a `designSize` drawing fits `size`, centred and bottom-aligned.
private func fit(_ ctx: inout GraphicsContext, size: CGSize, designSize: CGSize) {
    let s = min(size.width / designSize.width, size.height / designSize.height)
    ctx.translateBy(x: (size.width - designSize.width * s) / 2, y: size.height - designSize.height * s)
    ctx.scaleBy(x: s, y: s)
}

struct EarbudDrawing: View {
    /// 0...100, nil when unknown.
    var level: Int?
    var mirrored = false
    /// false hides the stem gauge (used inside a battery ring).
    var showsGauge = true

    var body: some View {
        Canvas { ctx, size in
            fit(&ctx, size: size, designSize: CGSize(width: 60, height: 90))
            if mirrored {
                ctx.translateBy(x: 58, y: 0)
                ctx.scaleBy(x: -1, y: 1)
            }

            // Silicone tip and its sound opening.
            let tip = rotatedEllipse(cx: 41, cy: 30, rx: 8, ry: 9.5, degrees: 35)
            ctx.fill(tip, with: .linearGradient(Gradient(colors: [Color(hex: 0x8D8E95), Color(hex: 0x5D5E65)]),
                                                startPoint: CGPoint(x: 33, y: 20), endPoint: CGPoint(x: 49, y: 40)))
            ctx.stroke(tip, with: .color(outline), lineWidth: 2)
            ctx.fill(rotatedEllipse(cx: 44, cy: 33.5, rx: 3.2, ry: 4, degrees: 35), with: .color(.black.opacity(0.45)))

            // Head and stem: stroke first, then fill, so their join has no inner line.
            var body = rotatedEllipse(cx: 25, cy: 24, rx: 18, ry: 14.5, degrees: -12)
            body.addPath(Path(roundedRect: CGRect(x: 15.5, y: 28, width: 14, height: 58), cornerRadius: 7))
            let bodyShading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Color(hex: 0x55565D), Color(hex: 0x26272C)]),
                startPoint: CGPoint(x: 0, y: 10), endPoint: CGPoint(x: 40, y: 90))
            ctx.stroke(body, with: .color(outline), lineWidth: 2.4)
            ctx.fill(body, with: bodyShading)

            var highlight = Path()
            highlight.move(to: CGPoint(x: 12, y: 18))
            highlight.addCurve(to: CGPoint(x: 27, y: 11), control1: CGPoint(x: 15, y: 13), control2: CGPoint(x: 21, y: 10.5))
            ctx.stroke(highlight, with: .color(.white.opacity(0.32)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

            guard showsGauge else { return }
            // Battery gauge inside the stem, filled from the bottom.
            let track = CGRect(x: 19.5, y: 44, width: 6, height: 36)
            ctx.fill(Path(roundedRect: track, cornerRadius: 3), with: .color(.black.opacity(0.45)))
            if let level, level > 0 {
                let h = track.height * CGFloat(min(level, 100)) / 100
                let fill = CGRect(x: track.minX, y: track.maxY - h, width: track.width, height: h)
                ctx.fill(Path(roundedRect: fill, cornerRadius: 3),
                         with: .linearGradient(gaugeGradient, startPoint: CGPoint(x: 0, y: track.minY),
                                               endPoint: CGPoint(x: 0, y: track.maxY)))
            }
        }
        .accessibilityHidden(true)
    }
}

struct CaseDrawing: View {
    /// 0...100, nil when unknown.
    var level: Int?
    /// false draws the front lights plain white instead of as a battery gauge (used inside a ring).
    var showsGauge = true

    var body: some View {
        Canvas { ctx, size in
            fit(&ctx, size: size, designSize: CGSize(width: 90, height: 90))

            // Near-square case with a rounded base.
            var body = Path()
            body.move(to: CGPoint(x: 30, y: 28))
            body.addLine(to: CGPoint(x: 60, y: 28))
            body.addCurve(to: CGPoint(x: 76, y: 45), control1: CGPoint(x: 71, y: 28), control2: CGPoint(x: 76, y: 34))
            body.addLine(to: CGPoint(x: 76, y: 60))
            body.addCurve(to: CGPoint(x: 45, y: 86), control1: CGPoint(x: 76, y: 76), control2: CGPoint(x: 66, y: 86))
            body.addCurve(to: CGPoint(x: 14, y: 60), control1: CGPoint(x: 24, y: 86), control2: CGPoint(x: 14, y: 76))
            body.addLine(to: CGPoint(x: 14, y: 45))
            body.addCurve(to: CGPoint(x: 30, y: 28), control1: CGPoint(x: 14, y: 34), control2: CGPoint(x: 19, y: 28))
            body.closeSubpath()

            ctx.stroke(body, with: .color(outline), lineWidth: 2.4)
            ctx.fill(body, with: .linearGradient(Gradient(colors: [Color(hex: 0x4A4B52), Color(hex: 0x202125)]),
                                                 startPoint: CGPoint(x: 20, y: 28), endPoint: CGPoint(x: 60, y: 86)))

            ctx.drawLayer { layer in
                layer.clip(to: body)
                // Lid seam, dipping toward the front centre, with a faint bevel under it.
                for (dy, color, width) in [(0.0, Color.black.opacity(0.6), 1.4), (1.5, Color.white.opacity(0.09), 0.8)] {
                    var seam = Path()
                    seam.move(to: CGPoint(x: 10, y: 41.5 + dy))
                    seam.addCurve(to: CGPoint(x: 45, y: 46.5 + dy), control1: CGPoint(x: 26, y: 42 + dy), control2: CGPoint(x: 36, y: 44.5 + dy))
                    seam.addCurve(to: CGPoint(x: 80, y: 41.5 + dy), control1: CGPoint(x: 54, y: 44.5 + dy), control2: CGPoint(x: 64, y: 42 + dy))
                    layer.stroke(seam, with: .color(color), lineWidth: width)
                }
                var highlight = Path()
                highlight.move(to: CGPoint(x: 24, y: 32))
                highlight.addCurve(to: CGPoint(x: 45, y: 30), control1: CGPoint(x: 30, y: 30.4), control2: CGPoint(x: 38, y: 30))
                highlight.addCurve(to: CGPoint(x: 66, y: 32), control1: CGPoint(x: 52, y: 30), control2: CGPoint(x: 60, y: 30.4))
                layer.stroke(highlight, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }

            // Three slanted front lights; each lit bar is roughly a third of the battery.
            if !showsGauge {
                for n in 0..<3 {
                    let x = 38 + CGFloat(n) * 5.4
                    var bar = Path()
                    bar.move(to: CGPoint(x: x + 2.4, y: 52.5))
                    bar.addLine(to: CGPoint(x: x + 5, y: 52.5))
                    bar.addLine(to: CGPoint(x: x + 2.6, y: 58.5))
                    bar.addLine(to: CGPoint(x: x, y: 58.5))
                    bar.closeSubpath()
                    ctx.fill(bar, with: .color(.white.opacity(0.75)))
                }
                return
            }
            let lit = level.map { max($0 > 0 ? 1 : 0, Int((Double($0) / 33.4).rounded())) } ?? 0
            for n in 0..<3 {
                let x = 38 + CGFloat(n) * 5.4
                var bar = Path()
                bar.move(to: CGPoint(x: x + 2.4, y: 52.5))
                bar.addLine(to: CGPoint(x: x + 5, y: 52.5))
                bar.addLine(to: CGPoint(x: x + 2.6, y: 58.5))
                bar.addLine(to: CGPoint(x: x, y: 58.5))
                bar.closeSubpath()
                if n < lit {
                    ctx.drawLayer { glow in
                        glow.addFilter(.blur(radius: 1.6))
                        glow.opacity = 0.4
                        glow.fill(bar, with: .color(Color(hex: 0xFF7A45)))
                    }
                    ctx.fill(bar, with: .linearGradient(gaugeGradient, startPoint: CGPoint(x: 0, y: 52.5), endPoint: CGPoint(x: 0, y: 58.5)))
                } else {
                    ctx.fill(bar, with: .color(.white.opacity(0.12)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static let flexOrange = Color(hex: 0xFF5A1F)
}
