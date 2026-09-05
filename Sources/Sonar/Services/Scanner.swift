import Foundation
import SwiftUI
import Combine

@MainActor
final class Scanner: ObservableObject {
    @Published var devices: [Device] = []
    @Published var events: [ScanEvent] = []
    @Published var anomalies: [AnomalyRecord] = []

    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var statusText = "Ready. Press Scan to map your network."
    @Published var lastScan: Date?
    @Published var scanningPortsFor: String?

    @Published var metricsHistory: [MetricSample] = []
    weak var throughput: ThroughputMeter?

    @Published var autoRefresh = false
    @Published var notifyJoinLeave = SettingsStore.notifyJoinLeave {
        didSet { SettingsStore.notifyJoinLeave = notifyJoinLeave }
    }
    @Published var interval: TimeInterval = 60

    // Network summary (for the header).
    @Published var interfaceName = ""
    @Published var localIP = ""
    @Published var gatewayIP = ""
    @Published var subnetSize = 0
    @Published var gatewayLatency: Double?
    @Published var internetLatency: Double?

    private let store = DeviceStore()
    private let metrics = MetricsStore()
    private var metricsTimer: Timer?
    private var autoTimer: Timer?

    init() {
        events = store.events
        anomalies = store.anomalies
        metricsHistory = metrics.samples
        Notifier.requestAuthorization()
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recordMetric() }
        }
    }

    func recordMetric() {
        let hist = throughput?.history ?? []
        let recent = hist.suffix(60)
        let d = recent.isEmpty ? (throughput?.downBps ?? 0) : recent.map { $0.down }.reduce(0, +) / Double(recent.count)
        let u = recent.isEmpty ? (throughput?.upBps ?? 0) : recent.map { $0.up }.reduce(0, +) / Double(recent.count)
        metrics.record(MetricSample(t: Date(), online: onlineCount, down: d, up: u,
                                    gwLatency: gatewayLatency, netLatency: internetLatency))
        metricsHistory = metrics.samples
    }

    var onlineCount: Int { devices.filter { $0.isOnline }.count }
    var newCount: Int { devices.filter { $0.isNew && $0.isOnline }.count }

    // MARK: - Full discovery scan

    func scanNow() async {
        if isScanning { return }
        isScanning = true
        progress = 0
        defer { isScanning = false }

        statusText = "Locating active network…"
        guard let net = await Task.detached(operation: { NetworkInfo.current() }).value else {
            statusText = "No active network connection found."
            return
        }
        interfaceName = net.interface
        localIP = net.localIP
        gatewayIP = net.gatewayIP
        subnetSize = net.hosts.count + 1

        // Fire SSDP/UPnP discovery in parallel with the ping sweep.
        let ssdpFuture = Task.detached(priority: .utility) { SSDP.discover(timeout: 2.0) }

        statusText = "Sweeping \(net.hosts.count) addresses…"
        let alive = await pingSweep(net.hosts)

        statusText = "Reading ARP table…"
        let arp = Arp.table()
        let ssdp = await ssdpFuture.value

        statusText = "Identifying devices…"
        var candidates = Set<String>()
        candidates.formUnion(alive)
        candidates.formUnion(arp.keys)
        if !net.gatewayIP.isEmpty { candidates.insert(net.gatewayIP) }
        candidates.insert(net.localIP)
        candidates = candidates.filter { ip in
            guard let first = Int(ip.split(separator: ".").first ?? "") else { return false }
            return first < 224 && !ip.hasSuffix(".255")   // drop multicast + broadcast
        }

        let netCopy = net, arpCopy = arp, ssdpCopy = ssdp
        let built: [Device] = await withTaskGroup(of: Device?.self) { group in
            for ip in candidates {
                group.addTask { await Scanner.buildDevice(ip: ip, net: netCopy, arp: arpCopy, ssdp: ssdpCopy) }
            }
            var acc: [Device] = []
            for await d in group { if let d { acc.append(d) } }
            return acc
        }

        applyResults(built)
        lastScan = Date()
        progress = 1
        statusText = summaryText()
        refreshHealth()
        recordMetric()
    }

    private func pingSweep(_ hosts: [String]) async -> Set<String> {
        var alive = Set<String>()
        let total = max(hosts.count, 1)
        var done = 0
        for chunk in hosts.chunked(64) {
            await withTaskGroup(of: String?.self) { group in
                for ip in chunk { group.addTask { await Ping.alive(ip) ? ip : nil } }
                for await r in group {
                    done += 1
                    progress = Double(done) / Double(total)
                    if let r { alive.insert(r) }
                }
            }
        }
        return alive
    }

    nonisolated private static func buildDevice(ip: String, net: NetworkInfo,
                                                arp: [String: String],
                                                ssdp: [String: SSDPDevice]) async -> Device? {
        let isThis = (ip == net.localIP)
        let isGw = (ip == net.gatewayIP)
        let mac = isThis ? net.localMAC : (arp[ip] ?? "")

        let hostname = Resolver.hostname(for: ip)
        var vendor = OUIDatabase.vendor(for: mac)
        let s = ssdp[ip]
        if (vendor == nil || vendor!.isEmpty), let server = s?.server {
            vendor = shortServer(server)
        }
        let hint = hostname ?? s?.server
        let type = Fingerprint.inferType(vendor: vendor, hostname: hint, ports: [],
                                         isGateway: isGw, isThisDevice: isThis)

        var dev = Device(mac: mac, ip: ip, hostname: hostname, vendor: vendor,
                         deviceType: type, isOnline: true, isGateway: isGw, isThisDevice: isThis)
        dev.ssdpServer = s?.server
        return dev
    }

    // MARK: - Merge + presence diffing

    private func applyResults(_ incoming: [Device]) {
        if let gw = incoming.first(where: { $0.isGateway }), !gw.mac.isEmpty {
            let key = "sonar.gatewayMAC"
            let prev = UserDefaults.standard.string(forKey: key)
            if let prev, prev != gw.mac {
                store.addAnomaly(AnomalyRecord(kind: "gatewayMAC",
                    title: "Gateway MAC address changed",
                    detail: "Your router's MAC went from \(prev) to \(gw.mac). This can mean the router was replaced — or that a rogue gateway (evil-twin) is on the network. Verify it's really your router.",
                    severity: 2))
                Notifier.notify(title: "⚠︎ Gateway MAC changed", body: "Possible rogue router — verify your gateway in Sonar.")
            }
            UserDefaults.standard.set(gw.mac, forKey: key)
        }
        let oldByID = Dictionary(devices.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var result: [Device] = []
        var seen = Set<String>()

        for var dev in incoming {
            seen.insert(dev.id)

            if !dev.mac.isEmpty {
                let (firstSeen, wasNew) = store.note(mac: dev.mac, vendor: dev.vendor, hostname: dev.hostname)
                dev.firstSeen = firstSeen
                if let rec = store.record(dev.mac) {
                    dev.customName = rec.customName
                    dev.trusted = rec.trusted
                    dev.notes = rec.notes
                    dev.alertOnJoin = rec.alertOnJoin ?? false
                    dev.alertOnLeave = rec.alertOnLeave ?? false
                }
                if wasNew && !dev.isThisDevice {
                    dev.isNew = true
                    store.addEvent(ScanEvent(kind: .newDevice, mac: dev.mac, name: dev.displayName, ip: dev.ip))
                    Notifier.newDevice(name: dev.displayName, ip: dev.ip)
                    let hour = Calendar.current.component(.hour, from: Date())
                    if hour < 6 {
                        store.addAnomaly(AnomalyRecord(kind: "oddHours",
                            title: "New device at odd hours",
                            detail: "\(dev.displayName) (\(dev.ip)) first appeared at \(Date().formatted(date: .omitted, time: .shortened)) — outside typical hours.",
                            severity: 1))
                    }
                }
            }

            if let old = oldByID[dev.id] {
                dev.openPorts = old.openPorts
                dev.portsScanned = old.portsScanned
                dev.isNew = old.isNew || dev.isNew
                if old.firstSeen < dev.firstSeen { dev.firstSeen = old.firstSeen }
                if old.portsScanned {
                    dev.deviceType = Fingerprint.inferType(vendor: dev.vendor, hostname: dev.hostname,
                                                           ports: old.openPorts.map { $0.port },
                                                           isGateway: dev.isGateway, isThisDevice: dev.isThisDevice)
                }
                if !old.isOnline && !dev.isNew {
                    store.addEvent(ScanEvent(kind: .joined, mac: dev.mac, name: dev.displayName, ip: dev.ip))
                    if notifyJoinLeave || dev.alertOnJoin { Notifier.notify(title: "Device joined", body: "\(dev.displayName) — \(dev.ip)") }
                }
            }
            dev.lastSeen = Date()
            dev.isOnline = true
            result.append(dev)
        }

        for (id, old) in oldByID where !seen.contains(id) {
            var gone = old
            if gone.isOnline {
                gone.isOnline = false
                store.addEvent(ScanEvent(kind: .left, mac: gone.mac, name: gone.displayName, ip: gone.ip))
                if notifyJoinLeave || gone.alertOnLeave { Notifier.notify(title: "Device left", body: "\(gone.displayName) — \(gone.ip)") }
            }
            result.append(gone)
        }

        store.saveRecords()
        devices = sortDevices(result)
        events = store.events
        anomalies = store.anomalies
    }

    private func sortDevices(_ list: [Device]) -> [Device] {
        list.sorted { a, b in
            func key(_ d: Device) -> (Int, Int, Int, UInt32) {
                (d.isOnline ? 0 : 1, d.isGateway ? 0 : 1, d.isThisDevice ? 0 : 1,
                 NetworkInfo.ipToUInt32(d.ip) ?? 0)
            }
            return key(a) < key(b)
        }
    }

    private func summaryText() -> String {
        let n = newCount
        let base = "\(onlineCount) online · scanned \(subnetSize) addresses"
        return n > 0 ? "\(base) · \(n) new device\(n == 1 ? "" : "s")" : base
    }

    // MARK: - Port scan (on demand)

    func scanPorts(_ device: Device) async {
        scanningPortsFor = device.id
        defer { scanningPortsFor = nil }
        let ports = await PortScanner.scan(ip: device.ip)
        guard let i = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[i].openPorts = ports
        devices[i].portsScanned = true
        devices[i].deviceType = Fingerprint.inferType(vendor: devices[i].vendor,
                                                       hostname: devices[i].hostname,
                                                       ports: ports.map { $0.port },
                                                       isGateway: devices[i].isGateway,
                                                       isThisDevice: devices[i].isThisDevice)
        if let hp = [80, 8080, 8000, 8888].first(where: { p in ports.contains { $0.port == p } }),
           let title = await HTTPTitle.fetch(ip: device.ip, port: hp) {
            if let j = devices.firstIndex(where: { $0.id == device.id }) { devices[j].httpTitle = title }
        }
    }

    // MARK: - Labels

    func updateLabel(for device: Device, name: String?, trusted: Bool, notes: String) {
        guard !device.mac.isEmpty else { return }
        let clean = (name ?? "").trimmingCharacters(in: .whitespaces)
        store.setLabel(mac: device.mac, customName: clean.isEmpty ? nil : clean, trusted: trusted, notes: notes)
        if let i = devices.firstIndex(where: { $0.id == device.id }) {
            devices[i].customName = clean.isEmpty ? nil : clean
            devices[i].trusted = trusted
            devices[i].notes = notes
            devices[i].isNew = false
        }
    }

    func setAlerts(for device: Device, onJoin: Bool, onLeave: Bool) {
        guard !device.mac.isEmpty else { return }
        store.setAlerts(mac: device.mac, onJoin: onJoin, onLeave: onLeave)
        if let i = devices.firstIndex(where: { $0.id == device.id }) {
            devices[i].alertOnJoin = onJoin
            devices[i].alertOnLeave = onLeave
        }
    }

    func clearNewFlag(_ device: Device) {
        if let i = devices.firstIndex(where: { $0.id == device.id }) { devices[i].isNew = false }
    }

    func clearEvents() { store.clearEvents(); events = [] }
    func clearAnomalies() { store.clearAnomalies(); anomalies = [] }

    // MARK: - Health + throughput meter

    private func refreshHealth() {
        let gw = gatewayIP
        Task.detached(priority: .utility) {
            let g = gw.isEmpty ? nil : Ping.latency(gw)
            let i = Ping.latency("1.1.1.1")
            await MainActor.run { self.gatewayLatency = g; self.internetLatency = i }
        }
    }

    func attach(_ meter: ThroughputMeter) { throughput = meter }

    func setAutoRefresh(_ on: Bool) {
        autoRefresh = on
        autoTimer?.invalidate(); autoTimer = nil
        if on {
            autoTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in await self?.scanNow() }
            }
        }
    }

    func setInterval(_ seconds: TimeInterval) {
        interval = seconds
        if autoRefresh { setAutoRefresh(true) }
    }

    // Helpers for SSDP enrichment.
    nonisolated static func shortServer(_ server: String) -> String? {
        for token in server.split(separator: " ") {
            let t = String(token)
            let lower = t.lowercased()
            if lower.hasPrefix("upnp") || lower.hasPrefix("linux") || lower.hasPrefix("http") { continue }
            let product = t.split(separator: "/").first.map(String.init) ?? t
            if product.count >= 3 { return product }
        }
        return nil
    }
}
