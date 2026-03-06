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
                Spacer()
                quickAddButtons
            }

            floatingButtons
        }
        .sheet(isPresented: $viewModel.showingAddLog) {
            AddLogSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppTheme.pink)
                        .font(.title2)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("👶")
                        .font(.title2)
                    Text(viewModel.baby.ageChineseString)
                        .foregroundColor(AppTheme.textPrimary)
                        .font(.subheadline)
                }

                Spacer()

                Button(action: {}) {
                    Text("升级")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.textSecondary, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)

            HStack {
                Spacer()

                Text(viewModel.selectedDate.chineseFormatted)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.pink)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("出生后")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    HStack(spacing: 2) {
                        Text("第")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Text("\(viewModel.baby.ageInDays)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("天")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Daily Summary Bar

    private var dailySummaryBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("🍼")
                    .font(.caption)
                Text("\(viewModel.dailyStats.feedingCount)次")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(Int(viewModel.dailyStats.feedingMl))ml")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            HStack(spacing: 4) {
                Text("😴")
                    .font(.caption)
                Text(viewModel.dailyStats.sleepDurationString)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            HStack(spacing: 4) {
                Text("💩")
                    .font(.caption)
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
                HStack(alignment: .top, spacing: 0) {
                    hourMarkersColumn
                    timelineEntriesColumn
                }
            }
            .onAppear {
                let currentHour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(currentHour, anchor: .center)
            }
        }
    }

    private var hourMarkersColumn: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 4) {
                    Text("\(hour)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 20, alignment: .trailing)

                    activityIndicator(for: hour)
                }
                .frame(height: 44)
                .id(hour)
            }
        }
        .padding(.leading, 8)
    }

    private func activityIndicator(for hour: Int) -> some View {
        let activities = viewModel.activitiesForHour(hour)

        return HStack(spacing: 2) {
            ForEach(activities.prefix(3), id: \.id) { log in
                Circle()
                    .fill(log.type?.themeColor ?? AppTheme.textSecondary)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 24, alignment: .leading)
    }

    private var timelineEntriesColumn: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.sortedLogs) { log in
                TimelineEntryRow(log: log)
            }
        }
        .padding(.leading, 8)
    }

    // MARK: - Diary Section

    private var diarySection: some View {
        HStack {
            HStack(spacing: 8) {
                Text("📕")
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
                QuickAddButton(icon: "🍼", title: "配方奶", color: AppTheme.feedingColor) {
                    viewModel.selectedLogType = .milkFormula
                    viewModel.showingAddLog = true
                }

                QuickAddButton(icon: "😴", title: "睡觉", color: AppTheme.sleepColor) {
                    viewModel.selectedLogType = .sleep
                    viewModel.showingAddLog = true
                }

                QuickAddButton(icon: "🌅", title: "起床", color: AppTheme.sleepColor) {
                    viewModel.recordWakeUp()
                }

                QuickAddButton(icon: "💩", title: "便便", color: AppTheme.diaperColor) {
                    viewModel.selectedLogType = .diaperDirty
                    viewModel.showingAddLog = true
                }

                QuickAddButton(icon: "🥣", title: "断奶食品", color: AppTheme.solidFoodColor) {
                    viewModel.selectedLogType = .milkSolid
                    viewModel.showingAddLog = true
                }

                QuickAddButton(icon: "🤱", title: "瓶喂母乳", color: AppTheme.breastMilkColor) {
                    viewModel.selectedLogType = .milkBreast
                    viewModel.showingAddLog = true
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(AppTheme.background)
    }

    // MARK: - Floating Buttons

    private var floatingButtons: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(AppTheme.pink)
                            .clipShape(Circle())
                    }

                    Button(action: {}) {
                        Image(systemName: "timer")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(AppTheme.pink)
                            .clipShape(Circle())
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 180)
            }
        }
    }
}

// MARK: - Timeline Entry Row

struct TimelineEntryRow: View {
    let log: PhysiologyLog

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(log.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)

                if let timeAgo = log.timeAgoString {
                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(AppTheme.pink)
                }
            }
            .frame(width: 60, alignment: .trailing)

            ZStack {
                Circle()
                    .fill(log.type?.themeColor.opacity(0.2) ?? AppTheme.cardBackground)
                    .frame(width: 44, height: 44)

                Text(log.type?.cuteIcon ?? "📝")
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(log.type?.chineseName ?? "记录")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)

                if let detail = log.detailString {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(AppTheme.pink)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppTheme.cardBackground)
    }
}

// MARK: - Quick Add Button

struct QuickAddButton: View {
    let icon: String
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

                    Text(icon)
                        .font(.title2)
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

extension PhysiologyLog {
    var timeAgoString: String? {
        let minutes = Int(-startTime.timeIntervalSinceNow / 60)
        if minutes < 60 {
            return "\(minutes)分钟前"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)小时\(mins)分钟前"
        }
    }

    var detailString: String? {
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
        case .diaperDirty:
            return "大/软/茶色"
        case .diaperWet:
            return "小便"
        case .milkSolid:
            return notes ?? "辅食"
        case .none:
            return nil
        }
        return nil
    }
}

#Preview {
    RecordView(baby: Baby(
        id: "1",
        familyId: "f1",
        name: "宝宝",
        birthDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    ))
}
