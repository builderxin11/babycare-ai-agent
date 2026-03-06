import SwiftUI

struct ReportDetailView: View {
    let report: DailyReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Summary
                summarySection

                // Observations
                if !report.observations.isEmpty {
                    observationsSection
                }

                // Action Items
                if !report.actionItems.isEmpty {
                    actionItemsSection
                }

                // Warnings
                if !report.warnings.isEmpty {
                    warningsSection
                }

                // Data Snapshot
                dataSnapshotSection

                // Disclaimer
                disclaimerSection
            }
            .padding()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.reportDateDisplayString)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(report.babyName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                healthStatusBadge
            }

            HStack(spacing: 16) {
                trendIndicator
                confidenceIndicator
            }
        }
    }

    private var healthStatusBadge: some View {
        VStack(spacing: 4) {
            Image(systemName: report.healthStatus.icon)
                .font(.title)
            Text(report.healthStatus.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(statusColor)
        .padding()
        .background(statusColor.opacity(0.15))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch report.healthStatus {
        case .healthy: return .green
        case .monitor: return .orange
        case .concern: return .red
        }
    }

    private var trendIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: report.trendDirection.icon)
            Text("Trend: \(report.trendDirection.displayName)")
                .font(.caption)
        }
        .foregroundColor(trendColor)
    }

    private var trendColor: Color {
        switch report.trendDirection {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .orange
        }
    }

    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
            Text("\(report.confidencePercentage)% confidence")
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)

            Text(report.summary)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Observations

    private var observationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Observations")
                .font(.headline)

            ForEach(report.observations, id: \.self) { observation in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)

                    Text(observation)
                        .font(.body)
                }
            }
        }
    }

    // MARK: - Action Items

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Actions")
                .font(.headline)

            ForEach(report.actionItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .frame(width: 24)

                    Text(item)
                        .font(.body)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Warnings

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Items to Monitor")
                    .font(.headline)
            }

            ForEach(report.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)

                    Text(warning)
                        .font(.body)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Data Snapshot

    private var dataSnapshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Snapshot")
                .font(.headline)

            HStack(spacing: 16) {
                dataCard(title: "Today", data: report.dataSnapshot)
                dataCard(title: "7-Day Avg", data: report.baselineSnapshot)
            }
        }
    }

    private func dataCard(title: String, data: [String: AnyCodable]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if let feedingMl = data["feeding_ml"]?.value as? Double {
                dataRow(icon: "cup.and.saucer.fill", label: "Feeding", value: "\(Int(feedingMl)) ml")
            }

            if let sleepMin = data["sleep_min"]?.value as? Double {
                let hours = Int(sleepMin) / 60
                let mins = Int(sleepMin) % 60
                dataRow(icon: "moon.zzz.fill", label: "Sleep", value: "\(hours)h \(mins)m")
            }

            if let diaperCount = data["diaper_count"]?.value as? Int {
                dataRow(icon: "drop.triangle.fill", label: "Diapers", value: "\(diaperCount)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func dataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)

            Text(report.disclaimer)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    ReportDetailView(report: DailyReport(
        babyId: "1",
        babyName: "Emma",
        reportDate: Date(),
        healthStatus: .healthy,
        confidenceScore: 0.87,
        trendDirection: .improving,
        summary: "Emma had a good day today! Feeding volumes are back to normal after the vaccination dip earlier this week. Sleep patterns continue to improve.",
        observations: [
            "Feeding volume recovered to 520ml, up from 480ml yesterday",
            "Sleep duration increased by 30 minutes compared to baseline",
            "Regular diaper changes indicate good hydration"
        ],
        actionItems: [
            "Continue with the current feeding schedule",
            "Consider starting bedtime routine 15 minutes earlier"
        ],
        warnings: [
            "Monitor for any remaining vaccine-related symptoms"
        ],
        dataSnapshot: [
            "feeding_ml": AnyCodable(520.0),
            "sleep_min": AnyCodable(840.0),
            "diaper_count": AnyCodable(8)
        ],
        baselineSnapshot: [
            "feeding_ml": AnyCodable(500.0),
            "sleep_min": AnyCodable(810.0),
            "diaper_count": AnyCodable(7)
        ]
    ))
}
