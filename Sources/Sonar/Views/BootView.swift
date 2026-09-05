import SwiftUI

struct BootView: View {
    var onDone: () -> Void
    @State private var visible = 0
    @State private var progress: CGFloat = 0
    @State private var showReady = false

    private let lines: [(String, String)] = [
        ("initializing kernel modules", "OK"),
        ("probing network interfaces", "OK"),
        ("calibrating radar array", "OK"),
        ("mounting device registry", "OK"),
        ("arming anomaly detection", "OK"),
        ("establishing secure channel", "OK"),
    ]

    var body: some View {
        ZStack {
            Term.bg2.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 7) {
                GlitchWordmark(size: 44)
                Text("N E T W O R K   C O M M A N D   ·   v2.0.0")
                    .font(Term.mono(10)).foregroundStyle(Term.dim).tracking(3)
                    .padding(.bottom, 20)

                ForEach(0..<lines.count, id: \.self) { i in
                    if i < visible {
                        HStack(spacing: 8) {
                            Text(">").foregroundStyle(Term.green)
                            Text(lines[i].0).foregroundStyle(Term.dim)
                            Text(String(repeating: ".", count: max(2, 30 - lines[i].0.count)))
                                .foregroundStyle(Term.faint)
                            Text(lines[i].1).foregroundStyle(Term.green).glow(Term.green, 3)
                        }
                        .font(Term.mono(12))
                        .transition(.opacity)
                    }
                }

                if showReady {
                    HStack(spacing: 8) {
                        Text(">").foregroundStyle(Term.cyan)
                        Text("SYSTEM READY").foregroundStyle(Term.cyan).glow(Term.cyan, 5)
                        BlinkingCursor(size: 12)
                    }
                    .font(Term.mono(12, .bold))
                    .padding(.top, 6)
                    .transition(.opacity)
                }

                ProgressBar(progress: progress)
                    .frame(width: 340, height: 6)
                    .padding(.top, 22)
            }
            .frame(width: 400, alignment: .leading)
        }
        .task {
            for i in 0..<lines.count {
                try? await Task.sleep(nanoseconds: 240_000_000)
                withAnimation(.easeOut(duration: 0.18)) { visible = i + 1 }
                withAnimation(.linear(duration: 0.24)) { progress = CGFloat(i + 1) / CGFloat(lines.count) }
            }
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.easeOut(duration: 0.2)) { showReady = true }
            try? await Task.sleep(nanoseconds: 620_000_000)
            onDone()
        }
    }
}

struct ProgressBar: View {
    var progress: CGFloat
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Term.inputBG)
                    .overlay(Rectangle().strokeBorder(Term.border, lineWidth: 1))
                Rectangle().fill(Term.accent)
                    .frame(width: max(0, g.size.width * progress))
                    .glow(Term.cyan, 5)
            }
        }
    }
}
