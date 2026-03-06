import SwiftUI

struct SourceBadge: View {
    let sourceType: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)

            Text(displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(6)
    }

    private var iconName: String {
        switch sourceType.lowercased() {
        case "data_analysis", "data":
            return "chart.bar.fill"
        case "medical", "book":
            return "book.fill"
        case "xhs_post", "social":
            return "text.bubble.fill"
        default:
            return "doc.fill"
        }
    }

    private var displayName: String {
        switch sourceType.lowercased() {
        case "data_analysis", "data":
            return "Data"
        case "medical", "book":
            return "Medical"
        case "xhs_post", "social":
            return "Social"
        default:
            return sourceType.capitalized
        }
    }

    private var badgeColor: Color {
        switch sourceType.lowercased() {
        case "data_analysis", "data":
            return .blue
        case "medical", "book":
            return .purple
        case "xhs_post", "social":
            return .orange
        default:
            return .gray
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        SourceBadge(sourceType: "data_analysis")
        SourceBadge(sourceType: "medical")
        SourceBadge(sourceType: "xhs_post")
    }
    .padding()
}
