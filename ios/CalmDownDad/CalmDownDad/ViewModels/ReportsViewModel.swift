import Foundation
import SwiftUI
import Combine

@MainActor
class ReportsViewModel: ObservableObject {
    @Published var baby: Baby
    @Published var reports: [DailyReport] = []
    @Published var selectedReport: DailyReport?
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var error: Error?

    private let agentService = AgentAPIService.shared

    init(baby: Baby) {
        self.baby = baby
    }

    func generateReport(for date: Date = Date()) async {
        isGenerating = true
        error = nil

        do {
            let report = try await agentService.generateReport(baby: baby, date: date)
            if let existingIndex = reports.firstIndex(where: { $0.reportDateString == report.reportDateString }) {
                reports[existingIndex] = report
            } else {
                reports.insert(report, at: 0)
            }
            selectedReport = report
        } catch {
            self.error = error
        }

        isGenerating = false
    }

    func selectReport(_ report: DailyReport) {
        selectedReport = report
    }

    func clearSelection() {
        selectedReport = nil
    }

    var todayReport: DailyReport? {
        let today = Configuration.dateOnlyFormatter.string(from: Date())
        return reports.first { $0.reportDateString == today }
    }

    var hasTodayReport: Bool {
        todayReport != nil
    }

    var sortedReports: [DailyReport] {
        reports.sorted { $0.reportDate > $1.reportDate }
    }
}
