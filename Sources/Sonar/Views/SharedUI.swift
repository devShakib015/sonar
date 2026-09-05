import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Term.panel, Term.panel.opacity(0.35)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Term.border, lineWidth: 1))
            .overlay(HUDCorners())
            .shadow(color: Term.green.opacity(0.06), radius: 10)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var mono = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label.uppercased())
                .font(Term.mono(11))
                .foregroundStyle(Term.dim)
                .frame(width: 112, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(Term.mono(12))
                .foregroundStyle(Term.green)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

struct SectionTitle: View {
    let text: String
    var icon: String?
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 11)) }
            Text("[ \(text.uppercased()) ]")
                .font(Term.mono(11, .bold)).tracking(1)
        }
        .foregroundStyle(Term.green)
    }
}

struct DeviceIcon: View {
    let type: DeviceType
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Term.inputBG)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(type.tint.opacity(0.5), lineWidth: 1))
            Image(systemName: type.symbol)
                .font(.system(size: size * 0.46))
                .foregroundStyle(type.tint)
        }
        .frame(width: size, height: size)
    }
}

struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(Term.mono(9, .bold)).tracking(1)
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .foregroundStyle(Term.bg)
            .background(Term.amber)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

func severityColor(_ s: Int) -> Color {
    switch s { case 2: return Term.red; case 1: return Term.amber; default: return Term.dim }
}
func severityLabel(_ s: Int) -> String {
    switch s { case 2: return "WARN"; case 1: return "CAUTION"; default: return "INFO" }
}
