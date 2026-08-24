import Foundation
import Observation

/// Estado observável da revisão de classificação durante a importação.
///
/// O GranaApp não executa categorização remota. O fluxo local cria sugestões
/// fallback em "Não Classificado" para que o usuário revise e escolha a
/// categoria final antes do commit.
@MainActor
@Observable
final class CategorizationStore {
    enum Status: Equatable {
        case idle
        case classifying(processed: Int, total: Int, message: String)
        case ready(total: Int, fallback: Int)
        case failed(message: String)
    }

    private let container: AppContainer

    private(set) var status: Status = .idle
    private(set) var suggestions: [CategorizationSuggestion] = []
    private(set) var categories: [Category] = []
    private(set) var accounts: [Account] = []
    private(set) var institutions: [Institution] = []

    private var currentTask: Task<Void, Never>?

    init(container: AppContainer) {
        self.container = container
    }

    func loadCategories() async {
        do {
            async let cats = container.categoryCatalog.load()
            async let accountSnapshot = container.remoteAccounts.load()
            async let insts = container.institutionCatalog.load()
            let (loadedCategories, snapshot, loadedInstitutions) = try await (
                cats,
                accountSnapshot,
                insts
            )
            categories = loadedCategories
            accounts = snapshot.accounts
            institutions = loadedInstitutions
        } catch {
            NoticeCenter.shared.report(error)
        }
    }

    var rootCategories: [Category] {
        categories.filter { $0.parentId == nil }
    }

    func subcategories(of parentId: UUID) -> [Category] {
        categories.filter { $0.parentId == parentId }
    }

    func category(for id: UUID) -> Category? {
        categories.first { $0.id == id }
    }

    func institutionKind(forAccountId accountId: UUID) -> InstitutionKind? {
        guard let account = accounts.first(where: { $0.id == accountId }),
              let institutionId = account.institutionId,
              let institution = institutions.first(where: { $0.id == institutionId })
        else { return nil }
        return institution.kind
    }

    func classifyDrafts(_ drafts: [TransactionDraft]) {
        cancel()
        status = .classifying(processed: 0, total: drafts.count, message: "Preparando classificação…")
        suggestions = []

        let service = container.categorization
        currentTask = Task { [weak self] in
            do {
                let result = try await service.classifyDrafts(
                    drafts,
                    progress: { progress in
                        Task { @MainActor in
                            self?.handle(progress: progress)
                        }
                    }
                )
                self?.suggestions = result.suggestions
            } catch is CancellationError {
                self?.status = .idle
            } catch {
                self?.handleCategorizationFailure(error)
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    func waitForCompletion() async {
        await currentTask?.value
    }

    func confirm(at index: Int) async {
        guard suggestions.indices.contains(index) else { return }
        suggestions[index].isReviewed = true
    }

    func confirmAll() async {
        let pending = suggestions.indices.filter { !suggestions[$0].isReviewed }
        for index in pending {
            await confirm(at: index)
        }
    }

    func applyCorrection(
        at index: Int,
        correctedCategoryId: UUID,
        correctedSubcategoryId: UUID?
    ) async {
        guard suggestions.indices.contains(index) else { return }
        let hash = suggestions[index].descriptionHash
        propagateCorrectionInMemory(
            matchingHash: hash,
            categoryId: correctedCategoryId,
            subcategoryId: correctedSubcategoryId
        )
    }

    private func propagateCorrectionInMemory(
        matchingHash hash: String,
        categoryId: UUID,
        subcategoryId: UUID?
    ) {
        for idx in suggestions.indices where suggestions[idx].descriptionHash == hash {
            suggestions[idx].categoryId = categoryId
            suggestions[idx].subcategoryId = subcategoryId
            suggestions[idx].isReviewed = true
        }
    }

    func resolvedCategory(forTransactionId id: UUID) -> (categoryId: UUID, subcategoryId: UUID?)? {
        guard let suggestion = suggestions.first(where: { $0.transactionId == id }) else { return nil }
        return (suggestion.categoryId, suggestion.subcategoryId)
    }

    private func handle(progress: CategorizationService.Progress) {
        switch progress {
        case let .started(total):
            status = .classifying(processed: 0, total: total, message: "Preparando classificação…")
        case let .finished(total, fallback):
            status = .ready(total: total, fallback: fallback)
        case let .failed(error):
            status = .failed(message: error.localizedDescription)
        }
    }

    private func handleCategorizationFailure(_ error: Error) {
        status = .failed(message: error.localizedDescription)
        NoticeCenter.shared.report(error, title: "Falha ao classificar")
    }
}
