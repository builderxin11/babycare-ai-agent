import SwiftUI
import Charts

struct GrowthChartView: View {
    let baby: Baby

    @State private var selectedMetric: GrowthMetric = .weight

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Metric Selector
                metricSelector

                // Chart
                chartSection

                // WHO Standards Reference
                referenceSection

                // Add Measurement Button
                addMeasurementButton
            }
            .padding()
        }
        .background(AppTheme.background)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("📈")
                .font(.system(size: 40))

            Text("成长曲线")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)

            Text("基于WHO标准")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
    }

    // MARK: - Metric Selector

    private var metricSelector: some View {
        HStack(spacing: 12) {
            ForEach(GrowthMetric.allCases, id: \.self) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    VStack(spacing: 4) {
                        Text(metric.icon)
                            .font(.title2)

                        Text(metric.chineseName)
                            .font(.caption)
                            .foregroundColor(selectedMetric == metric ? AppTheme.pink : AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedMetric == metric ? AppTheme.pink.opacity(0.2) : AppTheme.cardBackground)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedMetric.chartTitle)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            // Placeholder chart
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground)
                    .frame(height: 250)

                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textSecondary)

                    Text("添加测量数据以查看成长曲线")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Reference Section

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("参考范围")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 16) {
                ReferenceCard(
                    title: "同龄标准",
                    value: selectedMetric.standardRange,
                    color: AppTheme.green
                )

                ReferenceCard(
                    title: "当前百分位",
                    value: "待测量",
                    color: AppTheme.pink
                )
            }
        }
    }

    // MARK: - Add Measurement Button

    private var addMeasurementButton: some View {
        Button {
            // TODO: Show add measurement sheet
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("添加测量记录")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.pink)
            .cornerRadius(12)
        }
    }
}

// MARK: - Reference Card

struct ReferenceCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Growth Metric

enum GrowthMetric: CaseIterable {
    case weight
    case height
    case headCircumference

    var icon: String {
        switch self {
        case .weight: return "⚖️"
        case .height: return "📏"
        case .headCircumference: return "🧠"
        }
    }

    var chineseName: String {
        switch self {
        case .weight: return "体重"
        case .height: return "身高"
        case .headCircumference: return "头围"
        }
    }

    var chartTitle: String {
        switch self {
        case .weight: return "体重变化 (kg)"
        case .height: return "身高变化 (cm)"
        case .headCircumference: return "头围变化 (cm)"
        }
    }

    var standardRange: String {
        switch self {
        case .weight: return "9.0-11.5 kg"
        case .height: return "73-80 cm"
        case .headCircumference: return "44-47 cm"
        }
    }
}

#Preview {
    GrowthChartView(baby: Baby(
        id: "1",
        familyId: "f1",
        name: "宝宝",
        birthDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    ))
}
