import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("SupportedInstitutionsFeature")
struct SupportedInstitutionsFeatureTests {
    @Test("Carrega o catálogo na primeira task")
    func loadsInstitutionsOnFirstTask() async {
        let institutions = [
            Institution.fixture(name: "Inter"),
            Institution.fixture(name: "Nubank"),
        ]

        let store = TestStore(initialState: SupportedInstitutionsFeature.State()) {
            SupportedInstitutionsFeature()
        } withDependencies: {
            $0.supportedInstitutionsClient.load = { institutions }
        }

        await store.send(.task) {
            $0.isLoading = true
        }

        await store.receive(.snapshotLoaded(.success(institutions))) {
            $0.institutions = institutions
            $0.isLoading = false
            $0.hasLoaded = true
            $0.loadErrorMessage = nil
        }
    }

    @Test("Refresh propaga erro e limpa estado carregado")
    func refreshSurfacesError() async {
        let error = SupportedInstitutionsFeatureTestError.unauthorized
        let store = TestStore(initialState: SupportedInstitutionsFeature.State()) {
            SupportedInstitutionsFeature()
        } withDependencies: {
            $0.supportedInstitutionsClient.load = {
                throw error
            }
            $0.noticeClient.report = { reportedError, _ in
                #expect(reportedError is SupportedInstitutionsFeatureTestError)
            }
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }

        await store.receive(.snapshotLoaded(.failure(error))) {
            $0.institutions = []
            $0.isLoading = false
            $0.hasLoaded = false
            $0.loadErrorMessage = error.localizedDescription
        }
    }
}

private enum SupportedInstitutionsFeatureTestError: LocalizedError {
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Sessão expirada"
        }
    }
}
