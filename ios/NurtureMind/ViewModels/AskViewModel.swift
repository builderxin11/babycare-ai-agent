import Foundation
import SwiftUI
import Combine

@MainActor
class AskViewModel: ObservableObject {
    @Published var babies: [Baby] = []
    @Published var selectedBaby: Baby?
    @Published var question: String = ""
    @Published var advice: ParentingAdvice?
    @Published var isLoading = false
    @Published var isLoadingBabies = false
    @Published var error: Error?

    private let amplifyService = AmplifyService.shared
    private let agentService = AgentAPIService.shared

    var canAsk: Bool {
        selectedBaby != nil && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadBabies() async {
        isLoadingBabies = true

        do {
            babies = try await amplifyService.listBabies()
            if selectedBaby == nil, let first = babies.first {
                selectedBaby = first
            }
        } catch {
            self.error = error
        }

        isLoadingBabies = false
    }

    func askAgent() async {
        guard let baby = selectedBaby else {
            error = AskError.noBabySelected
            return
        }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            error = AskError.emptyQuestion
            return
        }

        isLoading = true
        error = nil
        advice = nil

        do {
            advice = try await agentService.askAgent(question: trimmedQuestion, baby: baby)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func clearAdvice() {
        advice = nil
        question = ""
    }
}

// MARK: - Errors

enum AskError: LocalizedError {
    case noBabySelected
    case emptyQuestion

    var errorDescription: String? {
        switch self {
        case .noBabySelected:
            return "Please select a baby first"
        case .emptyQuestion:
            return "Please enter a question"
        }
    }
}

// MARK: - Sample Questions

extension AskViewModel {
    static let sampleQuestions = [
        "Why is my baby sleeping less than usual?",
        "Is it normal for my baby to have reduced appetite after vaccination?",
        "How can I help my baby with jet lag?",
        "What are the signs of teething I should look for?",
        "How much should my baby be eating at this age?"
    ]
}
