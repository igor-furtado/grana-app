import SwiftUI
import Testing
@testable import GranaApp

@Suite("Shell autenticado")
struct AppShellStoreTests {
    @MainActor
    @Test("Monta a seção inicial imediatamente")
    func mountsInitialSection() {
        let store = AppShellStore(initialSection: .creditCards)

        #expect(store.isMounted(.creditCards))
        #expect(!store.isMounted(.transactions))
    }

    @MainActor
    @Test("Preserva branches já visitadas ao ativar outra seção")
    func keepsMountedBranchesAfterSwitching() {
        let store = AppShellStore(initialSection: .dashboard)

        store.activate(.transactions)

        #expect(store.isMounted(.dashboard))
        #expect(store.isMounted(.transactions))
    }

    @MainActor
    @Test("Entrega a mesma branch para leituras repetidas")
    func returnsStableBranchInstances() {
        let store = AppShellStore(initialSection: .dashboard)

        let first = store.branch(for: .accounts)
        let second = store.branch(for: .accounts)

        #expect(first === second)
    }

    @MainActor
    @Test("Preserva o path já montado ao alternar de seção")
    func preservesBranchPathAcrossSectionSwitches() {
        let store = AppShellStore(initialSection: .dashboard)
        let transactions = store.branch(for: .transactions)

        store.activate(.transactions)
        transactions.path.append("detalhe")
        store.activate(.accounts)

        #expect(store.branch(for: .transactions).path.count == 1)
    }
}
