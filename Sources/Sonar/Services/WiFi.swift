import Foundation
import CoreWLAN

struct WiFiInfo {
    var ssid: String?
    var bssid: String?
    var rssi: Int
    var noise: Int
    var txRate: Double
    var channel: Int
    var band: String
    var width: String
    var security: String
    var interfaceName: String
    var hardwareAddress: String?
    var snr: Int { rssi - noise }

    var quality: (label: String, tint: String) {
        switch rssi {
        case (-55)...0:   return ("Excellent", "green")
        case (-67)...(-56): return ("Good", "green")
        case (-70)...(-68): return ("Fair", "yellow")
        case (-80)...(-71): return ("Weak", "orange")
        default:          return ("Poor", "red")
        }
    }
}

struct WiFiScanResult: Identifiable {
    let id = UUID()
    var ssid: String
    var bssid: String?
    var rssi: Int
    var channel: Int
    var band: String
}

enum WiFi {
    static func current() -> WiFiInfo? {
        guard let iface = CWWiFiClient.shared().interface() else { return nil }
        let ch = iface.wlanChannel()
        return WiFiInfo(
            ssid: iface.ssid(),
            bssid: iface.bssid(),
            rssi: iface.rssiValue(),
            noise: iface.noiseMeasurement(),
            txRate: iface.transmitRate(),
            channel: ch?.channelNumber ?? 0,
            band: bandString(ch?.channelBand),
            width: widthString(ch?.channelWidth),
            security: securityString(iface.security()),
            interfaceName: iface.interfaceName ?? "",
            hardwareAddress: iface.hardwareAddress()
        )
    }

    static func scan() -> [WiFiScanResult] {
        guard let iface = CWWiFiClient.shared().interface() else { return [] }
        do {
            let nets = try iface.scanForNetworks(withSSID: nil)
            return nets.map { n in
                WiFiScanResult(ssid: n.ssid ?? "(hidden)",
                               bssid: n.bssid,
                               rssi: n.rssiValue,
                               channel: n.wlanChannel?.channelNumber ?? 0,
                               band: bandString(n.wlanChannel?.channelBand))
            }.sorted { $0.rssi > $1.rssi }
        } catch { return [] }
    }

    static func bandString(_ b: CWChannelBand?) -> String {
        switch b {
        case .some(.band2GHz): return "2.4 GHz"
        case .some(.band5GHz): return "5 GHz"
        default: return b == nil ? "—" : "6 GHz"
        }
    }

    static func widthString(_ w: CWChannelWidth?) -> String {
        switch w {
        case .some(.width20MHz): return "20 MHz"
        case .some(.width40MHz): return "40 MHz"
        case .some(.width80MHz): return "80 MHz"
        case .some(.width160MHz): return "160 MHz"
        default: return "—"
        }
    }

    static func securityString(_ s: CWSecurity) -> String {
        switch s {
        case .none: return "Open — no encryption"
        case .WEP: return "WEP (insecure)"
        case .wpaPersonal, .wpaPersonalMixed: return "WPA Personal"
        case .wpa2Personal: return "WPA2 Personal"
        case .wpa3Personal: return "WPA3 Personal"
        case .wpaEnterprise, .wpa2Enterprise, .wpa3Enterprise: return "Enterprise"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    // Least-congested channel suggestions from a scan.
    static func advice(_ scan: [WiFiScanResult]) -> String? {
        guard !scan.isEmpty else { return nil }
        func best(_ band: String, candidates: [Int]) -> Int? {
            let inBand = scan.filter { $0.band == band }
            guard !inBand.isEmpty else { return nil }
            var counts: [Int: Int] = [:]
            for n in inBand { counts[n.channel, default: 0] += 1 }
            return candidates.min { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
        }
        var parts: [String] = []
        if let c = best("2.4 GHz", candidates: [1, 6, 11]) { parts.append("2.4 GHz → channel \(c)") }
        let fiveChannels = Array(Set(scan.filter { $0.band == "5 GHz" }.map { $0.channel })) + [36, 44, 149, 157]
        if let c = best("5 GHz", candidates: fiveChannels) { parts.append("5 GHz → channel \(c)") }
        return parts.isEmpty ? nil : "Least congested: " + parts.joined(separator: ",  ")
    }
}
