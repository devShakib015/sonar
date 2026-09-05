import SwiftUI

struct RadarView: View {
    @EnvironmentObject var scanner: Scanner
    var selectDevice: (String) -> Void

    private struct Blip: Identifiable {
        let id: String
        let name: String
        let type: DeviceType
        let online: Bool
        let angle: Double     // radians
        let pos: CGPoint
    }

    // Deterministic 0..<1 from a string + salt (FNV-1a).
    private func frac(_ s: String, _ salt: UInt64) -> Double {
        var h: UInt64 = 1469598103934665603 &+ salt
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Double(h % 100_000) / 100_000.0
    }

    private func blips(in size: CGSize) -> [Blip] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = min(size.width, size.height) / 2 - 34
        return scanner.devices.compactMap { d in
            if d.isThisDevice {
                return Blip(id: d.id, name: "This Mac", type: .thisDevice, online: true, angle: 0, pos: center)
            }
            let angle = frac(d.id, 1) * 2 * .pi
            let rFrac: Double = d.isGateway ? 0.26 : (0.45 + 0.5 * frac(d.id, 2))
            let r = maxR * rFrac
            let pos = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            return Blip(id: d.id, name: d.displayName, type: d.deviceType, online: d.isOnline, angle: angle, pos: pos)
        }
    }

    private func sweepAngle(_ t: Double) -> Double {
        (t.truncatingRemainder(dividingBy: 6) / 6) * 2 * .pi
    }

    // Trailing glow 1→0 as the beam passes a blip.
    private func glow(_ blipAngle: Double, _ sweep: Double) -> Double {
        var d = (sweep - blipAngle).truncatingRemainder(dividingBy: 2 * .pi)
        if d < 0 { d += 2 * .pi }
        return d < 1.2 ? (1 - d / 1.2) : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Radar").font(.largeTitle.weight(.bold))
                    Text("\(scanner.onlineCount) devices online").foregroundStyle(.secondary).font(.callout)
                }
                Spacer()
                Button { Task { await scanner.scanNow() } } label: {
                    Label(scanner.isScanning ? "Scanning…" : "Scan", systemImage: "dot.radiowaves.left.and.right")
                }.disabled(scanner.isScanning).buttonStyle(.borderedProminent)
            }
            .padding(20)

            GeometryReader { geo in
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let sweep = sweepAngle(t)
                    ZStack {
                        Canvas { ctx, size in drawRadar(ctx, size, sweep) }
                        ForEach(blips(in: geo.size)) { b in
                            blipView(b, glow: b.type == .thisDevice ? 0 : glow(b.angle, sweep))
                        }
                    }
                }
            }
        }
        .navigationTitle("Radar")
    }

    private func drawRadar(_ ctx: GraphicsContext, _ size: CGSize, _ sweep: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = min(size.width, size.height) / 2 - 34
        let teal = Color.teal

        // rings
        for f in [0.26, 0.5, 0.75, 1.0] {
            let r = maxR * f
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: rect), with: .color(teal.opacity(0.16)), lineWidth: 1)
        }
        // crosshair
        var cross = Path()
        cross.move(to: CGPoint(x: center.x - maxR, y: center.y)); cross.addLine(to: CGPoint(x: center.x + maxR, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - maxR)); cross.addLine(to: CGPoint(x: center.x, y: center.y + maxR))
        ctx.stroke(cross, with: .color(teal.opacity(0.10)), lineWidth: 1)

        // sweep wedge
        var wedge = Path()
        wedge.move(to: center)
        wedge.addArc(center: center, radius: maxR,
                     startAngle: .radians(sweep - 0.6), endAngle: .radians(sweep), clockwise: false)
        wedge.closeSubpath()
        let beamEnd = CGPoint(x: center.x + cos(sweep) * maxR, y: center.y + sin(sweep) * maxR)
        ctx.fill(wedge, with: .linearGradient(
            Gradient(colors: [teal.opacity(0.35), teal.opacity(0)]),
            startPoint: center, endPoint: beamEnd))

        // leading edge line
        var edge = Path(); edge.move(to: center); edge.addLine(to: beamEnd)
        ctx.stroke(edge, with: .color(teal.opacity(0.5)), lineWidth: 1.5)

        // center
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)),
                 with: .color(teal))
    }

    @ViewBuilder
    private func blipView(_ b: Blip, glow: Double) -> some View {
        let base: Double = b.online ? 1 : 0.28
        ZStack {
            if b.type == .thisDevice {
                Circle().fill(Color.blue.opacity(0.9)).frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
            } else {
                Circle().fill(b.type.tint.opacity(0.25 + 0.5 * glow))
                    .frame(width: 26 + 18 * glow, height: 26 + 18 * glow)   // glow halo
                Image(systemName: b.type.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(b.type.tint.opacity(base))
                    .padding(6)
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor).opacity(0.9)))
                    .overlay(Circle().stroke(b.type.tint.opacity(base), lineWidth: 1))
            }
        }
        .overlay(alignment: .top) {
            if b.type != .thisDevice {
                Text(b.name).font(.system(size: 9, weight: .medium)).lineLimit(1)
                    .foregroundStyle(.secondary).fixedSize()
                    .offset(y: -16).opacity(base)
            }
        }
        .position(b.pos)
        .onTapGesture { if b.type != .thisDevice { selectDevice(b.id) } }
        .help(b.name)
    }
}
