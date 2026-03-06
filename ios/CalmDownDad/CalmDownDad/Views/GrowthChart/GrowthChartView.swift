import SwiftUI
import Charts

struct GrowthChartView: View {
    let baby: Baby

    @ObservedObject private var dataStore = GrowthDataStore.shared
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var selectedMetric: GrowthMetric = .weight
    @State private var showingAddSheet = false
    @State private var selectedMeasurementType: GrowthMeasurementType = .weight

    private var currentMeasurements: [GrowthMeasurement] {
        dataStore.measurements(of: selectedMetric.measurementType)
    }

    private var latestMeasurement: GrowthMeasurement? {
        currentMeasurements.last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Metric Selector
                metricSelector

                // Latest Value
                if let latest = latestMeasurement {
                    latestValueCard(latest)
                }

                // Chart
                chartSection

                // Measurement History
                if !currentMeasurements.isEmpty {
                    historySection
                }

                // WHO Standards Reference
                referenceSection

                // Add Measurement Button
                addMeasurementButton
            }
            .padding()
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingAddSheet) {
            GrowthChartAddSheet(
                measurementType: selectedMeasurementType,
                onSave: { measurement in
                    dataStore.addMeasurement(measurement)
                    showingAddSheet = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    private func latestValueCard(_ measurement: GrowthMeasurement) -> some View {
        VStack(spacing: 8) {
            Text(L10n.latestMeasurement)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

            Text(measurement.displayValue)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(AppTheme.growthColor)

            Text(measurement.measuredAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.pink)

            Text(L10n.growthChart)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.textPrimary)

            Text(L10n.basedOnWHO)
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
                        Image(systemName: metric.systemIcon)
                            .font(.title2)
                            .foregroundColor(selectedMetric == metric ? AppTheme.pink : AppTheme.textSecondary)

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

            if currentMeasurements.count >= 2 {
                // Show actual chart
                Chart(currentMeasurements) { measurement in
                    LineMark(
                        x: .value("日期", measurement.measuredAt),
                        y: .value(selectedMetric.chineseName, measurement.value)
                    )
                    .foregroundStyle(AppTheme.growthColor)
                    .symbol(Circle())

                    PointMark(
                        x: .value("日期", measurement.measuredAt),
                        y: .value(selectedMetric.chineseName, measurement.value)
                    )
                    .foregroundStyle(AppTheme.growthColor)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(height: 200)
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(12)
            } else {
                // Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                        .frame(height: 200)

                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.textSecondary)

                        Text(L10n.needMoreData)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.measurementRecords)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            ForEach(currentMeasurements.reversed()) { measurement in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(measurement.displayValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.textPrimary)

                        Text(measurement.measuredAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    if let notes = measurement.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Reference Section

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.referenceRange)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 16) {
                ReferenceCard(
                    title: L10n.ageStandard,
                    value: selectedMetric.standardRange,
                    color: AppTheme.green
                )

                ReferenceCard(
                    title: L10n.currentPercentile,
                    value: L10n.toMeasure,
                    color: AppTheme.pink
                )
            }
        }
    }

    // MARK: - Add Measurement Button

    private var addMeasurementButton: some View {
        Button {
            selectedMeasurementType = selectedMetric.measurementType
            showingAddSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(L10n.addRecordString(for: selectedMetric.localizedName))
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

// MARK: - Growth Chart Add Sheet

struct GrowthChartAddSheet: View {
    let measurementType: GrowthMeasurementType
    let onSave: (GrowthMeasurement) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var measurementDate: Date = Date()
    @State private var value: Double = 0
    @State private var notes: String = ""

    private var valueRange: ClosedRange<Double> {
        switch measurementType {
        case .weight: return 2.0...30.0
        case .height: return 40.0...150.0
        case .headCircumference: return 30.0...60.0
        }
    }

    private var step: Double {
        switch measurementType {
        case .weight: return 0.1
        case .height, .headCircumference: return 0.5
        }
    }

    private var defaultValue: Double {
        switch measurementType {
        case .weight: return 8.0
        case .height: return 70.0
        case .headCircumference: return 45.0
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(AppTheme.growthColor.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: measurementType.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(AppTheme.growthColor)
                            }
                            .padding(.top, 8)

                            // Value display
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f", value))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(AppTheme.growthColor)

                                Text(measurementType.unit)
                                    .font(.title3)
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            // Slider
                            VStack(spacing: 8) {
                                Slider(value: $value, in: valueRange, step: step)
                                    .tint(AppTheme.growthColor)

                                HStack {
                                    Text(String(format: "%.1f", valueRange.lowerBound))
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.1f", valueRange.upperBound))
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.measurementDate)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                DatePicker("", selection: $measurementDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.notes)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField(L10n.addNotes, text: $notes)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        let measurement = GrowthMeasurement(
                            babyId: "",
                            type: measurementType,
                            value: value,
                            measuredAt: measurementDate,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(measurement)
                    } label: {
                        Text(L10n.save)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.pink)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle(measurementType.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { value = defaultValue }
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

    var systemIcon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .height: return "ruler.fill"
        case .headCircumference: return "brain.head.profile"
        }
    }

    var chineseName: String {
        localizedName
    }

    var localizedName: String {
        switch self {
        case .weight: return L10n.weight
        case .height: return L10n.height
        case .headCircumference: return L10n.headCircumference
        }
    }

    var chartTitle: String {
        switch self {
        case .weight: return L10n.weightChange
        case .height: return L10n.heightChange
        case .headCircumference: return L10n.headCircumferenceChange
        }
    }

    var standardRange: String {
        switch self {
        case .weight: return "9.0-11.5 kg"
        case .height: return "73-80 cm"
        case .headCircumference: return "44-47 cm"
        }
    }

    var measurementType: GrowthMeasurementType {
        switch self {
        case .weight: return .weight
        case .height: return .height
        case .headCircumference: return .headCircumference
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
