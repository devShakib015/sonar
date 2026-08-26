import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var scanner: Scanner
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Activity", systemImage: "clock.arrow.circlepath").font(.headline)
                Spacer()
                Button("Clear") { scanner.clearEvents() }.disabled(scanner.events.isEmpty)
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()

            if scanner.events.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No activity yet.").foregroundStyle(.secondary)
                    Text("Joins, departures and new devices will appear here.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                List(scanner.events) { e in
                    HStack(spacing: 10) {
                        Image(systemName: e.kind.symbol).foregroundStyle(e.kind.tint).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(e.kind.verb): \(e.name)").fontWeight(.medium)
                            Text("\(e.ip)  ·  \(e.mac.isEmpty ? "unknown MAC" : e.mac)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(e.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 540, height: 470)
    }
}
