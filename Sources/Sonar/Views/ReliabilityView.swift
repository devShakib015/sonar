import SwiftUI
import Charts

struct ReliabilityView: View {
    @EnvironmentObject var uptime: UptimeMonitor
    @State private var speedHistory: [SpeedResult] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Uptime & Reliability").font(Term.mono(26, .bold)).foregroundStyle(Term.green).glow()
                statusCard
                outagesCard
                speedHistoryCard
            }
            .padding(20)
        }
        .navigationTitle("Uptime")
        .onAppear { speedHistory = SpeedHistory.load() }
    }

    private func pill(_ up: Bool, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(up ? Color.green : Color.red).frame(width: 8, height: 8)
            Text("\(label): \(up ? "Up" : "Down")").font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill((up ? Color.green : Color.red).opacity(0.15)))
    }

    private var statusCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Connection status", icon: "bolt.horizontal.circle")
                    Spacer()
                    Toggle("Monitoring", isOn: Binding(get: { uptime.monitoring }, set: { _ in uptime.toggle() }))
                        .toggleStyle(.switch)
                }
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.2f%%", uptime.uptimePercent(hours: 24)))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(uptime.uptimePercent(hours: 24) > 99 ? .green : Term.amber)
                        Text("uptime (24h)").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        pill(uptime.internetUp, "Internet")
                        pill(uptime.gatewayUp, "Gateway")
                        if let l = uptime.lastCheck {
                            Text("Checked \(l.formatted(date: .omitted, time: .standard))")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
                if let c = uptime.currentOutage {
                    Label("\(c.scope == "local" ? "Local network" : "Internet") down since \(c.start.formatted(date: .omitted, time: .shortened))",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red).font(.callout.weight(.medium))
                }
            }
        }
    }

    private var outagesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Outage log", icon: "list.bullet.clipboard")
                if uptime.outages.isEmpty {
                    Label("No outages recorded since monitoring began. 🎉", systemImage: "checkmark.seal")
                        .foregroundStyle(.green).font(.callout)
                } else {
                    ForEach(uptime.outages.prefix(30)) { o in
                        HStack(spacing: 10) {
                            Image(systemName: o.scope == "local" ? "house.slash" : "globe.badge.chevron.backward")
                                .foregroundStyle(.red).frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(o.scope == "local" ? "Local network" : "Internet").fontWeight(.medium)
                                Text(o.start.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(o.durationSec.map { UptimeMonitor.fmt($0) } ?? "ongoing")
                                .font(.caption.monospacedDigit()).foregroundStyle(Term.amber)
                        }
                    }
                }
            }
        }
    }

    private var speedHistoryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Speed-test history", icon: "gauge.with.dots.needle.67percent")
                if speedHistory.count < 2 {
                    Text("Run a few tests in the Diagnostics tab and they'll be charted here over time.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Chart(speedHistory.reversed()) { r in
                        LineMark(x: .value("t", r.date), y: .value("down", r.down), series: .value("s", "down"))
                            .foregroundStyle(Term.cyan)
                        PointMark(x: .value("t", r.date), y: .value("down", r.down)).foregroundStyle(Term.cyan)
                        LineMark(x: .value("t", r.date), y: .value("up", r.up), series: .value("s", "up"))
                            .foregroundStyle(.green)
                    }
                    .frame(height: 140)
                    .chartYAxisLabel("Mbps")
                    HStack(spacing: 14) {
                        Label("Download", systemImage: "circle.fill").foregroundStyle(Term.cyan)
                        Label("Upload", systemImage: "circle.fill").foregroundStyle(.green)
                    }.font(.caption2)
                    ForEach(speedHistory.prefix(5)) { r in
                        HStack {
                            Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "↓ %.1f  ↑ %.1f Mbps", r.down, r.up)).font(.caption.monospacedDigit())
                        }
                    }
                }
            }
        }
    }
}
