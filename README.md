# Sonar — Complete Network Toolkit for macOS

<img src="icon_1024.png" width="120" align="right"/>

A native SwiftUI app that gives you complete visibility and control of your own
network — discovery, deep diagnostics, Wi-Fi analysis, control actions, live
monitoring, and reporting. No dependencies, no tracking, fully free.

## Features

### 🔍 Devices
- Ping-sweep + ARP discovery of every device (IP, MAC, vendor, hostname)
- mDNS/Bonjour names, SSDP/UPnP enumeration, randomized-MAC detection
- Device-type fingerprinting (router, Mac, iPhone, printer, camera, NAS, TV, IoT…)
- On-demand TCP port scan with **service/version banner grabbing**
- **Security-exposure flags** (Telnet, open SMB, unauthenticated VNC, exposed DBs…)
- New-device alerts, presence history, per-device labels/notes/trust

### 🛠️ Diagnostics
- **Internet speed test** — download / upload / latency / jitter (Cloudflare)
- **Ping monitor** with live latency chart, min/avg/max, packet loss
- **Traceroute** — hop-by-hop with IP geolocation
- **DNS lookup** (A/AAAA/MX/TXT/CNAME/NS/PTR), **WHOIS**, **public IP + ISP**

### 📶 Wi-Fi analyzer
- Live link stats: SSID, BSSID, security, channel, band, width, TX rate, SNR
- Signal-strength meter + RSSI history chart
- Nearby-AP scan with **least-congested channel** recommendation

### 🎛️ Control
- **Wake-on-LAN** magic packets
- **Switch this Mac's DNS** (Cloudflare / Google / Quad9 / custom Pi-hole·NextDNS)
- **macOS firewall** enable/disable
- Quick-launch: router admin, device web UI, SSH, copy details
- (System changes use macOS's own admin prompt — Sonar never sees your password)

### 📈 Trends (history over time)
- Metrics recorded every minute + after each scan, **persisted 7 days** on disk
- Charts over 1h / 6h / 24h / 7d: devices online, throughput, gateway/internet latency

### 🌐 DNS Logs (per-device domain history — the legit way)
- Connects to **NextDNS** (cloud API) or **Pi-hole v6** (self-hosted) — your own resolver
- Live per-device query stream: which device requested which domain, when, allowed/blocked
- Filter by device, search domains, top-domains + blocked counts
- This is the correct, consent-based answer to "who's browsing what": point your
  router's (or each device's) DNS at the resolver and read its log — no interception

### 📊 Monitor & export
- Live up/down throughput chart
- **Per-process bandwidth** (top talkers)
- Join/leave notifications
- Export the network map to **CSV / JSON / PDF**

## What it does NOT do — by design

Sonar shows **who's on your network and what they expose**, and controls **your
own** machine and router. It does **not** intercept, capture or decode other
people's traffic (no ARP-spoofing/MITM, no packet sniffing, no per-person web
history). That's interception/wiretapping even on your own network, and HTTPS
makes the content unreadable regardless. For household domain-level visibility,
run your DNS through **Pi-hole** or **NextDNS** (the Control tab helps you point
your Mac at either).

## Install (download build)

1. Open **Sonar.dmg** and drag **Sonar** to **Applications**.
2. First launch is blocked because the app isn't notarized (it's a free build).
   Bypass it once, either way:
   - **Right-click** Sonar → **Open** → **Open**, or
   - Terminal: `xattr -dr com.apple.quarantine /Applications/Sonar.app`
3. Allow the prompts: **Local Network** (required), **Location** (for Wi-Fi SSID
   + scanning), **Notifications** (optional).

## Build from source

```bash
swift run Sonar            # dev run
./build-app.sh            # produces Sonar.app + Sonar.dmg
swift run Sonar --diagnose # headless engine self-test
```

Requires macOS 14+ and the Swift toolchain (Xcode). The radar icon is generated
by `swift make-icon.swift`.

## Notes

- Everything runs locally; the only outbound calls are the speed test, WHOIS,
  and IP geolocation — all triggered by you.
- Vendor DB is a curated set; unknown prefixes fall back to SSDP/hostname hints.
