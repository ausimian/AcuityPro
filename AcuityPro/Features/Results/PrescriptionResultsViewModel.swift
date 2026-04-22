import SwiftUI

@MainActor
final class PrescriptionResultsViewModel: ObservableObject {
    @Published var prescription: FullPrescription?

    private let coordinator: RefractionCoordinatorViewModel

    init(coordinator: RefractionCoordinatorViewModel) {
        self.coordinator = coordinator
        coordinator.computeFinalPrescription()
        self.prescription = coordinator.prescription
    }

    var shareSummary: String {
        prescription?.shareSummary ?? ""
    }

    func testAgain() {
        coordinator.resetTest()
    }
}
