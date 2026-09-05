import SwiftUI

@MainActor final class ExposureModel: ObservableObject {
    @Published var result: ExposureResult?
    @Published var auditing = false
    @Published var host = ""
    @Published var preset = "Common"
    @Published var rangeStart = "1"
    @Published var rangeEnd = "1024"
    @Published var scanResults: [PortInfo] = []
    @Published var scanning = false
    @Published var scannedHost = ""
    @Published var didScan = false

    func runAudit() async { auditing = true; result = await IGD.audit(); auditing = false }

    func portList() -> [Int] {
        switch preset {
        case "Top 1024": return Array(1...1024)
        case "Custom":
            let a = max(1, Int(rangeStart) ?? 1), b = min(65535, Int(rangeEnd) ?? 1024)
            return a <= b ? Array(a...min(b, a + 4096)) : []
        default: return PortScanner.ports.map { $0.port }
        }
    }
    func runScan() async {
        scanning = true; scannedHost = host
        scanResults = await PortScanner.scanHost(host, ports: portList())
        didScan = true; scanning = false
    }
}

struct ExposureView: View {
    @EnvironmentObject var scanner: Scanner
    @StateObject private var m = ExposureModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Exposure Audit").font(.largeTitle.weight(.bold))
                upnpCard
                scannerCard
            }
            .padding(20)
        }
        .navigationTitle("Exposure")
        .onAppear { if m.host.isEmpty { m.host = scanner.gatewayIP } }
    }

    private var upnpCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Internet exposure (UPnP)", icon: "lock.shield")
                    Spacer()
                    Button(m.auditing ? "Auditing…" : "Run audit") { Task { await m.runAudit() } }
                        .buttonStyle(.borderedProminent).disabled(m.auditing)
                }
                Text("Asks your router which ports it forwards to the internet — what the outside world can reach.")
                    .font(.callout).foregroundStyle(.secondary)

                if let r = m.result {
                    if let ip = r.externalIP {
                        InfoRow(label: "External IP", value: ip, mono: true)
                        if ip.hasPrefix("10.") || ip.hasPrefix("100.64") || ip.hasPrefix("192.168") {
                            Label("This is a private/CGNAT address — you're behind your ISP's NAT, so inbound exposure is limited.", systemImage: "checkmark.shield")
                                .font(.caption).foregroundStyle(.green)
                        }
                    }
                    if r.mappings.isEmpty {
                        Label(r.note ?? "No port forwards found.", systemImage: r.upnpAvailable ? "checkmark.shield.fill" : "info.circle")
                            .foregroundStyle(r.upnpAvailable ? .green : .secondary).font(.callout)
                    } else {
                        Label("\(r.mappings.count) port(s) forwarded to the internet — review these:", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.callout.weight(.medium))
                        ForEach(r.mappings) { mp in
                            HStack(spacing: 10) {
                                Circle().fill(mp.enabled ? Color.orange : Color.secondary).frame(width: 7, height: 7)
                                Text("\(mp.proto) \(mp.externalPort)").font(.system(.callout, design: .monospaced)).foregroundStyle(.orange).frame(width: 90, alignment: .leading)
                                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                Text("\(mp.internalClient):\(mp.internalPort)").font(.system(.callout, design: .monospaced))
                                Spacer()
                                Text(mp.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    private var scannerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Advanced port scanner", icon: "magnifyingglass.circle")
                HStack {
                    TextField("Host or IP", text: $m.host).textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Menu("Device") {
                        Button("Gateway (\(scanner.gatewayIP))") { m.host = scanner.gatewayIP }
                        Divider()
                        ForEach(scanner.devices.filter { $0.isOnline }) { d in
                            Button("\(d.displayName) — \(d.ip)") { m.host = d.ip }
                        }
                    }.frame(width: 120)
                    Picker("", selection: $m.preset) {
                        Text("Common").tag("Common")
                        Text("Top 1024").tag("Top 1024")
                        Text("Custom").tag("Custom")
                    }.frame(width: 190)
                }
                if m.preset == "Custom" {
                    HStack {
                        Text("Ports").foregroundStyle(.secondary)
                        TextField("from", text: $m.rangeStart).frame(width: 70).textFieldStyle(.roundedBorder)
                        Text("–")
                        TextField("to", text: $m.rangeEnd).frame(width: 70).textFieldStyle(.roundedBorder)
                        Text("(max 4096 at a time)").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                Button(m.scanning ? "Scanning \(m.host)…" : "Scan \(m.host.isEmpty ? "" : m.host)") {
                    Task { await m.runScan() }
                }
                .buttonStyle(.bordered).disabled(m.scanning || m.host.isEmpty)

                if m.scanning {
                    ProgressView().controlSize(.small)
                } else if m.didScan {
                    if m.scanResults.isEmpty {
                        Label("No open ports found on \(m.scannedHost).", systemImage: "checkmark.shield").foregroundStyle(.green).font(.callout)
                    } else {
                        Text("\(m.scanResults.count) open on \(m.scannedHost):").font(.caption).foregroundStyle(.secondary)
                        ForEach(m.scanResults) { p in
                            HStack(spacing: 10) {
                                Text("\(p.port)").font(.system(.callout, design: .monospaced)).foregroundStyle(.blue).frame(width: 60, alignment: .leading)
                                Text(p.service).font(.callout)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}
