import SwiftUI

struct ControlView: View {
    @EnvironmentObject var scanner: Scanner
    @State private var macField = ""
    @State private var customDNS = ""
    @State private var currentDNS = "…"
    @State private var firewall: Bool?
    @State private var toast: String?

    private var macDevices: [Device] { scanner.devices.filter { !$0.mac.isEmpty && !$0.isThisDevice } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Control").font(.largeTitle.weight(.bold))
                if let toast { Label(toast, systemImage: "info.circle").font(.callout).foregroundStyle(.blue) }
                wakeCard
                dnsCard
                firewallCard
                launchCard
            }
            .padding(20)
        }
        .navigationTitle("Control")
        .task {
            currentDNS = await Task.detached { Control.currentDNS() }.value
            firewall = await Task.detached { Control.firewallEnabled() }.value
        }
    }

    private func flash(_ msg: String) {
        toast = msg
        Task { try? await Task.sleep(nanoseconds: 3_500_000_000); if toast == msg { toast = nil } }
    }

    private var wakeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Wake-on-LAN", icon: "power")
                Text("Send a magic packet to wake a sleeping device (must have WoL enabled).")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    TextField("AA:BB:CC:DD:EE:FF", text: $macField)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                    Menu("Known device") {
                        ForEach(macDevices) { d in
                            Button("\(d.displayName) — \(d.mac)") { macField = d.mac }
                        }
                    }.frame(width: 150)
                    Button("Wake") {
                        let ok = Control.wake(mac: macField)
                        flash(ok ? "Magic packet sent to \(macField)" : "Invalid MAC address")
                    }.buttonStyle(.borderedProminent).disabled(macField.isEmpty)
                }
            }
        }
    }

    private var dnsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "DNS for this Mac", icon: "arrow.triangle.branch")
                InfoRow(label: "Current", value: currentDNS, mono: true)
                Text("Point your Mac at a filtering resolver (Pi-hole / NextDNS give per-device domain logs).")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    dnsButton("Cloudflare", ["1.1.1.1", "1.0.0.1"])
                    dnsButton("Google", ["8.8.8.8", "8.8.4.4"])
                    dnsButton("Quad9", ["9.9.9.9"])
                    dnsButton("Automatic", [])
                }
                HStack {
                    TextField("Custom (e.g. Pi-hole IP or NextDNS)", text: $customDNS).textFieldStyle(.roundedBorder)
                    Button("Apply") { applyDNS(customDNS.split(separator: " ").map(String.init)) }
                        .disabled(customDNS.isEmpty)
                }
            }
        }
    }

    private func dnsButton(_ title: String, _ servers: [String]) -> some View {
        Button(title) { applyDNS(servers) }.buttonStyle(.bordered)
    }

    private func applyDNS(_ servers: [String]) {
        Task {
            let ok = await Task.detached { Control.setDNS(servers) }.value
            currentDNS = await Task.detached { Control.currentDNS() }.value
            flash(ok ? "DNS updated" : "DNS change cancelled")
        }
    }

    private var firewallCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(text: "macOS firewall", icon: "shield.lefthalf.filled")
                    Spacer()
                    switch firewall {
                    case .some(true): Text("On").foregroundStyle(.green).fontWeight(.semibold)
                    case .some(false): Text("Off").foregroundStyle(.orange).fontWeight(.semibold)
                    case .none: Text("Unknown").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Enable") { setFW(true) }.buttonStyle(.bordered).disabled(firewall == true)
                    Button("Disable") { setFW(false) }.buttonStyle(.bordered).disabled(firewall == false)
                }
            }
        }
    }

    private func setFW(_ on: Bool) {
        Task {
            _ = await Task.detached { Control.setFirewall(on) }.value
            firewall = await Task.detached { Control.firewallEnabled() }.value
            flash("Firewall \(on ? "enabled" : "disabled")")
        }
    }

    private var launchCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Quick launch", icon: "arrow.up.forward.app")
                Button {
                    Control.open("http://\(scanner.gatewayIP)")
                } label: { Label("Open router admin (\(scanner.gatewayIP))", systemImage: "wifi.router") }
                    .buttonStyle(.bordered).disabled(scanner.gatewayIP.isEmpty)

                Divider()
                Text("Per device").font(.caption).foregroundStyle(.secondary)
                ForEach(scanner.devices.filter { $0.isOnline && !$0.isThisDevice }.prefix(10)) { d in
                    HStack(spacing: 8) {
                        DeviceIcon(type: d.deviceType, size: 22)
                        Text(d.displayName).lineLimit(1).frame(width: 150, alignment: .leading)
                        Text(d.ip).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Web") { Control.open("http://\(d.ip)") }.controlSize(.small)
                        Button("SSH") { Control.sshTo(d.ip) }.controlSize(.small)
                        Button {
                            Control.copy("\(d.displayName)\nIP: \(d.ip)\nMAC: \(d.mac)")
                            flash("Copied \(d.displayName)")
                        } label: { Image(systemName: "doc.on.doc") }.controlSize(.small)
                    }
                    .font(.callout)
                }
            }
        }
    }
}
