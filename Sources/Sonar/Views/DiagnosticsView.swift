import SwiftUI
import Charts

// MARK: - Live models

@MainActor final class PingModel: ObservableObject {
    @Published var samples: [Double] = []
    @Published var running = false
    @Published var host = "1.1.1.1"
    private var task: Task<Void, Never>?

    func toggle() { running ? stop() : start() }
    func start() {
        running = true; samples = []
        let h = host
        task = Task { [weak self] in
            while !Task.isCancelled {
                let l = await Task.detached { Ping.latency(h) }.value ?? -1
                await MainActor.run { self?.push(l) }
                let alive = await MainActor.run { self?.running == true }
                if !alive { break }
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }
    func stop() { running = false; task?.cancel(); task = nil }
    deinit { task?.cancel() }
    private func push(_ v: Double) { samples.append(v); if samples.count > 60 { samples.removeFirst() } }

    var valid: [Double] { samples.filter { $0 >= 0 } }
    var minMs: Double? { valid.min() }
    var maxMs: Double? { valid.max() }
    var avgMs: Double? { valid.isEmpty ? nil : valid.reduce(0, +) / Double(valid.count) }
    var lossPct: Int { samples.isEmpty ? 0 : Int(Double(samples.filter { $0 < 0 }.count) / Double(samples.count) * 100) }
}

@MainActor final class TraceModel: ObservableObject {
    @Published var hops: [NetTools.TraceHop] = []
    @Published var running = false
    @Published var host = "google.com"

    func run() async {
        running = true; hops = []
        let h = host
        let result = await Task.detached { NetTools.traceroute(h) }.value
        hops = result
        running = false
        for (i, hop) in result.enumerated() {
            if let geo = await NetTools.geolocate(hop.ip), i < hops.count { hops[i].geo = geo }
        }
    }
}

// MARK: - Main view

struct DiagnosticsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Diagnostics").font(Term.mono(26, .bold)).foregroundStyle(Term.green).glow()
                SpeedTestCard()
                PingCard()
                TracerouteCard()
                HStack(alignment: .top, spacing: 18) { DNSCard(); PublicIPCard() }
                WhoisCard()
            }
            .padding(20)
        }
        .navigationTitle("Diagnostics")
    }
}

struct StatMini: View {
    let label: String, value: String
    var tint: Color = .primary
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpeedTestCard: View {
    @StateObject private var st = SpeedTest()
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle(text: "Internet speed test", icon: "gauge.with.dots.needle.67percent")
                    Spacer()
                    Button(st.isRunning ? "Testing…" : "Start test") { Task { await st.start() } }
                        .disabled(st.isRunning).buttonStyle(TermButton())
                }
                if st.isRunning {
                    VStack(spacing: 2) {
                        (Text(String(format: "%.1f", st.liveMbps)).font(.system(size: 46, weight: .bold, design: .rounded))
                         + Text(" Mbps").font(.title3).foregroundStyle(.secondary))
                        Text(st.phaseText).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                HStack {
                    StatMini(label: "Download", value: st.downMbps > 0 ? String(format: "%.1f", st.downMbps) : "—", tint: Term.cyan)
                    StatMini(label: "Upload", value: st.upMbps > 0 ? String(format: "%.1f", st.upMbps) : "—", tint: .green)
                    StatMini(label: "Ping", value: st.latencyMs.map { String(format: "%.0f ms", $0) } ?? "—")
                    StatMini(label: "Jitter", value: st.jitterMs.map { String(format: "%.0f ms", $0) } ?? "—")
                }
                if let e = st.error { Text(e).font(.caption).foregroundStyle(.red) }
            }
        }
    }
}

struct PingCard: View {
    @StateObject private var pm = PingModel()
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Ping monitor", icon: "waveform.path.ecg")
                    Spacer()
                    TextField("Host", text: $pm.host).frame(width: 140).textFieldStyle(.roundedBorder)
                        .disabled(pm.running)
                    Button(pm.running ? "Stop" : "Start") { pm.toggle() }
                        .buttonStyle(TermButton())
                }
                if pm.samples.isEmpty {
                    Text("Continuously pings a host and charts round-trip latency.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Chart(Array(pm.samples.enumerated()), id: \.offset) { i, v in
                        LineMark(x: .value("n", i), y: .value("ms", max(v, 0)))
                            .foregroundStyle(Term.cyan).interpolationMethod(.catmullRom)
                        if v < 0 {
                            PointMark(x: .value("n", i), y: .value("ms", 0)).foregroundStyle(.red)
                        }
                    }
                    .frame(height: 120)
                    .chartYAxisLabel("ms")
                    HStack {
                        StatMini(label: "min", value: pm.minMs.map { String(format: "%.0f", $0) } ?? "—")
                        StatMini(label: "avg", value: pm.avgMs.map { String(format: "%.0f", $0) } ?? "—", tint: Term.cyan)
                        StatMini(label: "max", value: pm.maxMs.map { String(format: "%.0f", $0) } ?? "—")
                        StatMini(label: "loss", value: "\(pm.lossPct)%", tint: pm.lossPct > 0 ? .red : .primary)
                    }
                }
            }
        }
    }
}

struct TracerouteCard: View {
    @StateObject private var tm = TraceModel()
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Traceroute", icon: "point.topleft.down.to.point.bottomright.curvepath")
                    Spacer()
                    TextField("Host", text: $tm.host).frame(width: 160).textFieldStyle(.roundedBorder)
                        .disabled(tm.running)
                    Button(tm.running ? "Tracing…" : "Trace") { Task { await tm.run() } }
                        .disabled(tm.running).buttonStyle(TermButton())
                }
                if tm.hops.isEmpty && !tm.running {
                    Text("Maps every network hop between you and the destination, with geolocation.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(tm.hops) { hop in
                    HStack(spacing: 10) {
                        Text("\(hop.hop)").font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary).frame(width: 24, alignment: .trailing)
                        Text(hop.ip).font(.system(.callout, design: .monospaced))
                            .frame(width: 130, alignment: .leading)
                        Text(hop.ms.map { String(format: "%.1f ms", $0) } ?? "—")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                        Text(hop.geo ?? "").font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

struct DNSCard: View {
    @State private var name = "google.com"
    @State private var type = "A"
    @State private var result = ""
    @State private var busy = false
    private let types = ["A", "AAAA", "MX", "TXT", "CNAME", "NS", "PTR"]
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "DNS lookup", icon: "magnifyingglass")
                HStack {
                    TextField("domain", text: $name).textFieldStyle(.roundedBorder)
                    Picker("", selection: $type) { ForEach(types, id: \.self) { Text($0) } }.frame(width: 84)
                    Button("Query") {
                        busy = true
                        Task {
                            let r = await Task.detached { NetTools.dnsLookup(name, type: type) }.value
                            result = r; busy = false
                        }
                    }.disabled(busy)
                }
                if !result.isEmpty {
                    ScrollView {
                        Text(result).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 88)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Term.inputBG))
                }
            }
        }
    }
}

struct WhoisCard: View {
    @State private var domain = "apple.com"
    @State private var result = ""
    @State private var busy = false
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "WHOIS", icon: "doc.text.magnifyingglass")
                    Spacer()
                    TextField("domain", text: $domain).frame(width: 180).textFieldStyle(.roundedBorder)
                    Button(busy ? "…" : "Lookup") {
                        busy = true
                        Task {
                            let r = await Task.detached { NetTools.whois(domain) }.value
                            result = r; busy = false
                        }
                    }.disabled(busy)
                }
                if !result.isEmpty {
                    ScrollView {
                        Text(result).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 160)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Term.inputBG))
                }
            }
        }
    }
}

struct PublicIPCard: View {
    @State private var info: NetTools.PublicIP?
    @State private var loading = true
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Public IP", icon: "globe")
                if loading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let info {
                    InfoRow(label: "IP", value: info.ip, mono: true)
                    InfoRow(label: "Location", value: [info.city, info.region, info.country].filter { !$0.isEmpty }.joined(separator: ", "))
                    InfoRow(label: "ISP", value: info.org)
                } else {
                    Text("Couldn’t reach the lookup service.").font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .task {
            info = await NetTools.publicIP()
            loading = false
        }
    }
}
