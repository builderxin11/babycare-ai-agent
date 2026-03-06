import Foundation
import SwiftUI
import Combine

// MARK: - Quick Button Type

enum QuickButtonType: String, CaseIterable, Identifiable, Codable {
    case formulaMilk = "formula_milk"
    case sleep = "sleep"
    case wakeUp = "wake_up"
    case dirtyDiaper = "dirty_diaper"
    case bath = "bath"
    case vaccine = "vaccine"
    case solidFood = "solid_food"
    case breastMilk = "breast_milk"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .formulaMilk: return L10n.formulaMilk
        case .sleep: return L10n.sleep
        case .wakeUp: return L10n.wakeUp
        case .dirtyDiaper: return L10n.dirtyDiaper
        case .bath: return L10n.bath
        case .vaccine: return L10n.vaccine
        case .solidFood: return L10n.solidFood
        case .breastMilk: return L10n.breastMilk
        }
    }

    var icon: String {
        switch self {
        case .formulaMilk: return "cup.and.saucer.fill"
        case .sleep: return "moon.zzz.fill"
        case .wakeUp: return "sun.horizon.fill"
        case .dirtyDiaper: return "drop.fill"
        case .bath: return "bathtub.fill"
        case .vaccine: return "syringe.fill"
        case .solidFood: return "leaf.fill"
        case .breastMilk: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .formulaMilk: return AppTheme.feedingColor
        case .sleep: return AppTheme.sleepColor
        case .wakeUp: return AppTheme.orange
        case .dirtyDiaper: return AppTheme.diaperColor
        case .bath: return AppTheme.bathColor
        case .vaccine: return AppTheme.vaccineColor
        case .solidFood: return AppTheme.solidFoodColor
        case .breastMilk: return AppTheme.breastMilkColor
        }
    }

    var logType: PhysiologyLogType? {
        switch self {
        case .formulaMilk: return .milkFormula
        case .sleep: return .sleep
        case .wakeUp: return nil // Special handling
        case .dirtyDiaper: return .diaperDirty
        case .bath: return .bath
        case .vaccine: return nil // Special handling
        case .solidFood: return .milkSolid
        case .breastMilk: return .milkBreast
        }
    }
}

// MARK: - Button Order Manager

@MainActor
class ButtonOrderManager: ObservableObject {
    static let shared = ButtonOrderManager()

    @Published var buttonOrder: [QuickButtonType] {
        didSet {
            saveOrder()
        }
    }

    private let storageKey = "quick_button_order"

    private init() {
        // Load saved order or use default
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedOrder = try? JSONDecoder().decode([QuickButtonType].self, from: data) {
            // Make sure all button types are included (in case new ones were added)
            var order = savedOrder
            for buttonType in QuickButtonType.allCases {
                if !order.contains(buttonType) {
                    order.append(buttonType)
                }
            }
            buttonOrder = order
        } else {
            buttonOrder = QuickButtonType.allCases
        }
    }

    private func saveOrder() {
        if let data = try? JSONEncoder().encode(buttonOrder) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func moveButton(from source: IndexSet, to destination: Int) {
        buttonOrder.move(fromOffsets: source, toOffset: destination)
    }

    func resetToDefault() {
        buttonOrder = QuickButtonType.allCases
    }
}
