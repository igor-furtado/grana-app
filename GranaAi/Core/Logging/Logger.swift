import Foundation
import OSLog

/// Logger global do app, com categorias separadas. Por que `os.Logger` (Apple):
/// - Roda em produção sem custo (formatação lazy).
/// - Aparece no Console.app filtrado por subsystem/category — útil pra debug.
/// - Não precisa de dependência externa.
///
/// Uso: `log.database.info("texto")`, `log.sync.error("...")`.
struct Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.granaai.app"

    let database = Logger(subsystem: subsystem, category: "database")
    let sync = Logger(subsystem: subsystem, category: "sync")
    let network = Logger(subsystem: subsystem, category: "network")
    let ui = Logger(subsystem: subsystem, category: "ui")
    let ai = Logger(subsystem: subsystem, category: "ai")
    let `import` = Logger(subsystem: subsystem, category: "import")
}

/// Instância global. Não é singleton com estado — é apenas um agrupador de
/// `Logger`s, que são leves e thread-safe por design.
let log = Log()
