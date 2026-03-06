import SwiftUI

struct BabyRowView: View {
    let baby: Baby

    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 4) {
                Text(baby.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(baby.ageDisplayString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let gender = baby.gender {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(gender.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarColor.opacity(0.2))

            Text(baby.name.prefix(1).uppercased())
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(avatarColor)
        }
        .frame(width: 50, height: 50)
    }

    private var avatarColor: Color {
        switch baby.gender {
        case .male:
            return .blue
        case .female:
            return .pink
        case .other, .none:
            return .purple
        }
    }
}

#Preview {
    List {
        BabyRowView(baby: Baby(
            id: "1",
            familyId: "f1",
            name: "Emma",
            birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date())!,
            gender: .female
        ))
        BabyRowView(baby: Baby(
            id: "2",
            familyId: "f1",
            name: "Liam",
            birthDate: Calendar.current.date(byAdding: .day, value: -45, to: Date())!,
            gender: .male
        ))
    }
}
