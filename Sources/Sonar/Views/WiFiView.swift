import SwiftUI
import CoreLocation
import Charts

@MainActor final class WiFiModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var info: WiFiInfo?
    @Published var rssiHistory: [Int] = []
    @Published var scanResults: [WiFiScanResult] = []
    @Published var scanning = false
    private let loc = CLLocationManager()
    private var timer: Timer?

    override init() { super.init(); loc.delegate = self }

    func onAppear() {
        loc.requestWhenInUseAuthorization()
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func onDisappear() { timer?.invalidate(); timer = nil }

    func refresh() {
        info = WiFi.current()
        if let r = info?.rssi, r != 0 {
            rssiHistory.append(r)
            if rssiHistory.count > 60 { rssiHistory.removeFirst() }
        }
    }
    func runScan() async {
        scanning = true
        scanResults = await Task.detached { WiFi.scan() }.value
        scanning = false
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refresh() }
    }
    var needsLocation: Bool { (info?.ssid ?? nil) == nil && info != nil }
}

struct WiFiView: View {
    @StateObject private var m = WiFiModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Wi-Fi Analyzer").font(Term.mono(26, .bold)).foregroundStyle(Term.green).glow()

                if m.info == nil {
                    Card { Label("No Wi-Fi interface found on this Mac.", systemImage: "wifi.slash").foregroundStyle(.secondary) }
                } else {
                    if m.needsLocation {
                        Card {
                            HStack(spacing: 10) {
                                Image(systemName: "location.slash").foregroundStyle(Term.amber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Grant Location access for SSID + scanning").fontWeight(.medium)
                                    Text("macOS requires Location permission to expose the network name and nearby APs.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Open Settings") {
                                    if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                                        NSWorkspace.shared.open(u)
                                    }
                                }
                            }
                        }
                    }
                    linkCard
                    scanCard
                }
            }
            .padding(20)
        }
        .navigationTitle("Wi-Fi")
        .onAppear { m.onAppear() }
        .onDisappear { m.onDisappear() }
    }

    private func tint(_ name: String) -> Color {
        switch name { case "green": return .green; case "yellow": return Term.amber
        case "orange": return Term.amber; case "red": return .red; default: return .primary }
    }

    private var linkCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(text: "Current connection", icon: "wifi")
                if let info = m.info {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Network", value: info.ssid ?? "—")
                            InfoRow(label: "BSSID", value: info.bssid ?? "—", mono: true)
                            InfoRow(label: "Security", value: info.security)
                            InfoRow(label: "Channel", value: "\(info.channel)  ·  \(info.band)  ·  \(info.width)")
                            InfoRow(label: "TX rate", value: info.txRate > 0 ? String(format: "%.0f Mbps", info.txRate) : "—")
                            InfoRow(label: "Noise", value: "\(info.noise) dBm  ·  SNR \(info.snr) dB")
                        }
                        VStack(spacing: 6) {
                            Text("\(info.rssi)").font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(tint(info.quality.tint))
                            Text("dBm").font(.caption).foregroundStyle(.secondary)
                            Text(info.quality.label).font(.callout.weight(.semibold))
                                .foregroundStyle(tint(info.quality.tint))
                            Gauge(value: Double(max(min(info.rssi, -30), -100)), in: -100...(-30)) { EmptyView() }
                                .gaugeStyle(.accessoryLinearCapacity)
                                .tint(tint(info.quality.tint))
                                .frame(width: 140)
                        }
                    }
                    if m.rssiHistory.count > 1 {
                        Chart(Array(m.rssiHistory.enumerated()), id: \.offset) { i, v in
                            LineMark(x: .value("n", i), y: .value("dBm", v))
                                .foregroundStyle(tint(info.quality.tint)).interpolationMethod(.catmullRom)
                        }
                        .chartYScale(domain: -100...(-30))
                        .frame(height: 90)
                    }
                }
            }
        }
    }

    private var scanCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Nearby networks", icon: "dot.radiowaves.up.forward")
                    Spacer()
                    Button(m.scanning ? "Scanning…" : "Scan") { Task { await m.runScan() } }
                        .disabled(m.scanning).buttonStyle(TermButton())
                }
                if let advice = WiFi.advice(m.scanResults) {
                    Label(advice, systemImage: "wand.and.stars").font(.callout).foregroundStyle(Term.cyan)
                }
                if m.scanResults.isEmpty {
                    Text("Scans for access points in range and recommends the least-congested channel.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(m.scanResults) { n in
                        HStack(spacing: 10) {
                            Image(systemName: "wifi").foregroundStyle(.secondary).frame(width: 18)
                            Text(n.ssid).lineLimit(1).frame(width: 160, alignment: .leading)
                            Text("ch \(n.channel)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
                            Text(n.band).font(.caption).foregroundStyle(.tertiary).frame(width: 60, alignment: .leading)
                            Text("\(n.rssi) dBm").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}
