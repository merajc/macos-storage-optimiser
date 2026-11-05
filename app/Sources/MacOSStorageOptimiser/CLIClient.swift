import Foundation

struct CLIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Collects stderr from the helper process without blocking stdout.
final class ErrorBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

/// Runs the bundled Zsh helper and streams its NDJSON output line by line.
final class CLIClient {
    let binaryURL: URL

    init(binaryURL: URL) {
        self.binaryURL = binaryURL
    }

    /// The app always ships the tested script inside Contents/Resources. When
    /// that is missing (e.g. `swift run` during development) we fall back to a
    /// PATH install, then to MSD_CLI for explicit overrides.
    static func locate() -> URL? {
        var candidates: [URL] = []

        if let override = ProcessInfo.processInfo.environment["MSD_CLI"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("macos-system-data"))
        }
        candidates.append(URL(fileURLWithPath: NSHomeDirectory() + "/.local/bin/macos-system-data"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/macos-system-data"))
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/macos-system-data"))

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    func stream(_ arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = binaryURL
            process.arguments = arguments
            process.environment = Self.environment()

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let errors = ErrorBuffer()
            let errorHandle = stderr.fileHandleForReading
            errorHandle.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    errors.append(chunk)
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: CLIError(
                    message: "Could not start the helper: \(error.localizedDescription)"
                ))
                return
            }

            let outputHandle = stdout.fileHandleForReading
            Task.detached {
                do {
                    for try await line in outputHandle.bytes.lines {
                        continuation.yield(line)
                    }
                    process.waitUntilExit()
                    errorHandle.readabilityHandler = nil
                    let code = process.terminationStatus
                    if code != 0 && code != 130 {
                        let reason = errors.text
                        continuation.finish(throwing: CLIError(
                            message: reason.isEmpty ? "Helper exited with code \(code)" : reason
                        ))
                    } else {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                if process.isRunning {
                    process.terminate()
                }
            }
        }
    }

    private static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        env["NO_COLOR"] = "1"
        return env
    }
}
