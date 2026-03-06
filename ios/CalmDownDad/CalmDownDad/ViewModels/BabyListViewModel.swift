import Foundation
import SwiftUI
import Combine

@MainActor
class BabyListViewModel: ObservableObject {
    @Published var babies: [Baby] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingAddBaby = false

    private let amplifyService = AmplifyService.shared

    func loadBabies() async {
        isLoading = true
        error = nil

        do {
            babies = try await amplifyService.listBabies()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func createBaby(name: String, birthDate: Date, gender: BabyGender?, notes: String?) async {
        isLoading = true
        error = nil

        let input = CreateBabyInput(
            familyId: "default-family",
            name: name,
            birthDate: Configuration.dateOnlyFormatter.string(from: birthDate),
            gender: gender?.rawValue,
            notes: notes,
            familyOwners: nil
        )

        do {
            let newBaby = try await amplifyService.createBaby(input)
            babies.insert(newBaby, at: 0)
            showingAddBaby = false
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func deleteBaby(_ baby: Baby) async {
        do {
            try await amplifyService.deleteBaby(id: baby.id)
            babies.removeAll { $0.id == baby.id }
        } catch {
            self.error = error
        }
    }
}
