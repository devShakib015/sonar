import SwiftUI

struct OnboardingView: View {
    var onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.teal.opacity(0.15)).frame(width: 96, height: 96)
                Image(systemName: "scope").font(.system(size: 46, weight: .medium)).foregroundStyle(.teal)
            }
            VStack(spacing: 4) {
                Text("Welcome to Sonar").font(.largeTitle.weight(.bold))
                Text("A complete, private network toolkit for your Mac.").foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                feature("dot.radiowaves.left.and.right", "See every device",
                        "Discover what's on your Wi-Fi, identify it, and get alerted when something new appears.")
                feature("lock.shield", "Audit your exposure",
                        "Port & service scans, security flags, and what your router forwards to the internet.")
                feature("bolt.horizontal.circle", "Monitor & diagnose",
                        "Speed tests, uptime tracking, Wi-Fi analysis, and 7-day trends.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))

            VStack(spacing: 3) {
                Text("On the first scan, macOS will ask for permissions:").font(.caption).foregroundStyle(.secondary)
                Text("Local Network (required)  ·  Location (Wi-Fi names)  ·  Notifications (optional)")
                    .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            }

            Button {
                SettingsStore.onboarded = true
                dismiss()
                onStart()
            } label: {
                Text("Start scanning").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).tint(.teal)
        }
        .padding(32)
        .frame(width: 460)
    }

    private func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(.teal).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(body).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
