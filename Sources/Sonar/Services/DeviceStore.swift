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
    }

    func isKnown(_ mac: String) -> Bool { !mac.isEmpty && records[mac] != nil }

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
        if let d = try? JSONEncoder().encode(anomalies) { try? d.write(to: anomaliesURL) }
    }
    func clearAnomalies() {
        anomalies = []
        if let d = try? JSONEncoder().encode(anomalies) { try? d.write(to: anomaliesURL) }
    }

    // MARK: persistence
    func saveRecords() {
        if let data = try? JSONEncoder().encode(records) { try? data.write(to: recordsURL) }
    }
    func saveEvents() {
        if let data = try? JSONEncoder().encode(events) { try? data.write(to: eventsURL) }
    }
    private func load() {
        if let d = try? Data(contentsOf: recordsURL),
           let r = try? JSONDecoder().decode([String: StoredDevice].self, from: d) { records = r }
        if let d = try? Data(contentsOf: eventsURL),
           let e = try? JSONDecoder().decode([ScanEvent].self, from: d) { events = e }
        if let d = try? Data(contentsOf: anomaliesURL),
           let a = try? JSONDecoder().decode([AnomalyRecord].self, from: d) { anomalies = a }
    }
}
