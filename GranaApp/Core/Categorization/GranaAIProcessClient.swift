import Foundation

final nonisolated class GranaAIProcessClient: GranaAIClassificationClientProtocol {
    private let executableURL: URL
    private let timeout: Duration

    init(executableURL: URL, timeout: Duration = .seconds(8)) {
        self.executableURL = executableURL
        self.timeout = timeout
    }

    static func defaultIfAvailable(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> GranaAIProcessClient? {
        if let path = environment["GRANA_AI_EXECUTABLE_PATH"], !path.isEmpty {
            return GranaAIProcessClient(executableURL: URL(fileURLWithPath: path))
        }

        if let bundledURL = Bundle.main.url(forAuxiliaryExecutable: "grana-ai") {
            return GranaAIProcessClient(executableURL: bundledURL)
        }

        return nil
    }

    func classify(_ request: GranaAIClassificationRequest) async throws -> GranaAIClassificationResponse {
        let input = try JSONEncoder().encode(request)
        let output = try await runProcess(
            arguments: [],
            input: input,
            requiresOutput: true
        )

        return try decodeResponse(output)
    }

    func learn(_ request: GranaAIClassificationLearningRequest) async throws {
        let input = try JSONEncoder().encode(request)
        _ = try await runProcess(
            arguments: ["learn"],
            input: input,
            requiresOutput: false
        )
    }

    private func decodeResponse(_ data: Data) throws -> GranaAIClassificationResponse {
        let response: GranaAIClassificationResponse
        do {
            response = try JSONDecoder().decode(GranaAIClassificationResponse.self, from: data)
        } catch {
            if let contractError = try? JSONDecoder().decode(GranaAIContractErrorResponse.self, from: data) {
                throw GranaAIProcessClientError.contract(contractError)
            }
            throw GranaAIProcessClientError.invalidResponse
        }

        guard response.version == GranaAIContract.version else {
            throw GranaAIProcessClientError.unsupportedVersion(response.version)
        }
        return response
    }

    private func runProcess(
        arguments: [String],
        input: Data,
        requiresOutput: Bool
    ) async throws -> Data {
        let processBox = ProcessBox()

        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Data.self) { group in
                group.addTask {
                    try Self.runProcess(
                        executableURL: self.executableURL,
                        arguments: arguments,
                        input: input,
                        requiresOutput: requiresOutput,
                        processBox: processBox
                    )
                }
                group.addTask {
                    try await Task.sleep(for: self.timeout)
                    processBox.terminate()
                    throw GranaAIProcessClientError.timedOut
                }

                guard let output = try await group.next() else {
                    throw GranaAIProcessClientError.emptyOutput
                }
                group.cancelAll()
                return output
            }
        } onCancel: {
            processBox.terminate()
        }
    }

    private static func runProcess(
        executableURL: URL,
        arguments: [String],
        input: Data,
        requiresOutput: Bool,
        processBox: ProcessBox
    ) throws -> Data {
        let process = processBox.process
        process.executableURL = executableURL
        process.arguments = arguments

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw GranaAIProcessClientError.launchFailed
        }

        inputPipe.fileHandleForWriting.write(input)
        try? inputPipe.fileHandleForWriting.close()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            if let contractError = try? JSONDecoder().decode(GranaAIContractErrorResponse.self, from: output) {
                throw GranaAIProcessClientError.contract(contractError)
            }
            throw GranaAIProcessClientError.nonZeroExit(status: process.terminationStatus)
        }

        guard requiresOutput || !output.isEmpty else {
            return output
        }

        guard !output.isEmpty else {
            throw GranaAIProcessClientError.emptyOutput
        }
        return output
    }
}

nonisolated enum GranaAIProcessClientError: LocalizedError, Equatable {
    case launchFailed
    case timedOut
    case nonZeroExit(status: Int32)
    case emptyOutput
    case invalidResponse
    case unsupportedVersion(String)
    case contract(GranaAIContractErrorResponse)

    var errorDescription: String? {
        switch self {
        case .launchFailed:
            return "Não foi possível executar o GranaAI local."
        case .timedOut:
            return "O GranaAI local excedeu o tempo limite de classificação."
        case let .nonZeroExit(status):
            return "O GranaAI local encerrou com status \(status)."
        case .emptyOutput:
            return "O GranaAI local não retornou resposta."
        case .invalidResponse:
            return "O GranaAI local retornou JSON incompatível."
        case let .unsupportedVersion(version):
            return "O GranaAI local retornou versão incompatível: \(version)."
        case let .contract(error):
            return "Erro estruturado do GranaAI local: \(error.code)."
        }
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process = Process()

    func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }
}
