import Foundation

/// Fatura de cartão de crédito.
///
/// Criada **lazy** pelo backend com as datas padrão vigentes no cartão quando
/// uma transação entra. Depois de criada, a fatura tem `closingDate` e
/// `dueDate` próprios: editar essas datas altera a fatura específica, não a
/// configuração padrão do cartão.
///
/// Os valores financeiros são lidos como projeções calculáveis a partir de
/// transações e pagamentos. `creditReceived` permanece no contrato por
/// compatibilidade, mas saldo automático entre faturas não é mais regra
/// de domínio.
struct Statement: Identifiable, Codable, Hashable {
    let id: UUID
    let accountId: UUID
    let closingDate: Date
    let dueDate: Date
    /// Compras menos créditos do próprio ciclo. Pode ser negativo.
    var netAmount: Decimal
    /// Crédito explícito/legado informado pelo backend, sem propagação automática.
    var creditReceived: Decimal
    /// Soma das transferências aplicadas à fatura.
    var paymentApplied: Decimal
    /// Data efetiva em que uma fatura fechada ficou integralmente coberta.
    var settledAt: Date?
    let createdAt: Date
    var updatedAt: Date

    var totalAmount: Decimal {
        max(0, netAmount - creditReceived)
    }

    var creditBalance: Decimal {
        max(0, -netAmount)
    }

    var paymentExcess: Decimal {
        max(0, paymentApplied - totalAmount)
    }

    var remainingAmount: Decimal {
        max(0, totalAmount - paymentApplied)
    }

    func status(referenceDate: Date = Date(), calendar: Calendar = .current) -> StatementStatus {
        guard calendar.startOfDay(for: referenceDate) > calendar.startOfDay(for: closingDate) else {
            return .forming
        }
        guard remainingAmount == 0, totalAmount > 0 else {
            return .closed
        }
        return creditReceived == 0 && creditBalance == 0 ? .paid : .settled
    }
}

enum StatementStatus: String, Codable, Hashable {
    case forming
    case closed
    case paid
    case settled

    var displayName: String {
        switch self {
        case .forming: "Em formação"
        case .closed: "Fechada"
        case .paid: "Paga"
        case .settled: "Quitada"
        }
    }
}

/// Aplicação de uma transferência sobre uma Fatura. Modela o N:N — uma
/// transferência pode aplicar a 1+ Faturas (split), uma Fatura pode receber
/// 1+ transferências (adiantamento). Cada linha registra **quanto** desta
/// transferência foi aplicado a esta Fatura específica.
///
/// A soma dos `appliedAmount` de payments com mesmo `transactionId` não deve
/// exceder `transactions.amount` daquela transferência. Validado no backend.
struct StatementPayment: Identifiable, Codable, Hashable {
    let id: UUID
    let statementId: UUID
    let transactionId: UUID
    /// Valor da transferência aplicado a esta Fatura (magnitude positiva).
    var appliedAmount: Decimal
    let createdAt: Date
    var updatedAt: Date
}

/// Aplicação explícita/legada de crédito entre faturas. O fluxo atual não cria
/// saldo automático entre faturas.
struct StatementCreditApplication: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceStatementId: UUID
    let destinationStatementId: UUID
    let appliedAmount: Decimal
    let createdAt: Date
}
