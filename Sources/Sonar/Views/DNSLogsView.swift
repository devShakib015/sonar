import SwiftUI

@MainActor final class DNSLogModel: ObservableObject {
    @Published var config = DNSLogs.loadConfig()
    @Published var queries: [DNSQuery] = []
    @Published var connected = false
    @Published var loading = false
    @Published var status = ""
    @Published var deviceFilter: String?
    @Published var search = ""
    private var timer: Timer?

    func save() { DNSLogs.saveConfig(config) }

    func connect() async {
        save()
        await refresh()
        if connected {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
        }
    }

    func disconnect() {
        timer?.invalidate(); timer = nil
        connected = false; queries = []; status = ""
    }

    func refresh() async {
        if loading { return }
        loading = true
        do {
            let q = try await DNSLogs.fetch(config)
            queries = q.sorted { $0.time > $1.time }
            connected = true
            status = "\(q.count) recent queries · updated \(Date().formatted(date: .omitted, time: .standard))"
        } catch {
            status = error.localizedDescription
            if queries.isEmpty { connected = false }
        }
        loading = false
    }

    var devices: [String] { Array(Set(queries.map { $0.device })).sorted() }
    var filtered: [DNSQuery] {
        queries.filter { q in
            (deviceFilter == nil || q.device == deviceFilter) &&
            (search.isEmpty || q.domain.localizedCaseInsensitiveContains(search))
        }
    }
    var blockedCount: Int { filtered.filter { $0.blocked }.count }
    var topDomains: [(String, Int)] {
        Dictionary(grouping: filtered, by: { $0.domain })
            .map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }.prefix(8).map { $0 }
    }
}

struct DNSLogsView: View {
    @StateObject private var m = DNSLogModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("DNS Logs").font(.largeTitle.weight(.bold))
                Text("See which device requested which domain — via your own DNS resolver. No traffic interception; this reads your resolver's query log.")
                    .font(.callout).foregroundStyle(.secondary)

                if m.connected { connectedView } else { setupView }
            }
            .padding(20)
        }
        .navigationTitle("DNS Logs")
    }

    // MARK: setup
    private var setupView: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(text: "Connect a resolver", icon: "network.badge.shield.half.filled")
                Picker("Provider", selection: $m.config.provider) {
                    Text("NextDNS").tag("NextDNS")
                    Text("Pi-hole").tag("Pi-hole")
                }.pickerStyle(.segmented).frame(width: 240)

                if m.config.provider == "NextDNS" {
                    TextField("Profile ID (e.g. abc123)", text: $m.config.nextdnsProfile).textFieldStyle(.roundedBorder)
                    SecureField("API key", text: $m.config.nextdnsKey).textFieldStyle(.roundedBorder)
                    helpLine("Get both from my.nextdns.io → Setup (profile ID) and Account (API key).",
                             "Open NextDNS", "https://my.nextdns.io/")
                } else {
                    TextField("Pi-hole host or IP (e.g. 192.168.0.5)", text: $m.config.piholeHost).textFieldStyle(.roundedBorder)
                    SecureField("App password (Pi-hole v6)", text: $m.config.piholePassword).textFieldStyle(.roundedBorder)
                    helpLine("In Pi-hole v6: Settings → Web interface / API → create an app password.", nil, nil)
                }

                HStack {
                    Button(m.loading ? "Connecting…" : "Connect") { Task { await m.connect() } }
                        .buttonStyle(.borderedProminent).disabled(m.loading)
                    if !m.status.isEmpty { Text(m.status).font(.caption).foregroundStyle(.red) }
                }

                Divider()
                Label("Point your router's DNS (or each device) at this resolver so queries flow through it. The Control tab sets this Mac's DNS.",
                      systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func helpLine(_ text: String, _ linkTitle: String?, _ url: String?) -> some View {
        HStack(spacing: 6) {
            Text(text).font(.caption).foregroundStyle(.secondary)
            if let linkTitle, let url, let u = URL(string: url) {
                Link(linkTitle, destination: u).font(.caption)
            }
        }
    }

    // MARK: connected
    private var connectedView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                StatCard(title: "Queries", value: "\(m.filtered.count)", icon: "list.bullet", tint: .blue)
                StatCard(title: "Blocked", value: "\(m.blockedCount)", icon: "hand.raised", tint: .red)
                StatCard(title: "Devices", value: "\(m.devices.count)", icon: "desktopcomputer", tint: .green)
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionTitle(text: "Query stream", icon: "waveform")
                        Spacer()
                        if m.loading { ProgressView().controlSize(.small) }
                        Menu(m.deviceFilter ?? "All devices") {
                            Button("All devices") { m.deviceFilter = nil }
                            Divider()
                            ForEach(m.devices, id: \.self) { d in Button(d) { m.deviceFilter = d } }
                        }.frame(width: 160)
                        Button("Disconnect") { m.disconnect() }.buttonStyle(.bordered)
                    }
                    TextField("Filter domains…", text: $m.search).textFieldStyle(.roundedBorder)

                    ForEach(m.filtered.prefix(120)) { q in
                        HStack(spacing: 10) {
                            Circle().fill(q.blocked ? Color.red : Color.green).frame(width: 7, height: 7)
                            Text(q.domain).font(.system(.callout, design: .monospaced)).lineLimit(1)
                            Spacer(minLength: 8)
                            Text(q.device).font(.caption).foregroundStyle(.secondary).lineLimit(1).frame(maxWidth: 130, alignment: .trailing)
                            Text(q.time.formatted(date: .omitted, time: .shortened))
                                .font(.caption.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 64, alignment: .trailing)
                        }
                    }
                    if !m.status.isEmpty { Text(m.status).font(.caption2).foregroundStyle(.tertiary) }
                }
            }

            if !m.topDomains.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(text: "Top domains", icon: "chart.bar")
                        ForEach(m.topDomains, id: \.0) { domain, count in
                            HStack {
                                Text(domain).font(.system(.callout, design: .monospaced)).lineLimit(1)
                                Spacer()
                                Text("\(count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
