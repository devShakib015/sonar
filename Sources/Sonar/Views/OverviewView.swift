import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var scanner: Scanner
    @EnvironmentObject var uptime: UptimeMonitor
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

                healthHero

                if !scanner.anomalies.isEmpty { anomaliesCard }

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

    private var report: HealthReport {
        HealthScore.evaluate(devices: scanner.devices, uptimePercent: uptime.uptimePercent(hours: 24))
    }
    private var gradeColor: Color {
        switch report.score { case 90...: return .green; case 70..<90: return .yellow; case 50..<70: return .orange; default: return .red }
    }
    private var anomaliesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle(text: "Security anomalies", icon: "exclamationmark.shield.fill")
                    Spacer()
                    Button("Clear") { scanner.clearAnomalies() }.buttonStyle(.borderless).font(.callout)
                }
                ForEach(scanner.anomalies.prefix(6)) { a in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(severityColor(a.severity)).font(.caption).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title).fontWeight(.semibold)
                            Text(a.detail).font(.callout).foregroundStyle(.secondary)
                            Text(a.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var healthHero: some View {
        Card {
            HStack(alignment: .center, spacing: 22) {
                HealthRing(score: report.score, color: gradeColor)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text("Network Health").font(.headline)
                        Text(report.grade).font(.headline.weight(.bold)).foregroundStyle(gradeColor)
                            .padding(.horizontal, 9).padding(.vertical, 1)
                            .background(Capsule().fill(gradeColor.opacity(0.16)))
                    }
                    ForEach(report.factors.prefix(4)) { f in
                        HStack(spacing: 6) {
                            Image(systemName: f.good ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(f.good ? .green : (f.delta <= -10 ? .red : .orange))
                            Text(f.label).font(.callout)
                            Spacer(minLength: 8)
                            if f.delta != 0 { Text("\(f.delta)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                        }
                    }
                    Text("Scan device ports (Devices tab) to sharpen the security score.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct HealthRing: View {
    let score: Int
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 12)
            Circle().trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: score)
            VStack(spacing: 0) {
                Text("\(score)").font(.system(size: 38, weight: .bold, design: .rounded))
                Text("/ 100").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 116, height: 116)
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
