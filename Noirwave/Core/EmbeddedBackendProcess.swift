import Foundation

@MainActor
final class EmbeddedBackendProcess {
    static let shared = EmbeddedBackendProcess()

    private let host = "127.0.0.1"
    private let port = 6605
    private let startupTimeout: TimeInterval = 8
    private var process: Process?
    private var startupTask: Task<Void, Never>?

    private var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    private var backendRoot: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("NoirwaveBackend", isDirectory: true)
    }

    func startIfNeeded() async {
        if await isBackendResponsive() {
            return
        }

        guard process == nil,
              let backendRoot,
              FileManager.default.fileExists(atPath: backendRoot.appendingPathComponent("src/server.mjs").path)
        else {
            return
        }

        guard let nodeExecutable = executablePath(
            environmentKey: "NOIRWAVE_NODE_PATH",
            markerFile: backendRoot.appendingPathComponent(".node-path"),
            fallbackNames: ["node"]
        ) else {
            return
        }

        do {
            let runtimeRoot = try runtimeDirectory()
            let backendProcess = Process()
            backendProcess.executableURL = URL(fileURLWithPath: nodeExecutable)
            backendProcess.arguments = ["src/server.mjs"]
            backendProcess.currentDirectoryURL = backendRoot
            backendProcess.standardOutput = FileHandle.nullDevice
            backendProcess.standardError = FileHandle.nullDevice
            backendProcess.environment = launchEnvironment(backendRoot: backendRoot, runtimeRoot: runtimeRoot)
            try backendProcess.run()
            process = backendProcess
            await waitUntilResponsive()
        } catch {
            process = nil
        }
    }

    func stop() {
        startupTask?.cancel()
        startupTask = nil
        process?.terminate()
        process = nil
    }

    private func waitUntilResponsive() async {
        let deadline = Date().addingTimeInterval(startupTimeout)
        while Date() < deadline {
            if await isBackendResponsive() {
                return
            }
            try? await Task.sleep(for: .milliseconds(180))
        }
    }

    private func isBackendResponsive() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("api/connect")
            var request = URLRequest(url: url)
            request.timeoutInterval = 0.75
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func runtimeDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Noirwave", isDirectory: true)
            .appendingPathComponent("BackendRuntime", isDirectory: true)
        guard let root else {
            throw CocoaError(.fileNoSuchFile)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func launchEnvironment(backendRoot: URL, runtimeRoot: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let markerPaths = [
            readMarker(backendRoot.appendingPathComponent(".node-path")),
            readMarker(backendRoot.appendingPathComponent(".uv-path")),
        ]
        let runtimeBins = markerPaths
            .compactMap(\.self)
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
        let defaultPath = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        environment["PATH"] = (runtimeBins + defaultPath + [environment["PATH"]])
            .compactMap(\.self)
            .joined(separator: ":")
        environment["NOIRWAVE_BACKEND_HOST"] = host
        environment["NOIRWAVE_BACKEND_PORT"] = String(port)
        environment["NOIRWAVE_RUNTIME_ROOT"] = runtimeRoot.path
        environment["UV_PROJECT_ENVIRONMENT"] = runtimeRoot.appendingPathComponent("python-env", isDirectory: true).path
        environment["UV_CACHE_DIR"] = runtimeRoot.appendingPathComponent("uv-cache", isDirectory: true).path
        if let uvPath = readMarker(backendRoot.appendingPathComponent(".uv-path")) {
            environment["NOIRWAVE_UV_PATH"] = uvPath
        }
        return environment
    }

    private func executablePath(
        environmentKey: String,
        markerFile: URL,
        fallbackNames: [String]
    ) -> String? {
        var candidates: [String?] = [
            ProcessInfo.processInfo.environment[environmentKey],
            readMarker(markerFile),
        ]
        candidates.append(contentsOf: fallbackNames.flatMap { name in
            [
                "/opt/homebrew/bin/\(name)",
                "/usr/local/bin/\(name)",
                "/usr/bin/\(name)",
            ]
        })

        return candidates
            .compactMap { $0?.nonEmpty }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func readMarker(_ url: URL) -> String? {
        (try? String(contentsOf: url, encoding: .utf8))?.trimmed.nonEmpty
    }
}
