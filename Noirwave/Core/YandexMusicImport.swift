import Foundation
import Security

struct YandexMusicImportItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval?
    let artworkURL: String?

    var searchQuery: String {
        [artist.nonEmpty, title.nonEmpty]
            .compactMap(\.self)
            .joined(separator: " ")
    }
}

struct YandexMusicImportRequest: Encodable {
    let token: String?
    let exportText: String?
}

struct YandexMusicImportResponse: Decodable {
    let result: Bool
    let tracks: [YandexMusicImportItem]
    let total: Int?
}

struct YandexMusicImportClient {
    private static let apiBaseEnvironmentKey = "NOIRWAVE_BACKEND_API_BASE"

    let baseURL: URL
    var session: URLSession = .shared

    init(baseURL: URL = YandexMusicImportClient.defaultBaseURL()) {
        self.baseURL = baseURL
    }

    func likedTracks(token: String?, exportText: String?) async throws -> [YandexMusicImportItem] {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("import")
            .appendingPathComponent("yandex")
            .appendingPathComponent("likes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(YandexMusicImportRequest(token: token, exportText: exportText))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            if let error = try? JSONDecoder().decode(DeemixAPIErrorResponse.self, from: data) {
                throw MusicProviderError.providerNotReady(error.error ?? "Yandex Music import failed.")
            }
            throw MusicProviderError.providerNotReady("Yandex Music import failed.")
        }

        let payload = try JSONDecoder().decode(YandexMusicImportResponse.self, from: data)
        return payload.tracks
    }

    private static func defaultBaseURL() -> URL {
        if let value = ProcessInfo.processInfo.environment[apiBaseEnvironmentKey],
           let url = URL(string: value) {
            return url
        }

        return URL(string: "http://127.0.0.1:6605")!
    }
}

enum YandexMusicTokenVaultError: LocalizedError {
    case invalidToken
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            "Enter a valid Yandex OAuth token."
        case .keychainFailure(let status):
            "Could not access Yandex Music token in Keychain (status \(status))."
        }
    }
}

struct YandexMusicTokenVault {
    static let app = YandexMusicTokenVault(
        service: "com.fsociety.noirwave.yandex-music",
        account: "oauth-token"
    )

    let service: String
    let account: String

    func savedToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw YandexMusicTokenVaultError.keychainFailure(status)
        }

        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return Self.normalizedToken(value)
    }

    func saveToken(_ value: String) throws {
        guard let token = Self.normalizedToken(value) else {
            throw YandexMusicTokenVaultError.invalidToken
        }

        let data = Data(token.utf8)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw YandexMusicTokenVaultError.keychainFailure(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw YandexMusicTokenVaultError.keychainFailure(addStatus)
        }
    }

    func deleteSavedToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw YandexMusicTokenVaultError.keychainFailure(status)
        }
    }

    static func normalizedToken(_ value: String) -> String? {
        let token = value.trimmed
        guard token.count >= 24,
              token.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else {
            return nil
        }
        return token
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum YandexImportMatchStatus: String, Equatable {
    case matched = "Matched"
    case ambiguous = "Ambiguous"
    case notFound = "Not Found"
}

struct YandexImportPreviewRow: Identifiable, Equatable {
    let id = UUID()
    let source: YandexMusicImportItem
    let candidates: [Track]
    var selectedTrack: Track?
    let status: YandexImportMatchStatus

    var importableTrack: Track? {
        switch status {
        case .matched, .ambiguous:
            selectedTrack
        case .notFound:
            nil
        }
    }
}

enum YandexImportMatcher {
    static func previewRow(for source: YandexMusicImportItem, candidates: [Track]) -> YandexImportPreviewRow {
        let ranked = candidates
            .filter(\.isPlayable)
            .map { track in (track: track, score: score(source: source, candidate: track)) }
            .filter { $0.score >= 58 }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.track.rank ?? 0 > rhs.track.rank ?? 0
                }
                return lhs.score > rhs.score
            }

        guard let best = ranked.first else {
            return YandexImportPreviewRow(source: source, candidates: [], selectedTrack: nil, status: .notFound)
        }

        let isAmbiguous = ranked.dropFirst().first.map { best.score - $0.score <= 8 } ?? false
        let status: YandexImportMatchStatus = isAmbiguous ? .ambiguous : .matched
        return YandexImportPreviewRow(
            source: source,
            candidates: ranked.prefix(4).map(\.track),
            selectedTrack: best.track,
            status: status
        )
    }

    private static func score(source: YandexMusicImportItem, candidate: Track) -> Int {
        let sourceTitle = source.title.searchNormalized
        let candidateTitle = candidate.title.searchNormalized
        let sourceArtist = source.artist.searchNormalized
        let candidateArtist = candidate.artist.searchNormalized
        let sourceAlbum = source.album.searchNormalized
        let candidateAlbum = candidate.album.searchNormalized

        var score = 0
        if sourceTitle == candidateTitle {
            score += 48
        } else if candidateTitle.contains(sourceTitle) || sourceTitle.contains(candidateTitle) {
            score += 34
        } else {
            score += 12 * overlap(sourceTitle, candidateTitle)
        }

        if sourceArtist == candidateArtist {
            score += 38
        } else if candidateArtist.contains(sourceArtist) || sourceArtist.contains(candidateArtist) {
            score += 26
        } else {
            score += 10 * overlap(sourceArtist, candidateArtist)
        }

        if !sourceAlbum.isEmpty && !candidateAlbum.isEmpty {
            if sourceAlbum == candidateAlbum {
                score += 10
            } else if candidateAlbum.contains(sourceAlbum) || sourceAlbum.contains(candidateAlbum) {
                score += 5
            }
        }

        if let duration = source.duration, duration > 0, candidate.duration > 0 {
            let difference = abs(candidate.duration - duration)
            if difference <= 2 {
                score += 10
            } else if difference <= 6 {
                score += 6
            } else if difference >= 18 {
                score -= 10
            }
        }

        return score
    }

    private static func overlap(_ lhs: String, _ rhs: String) -> Int {
        let left = Set(lhs.split(separator: " ").map(String.init))
        let right = Set(rhs.split(separator: " ").map(String.init))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return left.intersection(right).count
    }
}

struct MusicImportHistoryRecord: Codable, Identifiable, Hashable {
    let id: String
    let source: String
    let importedAt: Date
    let imported: Int
    let skipped: Int
    let notFound: Int
    let destination: String

    init(
        id: String = UUID().uuidString,
        source: String,
        importedAt: Date = Date(),
        imported: Int,
        skipped: Int,
        notFound: Int,
        destination: String
    ) {
        self.id = id
        self.source = source
        self.importedAt = importedAt
        self.imported = imported
        self.skipped = skipped
        self.notFound = notFound
        self.destination = destination
    }
}
