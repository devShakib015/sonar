import SwiftUI

struct DeviceRow: View {
    let device: Device
    var body: some View {
        HStack(spacing: 10) {
            DeviceIcon(type: device.deviceType, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(device.displayName).fontWeight(.medium).lineLimit(1)
                    if device.trusted {
                        Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.green)
                    }
                    if device.isNew { NewBadge() }
                }
                Text(device.ip)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Circle()
                .fill(device.isOnline ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 3)
        .opacity(device.isOnline ? 1 : 0.55)
    }
}
