import SwiftUI
import Combine

struct SummaryView: View {
    let baby: Baby
    @StateObject private var viewModel: SummaryViewModel

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
            Text("📊")
                .font(.system(size: 40))

            Text("本周摘要")
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
            Text("本周统计")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    icon: "🍼",
                    title: "喂养",
                    value: "\(viewModel.weeklyStats.totalFeedings)次",
                    subtitle: "共\(Int(viewModel.weeklyStats.totalFeedingMl))ml",
                    color: AppTheme.feedingColor
                )

                StatCard(
                    icon: "😴",
                    title: "睡眠",
                    value: viewModel.weeklyStats.avgSleepString,
                    subtitle: "日均",
                    color: AppTheme.sleepColor
                )

                StatCard(
                    icon: "💩",
                    title: "换尿布",
                    value: "\(viewModel.weeklyStats.totalDiapers)次",
                    subtitle: "本周总计",
                    color: AppTheme.diaperColor
                )

                StatCard(
                    icon: "🥣",
                    title: "辅食",
                    value: "\(viewModel.weeklyStats.totalSolidFeedings)次",
                    subtitle: "本周总计",
                    color: AppTheme.solidFoodColor
                )
            }
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("趋势")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 8) {
                TrendRow(
                    icon: "🍼",
                    title: "喂养量",
                    trend: viewModel.feedingTrend,
                    description: viewModel.feedingTrendDescription
                )

                TrendRow(
                    icon: "😴",
                    title: "睡眠时长",
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
                Text("✨")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 智能分析")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Text("获取个性化育儿建议")
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
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(icon)
                    .font(.title2)

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
    let icon: String
    let title: String
    let trend: TrendDirection
    let description: String

    var body: some View {
        HStack {
            Text(icon)
                .font(.title3)

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
            case .none:
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
    var feedingTrendDescription: String { "与上周持平" }
    var sleepTrend: TrendDirection { .improving }
    var sleepTrendDescription: String { "增加30分钟" }
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
        return "\(hours)小时\(mins)分"
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
