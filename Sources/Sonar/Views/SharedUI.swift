import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var mono = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 104, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(mono ? .system(.callout, design: .monospaced) : .callout)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

struct SectionTitle: View {
    let text: String
    var icon: String?
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(text.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
        }
        .foregroundStyle(.secondary)
    }
}

struct DeviceIcon: View {
    let type: DeviceType
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(type.tint.opacity(0.16))
            Image(systemName: type.symbol)
                .font(.system(size: size * 0.5))
                .foregroundStyle(type.tint)
        }
        .frame(width: size, height: size)
    }
}

struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.5)
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .background(Capsule().fill(.pink))
            .foregroundStyle(.white)
    }
}

func severityColor(_ s: Int) -> Color {
    switch s { case 2: return .red; case 1: return .orange; default: return .secondary }
}
func severityLabel(_ s: Int) -> String {
    switch s { case 2: return "Warning"; case 1: return "Caution"; default: return "Info" }
}
