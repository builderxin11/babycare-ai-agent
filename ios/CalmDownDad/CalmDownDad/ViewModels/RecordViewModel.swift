import Foundation
import SwiftUI
import Combine

@MainActor
class RecordViewModel: ObservableObject {
    @Published var baby: Baby
    @Published var selectedDate: Date = Date()
    @Published var physiologyLogs: [PhysiologyLog] = []
    @Published var isLoading = false
    @Published var error: Error?

    @Published var showingAddLog = false
    @Published var selectedLogType: PhysiologyLogType = .milkFormula

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
            case .none:
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

    func activitiesForHour(_ hour: Int) -> [PhysiologyLog] {
        let calendar = Calendar.current
        return physiologyLogs.filter { log in
            let logHour = calendar.component(.hour, from: log.startTime)
            return logHour == hour && calendar.isDate(log.startTime, inSameDayAs: selectedDate)
        }
    }

    // MARK: - Quick Actions

    func recordWakeUp() {
        // Find the most recent sleep log and set its end time
        if let lastSleep = physiologyLogs.first(where: { $0.type == .sleep && $0.endTime == nil }) {
            // TODO: Update the sleep log with end time
            Task {
                await loadData()
            }
        }
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
        return "\(hours)小时\(mins)分钟"
    }
}
