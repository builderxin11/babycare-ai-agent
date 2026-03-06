import Foundation
import SwiftUI
import Combine

@MainActor
class BabyDetailViewModel: ObservableObject {
    @Published var baby: Baby
    @Published var physiologyLogs: [PhysiologyLog] = []
    @Published var contextEvents: [ContextEvent] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingAddLog = false
    @Published var showingAddEvent = false

    private let amplifyService = AmplifyService.shared

    init(baby: Baby) {
        self.baby = baby
    }

    func loadData() async {
        isLoading = true
        error = nil

        do {
            async let logs = amplifyService.listPhysiologyLogs(babyId: baby.id, limit: 20)
            async let events = amplifyService.listContextEvents(babyId: baby.id, limit: 10)

            let (loadedLogs, loadedEvents) = try await (logs, events)
            physiologyLogs = loadedLogs
            contextEvents = loadedEvents
        } catch {
            self.error = error
        }

        isLoading = false
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

    func createEvent(
        type: ContextEventType,
        title: String,
        startDate: Date,
        endDate: Date?,
        notes: String?
    ) async {
        isLoading = true
        error = nil

        let input = CreateContextEventInput(
            babyId: baby.id,
            familyOwners: baby.familyOwners,
            type: type.rawValue,
            title: title,
            startDate: Configuration.dateOnlyFormatter.string(from: startDate),
            endDate: endDate.map { Configuration.dateOnlyFormatter.string(from: $0) },
            metadata: nil,
            notes: notes
        )

        do {
            let newEvent = try await amplifyService.createContextEvent(input)
            contextEvents.insert(newEvent, at: 0)
            showingAddEvent = false
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Timeline Grouping

    var groupedLogs: [(date: Date, logs: [PhysiologyLog])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: physiologyLogs) { log in
            calendar.startOfDay(for: log.startTime)
        }
        return grouped
            .map { (date: $0.key, logs: $0.value.sorted { $0.startTime > $1.startTime }) }
            .sorted { $0.date > $1.date }
    }

    var recentEvents: [ContextEvent] {
        contextEvents.prefix(5).map { $0 }
    }
}
