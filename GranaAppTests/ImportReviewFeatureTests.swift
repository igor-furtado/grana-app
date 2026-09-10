import ComposableArchitecture
import Foundation
import Testing
@testable import GranaApp

@MainActor
@Suite("ImportReviewFeature")
struct ImportReviewFeatureTests {
    @Test("Revisão combina drafts do plano com sugestões confirmadas")
    func reviewedRowsUsePlanDraftsAndCurrentSuggestions() throws {
        let categoryId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let subcategoryId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000102"))
        let draft = makeDraft()
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: categoryId,
            subcategoryId: subcategoryId
        )

        let state = ImportReviewFeature.State(
            plan: makePlan(drafts: [draft]),
            suggestions: [suggestion]
        )

        #expect(state.reviewedRows == [
            ReviewedImportRow(
                draft: draft,
                categoryId: categoryId,
                subcategoryId: subcategoryId
            ),
        ])
    }

    @Test("Aplicar correção propaga para sugestões com mesmo hash")
    func applyCorrectionPropagatesAcrossMatchingSuggestions() async {
        let oldCategoryId = UUID()
        let newCategoryId = UUID()
        let newSubcategoryId = UUID()
        let first = makeSuggestion(
            transactionId: UUID(),
            categoryId: oldCategoryId,
            subcategoryId: nil,
            descriptionHash: "same-hash",
            amount: 10
        )
        let second = makeSuggestion(
            transactionId: UUID(),
            categoryId: oldCategoryId,
            subcategoryId: nil,
            descriptionHash: "same-hash",
            amount: 20
        )

        let store = TestStore(
            initialState: ImportReviewFeature.State(
                plan: makePlan(drafts: []),
                suggestions: [first, second]
            )
        ) {
            ImportReviewFeature()
        }

        await store.send(.applyCorrection(index: 0, categoryId: newCategoryId, subcategoryId: newSubcategoryId)) {
            $0.suggestions[0].categoryId = newCategoryId
            $0.suggestions[0].subcategoryId = newSubcategoryId
            $0.suggestions[0].isReviewed = true
            $0.suggestions[1].categoryId = newCategoryId
            $0.suggestions[1].subcategoryId = newSubcategoryId
            $0.suggestions[1].isReviewed = true
        }
    }

    @Test("Correção para Transferências limpa subcategoria e bloqueia importação sem conta relacionada")
    func transferCorrectionClearsSubcategoryAndBlocksImportWithoutRelatedAccount() async {
        let expenseCategory = Category(
            id: UUID(),
            parentId: nil,
            name: "Alimentação",
            kind: .expense,
            slug: "alimentacao",
            createdAt: Date()
        )
        let transferCategory = Category(
            id: UUID(),
            parentId: nil,
            name: "Transferências",
            kind: .transfer,
            slug: "transferencias",
            createdAt: Date()
        )
        let draft = makeDraft()
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: expenseCategory.id,
            subcategoryId: UUID()
        )
        let store = TestStore(
            initialState: ImportReviewFeature.State(
                plan: makePlan(drafts: [draft]),
                suggestions: [suggestion],
                categories: [expenseCategory, transferCategory]
            )
        ) {
            ImportReviewFeature()
        }

        await store.send(.applyCorrection(index: 0, categoryId: transferCategory.id, subcategoryId: UUID())) {
            $0.suggestions[0].categoryId = transferCategory.id
            $0.suggestions[0].subcategoryId = nil
            $0.suggestions[0].isReviewed = true
        }

        #expect(store.state.canImport == false)
    }

    @Test("Transferência enviada usa conta do extrato como origem e seleção como destino")
    func outgoingTransferReviewedRowUsesSelectedDestination() throws {
        let originAccountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000401"))
        let destinationAccountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000402"))
        let transferCategory = Category(
            id: UUID(),
            parentId: nil,
            name: "Transferências",
            kind: .transfer,
            slug: "transferencias",
            createdAt: Date()
        )
        let draft = makeDraft(accountId: originAccountId, signedAmount: Decimal(-12))
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: transferCategory.id,
            subcategoryId: nil
        )
        var state = ImportReviewFeature.State(
            plan: makePlan(drafts: [draft]),
            suggestions: [suggestion],
            categories: [transferCategory],
            accounts: [
                makeAccount(id: originAccountId),
                makeAccount(id: destinationAccountId),
            ]
        )

        state.transferAccountSelections[draft.id] = destinationAccountId

        let row = try #require(state.reviewedRows.first)
        #expect(row.accountId == originAccountId)
        #expect(row.destinationAccountId == destinationAccountId)
        #expect(state.canImport)
    }

    @Test("Transferência recebida usa seleção como origem e conta do extrato como destino")
    func incomingTransferReviewedRowUsesSelectedOrigin() throws {
        let destinationAccountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000411"))
        let originAccountId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000412"))
        let transferCategory = Category(
            id: UUID(),
            parentId: nil,
            name: "Transferências",
            kind: .transfer,
            slug: "transferencias",
            createdAt: Date()
        )
        let draft = makeDraft(accountId: destinationAccountId, signedAmount: Decimal(12))
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: transferCategory.id,
            subcategoryId: nil
        )
        var state = ImportReviewFeature.State(
            plan: makePlan(drafts: [draft]),
            suggestions: [suggestion],
            categories: [transferCategory],
            accounts: [
                makeAccount(id: destinationAccountId),
                makeAccount(id: originAccountId),
            ]
        )

        state.transferAccountSelections[draft.id] = originAccountId

        let row = try #require(state.reviewedRows.first)
        #expect(row.accountId == originAccountId)
        #expect(row.destinationAccountId == destinationAccountId)
        #expect(state.canImport)
    }

    @Test("Conta relacionada de transferência não propaga por hash")
    func transferAccountSelectionDoesNotPropagateAcrossMatchingHashes() async {
        let transferCategory = Category(
            id: UUID(),
            parentId: nil,
            name: "Transferências",
            kind: .transfer,
            slug: "transferencias",
            createdAt: Date()
        )
        let firstDraft = makeDraft()
        let secondDraft = makeDraft()
        let selectedAccountId = UUID()
        let first = makeSuggestion(
            transactionId: firstDraft.id,
            categoryId: transferCategory.id,
            subcategoryId: nil,
            descriptionHash: "same-hash"
        )
        let second = makeSuggestion(
            transactionId: secondDraft.id,
            categoryId: transferCategory.id,
            subcategoryId: nil,
            descriptionHash: "same-hash"
        )
        let store = TestStore(
            initialState: ImportReviewFeature.State(
                plan: makePlan(drafts: [firstDraft, secondDraft]),
                suggestions: [first, second],
                categories: [transferCategory]
            )
        ) {
            ImportReviewFeature()
        }

        await store.send(.transferAccountChanged(index: 0, accountId: selectedAccountId)) {
            $0.transferAccountSelections[firstDraft.id] = selectedAccountId
        }
    }

    @Test("Revisão mantém Não Classificado no topo")
    func reviewOrderingKeepsFallbackRowsAtTop() {
        let earlier = Date(timeIntervalSince1970: 10)
        let later = Date(timeIntervalSince1970: 20)
        let fallback = makeSuggestion(
            transactionId: UUID(),
            categoryId: UUID(),
            subcategoryId: UUID(),
            descriptionHash: "fallback",
            source: .fallback,
            originalCategorySlug: nil,
            occurredAt: later,
            isReviewed: true
        )
        let regular = makeSuggestion(
            transactionId: UUID(),
            categoryId: UUID(),
            subcategoryId: nil,
            descriptionHash: "regular",
            description: "Uber",
            amount: 20,
            source: .granaAI,
            originalCategorySlug: "mobilidade",
            occurredAt: earlier
        )

        let orderedIndices = ImportReviewOrdering.orderedIndices(from: [regular, fallback])

        #expect(orderedIndices == [1, 0])
    }

    @Test("Wizard materializa revisão após classificação pronta")
    func wizardCreatesReviewStateAfterCategorizationReady() async {
        let draft = makeDraft()
        let plan = makePlan(drafts: [draft])
        let category = Category(
            id: UUID(),
            parentId: nil,
            name: "Não Classificado",
            kind: .expense,
            slug: "nao-classificado",
            createdAt: Date()
        )
        let account = Account(
            id: draft.accountId,
            type: .checking,
            initialBalance: 0,
            archived: false,
            institutionId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: category.id,
            subcategoryId: nil
        )

        let store = TestStore(
            initialState: ImportWizardFeature.State(
                pendingPlan: plan,
                categorization: ImportCategorizationFeature.State(
                    status: .ready(total: 1, fallback: 1),
                    suggestions: [suggestion],
                    categories: [category],
                    accounts: [account],
                    institutions: []
                )
            )
        ) {
            ImportWizardFeature()
        }

        await store.send(.categorization(.delegate(.ready))) {
            $0.review = ImportReviewFeature.State(
                plan: plan,
                suggestions: [suggestion],
                categories: [category],
                accounts: [account],
                institutions: []
            )
            $0.categorization = nil
            $0.pendingPlan = nil
            $0.phase = .reviewingCategorization
        }
    }

    @Test("Wizard transforma revisão concluída em feature de commit")
    func wizardCreatesCommitStateAfterFinalReview() async throws {
        let idempotencyKey = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000109"))
        let draft = makeDraft()
        let plan = makePlan(drafts: [draft])
        let category = Category(
            id: UUID(),
            parentId: nil,
            name: "Não Classificado",
            kind: .expense,
            slug: "nao-classificado",
            createdAt: Date()
        )
        let suggestion = makeSuggestion(
            transactionId: draft.id,
            categoryId: category.id,
            subcategoryId: nil
        )
        let review = ImportReviewFeature.State(
            plan: plan,
            suggestions: [suggestion],
            categories: [category],
            accounts: [],
            institutions: []
        )
        let commit = ReviewedImportCommit(
            idempotencyKey: idempotencyKey,
            reviewedRows: review.reviewedRows,
            pendingBatches: plan.batches,
            categories: [category],
            suggestions: [suggestion]
        )
        let store = TestStore(
            initialState: ImportWizardFeature.State(
                phase: .reviewingCategorization,
                review: review
            )
        ) {
            ImportWizardFeature()
        } withDependencies: {
            $0.uuid = .constant(idempotencyKey)
        }

        await store.send(.review(.importButtonTapped))

        await store.receive(.review(.delegate(.completed(commit))))

        await store.receive(.reviewCompleted(commit)) {
            $0.review = nil
            $0.commit = ImportCommitFeature.State(commit: commit)
            $0.phase = .confirming
        }
    }

    @Test("Wizard repassa conclusão da feature de commit")
    func wizardDelegatesCommitCompletion() async throws {
        let batchId = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000110"))
        let result = ImportCommitResult(
            batchIds: [batchId],
            importedRowCount: 3,
            duplicateRows: []
        )
        let commit = ReviewedImportCommit(
            idempotencyKey: UUID(),
            reviewedRows: [],
            pendingBatches: [],
            categories: [],
            suggestions: []
        )
        let store = TestStore(
            initialState: ImportWizardFeature.State(
                phase: .confirming,
                commit: ImportCommitFeature.State(commit: commit, status: .completed(result))
            )
        ) {
            ImportWizardFeature()
        }

        await store.send(.commit(.delegate(.completed(result)))) {
            $0.commit = nil
            $0.phase = .done(batchIds: [batchId], rowCount: 3)
        }

        await store.receive(.delegate(.completed))
    }

    private func makePlan(drafts: [TransactionDraft]) -> PendingImportPlan {
        PendingImportPlan(
            batches: [
                PendingImportBatch(
                    batch: ImportBatch(
                        id: UUID(),
                        sourceFilename: "extrato.ofx",
                        accountId: UUID(),
                        rowCount: drafts.count,
                        importedAt: Date(),
                        createdAt: Date(),
                        updatedAt: Date()
                    ),
                    importFormat: .ofx
                ),
            ],
            drafts: drafts,
            impact: ImportPlanImpact(
                importedRowCount: drafts.count,
                skippedDuplicateRowCount: 0,
                skippedDeselectedRowCount: 0,
                statementBalanceDraftCount: 0
            )
        )
    }

    private func makeDraft(
        accountId: UUID = UUID(),
        signedAmount: Decimal = Decimal(-12)
    ) -> TransactionDraft {
        TransactionDraft(
            id: UUID(),
            accountId: accountId,
            importBatchId: UUID(),
            signedAmount: signedAmount,
            occurredAt: Date(),
            description: "Padaria",
            notes: nil,
            externalId: "FIT-1"
        )
    }

    private func makeAccount(
        id: UUID,
        archived: Bool = false
    ) -> Account {
        Account(
            id: id,
            type: .checking,
            initialBalance: 0,
            archived: archived,
            institutionId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeSuggestion(
        transactionId: UUID,
        categoryId: UUID,
        subcategoryId: UUID?,
        descriptionHash: String = "hash",
        description: String = "Padaria",
        amount: Decimal = Decimal(12),
        source: CategorizationSuggestion.Source = .fallback,
        originalCategorySlug: String? = nil,
        occurredAt: Date = Date(),
        isReviewed: Bool = false
    ) -> CategorizationSuggestion {
        CategorizationSuggestion(
            id: UUID(),
            transactionId: transactionId,
            descriptionHash: descriptionHash,
            normalizedDescription: description.lowercased(),
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            source: source,
            originalCategoryId: nil,
            originalSubcategoryId: nil,
            originalCategorySlug: originalCategorySlug,
            originalSubcategoryName: nil,
            transactionDescription: description,
            transactionAmount: amount,
            transactionOccurredAt: occurredAt,
            transactionAccountId: UUID(),
            transactionNotes: nil,
            transactionDestinationAccountId: nil,
            isReviewed: isReviewed
        )
    }
}
