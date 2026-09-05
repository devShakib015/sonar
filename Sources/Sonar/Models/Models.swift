import Foundation
import SwiftUI

// A guessed category for a device, used for icon + label.
enum DeviceType: String, Codable, CaseIterable {
    case router, mac, iphone, ipad, appleDevice, appleTV, windows, linux
    case nas, printer, camera, tv, speaker, gameConsole, iot, phone
    case thisDevice, unknown

    var symbol: String {
        switch self {
        case .router:       return "wifi.router"
        case .mac:          return "desktopcomputer"
        case .iphone:       return "iphone"
        case .ipad:         return "ipad"
        case .appleDevice:  return "applelogo"
        case .appleTV:      return "appletv"
        case .windows:      return "pc"
        case .linux:        return "terminal"
        case .nas:          return "externaldrive.connected.to.line.below"
        case .printer:      return "printer"
        case .camera:       return "web.camera"
        case .tv:           return "tv"
        case .speaker:      return "hifispeaker"
        case .gameConsole:  return "gamecontroller"
        case .iot:          return "sensor"
        case .phone:        return "candybarphone"
        case .thisDevice:   return "laptopcomputer"
        case .unknown:      return "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .router:      return "Router / Gateway"
        case .mac:         return "Mac"
        case .iphone:      return "iPhone"
        case .ipad:        return "iPad"
        case .appleDevice: return "Apple device"
        case .appleTV:     return "Apple TV"
        case .windows:     return "Windows PC"
        case .linux:       return "Linux host"
        case .nas:         return "NAS / Storage"
        case .printer:     return "Printer"
        case .camera:      return "Camera"
        case .tv:          return "Smart TV"
        case .speaker:     return "Speaker"
        case .gameConsole: return "Game console"
        case .iot:         return "Smart / IoT device"
        case .phone:       return "Phone"
        case .thisDevice:  return "This Mac"
        case .unknown:     return "Unknown device"
        }
    }

    var tint: Color {
        switch self {
        case .router:        return Term.amber
        case .thisDevice:    return Term.cyan
        case .printer, .nas: return Term.amber
        case .camera:        return Term.red
        default:             return Term.green
        }
    }
}

struct PortInfo: Identifiable, Codable, Hashable {
    var port: Int
    var service: String
    var id: Int { port }
}

// Live representation of a device seen on the LAN.
struct Device: Identifiable, Hashable {
    var mac: String
    var ip: String
    var hostname: String?
    var vendor: String?
    var deviceType: DeviceType = .unknown

    var isOnline: Bool = true
    var isGateway: Bool = false
    var isThisDevice: Bool = false

    var firstSeen: Date = Date()
    var lastSeen: Date = Date()
    var openPorts: [PortInfo] = []
    var portsScanned: Bool = false
    var ssdpServer: String? = nil
    var httpTitle: String? = nil

    // User-managed metadata (persisted).
    var customName: String?
    var trusted: Bool = false
    var isNew: Bool = false
    var alertOnJoin: Bool = false
    var alertOnLeave: Bool = false
    var notes: String = ""

    // Stable identity: prefer MAC, fall back to IP for un-resolvable hosts.
    var id: String { mac.isEmpty ? ip : mac }

    var displayName: String {
        if let c = customName, !c.trimmingCharacters(in: .whitespaces).isEmpty { return c }
        if let h = hostname, !h.isEmpty {
            // Trim trailing dot and .local for readability.
            var name = h
            if name.hasSuffix(".") { name.removeLast() }
            if name.hasSuffix(".local") { name.removeLast(6) }
            return name
        }
        if isGateway { return "Gateway" }
        if let v = vendor, !v.isEmpty { return "\(v) device" }
        return ip
    }

    var subtitle: String {
        var parts: [String] = []
        if let v = vendor, !v.isEmpty, customName != nil || hostname != nil { parts.append(v) }
        parts.append(deviceType.label)
        return parts.joined(separator: " · ")
    }
}

enum EventKind: String, Codable {
    case newDevice, joined, left
    var symbol: String {
        switch self {
        case .newDevice: return "sparkles"
        case .joined:    return "arrow.right.circle.fill"
        case .left:      return "arrow.left.circle"
        }
    }
    var tint: Color {
        switch self {
        case .newDevice: return Term.amber
        case .joined:    return Term.green
        case .left:      return Term.dim
        }
    }
    var verb: String {
        switch self {
        case .newDevice: return "New device"
        case .joined:    return "Joined"
        case .left:      return "Left"
        }
    }
}

struct ScanEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var kind: EventKind
    var mac: String
    var name: String
    var ip: String
}

// Persisted per-device metadata, keyed by MAC.
struct StoredDevice: Codable {
    var mac: String
    var customName: String?
    var trusted: Bool
    var notes: String
    var firstSeen: Date
    var lastVendor: String?
    var lastHostname: String?
    var alertOnJoin: Bool? = nil
    var alertOnLeave: Bool? = nil
}

struct ThroughputSample: Identifiable, Hashable {
    let id = UUID()
    let time: Date
    let down: Double
    let up: Double
}

struct MetricSample: Codable, Identifiable, Hashable {
    var id = UUID()
    let t: Date
    let online: Int
    let down: Double
    let up: Double
    let gwLatency: Double?
    let netLatency: Double?
}

struct AnomalyRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    let kind: String
    let title: String
    let detail: String
    let severity: Int   // 1 caution, 2 warning
}
