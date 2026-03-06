import Foundation
import SwiftUI
import Combine

/// Shared storage for growth measurements that persists across view switches
@MainActor
class GrowthDataStore: ObservableObject {
    static let shared = GrowthDataStore()

    @Published var measurements: [GrowthMeasurement] = []

    private init() {}

    func addMeasurement(_ measurement: GrowthMeasurement) {
        measurements.append(measurement)
    }

    func measurements(of type: GrowthMeasurementType) -> [GrowthMeasurement] {
        measurements
            .filter { $0.type == type }
            .sorted { $0.measuredAt < $1.measuredAt }
    }

    func latestMeasurement(of type: GrowthMeasurementType) -> GrowthMeasurement? {
        measurements(of: type).last
    }
}
