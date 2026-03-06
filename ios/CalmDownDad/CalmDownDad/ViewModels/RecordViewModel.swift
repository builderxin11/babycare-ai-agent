import Foundation
import SwiftUI
import Combine

@MainActor
class RecordViewModel: ObservableObject {
    @Published var baby: Baby
    @Published var selectedDate: Date = Date()
    @Published var physiologyLogs: [PhysiologyLog] = []
    @Published var contextEvents: [ContextEvent] = []
    @Published var growthMeasurements: [GrowthMeasurement] = []
    @Published var isLoading = false
    @Published var error: Error?

    @Published var showingAddLog = false
    @Published var showingWakeUpSheet = false
    @Published var showingEditLog = false
    @Published var showingVaccineSheet = false
    @Published var showingGrowthSheet = false
    @Published var showingCustomLogSheet = false
    @Published var showingAddCustomButton = false
    @Published var selectedLogType: PhysiologyLogType = .milkFormula
    @Published var selectedGrowthType: GrowthMeasurementType = .weight
    @Published var editingLog: PhysiologyLog?
    @Published var selectedCustomButton: CustomButton?
    @Published var customButtons: [CustomButton] = []

    private let amplifyService = AmplifyService.shared

    init(baby: Baby) {
        self.baby = baby
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        do {
            physiologyLogs = try await amplifyService.listPhysiologyLogs(babyId: baby.id, limit: 100)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Daily Stats

    var dailyStats: DailyStats {
        let calendar = Calendar.current
        let todayLogs = physiologyLogs.filter {
            calendar.isDate($0.startTime, inSameDayAs: selectedDate)
        }

        var feedingCount = 0
        var feedingMl: Double = 0
        var sleepMinutes = 0
        var diaperCount = 0

        for log in todayLogs {
            switch log.type {
            case .milkFormula, .milkBreast, .milkSolid:
                feedingCount += 1
                feedingMl += log.amount ?? 0
            case .sleep:
                if let endTime = log.endTime {
                    sleepMinutes += Int(endTime.timeIntervalSince(log.startTime) / 60)
                }
            case .diaperWet, .diaperDirty:
                diaperCount += 1
            case .bath, .none:
                break
            }
        }

        return DailyStats(
            feedingCount: feedingCount,
            feedingMl: feedingMl,
            sleepMinutes: sleepMinutes,
            diaperCount: diaperCount
        )
    }

    // MARK: - Timeline Helpers

    var sortedLogs: [PhysiologyLog] {
        let calendar = Calendar.current
        return physiologyLogs
            .filter { calendar.isDate($0.startTime, inSameDayAs: selectedDate) }
            .sorted { $0.startTime > $1.startTime }
    }

    func logsForHour(_ hour: Int) -> [PhysiologyLog] {
        let calendar = Calendar.current
        return physiologyLogs
            .filter { log in
                let logHour = calendar.component(.hour, from: log.startTime)
                return logHour == hour && calendar.isDate(log.startTime, inSameDayAs: selectedDate)
            }
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Date Navigation

    var canGoToNextDay: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    func goToPreviousDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }

    func goToNextDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate),
           newDate <= Date() {
            selectedDate = newDate
        }
    }

    // MARK: - Sleep/Wake Logic

    /// Get all unended sleep logs sorted by startTime descending (most recent first)
    var unendedSleepLogs: [PhysiologyLog] {
        physiologyLogs
            .filter { $0.type == .sleep && $0.endTime == nil }
            .sorted { $0.startTime > $1.startTime }
    }

    /// The most recent unended sleep (the only valid one)
    var activeSleepLog: PhysiologyLog? {
        unendedSleepLogs.first
    }

    /// Check if a sleep log is invalid (not the most recent unended sleep)
    func isInvalidSleep(_ log: PhysiologyLog) -> Bool {
        guard log.type == .sleep, log.endTime == nil else { return false }
        guard let activeSleep = activeSleepLog else { return false }
        return log.id != activeSleep.id
    }

    /// Whether there's an active sleep that can be ended
    var hasActiveSleep: Bool {
        activeSleepLog != nil
    }

    // MARK: - Quick Actions

    func recordWakeUp(at wakeUpTime: Date) {
        // Find the most recent unended sleep log
        guard let activeSleep = activeSleepLog,
              let index = physiologyLogs.firstIndex(where: { $0.id == activeSleep.id }) else {
            // No active sleep, just create a wake-up record
            let wakeUpLog = PhysiologyLog(
                id: UUID().uuidString,
                babyId: baby.id,
                type: .sleep,
                startTime: wakeUpTime,
                endTime: wakeUpTime,
                amount: nil,
                unit: nil,
                notes: "起床"
            )
            physiologyLogs.insert(wakeUpLog, at: 0)
            showingWakeUpSheet = false
            return
        }

        let originalLog = physiologyLogs[index]

        // Update the sleep log with end time
        physiologyLogs[index] = PhysiologyLog(
            id: originalLog.id,
            babyId: originalLog.babyId,
            type: originalLog.type,
            startTime: originalLog.startTime,
            endTime: wakeUpTime,
            amount: originalLog.amount,
            unit: originalLog.unit,
            notes: originalLog.notes
        )

        // Calculate sleep duration for the wake-up note
        let duration = Int(wakeUpTime.timeIntervalSince(originalLog.startTime) / 60)
        let hours = duration / 60
        let mins = duration % 60
        let durationStr = L10n.sleptForString(hours: hours, minutes: mins)

        // Create a new "wake up" record that shows in timeline
        let wakeUpLog = PhysiologyLog(
            id: UUID().uuidString,
            babyId: baby.id,
            type: .sleep,
            startTime: wakeUpTime,
            endTime: wakeUpTime,
            amount: nil,
            unit: nil,
            notes: durationStr
        )
        physiologyLogs.insert(wakeUpLog, at: 0)
        showingWakeUpSheet = false
    }

    func createLog(
        type: PhysiologyLogType,
        startTime: Date,
        endTime: Date?,
        amount: Double?,
        unit: PhysiologyLogUnit?,
        notes: String?
    ) async {
        isLoading = true
        error = nil

        let input = CreatePhysiologyLogInput(
            babyId: baby.id,
            familyOwners: baby.familyOwners,
            type: type.rawValue,
            startTime: Configuration.iso8601DateFormatter.string(from: startTime),
            endTime: endTime.map { Configuration.iso8601DateFormatter.string(from: $0) },
            amount: amount,
            unit: unit?.rawValue,
            notes: notes
        )

        do {
            let newLog = try await amplifyService.createPhysiologyLog(input)
            physiologyLogs.insert(newLog, at: 0)
            showingAddLog = false
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Add Log Locally (for mock mode)

    func addLogLocally(type: PhysiologyLogType, amount: Double?, notes: String?, startTime: Date? = nil) {
        let logTime = startTime ?? Date()
        let newLog = PhysiologyLog(
            id: UUID().uuidString,
            babyId: baby.id,
            type: type,
            startTime: logTime,
            endTime: nil,
            amount: amount,
            unit: amount != nil ? .ml : nil,
            notes: notes
        )
        physiologyLogs.insert(newLog, at: 0)
        showingAddLog = false
    }

    // MARK: - Edit Log

    func startEditingLog(_ log: PhysiologyLog) {
        editingLog = log
        showingEditLog = true
    }

    func updateLog(id: String, type: PhysiologyLogType, startTime: Date, amount: Double?, notes: String?) {
        guard let index = physiologyLogs.firstIndex(where: { $0.id == id }) else { return }

        let original = physiologyLogs[index]
        physiologyLogs[index] = PhysiologyLog(
            id: original.id,
            babyId: original.babyId,
            type: type,
            startTime: startTime,
            endTime: original.endTime,
            amount: amount,
            unit: amount != nil ? .ml : nil,
            notes: notes
        )
        editingLog = nil
        showingEditLog = false
    }

    // MARK: - Delete Log

    func deleteLog(_ log: PhysiologyLog) {
        physiologyLogs.removeAll { $0.id == log.id }
    }

    func deleteLog(at id: String) {
        physiologyLogs.removeAll { $0.id == id }
    }

    // MARK: - Vaccine (Context Event)

    func addVaccine(title: String, date: Date, notes: String?) {
        let event = ContextEvent(
            id: UUID().uuidString,
            babyId: baby.id,
            type: .vaccine,
            title: title,
            startDate: date,
            notes: notes
        )
        contextEvents.insert(event, at: 0)
        showingVaccineSheet = false
    }

    // MARK: - Growth Measurements

    func addGrowthMeasurement(type: GrowthMeasurementType, value: Double, date: Date, notes: String?) {
        let measurement = GrowthMeasurement(
            babyId: baby.id,
            type: type,
            value: value,
            measuredAt: date,
            notes: notes
        )
        growthMeasurements.insert(measurement, at: 0)
        showingGrowthSheet = false
    }

    func latestMeasurement(of type: GrowthMeasurementType) -> GrowthMeasurement? {
        growthMeasurements
            .filter { $0.type == type }
            .sorted { $0.measuredAt > $1.measuredAt }
            .first
    }

    func measurements(of type: GrowthMeasurementType) -> [GrowthMeasurement] {
        growthMeasurements
            .filter { $0.type == type }
            .sorted { $0.measuredAt < $1.measuredAt }
    }

    // MARK: - Custom Buttons

    func addCustomButton(name: String, icon: String, colorHex: String) {
        let button = CustomButton(name: name, icon: icon, colorHex: colorHex)
        customButtons.append(button)
        showingAddCustomButton = false
    }

    func addCustomLog(button: CustomButton, time: Date, notes: String?) {
        let log = PhysiologyLog(
            id: UUID().uuidString,
            babyId: baby.id,
            type: nil, // Custom type, no predefined enum
            startTime: time,
            endTime: nil,
            amount: nil,
            unit: nil,
            notes: "[\(button.name)] \(notes ?? "")"
        )
        physiologyLogs.insert(log, at: 0)
        showingCustomLogSheet = false
    }

    func deleteCustomButton(_ button: CustomButton) {
        customButtons.removeAll { $0.id == button.id }
    }
}

// MARK: - Custom Button Model

struct CustomButton: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String

    init(id: String = UUID().uuidString, name: String, icon: String, colorHex: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
}

// MARK: - Daily Stats

struct DailyStats {
    let feedingCount: Int
    let feedingMl: Double
    let sleepMinutes: Int
    let diaperCount: Int

    var sleepDurationString: String {
        let hours = sleepMinutes / 60
        let mins = sleepMinutes % 60
        return L10n.durationString(hours: hours, minutes: mins)
    }
}
