import SwiftUI

struct RecordView: View {
    @StateObject private var viewModel: RecordViewModel

    init(baby: Baby) {
        _viewModel = StateObject(wrappedValue: RecordViewModel(baby: baby))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                dailySummaryBar
                timelineView
                diarySection
                Spacer(minLength: 0)
                quickAddButtons
            }
        }
        .sheet(isPresented: $viewModel.showingAddLog) {
            AddLogSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showingWakeUpSheet) {
            WakeUpSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showingEditLog) {
            if let log = viewModel.editingLog {
                EditLogSheet(viewModel: viewModel, log: log)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $viewModel.showingVaccineSheet) {
            VaccineSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showingGrowthSheet) {
            GrowthMeasurementSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showingCustomLogSheet) {
            if let button = viewModel.selectedCustomButton {
                CustomLogSheet(viewModel: viewModel, button: button)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $viewModel.showingAddCustomButton) {
            AddCustomButtonSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "face.smiling")
                    .font(.title2)
                    .foregroundColor(AppTheme.pink)
                Text(viewModel.baby.ageChineseString)
                    .foregroundColor(AppTheme.textPrimary)
                    .font(.subheadline)
            }
            .padding(.horizontal)

            // Date selector with swipe
            HStack {
                Button {
                    viewModel.goToPreviousDay()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppTheme.pink)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(viewModel.selectedDate.chineseFormatted)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.pink)

                    if Calendar.current.isDateInToday(viewModel.selectedDate) {
                        Text("今天")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                Button {
                    viewModel.goToNextDay()
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(viewModel.canGoToNextDay ? AppTheme.pink : AppTheme.textSecondary.opacity(0.3))
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.canGoToNextDay)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Daily Summary Bar

    private var dailySummaryBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.caption)
                    .foregroundColor(AppTheme.feedingColor)
                Text("\(viewModel.dailyStats.feedingCount)次")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(Int(viewModel.dailyStats.feedingMl))ml")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(.caption)
                    .foregroundColor(AppTheme.sleepColor)
                Text(viewModel.dailyStats.sleepDurationString)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.diaperColor)
                Text("\(viewModel.dailyStats.diaperCount)次")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 50)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground)
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        TimelineHourSection(
                            hour: hour,
                            logs: viewModel.logsForHour(hour),
                            isInvalidSleep: { viewModel.isInvalidSleep($0) },
                            onTap: { viewModel.startEditingLog($0) },
                            onDelete: { viewModel.deleteLog($0) }
                        )
                        .id(hour)
                    }
                }
            }
            .onAppear {
                let currentHour = Calendar.current.component(.hour, from: Date())
                withAnimation {
                    proxy.scrollTo(currentHour, anchor: .center)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width > 50 {
                        // Swipe right -> previous day
                        withAnimation {
                            viewModel.goToPreviousDay()
                        }
                    } else if value.translation.width < -50 && viewModel.canGoToNextDay {
                        // Swipe left -> next day
                        withAnimation {
                            viewModel.goToNextDay()
                        }
                    }
                }
        )
    }

    // MARK: - Diary Section

    private var diarySection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(AppTheme.pink)
                Text("育儿日记")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "pencil")
                    .foregroundColor(AppTheme.pink)
            }

            Button(action: {}) {
                Image(systemName: "camera")
                    .foregroundColor(AppTheme.pink)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
    }

    // MARK: - Quick Add Buttons

    private var quickAddButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                QuickAddButton(systemIcon: "cup.and.saucer.fill", title: "配方奶", color: AppTheme.feedingColor) {
                    viewModel.selectedLogType = .milkFormula
                    viewModel.showingAddLog = true
                }

                QuickAddButton(systemIcon: "moon.zzz.fill", title: "睡觉", color: AppTheme.sleepColor) {
                    viewModel.selectedLogType = .sleep
                    viewModel.showingAddLog = true
                }

                QuickAddButton(systemIcon: "sun.horizon.fill", title: "起床", color: AppTheme.orange) {
                    viewModel.showingWakeUpSheet = true
                }

                QuickAddButton(systemIcon: "drop.fill", title: "便便", color: AppTheme.diaperColor) {
                    viewModel.selectedLogType = .diaperDirty
                    viewModel.showingAddLog = true
                }

                QuickAddButton(systemIcon: "bathtub.fill", title: "洗澡", color: AppTheme.bathColor) {
                    viewModel.selectedLogType = .bath
                    viewModel.showingAddLog = true
                }

                QuickAddButton(systemIcon: "syringe.fill", title: "疫苗", color: AppTheme.vaccineColor) {
                    viewModel.showingVaccineSheet = true
                }

                QuickAddButton(systemIcon: "leaf.fill", title: "辅食", color: AppTheme.solidFoodColor) {
                    viewModel.selectedLogType = .milkSolid
                    viewModel.showingAddLog = true
                }

                QuickAddButton(systemIcon: "heart.fill", title: "母乳", color: AppTheme.breastMilkColor) {
                    viewModel.selectedLogType = .milkBreast
                    viewModel.showingAddLog = true
                }

                // Custom buttons
                ForEach(viewModel.customButtons) { button in
                    QuickAddButton(systemIcon: button.icon, title: button.name, color: Color(hex: button.colorHex)) {
                        viewModel.selectedCustomButton = button
                        viewModel.showingCustomLogSheet = true
                    }
                }

                // Add custom button
                QuickAddButton(systemIcon: "plus", title: "自定义", color: AppTheme.textSecondary) {
                    viewModel.showingAddCustomButton = true
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(AppTheme.background)
    }

}

// MARK: - Timeline Hour Section

struct TimelineHourSection: View {
    let hour: Int
    let logs: [PhysiologyLog]
    var isInvalidSleep: (PhysiologyLog) -> Bool = { _ in false }
    var onTap: (PhysiologyLog) -> Void = { _ in }
    var onDelete: (PhysiologyLog) -> Void = { _ in }

    private func dotColor(for log: PhysiologyLog) -> Color {
        if isInvalidSleep(log) {
            return AppTheme.textSecondary.opacity(0.5)
        }
        if log.isWakeUpMarker {
            return AppTheme.orange
        }
        return log.type?.themeColor ?? AppTheme.textSecondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Hour marker column
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("\(hour)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 20, alignment: .trailing)

                    // Activity indicator dots
                    HStack(spacing: 2) {
                        ForEach(logs.prefix(3), id: \.id) { log in
                            Circle()
                                .fill(dotColor(for: log))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(width: 24, alignment: .leading)
                }
            }
            .frame(width: 52)
            .padding(.top, 8)

            // Log entries for this hour
            if logs.isEmpty {
                // Empty hour - just show spacer
                Spacer()
                    .frame(height: 44)
            } else {
                VStack(spacing: 4) {
                    ForEach(logs) { log in
                        TimelineEntryRow(log: log, isInvalid: isInvalidSleep(log))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTap(log)
                            }
                            .contextMenu {
                                Button {
                                    onTap(log)
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    onDelete(log)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(minHeight: logs.isEmpty ? 44 : nil)
    }
}

// MARK: - Timeline Entry Row

struct TimelineEntryRow: View {
    let log: PhysiologyLog
    var isInvalid: Bool = false

    private var iconColor: Color {
        if isInvalid {
            return AppTheme.textSecondary
        }
        if log.isWakeUpMarker {
            return AppTheme.orange
        }
        return log.type?.themeColor ?? AppTheme.textSecondary
    }

    var body: some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(log.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isInvalid ? AppTheme.textSecondary : AppTheme.textPrimary)

                if let timeAgo = log.timeAgoString {
                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(isInvalid ? AppTheme.textSecondary : AppTheme.pink)
                }
            }
            .frame(width: 65, alignment: .trailing)

            // Icon with invalid indicator
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: log.displayIcon)
                    .font(.title3)
                    .foregroundColor(iconColor)

                // Invalid indicator
                if isInvalid {
                    Text("?")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(AppTheme.orange)
                        .clipShape(Circle())
                        .offset(x: 16, y: -16)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(log.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isInvalid ? AppTheme.textSecondary : AppTheme.textPrimary)

                    if isInvalid {
                        Text("(无效)")
                            .font(.caption2)
                            .foregroundColor(AppTheme.orange)
                    }
                }

                if let detail = log.detailString {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(isInvalid ? AppTheme.textSecondary : AppTheme.pink)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isInvalid ? AppTheme.cardBackground.opacity(0.5) : AppTheme.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Quick Add Button

struct QuickAddButton: View {
    let systemIcon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: systemIcon)
                        .font(.title2)
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Extensions

extension Baby {
    var ageChineseString: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0
        return "\(years)岁\(months)个月\(days)天"
    }
}

extension Date {
    var chineseFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        let weekday = formatter.string(from: self)
        return weekday.replacingOccurrences(of: "星期", with: "周")
    }
}

extension PhysiologyLogType {
    var systemIcon: String {
        switch self {
        case .milkBreast: return "heart.fill"
        case .milkFormula: return "cup.and.saucer.fill"
        case .milkSolid: return "leaf.fill"
        case .sleep: return "moon.zzz.fill"
        case .diaperWet: return "drop.fill"
        case .diaperDirty: return "drop.fill"
        case .bath: return "bathtub.fill"
        }
    }
}

extension PhysiologyLog {
    var timeAgoString: String? {
        let minutes = Int(-startTime.timeIntervalSinceNow / 60)
        if minutes < 0 { return nil } // Future time
        if minutes < 60 {
            return "\(minutes)分钟前"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)小时前"
            }
            return "\(hours)小时\(mins)分钟前"
        }
    }

    /// Check if this is a wake-up marker (sleep log where startTime == endTime)
    var isWakeUpMarker: Bool {
        guard type == .sleep, let endTime = endTime else { return false }
        return abs(endTime.timeIntervalSince(startTime)) < 60 // Within 1 minute
    }

    var displayName: String {
        if isWakeUpMarker {
            return "起床"
        }
        return type?.chineseName ?? "记录"
    }

    var displayIcon: String {
        if isWakeUpMarker {
            return "sun.horizon.fill"
        }
        return type?.systemIcon ?? "note.text"
    }

    var detailString: String? {
        // Wake-up marker shows the notes (sleep duration info)
        if isWakeUpMarker {
            return notes
        }

        switch type {
        case .milkFormula, .milkBreast:
            if let amount = amount {
                return "\(Int(amount))ml"
            }
        case .sleep:
            if let endTime = endTime {
                let duration = Int(endTime.timeIntervalSince(startTime) / 60)
                let hours = duration / 60
                let mins = duration % 60
                return "\(hours)小时\(mins)分钟"
            }
            return "睡眠中..."
        case .diaperDirty:
            return notes ?? "大/软/茶色"
        case .diaperWet:
            return "小便"
        case .milkSolid:
            return notes ?? "辅食"
        case .bath:
            return notes ?? "洗澡"
        case .none:
            return nil
        }
        return nil
    }
}

#Preview {
    RecordView(baby: Baby.preview)
}
