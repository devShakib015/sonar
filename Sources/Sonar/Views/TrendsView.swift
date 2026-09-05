import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject var scanner: Scanner
    @State private var range: TrendRange = .day

    enum TrendRange: String, CaseIterable, Identifiable {
        case hour = "1h", six = "6h", day = "24h", week = "7d"
        var id: String { rawValue }
        var seconds: TimeInterval {
            switch self { case .hour: return 3600; case .six: return 6*3600
            case .day: return 24*3600; case .week: return 7*24*3600 }
        }
    }

    private var samples: [MetricSample] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        return scanner.metricsHistory.filter { $0.t >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Trends").font(Term.mono(26, .bold)).foregroundStyle(Term.green).glow()
                    Spacer()
                    Picker("", selection: $range) {
                        ForEach(TrendRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(width: 220)
                }

                if samples.count < 2 {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Collecting data…", systemImage: "hourglass").font(.headline)
                            Text("Sonar records a metrics sample every minute and after every scan, and keeps 7 days of history on disk. Leave it running and trends will fill in here.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    summaryRow
                    devicesChart
                    throughputChart
                    latencyChart
                }
            }
            .padding(20)
        }
        .navigationTitle("Trends")
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Samples", value: "\(samples.count)", icon: "chart.dots.scatter", tint: Term.cyan)
            StatCard(title: "Peak devices", value: "\(samples.map { $0.online }.max() ?? 0)", icon: "wifi", tint: .green)
            StatCard(title: "Peak ↓", value: formatBytesPerSec(samples.map { $0.down }.max() ?? 0), icon: "arrow.down", tint: Term.cyan)
            StatCard(title: "Avg ping", value: avgLatencyText, icon: "timer", tint: Term.cyan)
        }
    }

    private var avgLatencyText: String {
        let vals = samples.compactMap { $0.netLatency }
        guard !vals.isEmpty else { return "—" }
        return String(format: "%.0f ms", vals.reduce(0, +) / Double(vals.count))
    }

    private var devicesChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Devices online", icon: "wifi")
                Chart(samples) { s in
                    AreaMark(x: .value("time", s.t), y: .value("online", s.online))
                        .foregroundStyle(.green.opacity(0.15))
                    LineMark(x: .value("time", s.t), y: .value("online", s.online))
                        .foregroundStyle(.green).interpolationMethod(.stepCenter)
                }
                .frame(height: 130)
            }
        }
    }

    private var throughputChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Throughput (avg per sample)", icon: "chart.xyaxis.line")
                Chart(samples) { s in
                    LineMark(x: .value("time", s.t), y: .value("down", s.down / 1024), series: .value("s", "down"))
                        .foregroundStyle(Term.cyan)
                    LineMark(x: .value("time", s.t), y: .value("up", s.up / 1024), series: .value("s", "up"))
                        .foregroundStyle(.green)
                }
                .frame(height: 130)
                .chartYAxisLabel("KB/s")
                HStack(spacing: 14) {
                    Label("Download", systemImage: "circle.fill").foregroundStyle(Term.cyan)
                    Label("Upload", systemImage: "circle.fill").foregroundStyle(.green)
                }.font(.caption2)
            }
        }
    }

    private var latencyChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Latency", icon: "timer")
                Chart(samples) { s in
                    if let g = s.gwLatency {
                        LineMark(x: .value("time", s.t), y: .value("ms", g), series: .value("s", "gateway"))
                            .foregroundStyle(Term.amber)
                    }
                    if let n = s.netLatency {
                        LineMark(x: .value("time", s.t), y: .value("ms", n), series: .value("s", "internet"))
                            .foregroundStyle(Term.cyan)
                    }
                }
                .frame(height: 130)
                .chartYAxisLabel("ms")
                HStack(spacing: 14) {
                    Label("Gateway", systemImage: "circle.fill").foregroundStyle(Term.amber)
                    Label("Internet", systemImage: "circle.fill").foregroundStyle(Term.cyan)
                }.font(.caption2)
            }
        }
    }
}
