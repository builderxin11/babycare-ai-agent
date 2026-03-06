import SwiftUI

// MARK: - Log Day View

struct LogDayView: View {
    let date: Date
    let logs: [PhysiologyLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateDisplayString)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ForEach(logs.prefix(5)) { log in
                LogRowView(log: log)
            }

            if logs.count > 5 {
                Text("+ \(logs.count - 5) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var dateDisplayString: String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Log Row View

struct LogRowView: View {
    let log: PhysiologyLog

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: log.type?.icon ?? "circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(categoryColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(log.displayDescription)
                    .font(.subheadline)

                Text(log.timeDisplayString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Duration if available
            if let duration = log.durationMinutes {
                Text("\(duration) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        guard let type = log.type else { return .gray }

        switch type.category {
        case .feeding: return .orange
        case .sleep: return .indigo
        case .diaper: return .green
        case .other: return .blue
        }
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: ContextEvent

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(eventColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: event.type?.icon ?? "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(eventColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    if let type = event.type {
                        Text(type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)
                    }

                    Text(event.dateRangeDisplayString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Ongoing badge
            if event.isOngoing {
                Text("Ongoing")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(eventColor)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }

    private var eventColor: Color {
        switch event.type {
        case .vaccine: return .blue
        case .travel, .jetLag: return .purple
        case .illness: return .red
        case .milestone: return .yellow
        case .other, .none: return .gray
        }
    }
}

#Preview("Log Day") {
    VStack {
        LogDayView(
            date: Date(),
            logs: [
                PhysiologyLog(
                    babyId: "1",
                    type: .milkFormula,
                    startTime: Date(),
                    amount: 120,
                    unit: .ml
                ),
                PhysiologyLog(
                    babyId: "1",
                    type: .sleep,
                    startTime: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!,
                    endTime: Date()
                ),
            ]
        )
    }
    .padding()
}

#Preview("Event Row") {
    VStack {
        EventRowView(event: ContextEvent(
            babyId: "1",
            type: .vaccine,
            title: "2-Month Vaccinations",
            startDate: Date()
        ))
        EventRowView(event: ContextEvent(
            babyId: "1",
            type: .travel,
            title: "Trip to Grandma's",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        ))
    }
    .padding()
}
