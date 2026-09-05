# Sonar — Complete Network Toolkit for macOS

<img src="icon_1024.png" width="120" align="right"/>

A native SwiftUI app that gives you complete visibility and control of your own
network — discovery, deep diagnostics, Wi-Fi analysis, control actions, live
monitoring, and reporting. No dependencies, no tracking, fully free.

## Features

### 🛰️ Radar & dashboard
- **Animated radar** — every device shown as a live blip sweeping around your Mac; click one to inspect it
- **Network Health Score** — a 0–100 security score with a grade and actionable factors
- **Security anomaly detection** — alerts on gateway-MAC changes (rogue router / evil-twin), new devices at odd hours, and per-device timelines

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

### 🛡️ Exposure audit
- **UPnP port-mapping audit** — asks your router what ports it forwards to the internet (what the outside world can actually reach)
- **Advanced port scanner** — scan any host/IP with Common, Top-1024, or custom port ranges

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

### ⚡ Uptime & reliability
- **Outage monitor** — continuously checks gateway + internet, logs every drop with its duration, shows a rolling 24-hour uptime %
- **Speed-test history** — every run charted over time

### 📡 Bonjour / mDNS services
- Browses the network to show what each device **advertises**: AirPlay, Cast, printers, HomeKit, SSH, screen & file sharing…
- Device web-UI **title grab** for sharper identification

### ⚙️ Settings & alerts
- **Launch at login**, **menu-bar-only** background mode, **device search**
- **Per-device alert rules** — get notified when a specific device joins or leaves

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

## Changelog

### v1.2.0
- **Radar view** — animated sweep with every device as a live blip
- **Network Health Score** — a 0–100 security score on the dashboard
- **Anomaly detection** — gateway-MAC-change alerts, odd-hours device flags, per-device timelines
- **Premium polish** — brand accent, first-run onboarding, and smoother animations

### v1.1.0
- **Exposure audit** — UPnP port-mapping check (what your router forwards to the internet) + advanced port scanner for any host/range
- **Uptime & reliability** — continuous outage monitor with a drop log + 24h uptime %, plus speed-test history charts
- **Bonjour / mDNS services** — browse what each device advertises; web-UI title grab for better identification
- **Settings & alerts** — launch at login, menu-bar-only mode, device search, and per-device join/leave alert rules

### v1.0.1
- Fixed the download speed test (was reporting 0.0) with a robust chunked download
- Added the MIT license

### v1.0.0
- Initial release: device discovery & fingerprinting, port scan with service banners, security-exposure flags, diagnostics (speed test, ping, traceroute, DNS, WHOIS, public IP), Wi-Fi analyzer, control actions (Wake-on-LAN, DNS switching, firewall), live monitoring, 7-day trends, and per-device DNS logs

## Notes

- Everything runs locally; the only outbound calls are the speed test, WHOIS,
  and IP geolocation — all triggered by you.
- Vendor DB is a curated set; unknown prefixes fall back to SSDP/hostname hints.
