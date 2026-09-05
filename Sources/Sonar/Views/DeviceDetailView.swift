import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject var scanner: Scanner
    let device: Device

    @State private var name = ""
    @State private var notes = ""
    @State private var trusted = false
    @State private var alertJoin = false
    @State private var alertLeave = false

    private var findings: [SecurityFinding] { Fingerprint.findings(ports: device.openPorts) }
    private var scanningPorts: Bool { scanner.scanningPortsFor == device.id }
    private var namePlaceholder: String { device.hostname ?? device.ip }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                identityCard
                portsCard
                if !findings.isEmpty { securityCard }
                if !device.mac.isEmpty { alertsCard }
                notesCard
            }
            .padding(20)
        }
        .navigationTitle(device.displayName)
        .task(id: device.id) {
            name = device.customName ?? ""
            notes = device.notes
            trusted = device.trusted
            alertJoin = device.alertOnJoin
            alertLeave = device.alertOnLeave
        }
    }

    private func save() {
        scanner.updateLabel(for: device, name: name, trusted: trusted, notes: notes)
    }

    private var headerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    DeviceIcon(type: device.deviceType, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(namePlaceholder, text: $name)
                            .textFieldStyle(.plain)
                            .font(.title2.weight(.semibold))
                            .onSubmit(save)
                        Text(device.deviceType.label + (device.vendor.map { " · \($0)" } ?? ""))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    statusPill
                }
                HStack {
                    Toggle(isOn: $trusted) {
                        Label("Trusted", systemImage: "checkmark.seal")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: trusted) { _, _ in save() }

                    Spacer()
                    if device.isNew {
                        Button("Dismiss “new”") { scanner.clearNewFlag(device) }
                            .buttonStyle(.borderless)
                    }
                    Button("Save", action: save)
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle().fill(device.isOnline ? Color.green : Color.secondary).frame(width: 8, height: 8)
            Text(device.isOnline ? "Online" : "Offline").font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill((device.isOnline ? Color.green : Color.secondary).opacity(0.15)))
    }

    private var identityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Identity", icon: "person.text.rectangle")
                InfoRow(label: "IP address", value: device.ip, mono: true)
                InfoRow(label: "MAC address", value: device.mac.isEmpty ? "Unknown" : device.mac, mono: true)
                InfoRow(label: "Vendor", value: device.vendor ?? "Unknown")
                InfoRow(label: "Hostname", value: device.hostname ?? "—", mono: device.hostname != nil)
                InfoRow(label: "Type", value: device.deviceType.label)
                if let s = device.ssdpServer { InfoRow(label: "UPnP", value: s) }
                if let t = device.httpTitle { InfoRow(label: "Web page", value: t) }
                InfoRow(label: "First seen", value: device.firstSeen.formatted(date: .abbreviated, time: .shortened))
                InfoRow(label: "Last seen", value: device.lastSeen.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private var portsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "Open ports & services", icon: "lock.open")
                    Spacer()
                    Button { Task { await scanner.scanPorts(device) } } label: {
                        if scanningPorts {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(device.portsScanned ? "Rescan" : "Scan ports")
                        }
                    }
                    .disabled(scanningPorts)
                    .buttonStyle(.bordered)
                }

                if scanningPorts {
                    Text("Probing \(PortScanner.ports.count) common ports and grabbing service banners…")
                        .font(.callout).foregroundStyle(.secondary)
                } else if !device.portsScanned {
                    Text("Runs a TCP connect scan of common ports and reads the service/version banners each one advertises.")
                        .font(.callout).foregroundStyle(.secondary)
                } else if device.openPorts.isEmpty {
                    Label("No common ports open — this device isn’t exposing services.", systemImage: "checkmark.shield")
                        .foregroundStyle(.green).font(.callout)
                } else {
                    ForEach(device.openPorts) { p in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(p.port)")
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(.blue)
                                .frame(width: 52, alignment: .leading)
                            Text(p.service).font(.callout).textSelection(.enabled)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private var securityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Security exposure", icon: "exclamationmark.shield")
                ForEach(findings) { f in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(severityColor(f.severity))
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(f.title).fontWeight(.semibold)
                                Text(severityLabel(f.severity))
                                    .font(.caption2)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(severityColor(f.severity).opacity(0.18)))
                                    .foregroundStyle(severityColor(f.severity))
                            }
                            Text(f.detail).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var alertsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "Alerts for this device", icon: "bell")
                Toggle("Notify when it joins the network", isOn: $alertJoin)
                    .onChange(of: alertJoin) { _, _ in scanner.setAlerts(for: device, onJoin: alertJoin, onLeave: alertLeave) }
                Toggle("Notify when it leaves the network", isOn: $alertLeave)
                    .onChange(of: alertLeave) { _, _ in scanner.setAlerts(for: device, onJoin: alertJoin, onLeave: alertLeave) }
            }
        }
    }

    private var notesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "Notes", icon: "note.text")
                TextEditor(text: $notes)
                    .frame(minHeight: 66)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
                HStack { Spacer(); Button("Save notes", action: save) }
            }
        }
    }
}
