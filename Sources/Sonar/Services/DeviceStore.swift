import Foundation

// Persists per-device labels (name / trusted / notes), the set of MACs ever
// seen (so "new device" survives relaunches), and the recent event log.
final class DeviceStore {
    private(set) var records: [String: StoredDevice] = [:]
    private(set) var events: [ScanEvent] = []

    private let dir: URL
    private let recordsURL: URL
    private let eventsURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("Sonar", isDirectory: true)
        recordsURL = dir.appendingPathComponent("devices.json")
        eventsURL = dir.appendingPathComponent("events.json")
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

    func addEvent(_ event: ScanEvent) {
        events.insert(event, at: 0)
        if events.count > 250 { events = Array(events.prefix(250)) }
        saveEvents()
    }

    func clearEvents() { events = []; saveEvents() }

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
    }
}
