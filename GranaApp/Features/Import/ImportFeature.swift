import ComposableArchitecture
import Foundation

@Reducer
struct ImportFeature {
    @ObservableState
    struct State: Equatable {
        var history = ImportHistoryFeature.State()
        var wizard: ImportWizardFeature.State?
    }

    enum Action: Equatable {
        case history(ImportHistoryFeature.Action)
        case wizard(ImportWizardFeature.Action)
        case globalFileDrop([URL])
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case financialDataChanged
    }

    @Dependency(\.noticeClient) private var noticeClient

    var body: some Reducer<State, Action> {
        Scope(state: \.history, action: \.history) {
            ImportHistoryFeature()
        }
        Reduce { state, action in
            switch action {
            case let .globalFileDrop(urls):
                switch ImportDropPolicy.evaluate(
                    urls: urls,
                    supportedExtensions: ImportWizardFeature.State.supportedExtensions,
                    isImportInProgress: state.wizard != nil
                ) {
                case .ignore:
                    return .none

                case let .rejectUnsupported(extensionLabel):
                    return .run { _ in
                        await noticeClient.report(
                            ImportError.unsupportedFormat(extension: extensionLabel),
                            "Arquivo não suportado"
                        )
                    }

                case .rejectImportInProgress:
                    return .run { _ in
                        await noticeClient.info(
                            "Importação em andamento",
                            "Conclua ou cancele o arquivo atual antes de iniciar outra importação."
                        )
                    }

                case let .accept(url, droppedMultipleFiles):
                    state.wizard = ImportWizardFeature.State(initialFile: url)
                    guard droppedMultipleFiles else { return .none }
                    return .run { _ in
                        await noticeClient.info(
                            "Vários arquivos soltos",
                            "Importe um por vez. Abrindo \"\(url.lastPathComponent)\"."
                        )
                    }
                }

            case let .history(.delegate(.startImport(file))):
                state.wizard = ImportWizardFeature.State(initialFile: file)
                return .none

            case .wizard(.delegate(.close)):
                state.wizard = nil
                return .none

            case .wizard(.delegate(.completed)):
                state.wizard = nil
                return .merge(
                    .send(.delegate(.financialDataChanged)),
                    .send(.history(.refresh))
                )

            case .wizard(.delegate(.presentFileImporter)):
                return .none

            case .history, .wizard, .delegate:
                return .none
            }
        }
        .ifLet(\.wizard, action: \.wizard) {
            ImportWizardFeature()
        }
    }
}
