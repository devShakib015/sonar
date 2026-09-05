import SwiftUI
import Charts

@MainActor final class MonitorModel: ObservableObject {
    @Published var procs: [Monitor.ProcUsage] = []
    @Published var loading = false
    private var timer: Timer?

    func onAppear() {
        Task { await refresh() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }
    func onDisappear() { timer?.invalidate(); timer = nil }

    func refresh() async {
        if loading { return }
        loading = true
        procs = await Task.detached { Monitor.topTalkers() }.value
        loading = false
    }
}

struct MonitorView: View {
    @EnvironmentObject var scanner: Scanner
    @EnvironmentObject var meter: ThroughputMeter
    @StateObject private var m = MonitorModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Monitor").font(Term.mono(26, .bold)).foregroundStyle(Term.green).glow()
                throughputCard
                talkersCard
                exportCard
            }
            .padding(20)
        }
        .navigationTitle("Monitor")
        .onAppear { m.onAppear() }
        .onDisappear { m.onDisappear() }
    }

    private var throughputCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Live throughput", icon: "chart.xyaxis.line")
                    Spacer()
                    HStack(spacing: 3) { Image(systemName: "arrow.down"); Text(formatBytesPerSec(meter.downBps)) }.foregroundStyle(Term.cyan)
                    HStack(spacing: 3) { Image(systemName: "arrow.up"); Text(formatBytesPerSec(meter.upBps)) }.foregroundStyle(.green)
                }
                .font(.callout.monospacedDigit())

                if meter.history.count > 1 {
                    Chart(Array(meter.history.enumerated()), id: \.offset) { i, s in
                        AreaMark(x: .value("t", i), y: .value("down", s.down / 1024))
                            .foregroundStyle(Term.cyan.opacity(0.15))
                        LineMark(x: .value("t", i), y: .value("down", s.down / 1024), series: .value("s", "down"))
                            .foregroundStyle(Term.cyan)
                        LineMark(x: .value("t", i), y: .value("up", s.up / 1024), series: .value("s", "up"))
                            .foregroundStyle(.green)
                    }
                    .frame(height: 140)
                    .chartYAxisLabel("KB/s")
                } else {
                    Text("Charts your Mac's up/down traffic once data flows (updates every second).")
                        .font(.callout).foregroundStyle(.secondary).frame(height: 60)
                }
            }
        }
    }

    private var talkersCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Top talkers (per process)", icon: "app.badge")
                    Spacer()
                    if m.loading { ProgressView().controlSize(.small) }
                }
                if m.procs.isEmpty {
                    Text("Measuring which apps are using your connection…")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(m.procs) { p in
                        HStack(spacing: 10) {
                            Text(p.name).lineLimit(1).frame(width: 190, alignment: .leading)
                            Spacer()
                            Label(formatBytesPerSec(p.inBps), systemImage: "arrow.down")
                                .foregroundStyle(Term.cyan).font(.caption.monospacedDigit())
                            Label(formatBytesPerSec(p.outBps), systemImage: "arrow.up")
                                .foregroundStyle(.green).font(.caption.monospacedDigit())
                        }
                    }
                }
            }
        }
    }

    private var exportCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Export network map", icon: "square.and.arrow.up")
                HStack {
                    Button { Exporter.save(Exporter.csv(scanner.devices), name: "sonar-network.csv") } label: {
                        Label("CSV", systemImage: "tablecells")
                    }.buttonStyle(TermButton())
                    Button { Exporter.save(Exporter.json(scanner.devices), name: "sonar-network.json") } label: {
                        Label("JSON", systemImage: "curlybraces")
                    }.buttonStyle(TermButton())
                    Button { Exporter.savePDF(Exporter.report(scanner.devices), name: "sonar-report.pdf") } label: {
                        Label("PDF report", systemImage: "doc.richtext")
                    }.buttonStyle(TermButton())
                }
                Text("\(scanner.devices.count) devices will be exported.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
