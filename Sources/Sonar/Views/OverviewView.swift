import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var scanner: Scanner
    var openHistory: () -> Void
    var selectDevice: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Network").font(.largeTitle.weight(.bold))
                    Text(scanner.interfaceName.isEmpty
                         ? "Press Scan to map every device on your Wi-Fi."
                         : "Interface \(scanner.interfaceName) · \(scanner.subnetSize) addresses in range")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    StatCard(title: "Devices online", value: "\(scanner.onlineCount)",
                             icon: "wifi", tint: .green)
                    StatCard(title: "New / unknown", value: "\(scanner.newCount)",
                             icon: "sparkles", tint: .pink)
                    StatCard(title: "Total tracked", value: "\(scanner.devices.count)",
                             icon: "square.stack.3d.up", tint: .blue)
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(text: "Network", icon: "network")
                        InfoRow(label: "This Mac", value: scanner.localIP, mono: true)
                        InfoRow(label: "Gateway", value: scanner.gatewayIP, mono: true)
                        InfoRow(label: "Interface", value: scanner.interfaceName)
                        InfoRow(label: "Gateway ping",
                                value: scanner.gatewayLatency.map { String(format: "%.1f ms", $0) } ?? "—")
                        InfoRow(label: "Internet ping",
                                value: scanner.internetLatency.map { String(format: "%.1f ms", $0) } ?? "—")
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SectionTitle(text: "Recent activity", icon: "clock.arrow.circlepath")
                            Spacer()
                            Button("See all", action: openHistory)
                                .buttonStyle(.borderless)
                                .font(.callout)
                        }
                        if scanner.events.isEmpty {
                            Text("No joins or departures recorded yet.")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            ForEach(scanner.events.prefix(6)) { e in
                                HStack(spacing: 10) {
                                    Image(systemName: e.kind.symbol)
                                        .foregroundStyle(e.kind.tint).frame(width: 18)
                                    Text("\(e.kind.verb): \(e.name)").lineLimit(1)
                                    Spacer()
                                    Text(e.date.formatted(date: .omitted, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .font(.callout)
                            }
                        }
                    }
                }

                Text("Select a device to inspect its identity, open ports and exposure.")
                    .font(.callout).foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .navigationTitle("Overview")
    }
}

struct StatCard: View {
    let title: String, value: String, icon: String, tint: Color
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).foregroundStyle(tint).font(.title3)
                Text(value).font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
