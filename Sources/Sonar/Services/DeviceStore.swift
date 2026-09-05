import Foundation

// Persists per-device labels (name / trusted / notes), the set of MACs ever
// seen (so "new device" survives relaunches), and the recent event log.
final class DeviceStore {
    private(set) var records: [String: StoredDevice] = [:]
    private(set) var events: [ScanEvent] = []
    private(set) var anomalies: [AnomalyRecord] = []

    private let dir: URL
    private let recordsURL: URL
    private let eventsURL: URL
    private let anomaliesURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("Sonar", isDirectory: true)
        recordsURL = dir.appendingPathComponent("devices.json")
        eventsURL = dir.appendingPathComponent("events.json")
        anomaliesURL = dir.appendingPathComponent("anomalies.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
        prune()
    }

    // Record a sighting; returns (firstSeen, wasBrandNew).
    @discardableResult
    func note(mac: String, vendor: String?, hostname: String?) -> (Date, Bool) {
        guard !mac.isEmpty else { return (Date(), false) }
        if var rec = records[mac] {
            if let vendor { rec.lastVendor = vendor }
            if let hostname { rec.lastHostname = hostname }
            records[mac] = rec
            return (rec.firstSeen, false)
        } else {
            let now = Date()
            records[mac] = StoredDevice(mac: mac, customName: nil, trusted: false,
                                        notes: "", firstSeen: now,
                                        lastVendor: vendor, lastHostname: hostname)
            return (now, true)
        }
    }

    func record(_ mac: String) -> StoredDevice? { records[mac] }

    func setLabel(mac: String, customName: String?, trusted: Bool, notes: String) {
        guard !mac.isEmpty else { return }
        if var rec = records[mac] {
            rec.customName = customName; rec.trusted = trusted; rec.notes = notes
            records[mac] = rec
        } else {
            records[mac] = StoredDevice(mac: mac, customName: customName, trusted: trusted,
                                        notes: notes, firstSeen: Date(),
                                        lastVendor: nil, lastHostname: nil)
        }
        saveRecords()
    }

    func setAlerts(mac: String, onJoin: Bool, onLeave: Bool) {
        guard !mac.isEmpty else { return }
        if var rec = records[mac] {
            rec.alertOnJoin = onJoin; rec.alertOnLeave = onLeave; records[mac] = rec
        } else {
            records[mac] = StoredDevice(mac: mac, customName: nil, trusted: false, notes: "",
                                        firstSeen: Date(), lastVendor: nil, lastHostname: nil,
                                        alertOnJoin: onJoin, alertOnLeave: onLeave)
        }
        saveRecords()
    }

    func addEvent(_ event: ScanEvent) {
        events.insert(event, at: 0)
        if events.count > 250 { events = Array(events.prefix(250)) }
        saveEvents()
    }

    func clearEvents() { events = []; saveEvents() }

    func addAnomaly(_ a: AnomalyRecord) {
        anomalies.insert(a, at: 0)
        if anomalies.count > 200 { anomalies = Array(anomalies.prefix(200)) }
        if let d = try? JSONEncoder().encode(anomalies) { try? d.write(to: anomaliesURL, options: .atomic) }
    }
    func clearAnomalies() {
        anomalies = []
        if let d = try? JSONEncoder().encode(anomalies) { try? d.write(to: anomaliesURL, options: .atomic) }
    }

    // MARK: persistence
    func saveRecords() {
        if let data = try? JSONEncoder().encode(records) { try? data.write(to: recordsURL, options: .atomic) }
    }
    func saveEvents() {
        if let data = try? JSONEncoder().encode(events) { try? data.write(to: eventsURL, options: .atomic) }
    }
    // Decodes JSON; if the file exists but is corrupt, preserves it as .corrupt
    // instead of silently discarding (and later overwriting) it.
    private func loadJSON<T: Decodable>(_ url: URL, _ type: T.Type) -> T? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        if let v = try? JSONDecoder().decode(T.self, from: d) { return v }
        let backup = url.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: url, to: backup)
        return nil
    }

    private func load() {
        records = loadJSON(recordsURL, [String: StoredDevice].self) ?? [:]
        events = loadJSON(eventsURL, [ScanEvent].self) ?? []
        anomalies = loadJSON(anomaliesURL, [AnomalyRecord].self) ?? []
    }

    // Bound growth: keep all user-labeled devices; cap unlabeled to the newest 400.
    private func prune() {
        let maxUnlabeled = 400
        let unlabeled = records.values.filter {
            $0.customName == nil && $0.notes.isEmpty && !$0.trusted
                && !($0.alertOnJoin ?? false) && !($0.alertOnLeave ?? false)
        }
        guard unlabeled.count > maxUnlabeled else { return }
        for r in unlabeled.sorted(by: { $0.firstSeen < $1.firstSeen }).prefix(unlabeled.count - maxUnlabeled) {
            records.removeValue(forKey: r.mac)
        }
        saveRecords()
    }
}
