import Foundation
import Observation

@MainActor
@Observable
final class InstitutionCatalogStore {
    private let container: AppContainer

    private(set) var institutions: [Institution] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var loadError: Error?

    init(container: AppContainer) {
        self.container = container
    }

    func load() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            loadError = nil
            institutions = try await container.institutionCatalog.load()
            hasLoaded = true
        } catch {
            loadError = error
            NoticeCenter.shared.report(error)
        }
    }
}
