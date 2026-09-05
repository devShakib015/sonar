import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var scanner: Scanner
    @EnvironmentObject var meter: ThroughputMeter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(Term.cyan)
                Text("Sonar").fontWeight(.semibold)
                Spacer()
                Text("\(scanner.onlineCount) online").foregroundStyle(.secondary).font(.callout)
            }

            HStack(spacing: 14) {
                Label(formatBytesPerSec(meter.downBps), systemImage: "arrow.down").foregroundStyle(Term.cyan)
                Label(formatBytesPerSec(meter.upBps), systemImage: "arrow.up").foregroundStyle(.green)
            }
            .font(.caption.monospacedDigit())

            if scanner.newCount > 0 {
                Label("\(scanner.newCount) new device\(scanner.newCount == 1 ? "" : "s") detected",
                      systemImage: "sparkles")
                    .foregroundStyle(Term.amber).font(.callout)
            }

            Divider()

            ForEach(Array(scanner.devices.filter { $0.isOnline }.prefix(6))) { d in
                HStack(spacing: 8) {
                    Image(systemName: d.deviceType.symbol).foregroundStyle(d.deviceType.tint).frame(width: 16)
                    Text(d.displayName).lineLimit(1)
                    Spacer()
                    Text(d.ip).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                }
                .font(.callout)
            }

            Divider()

            HStack {
                Button { Task { await scanner.scanNow() } } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .disabled(scanner.isScanning)
                Spacer()
                Button("Open") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 290)
    }
}
