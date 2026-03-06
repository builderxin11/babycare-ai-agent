import SwiftUI

struct AddLogSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date = Date()
    @State private var selectedAmount: Int = 120  // Default 120ml
    @State private var notes: String = ""

    // Amount options from 10 to 300 in 10ml increments
    private let amountOptions = Array(stride(from: 10, through: 300, by: 10))

    private var title: String {
        viewModel.selectedLogType.chineseName
    }

    private var showsAmount: Bool {
        switch viewModel.selectedLogType {
        case .milkBreast, .milkFormula:
            return true
        default:
            return false
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
                                    .fill(viewModel.selectedLogType.themeColor.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: viewModel.selectedLogType.systemIcon)
                                    .font(.system(size: 28))
                                    .foregroundColor(viewModel.selectedLogType.themeColor)
                            }
                            .padding(.top, 8)

                            // Time picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("时间")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                DatePicker("", selection: $startTime)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Amount picker (for feeding types)
                            if showsAmount {
                                VStack(spacing: 8) {
                                    Text("用量")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    HStack(spacing: 0) {
                                        Picker("", selection: $selectedAmount) {
                                            ForEach(amountOptions, id: \.self) { ml in
                                                Text("\(ml)").tag(ml)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 100, height: 100)

                                        Text("ml")
                                            .font(.title2)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(12)
                                }
                            }

                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("备注")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("添加备注...", text: $notes)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Save button - always visible at bottom
                    Button {
                        saveLog()
                    } label: {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.pink)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func saveLog() {
        let parsedAmount: Double? = showsAmount ? Double(selectedAmount) : nil

        viewModel.addLogLocally(
            type: viewModel.selectedLogType,
            amount: parsedAmount,
            notes: notes.isEmpty ? nil : notes,
            startTime: startTime
        )
        dismiss()
    }
}

// MARK: - Edit Log Sheet

struct EditLogSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    let log: PhysiologyLog
    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date
    @State private var selectedAmount: Int
    @State private var notes: String

    private let amountOptions = Array(stride(from: 10, through: 300, by: 10))

    private var logType: PhysiologyLogType {
        log.type ?? .milkFormula
    }

    private var showsAmount: Bool {
        switch logType {
        case .milkBreast, .milkFormula, .milkSolid:
            return true
        default:
            return false
        }
    }

    init(viewModel: RecordViewModel, log: PhysiologyLog) {
        self.viewModel = viewModel
        self.log = log
        _startTime = State(initialValue: log.startTime)
        _selectedAmount = State(initialValue: Int(log.amount ?? 120))
        _notes = State(initialValue: log.notes ?? "")
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
                                    .fill(logType.themeColor.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: logType.systemIcon)
                                    .font(.system(size: 28))
                                    .foregroundColor(logType.themeColor)
                            }
                            .padding(.top, 8)

                            // Time picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("时间")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                DatePicker("", selection: $startTime)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Amount picker (for feeding types)
                            if showsAmount {
                                VStack(spacing: 8) {
                                    Text("用量")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    HStack(spacing: 0) {
                                        Picker("", selection: $selectedAmount) {
                                            ForEach(amountOptions, id: \.self) { ml in
                                                Text("\(ml)").tag(ml)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 100, height: 100)

                                        Text("ml")
                                            .font(.title2)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .background(AppTheme.cardBackground)
                                    .cornerRadius(12)
                                }
                            }

                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("备注")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("添加备注...", text: $notes)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Delete button
                            Button(role: .destructive) {
                                viewModel.deleteLog(log)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("删除此记录")
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Save button
                    Button {
                        saveChanges()
                    } label: {
                        Text("保存修改")
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
            .navigationTitle("编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func saveChanges() {
        let parsedAmount: Double? = showsAmount ? Double(selectedAmount) : nil
        viewModel.updateLog(
            id: log.id,
            type: logType,
            startTime: startTime,
            amount: parsedAmount,
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}

// MARK: - Wake Up Sheet

struct WakeUpSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var wakeUpTime: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.orange.opacity(0.2))
                            .frame(width: 70, height: 70)

                        Image(systemName: "sun.horizon.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.orange)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    // Active sleep info
                    if let activeSleep = viewModel.activeSleepLog {
                        VStack(spacing: 8) {
                            Text("对应的睡眠记录")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)

                            HStack(spacing: 12) {
                                Image(systemName: "moon.zzz.fill")
                                    .foregroundColor(AppTheme.sleepColor)

                                Text("睡觉")
                                    .foregroundColor(AppTheme.textPrimary)

                                Text(activeSleep.startTime.formatted(date: .omitted, time: .shortened))
                                    .foregroundColor(AppTheme.pink)

                                Spacer()
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("没有进行中的睡眠记录")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

                    // Time picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("起床时间")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)

                        DatePicker("", selection: $wakeUpTime)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Sleep duration preview
                    if let activeSleep = viewModel.activeSleepLog {
                        let duration = Int(wakeUpTime.timeIntervalSince(activeSleep.startTime) / 60)
                        let hours = max(0, duration / 60)
                        let mins = max(0, duration % 60)

                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(AppTheme.textSecondary)

                            Text("睡眠时长: ")
                                .foregroundColor(AppTheme.textSecondary)

                            Text("\(hours)小时\(mins)分钟")
                                .foregroundColor(duration >= 0 ? AppTheme.pink : AppTheme.orange)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    Spacer(minLength: 20)

                    // Save button
                    Button {
                        viewModel.recordWakeUp(at: wakeUpTime)
                    } label: {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.pink)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("起床")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        viewModel.recordWakeUp(at: wakeUpTime)
                    }
                    .foregroundColor(AppTheme.pink)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Vaccine Sheet

struct VaccineSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var vaccineName: String = ""
    @State private var vaccineDate: Date = Date()
    @State private var notes: String = ""

    private let commonVaccines = [
        "乙肝疫苗", "卡介苗", "脊灰疫苗", "百白破疫苗",
        "麻腮风疫苗", "乙脑疫苗", "A群流脑疫苗", "甲肝疫苗"
    ]

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
                                    .fill(AppTheme.vaccineColor.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "syringe.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppTheme.vaccineColor)
                            }
                            .padding(.top, 8)

                            // Vaccine name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("疫苗名称")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("输入疫苗名称", text: $vaccineName)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Common vaccines
                            VStack(alignment: .leading, spacing: 8) {
                                Text("常见疫苗")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                FlowLayout(spacing: 8) {
                                    ForEach(commonVaccines, id: \.self) { vaccine in
                                        Button {
                                            vaccineName = vaccine
                                        } label: {
                                            Text(vaccine)
                                                .font(.caption)
                                                .foregroundColor(vaccineName == vaccine ? .white : AppTheme.vaccineColor)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(vaccineName == vaccine ? AppTheme.vaccineColor : AppTheme.cardBackground)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                            }

                            // Date picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("接种日期")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                DatePicker("", selection: $vaccineDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("备注")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("添加备注...", text: $notes)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Save button
                    Button {
                        viewModel.addVaccine(
                            title: vaccineName,
                            date: vaccineDate,
                            notes: notes.isEmpty ? nil : notes
                        )
                    } label: {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(vaccineName.isEmpty ? AppTheme.textSecondary : AppTheme.pink)
                            .cornerRadius(12)
                    }
                    .disabled(vaccineName.isEmpty)
                    .padding()
                }
            }
            .navigationTitle("疫苗记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Growth Measurement Sheet

struct GrowthMeasurementSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var measurementDate: Date = Date()
    @State private var value: Double = 0
    @State private var notes: String = ""

    private var measurementType: GrowthMeasurementType {
        viewModel.selectedGrowthType
    }

    // Value ranges based on type
    private var valueRange: ClosedRange<Double> {
        switch measurementType {
        case .weight:
            return 2.0...30.0
        case .height:
            return 40.0...150.0
        case .headCircumference:
            return 30.0...60.0
        }
    }

    private var step: Double {
        switch measurementType {
        case .weight:
            return 0.1
        case .height, .headCircumference:
            return 0.5
        }
    }

    private var defaultValue: Double {
        switch measurementType {
        case .weight:
            return 8.0
        case .height:
            return 70.0
        case .headCircumference:
            return 45.0
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
                                Text(String(format: measurementType == .weight ? "%.1f" : "%.1f", value))
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

                            // Date picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("测量日期")
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
                                Text("备注")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("添加备注...", text: $notes)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Save button
                    Button {
                        viewModel.addGrowthMeasurement(
                            type: measurementType,
                            value: value,
                            date: measurementDate,
                            notes: notes.isEmpty ? nil : notes
                        )
                    } label: {
                        Text("保存")
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
            .navigationTitle(measurementType.chineseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                value = defaultValue
            }
        }
    }
}

// MARK: - Custom Log Sheet

struct CustomLogSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    let button: CustomButton
    @Environment(\.dismiss) private var dismiss

    @State private var logTime: Date = Date()
    @State private var notes: String = ""

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
                                    .fill(Color(hex: button.colorHex).opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: button.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: button.colorHex))
                            }
                            .padding(.top, 8)

                            Text(button.name)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.textPrimary)

                            // Time picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("时间")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                DatePicker("", selection: $logTime)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("备注")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("添加备注...", text: $notes)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        viewModel.addCustomLog(button: button, time: logTime, notes: notes.isEmpty ? nil : notes)
                    } label: {
                        Text("保存")
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
            .navigationTitle(button.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Add Custom Button Sheet

struct AddCustomButtonSheet: View {
    @ObservedObject var viewModel: RecordViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var selectedColor: String = "FF6B6B"

    private let iconOptions = [
        "star.fill", "heart.fill", "bell.fill", "flag.fill",
        "bookmark.fill", "tag.fill", "bolt.fill", "flame.fill",
        "drop.fill", "leaf.fill", "pawprint.fill", "hare.fill",
        "ant.fill", "ladybug.fill", "fish.fill", "tortoise.fill",
        "cross.fill", "pills.fill", "bandage.fill", "eye.fill",
        "ear.fill", "hand.raised.fill", "figure.walk", "bicycle"
    ]

    private let colorOptions = [
        "FF6B6B", "4ECDC4", "45B7D1", "96CEB4",
        "FFEAA7", "DDA0DD", "98D8C8", "F7DC6F",
        "BB8FCE", "85C1E9", "F8B500", "00CED1"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Preview
                            ZStack {
                                Circle()
                                    .fill(Color(hex: selectedColor).opacity(0.2))
                                    .frame(width: 80, height: 80)

                                Image(systemName: selectedIcon)
                                    .font(.system(size: 36))
                                    .foregroundColor(Color(hex: selectedColor))
                            }
                            .padding(.top, 16)

                            // Name input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("名称")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                TextField("输入名称", text: $name)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .padding()
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)

                            // Icon selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("图标")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                    ForEach(iconOptions, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.title2)
                                                .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : AppTheme.textSecondary)
                                                .frame(width: 44, height: 44)
                                                .background(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : AppTheme.cardBackground)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }

                            // Color selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("颜色")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                    ForEach(colorOptions, id: \.self) { color in
                                        Button {
                                            selectedColor = color
                                        } label: {
                                            Circle()
                                                .fill(Color(hex: color))
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 3)
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        viewModel.addCustomButton(name: name, icon: selectedIcon, colorHex: selectedColor)
                    } label: {
                        Text("添加")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.isEmpty ? AppTheme.textSecondary : AppTheme.pink)
                            .cornerRadius(12)
                    }
                    .disabled(name.isEmpty)
                    .padding()
                }
            }
            .navigationTitle("自定义按钮")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.pink)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    AddLogSheet(viewModel: RecordViewModel(baby: Baby.preview))
}
