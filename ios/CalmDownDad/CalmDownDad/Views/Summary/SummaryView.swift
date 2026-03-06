import SwiftUI
import Combine

struct SummaryView: View {
    let baby: Baby
    @StateObject private var viewModel: SummaryViewModel
    @ObservedObject var languageManager = LanguageManager.shared

    init(baby: Baby) {
        self.baby = baby
        _viewModel = StateObject(wrappedValue: SummaryViewModel(baby: baby))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView
                weeklyStatsSection
                trendsSection
                aiInsightsButton
            }
            .padding()
        }
        .background(AppTheme.background)
        .task {
            await viewModel.loadData()
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.pink)

            Text(L10n.weeklySummary)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)

            Text(viewModel.dateRangeString)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
    }

    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.weeklyStats)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    systemIcon: "cup.and.saucer.fill",
                    title: L10n.feeding,
                    value: L10n.countString(viewModel.weeklyStats.totalFeedings),
                    subtitle: L10n.mlString(Int(viewModel.weeklyStats.totalFeedingMl)),
                    color: AppTheme.feedingColor
                )

                StatCard(
                    systemIcon: "moon.zzz.fill",
                    title: L10n.sleep,
                    value: viewModel.weeklyStats.avgSleepString,
                    subtitle: L10n.dailyAverage,
                    color: AppTheme.sleepColor
                )

                StatCard(
                    systemIcon: "drop.fill",
                    title: L10n.diaperChange,
                    value: L10n.countString(viewModel.weeklyStats.totalDiapers),
                    subtitle: L10n.weeklyTotal,
                    color: AppTheme.diaperColor
                )

                StatCard(
                    systemIcon: "leaf.fill",
                    title: L10n.solidFood,
                    value: L10n.countString(viewModel.weeklyStats.totalSolidFeedings),
                    subtitle: L10n.weeklyTotal,
                    color: AppTheme.solidFoodColor
                )
            }
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.trends)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 8) {
                TrendRow(
                    systemIcon: "cup.and.saucer.fill",
                    title: L10n.feedingAmount,
                    trend: viewModel.feedingTrend,
                    description: viewModel.feedingTrendDescription
                )

                TrendRow(
                    systemIcon: "moon.zzz.fill",
                    title: L10n.sleepDurationTitle,
                    trend: viewModel.sleepTrend,
                    description: viewModel.sleepTrendDescription
                )
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    private var aiInsightsButton: some View {
        NavigationLink {
            AskView()
        } label: {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(AppTheme.pink)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.aiAnalysis)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Text(L10n.getPersonalizedAdvice)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.pink)
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.pink.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let systemIcon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemIcon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Trend Row

struct TrendRow: View {
    let systemIcon: String
    let title: String
    let trend: TrendDirection
    let description: String

    var body: some View {
        HStack {
            Image(systemName: systemIcon)
                .font(.title3)
                .foregroundColor(AppTheme.textSecondary)

            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: trend.icon)
                Text(description)
                    .font(.caption)
            }
            .foregroundColor(trendColor)
        }
    }

    private var trendColor: Color {
        switch trend {
        case .improving: return AppTheme.green
        case .stable: return AppTheme.blue
        case .declining: return AppTheme.orange
        }
    }
}

// MARK: - Summary View Model

@MainActor
class SummaryViewModel: ObservableObject {
    let baby: Baby
    @Published var physiologyLogs: [PhysiologyLog] = []
    @Published var isLoading = false

    private let amplifyService = AmplifyService.shared

    init(baby: Baby) {
        self.baby = baby
    }

    func loadData() async {
        isLoading = true
        do {
            physiologyLogs = try await amplifyService.listPhysiologyLogs(babyId: baby.id, limit: 200)
        } catch {
            print("Error loading data: \(error)")
        }
        isLoading = false
    }

    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -6, to: endDate)!
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var weeklyStats: WeeklyStats {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: -6, to: Date())!
        let weekLogs = physiologyLogs.filter { $0.startTime >= weekStart }

        var totalFeedings = 0
        var totalFeedingMl: Double = 0
        var totalSleepMinutes = 0
        var totalDiapers = 0
        var totalSolidFeedings = 0

        for log in weekLogs {
            switch log.type {
            case .milkFormula, .milkBreast:
                totalFeedings += 1
                totalFeedingMl += log.amount ?? 0
            case .milkSolid:
                totalSolidFeedings += 1
            case .sleep:
                if let endTime = log.endTime {
                    totalSleepMinutes += Int(endTime.timeIntervalSince(log.startTime) / 60)
                }
            case .diaperWet, .diaperDirty:
                totalDiapers += 1
            case .bath, .none:
                break
            }
        }

        return WeeklyStats(
            totalFeedings: totalFeedings,
            totalFeedingMl: totalFeedingMl,
            totalSleepMinutes: totalSleepMinutes,
            totalDiapers: totalDiapers,
            totalSolidFeedings: totalSolidFeedings
        )
    }

    var feedingTrend: TrendDirection { .stable }
    var feedingTrendDescription: String { L10n.sameAsLastWeek }
    var sleepTrend: TrendDirection { .improving }
    var sleepTrendDescription: String { "+30 min" }
}

struct WeeklyStats {
    let totalFeedings: Int
    let totalFeedingMl: Double
    let totalSleepMinutes: Int
    let totalDiapers: Int
    let totalSolidFeedings: Int

    var avgSleepString: String {
        let avgMinutes = totalSleepMinutes / 7
        let hours = avgMinutes / 60
        let mins = avgMinutes % 60
        return L10n.shortDurationString(hours: hours, minutes: mins)
    }
}

#Preview {
    SummaryView(baby: Baby(
        id: "1",
        familyId: "f1",
        name: "宝宝",
        birthDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    ))
}
