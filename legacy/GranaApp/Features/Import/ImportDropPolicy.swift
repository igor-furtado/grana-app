import Foundation

enum ImportDropPolicy {
    static func evaluate(
        urls: [URL],
        supportedExtensions: Set<String>,
        isImportInProgress: Bool
    ) -> ImportDropDecision {
        guard !urls.isEmpty else { return .ignore }
        guard !isImportInProgress else { return .rejectImportInProgress }

        let first = urls[0]
        let ext = first.pathExtension.lowercased()
        let extensionLabel = ext.isEmpty ? "(sem extensão)" : ext
        guard supportedExtensions.contains(ext) else {
            return .rejectUnsupported(extensionLabel: extensionLabel)
        }

        return .accept(first, droppedMultipleFiles: urls.count > 1)
    }
}

enum ImportDropDecision: Equatable {
    case ignore
    case rejectUnsupported(extensionLabel: String)
    case rejectImportInProgress
    case accept(URL, droppedMultipleFiles: Bool)

    var acceptsDrop: Bool {
        if case .accept = self {
            return true
        }
        return false
    }
}
