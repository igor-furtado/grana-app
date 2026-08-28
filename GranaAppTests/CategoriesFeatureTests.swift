import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("CategoriesFeature")
struct CategoriesFeatureTests {
    @Test("Carrega categorias e seleciona a primeira raiz em ordem alfabética")
    func loadsCategoriesAndSelectsFirstRoot() async {
        let food = makeCategory(name: "Alimentação", slug: "alimentacao", kind: .expense)
        let child = makeSubcategory(name: "Padaria", parentId: food.id, kind: .expense)
        let salary = makeCategory(name: "Salário", slug: "salario", kind: .income)

        let store = TestStore(initialState: CategoriesFeature.State()) {
            CategoriesFeature()
        } withDependencies: {
            $0.categoriesClient.loadCategories = { [child, salary, food] }
        }

        await store.send(.task) {
            $0.isLoading = true
        }

        await store.receive(.categoriesLoaded([child, salary, food])) {
            $0.categories = [child, salary, food]
            $0.isLoading = false
            $0.hasLoaded = true
            $0.selectedId = food.id
        }
    }

    @Test("Refresh troca a seleção quando a raiz escolhida some do catálogo")
    func refreshReselectsWhenSelectionDisappears() async {
        let groceries = makeCategory(name: "Compras", slug: "compras", kind: .expense)
        let transport = makeCategory(name: "Transporte", slug: "transporte", kind: .expense)
        let utilities = makeCategory(name: "Utilidades", slug: "utilidades", kind: .expense)

        let store = TestStore(
            initialState: CategoriesFeature.State(
                categories: [groceries, transport],
                isLoading: false,
                hasLoaded: true,
                selectedId: transport.id,
                loadErrorMessage: nil
            )
        ) {
            CategoriesFeature()
        } withDependencies: {
            $0.categoriesClient.loadCategories = { [utilities] }
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }

        await store.receive(.categoriesLoaded([utilities])) {
            $0.categories = [utilities]
            $0.isLoading = false
            $0.hasLoaded = true
            $0.selectedId = utilities.id
        }
    }

    @Test("Refresh com erro mantém snapshot anterior e expõe mensagem")
    func refreshFailureKeepsPreviousSnapshot() async {
        let income = makeCategory(name: "Salário", slug: "salario", kind: .income)

        let store = TestStore(
            initialState: CategoriesFeature.State(
                categories: [income],
                isLoading: false,
                hasLoaded: true,
                selectedId: income.id,
                loadErrorMessage: nil
            )
        ) {
            CategoriesFeature()
        } withDependencies: {
            $0.categoriesClient.loadCategories = {
                throw CategoriesTestFailure.offline
            }
            $0.noticeClient.report = { _, _ in }
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }

        await store.receive(.loadFailed(CategoriesTestFailure.offline.localizedDescription)) {
            $0.isLoading = false
            $0.loadErrorMessage = CategoriesTestFailure.offline.localizedDescription
        }
    }
}

private func makeCategory(
    name: String,
    slug: String,
    kind: CategoryKind
) -> Category {
    Category(
        id: UUID(),
        parentId: nil,
        name: name,
        kind: kind,
        slug: slug,
        createdAt: Date()
    )
}

private func makeSubcategory(
    name: String,
    parentId: UUID,
    kind: CategoryKind
) -> Category {
    Category(
        id: UUID(),
        parentId: parentId,
        name: name,
        kind: kind,
        slug: nil,
        createdAt: Date()
    )
}

private enum CategoriesTestFailure: LocalizedError {
    case offline

    var errorDescription: String? {
        switch self {
        case .offline:
            "Sem conexão"
        }
    }
}
