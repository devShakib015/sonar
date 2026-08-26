import Foundation

// Heuristic device classification and a lightweight security-exposure audit,
// derived from vendor, hostname and the set of open ports.
enum Fingerprint {

    static func inferType(vendor: String?, hostname: String?, ports: [Int],
                          isGateway: Bool, isThisDevice: Bool) -> DeviceType {
        if isThisDevice { return .thisDevice }
        if isGateway { return .router }

        let v = (vendor ?? "").lowercased()
        let h = (hostname ?? "").lowercased()
        let hay = v + " " + h
        let p = Set(ports)

        func has(_ s: String) -> Bool { hay.contains(s) }

        // Strong signals from hostname / vendor first.
        if has("iphone") { return .iphone }
        if has("ipad") { return .ipad }
        if has("macbook") || has("imac") || has("mac-mini") || has("mac mini") { return .mac }
        if has("apple-tv") || has("appletv") { return .appleTV }
        if has("homepod") || has("sonos") || has("echo") || has("speaker") { return .speaker }
        if has("chromecast") || has("roku") || has("bravia") || has("firetv") || has("fire tv") || has("smart-tv") || has("smarttv") { return .tv }
        if has("hikvision") || has("dahua") || has("wyze") || has("camera") || has("ipcam") { return .camera }
        if has("synology") || has("qnap") || has("nas") || has("truenas") { return .nas }
        if has("playstation") || has("xbox") || has("nintendo") { return .gameConsole }
        if has("android") || has("pixel") || has("galaxy") || has("oneplus") || has("xiaomi") { return .phone }
        if has("raspberry") || has("espressif") || has("esp") { return .iot }

        // Port-based signals.
        if p.contains(62078) { return .iphone }
        if p.contains(9100) || p.contains(631) || p.contains(515) { return .printer }
        if p.contains(554) { return .camera }
        if p.contains(8009) { return .tv }
        if p.contains(32400) { return .nas }
        if p.contains(3389) || p.contains(135) { return .windows }
        if p.contains(445) && p.contains(139) { return .windows }

        if v.contains("apple") { return .appleDevice }
        if p == Set([22]) || (p.contains(22) && !p.contains(445)) { return .linux }
        return .unknown
    }

    // Human-readable exposure findings. Severity: 0 info, 1 caution, 2 warning.
    static func findings(ports: [PortInfo]) -> [SecurityFinding] {
        var out: [SecurityFinding] = []
        let open = Set(ports.map { $0.port })

        func add(_ sev: Int, _ title: String, _ detail: String) {
            out.append(SecurityFinding(severity: sev, title: title, detail: detail))
        }

        if open.contains(23) { add(2, "Telnet exposed (23)", "Telnet is unencrypted — anything typed, including passwords, travels in clear text. Disable it.") }
        if open.contains(21) { add(1, "FTP exposed (21)", "FTP often allows cleartext or anonymous login. Prefer SFTP/SSH.") }
        if open.contains(5900) { add(2, "VNC screen sharing (5900)", "Remote screen access is reachable on the LAN. Ensure it requires a strong password.") }
        if open.contains(3389) { add(1, "RDP exposed (3389)", "Remote Desktop is reachable. Keep it patched and password-protected.") }
        if open.contains(445) || open.contains(139) { add(1, "SMB file sharing (445/139)", "Windows/NAS file sharing is exposed — verify shares aren't world-readable.") }
        if open.contains(3306) || open.contains(5432) || open.contains(6379) || open.contains(27017) || open.contains(9200) {
            add(2, "Database port exposed", "A database service is reachable from the LAN. It should normally bind to localhost only.")
        }
        if open.contains(1883) { add(1, "MQTT broker (1883)", "An IoT message broker is exposed and often unauthenticated by default.") }
        if open.contains(9100) { add(0, "Raw printing (9100)", "The printer accepts raw print jobs from any LAN device.") }
        if (open.contains(80) || open.contains(8080)) && !open.contains(443) {
            add(0, "Unencrypted web interface", "An admin/web interface is served over plain HTTP. Credentials would be sent unencrypted.")
        }
        return out
    }
}

struct SecurityFinding: Identifiable, Hashable {
    var id = UUID()
    var severity: Int   // 0 info, 1 caution, 2 warning
    var title: String
    var detail: String
}
