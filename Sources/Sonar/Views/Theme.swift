import SwiftUI

// Futuristic HUD / phosphor palette + effects.
enum Term {
    static let bg      = Color(red: 0.015, green: 0.04,  blue: 0.05)
    static let bg2     = Color(red: 0.005, green: 0.02,  blue: 0.035)
    static let panel   = Color(red: 0.03,  green: 0.075, blue: 0.085).opacity(0.72)
    static let inputBG = Color(red: 0.01,  green: 0.03,  blue: 0.04)
    static let green   = Color(red: 0.25,  green: 1.0,   blue: 0.55)
    static let dim     = Color(red: 0.4,   green: 1.0,   blue: 0.7).opacity(0.6)
    static let faint   = Color(red: 0.4,   green: 1.0,   blue: 0.7).opacity(0.32)
    static let amber   = Color(red: 1.0,   green: 0.72,  blue: 0.2)
    static let red     = Color(red: 1.0,   green: 0.3,   blue: 0.4)
    static let cyan    = Color(red: 0.3,   green: 0.9,   blue: 1.0)
    static let violet  = Color(red: 0.7,   green: 0.5,   blue: 1.0)
    static let border  = Color(red: 0.3,   green: 0.95,  blue: 0.85).opacity(0.30)

    static let accent = LinearGradient(colors: [green, cyan], startPoint: .leading, endPoint: .trailing)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    func glow(_ color: Color = Term.green, _ radius: CGFloat = 5) -> some View {
        shadow(color: color.opacity(0.6), radius: radius)
    }
    func crt() -> some View { modifier(CRT()) }
}

// Animated depth grid + gradient — the futuristic backdrop.
struct HUDBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Term.bg, Term.bg2], startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    let spacing: CGFloat = 44
                    let off = CGFloat((t * 6).truncatingRemainder(dividingBy: Double(spacing)))
                    var x = -off
                    while x < size.width {
                        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) },
                                   with: .color(Term.green.opacity(0.045)), lineWidth: 0.5)
                        x += spacing
                    }
                    var y = -off
                    while y < size.height {
                        ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: size.width, y: y)) },
                                   with: .color(Term.green.opacity(0.045)), lineWidth: 0.5)
                        y += spacing
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// CRT scanlines + vignette.
struct CRT: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(
            ZStack {
                Canvas { ctx, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                 with: .color(.black.opacity(0.13)))
                        y += 3
                    }
                }
                RadialGradient(colors: [.clear, .black.opacity(0.4)], center: .center, startRadius: 240, endRadius: 1000)
            }
            .allowsHitTesting(false)
        )
    }
}

// L-shaped corner brackets — the signature HUD frame on every panel.
struct HUDCorners: View {
    var color: Color = Term.cyan
    var len: CGFloat = 9
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, o: CGFloat = 1.5
            Path { p in
                p.move(to: CGPoint(x: o, y: o + len)); p.addLine(to: CGPoint(x: o, y: o)); p.addLine(to: CGPoint(x: o + len, y: o))
                p.move(to: CGPoint(x: w - o - len, y: o)); p.addLine(to: CGPoint(x: w - o, y: o)); p.addLine(to: CGPoint(x: w - o, y: o + len))
                p.move(to: CGPoint(x: o, y: h - o - len)); p.addLine(to: CGPoint(x: o, y: h - o)); p.addLine(to: CGPoint(x: o + len, y: h - o))
                p.move(to: CGPoint(x: w - o - len, y: h - o)); p.addLine(to: CGPoint(x: w - o, y: h - o)); p.addLine(to: CGPoint(x: w - o, y: h - o - len))
            }
            .stroke(color.opacity(0.85), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

// Glowing HUD button.
struct TermButton: ButtonStyle {
    var tint: Color = Term.green
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Term.mono(12, .semibold))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .foregroundStyle(configuration.isPressed ? Term.bg : tint)
            .background(configuration.isPressed ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(tint.opacity(0.65), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: tint.opacity(configuration.isPressed ? 0 : 0.35), radius: 5)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct BlinkingCursor: View {
    var size: CGFloat = 18
    @State private var on = true
    var body: some View {
        Text("_")
            .font(Term.mono(size, .bold)).foregroundStyle(Term.cyan)
            .opacity(on ? 1 : 0)
            .onAppear { withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { on = false } }
    }
}

struct WindowStyler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.backgroundColor = NSColor(Term.bg2)
            w.titlebarAppearsTransparent = true
            w.appearance = NSAppearance(named: .darkAqua)
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
