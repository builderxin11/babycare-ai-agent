import SwiftUI

struct RiskBadge: View {
    let level: RiskLevel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)

            Text(level.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(8)
    }

    private var iconName: String {
        switch level {
        case .low:
            return "checkmark.shield.fill"
        case .medium:
            return "exclamationmark.shield.fill"
        case .high:
            return "xmark.shield.fill"
        }
    }

    private var badgeColor: Color {
        switch level {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        RiskBadge(level: .low)
        RiskBadge(level: .medium)
        RiskBadge(level: .high)
    }
    .padding()
}
