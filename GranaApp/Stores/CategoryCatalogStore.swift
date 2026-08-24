import Foundation
import Observation

@MainActor
@Observable
final class CategoryCatalogStore {
    private let container: AppContainer

    private(set) var categories: [Category] = []
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
            categories = try await container.categoryCatalog.load()
            hasLoaded = true
        } catch {
            loadError = error
            NoticeCenter.shared.report(error)
        }
    }
}
