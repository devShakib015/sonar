import Foundation

// Offline MAC-to-vendor lookup. Curated set of common consumer/IoT prefixes —
// covers most home devices; unknown prefixes fall back gracefully.
enum OUIDatabase {
    static func vendor(for mac: String) -> String? {
        let clean = mac.uppercased().replacingOccurrences(of: "-", with: ":")
        let octets = clean.split(separator: ":")
        guard octets.count >= 3 else { return nil }

        // Detect locally-administered (randomized/private) MAC addresses.
        if let first = UInt8(octets[0], radix: 16), (first & 0x02) != 0 {
            return "Randomized MAC (private)"
        }

        let prefix = octets[0...2].joined(separator: ":")
        return table[prefix]
    }

    static let table: [String: String] = [
        // Apple (sampling of many ranges)
        "8C:85:90": "Apple", "F0:18:98": "Apple", "A4:83:E7": "Apple", "3C:15:C2": "Apple",
        "D0:81:7A": "Apple", "F4:F1:5A": "Apple", "AC:BC:32": "Apple", "60:F8:1D": "Apple",
        "68:AB:BC": "Apple", "A8:5C:2C": "Apple", "F0:99:BF": "Apple", "DC:A9:04": "Apple",
        "40:B3:95": "Apple", "90:B0:ED": "Apple", "38:F9:D3": "Apple", "34:12:98": "Apple",
        // Samsung
        "00:12:FB": "Samsung", "5C:0A:5B": "Samsung", "E8:50:8B": "Samsung", "34:23:BA": "Samsung",
        "8C:77:12": "Samsung", "C8:19:F7": "Samsung", "FC:A1:3E": "Samsung",
        // Google / Nest / Chromecast
        "F4:F5:D8": "Google", "1C:F2:9A": "Google", "3C:5A:B4": "Google",
        "F8:8F:CA": "Google", "48:D6:D5": "Google",
        // Amazon (Echo / Fire)
        "FC:65:DE": "Amazon", "F0:27:2D": "Amazon", "44:65:0D": "Amazon", "68:37:E9": "Amazon",
        "50:DC:E7": "Amazon", "0C:47:C9": "Amazon", "74:C2:46": "Amazon",
        // Espressif (ESP8266/ESP32 — very common in DIY IoT)
        "24:0A:C4": "Espressif (ESP)", "30:AE:A4": "Espressif (ESP)", "A4:CF:12": "Espressif (ESP)",
        "8C:AA:B5": "Espressif (ESP)", "3C:71:BF": "Espressif (ESP)", "EC:FA:BC": "Espressif (ESP)",
        // Raspberry Pi
        "B8:27:EB": "Raspberry Pi", "DC:A6:32": "Raspberry Pi", "E4:5F:01": "Raspberry Pi", "28:CD:C1": "Raspberry Pi",
        // Networking gear
        "50:C7:BF": "TP-Link", "AC:84:C6": "TP-Link", "C0:06:C3": "TP-Link",
        "A0:63:91": "Netgear", "9C:3D:CF": "Netgear", "20:E5:2A": "Netgear",
        "FC:EC:DA": "Ubiquiti", "74:AC:B9": "Ubiquiti", "78:8A:20": "Ubiquiti", "E0:63:DA": "Ubiquiti",
        "F0:9F:C2": "Ubiquiti", "B4:FB:E4": "Ubiquiti",
        "00:05:5D": "D-Link", "1C:BD:B9": "D-Link",
        "00:1A:2B": "Cisco", "00:0C:29": "VMware", "00:50:56": "VMware",
        // Media / smart home
        "B8:E9:37": "Sonos", "94:9F:3E": "Sonos", "5C:AA:FD": "Sonos",
        "DC:56:E7": "Roku", "CC:6D:A0": "Roku", "B0:A7:37": "Roku",
        "00:04:4B": "NVIDIA", "48:B0:2D": "NVIDIA",
        "B0:4E:26": "TP-Link", "50:02:91": "Belkin/Wemo",
        // Phones (non-random)
        "28:6C:07": "Xiaomi", "64:CC:2E": "Xiaomi", "F8:A4:5F": "Xiaomi",
        "00:9A:CD": "Huawei", "48:AD:08": "Huawei", "24:DF:6A": "Huawei",
        "2C:5B:B8": "OnePlus", "94:65:2D": "OnePlus",
        // Consoles
        "00:D9:D1": "Sony (PlayStation)", "78:C8:81": "Sony", "7C:BB:8A": "Nintendo", "98:B6:E9": "Nintendo",
        "00:15:5D": "Microsoft (Xbox/Hyper-V)", "3C:83:75": "Microsoft",
        // Printers
        "00:1B:A9": "Brother", "30:05:5C": "Brother", "00:26:73": "Canon", "AC:CF:5C": "Canon",
        "00:1E:8F": "Epson", "38:9D:92": "HP", "70:5A:0F": "HP",
        // Cameras
        "3C:EF:8C": "Hikvision", "44:19:B6": "Hikvision", "BC:AD:28": "Dahua", "10:12:FB": "Wyze"
    ]
}
