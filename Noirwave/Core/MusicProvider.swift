import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
    case catalog = "Tracks"
    case library = "Artists"
    case playlists = "Albums"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .catalog:
            "square.grid.2x2"
        case .library:
            "music.mic"
        case .playlists:
            "rectangle.stack"
        }
    }

    var resultsTitle: String {
        switch self {
        case .catalog:
            "Track Results"
        case .library:
            "Artist Results"
        case .playlists:
            "Album Results"
        }
    }
}

enum PlaybackState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case failed(String)
}

struct TrackLyricsLine: Identifiable, Equatable, Hashable {
    let milliseconds: Int
    let duration: Int?
    let text: String

    var id: Int { milliseconds }

    var startTime: TimeInterval {
        TimeInterval(milliseconds) / 1_000
    }
}

struct TrackLyrics: Equatable, Hashable {
    let text: String
    let lines: [TrackLyricsLine]
    let copyright: String?
    let writers: String?

    init(
        text: String,
        lines: [TrackLyricsLine],
        copyright: String?,
        writers: String?
    ) {
        self.text = text.trimmed
        self.lines = lines
            .filter { !$0.text.trimmed.isEmpty }
            .sorted { $0.milliseconds < $1.milliseconds }
        self.copyright = copyright?.nonEmpty
        self.writers = writers?.nonEmpty
    }

    var isAvailable: Bool {
        !text.isEmpty || !lines.isEmpty
    }

    var hasSynchronizedLines: Bool {
        !lines.isEmpty
    }

    func activeLineIndex(at playbackTime: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }

        let playbackMilliseconds = max(Int((playbackTime * 1_000).rounded()), 0)
        var activeIndex = 0

        for (index, line) in lines.enumerated() {
            guard line.milliseconds <= playbackMilliseconds else {
                break
            }
            activeIndex = index
        }

        return activeIndex
    }
}

enum LyricsState: Equatable {
    case idle
    case loading
    case loaded(TrackLyrics)
    case unavailable(String)
    case failed(String)
}

enum ProviderAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unsupported
}

struct ProviderStatus: Equatable {
    var authorization: ProviderAuthorizationState
    var canPlayCatalogContent: Bool
    var message: String?

    static let disconnected = ProviderStatus(
        authorization: .notDetermined,
        canPlayCatalogContent: false,
        message: nil
    )
}

@MainActor
protocol MusicProviding: AnyObject {
    var sourceName: String { get }

    func featuredTracks() async throws -> [Track]
    func search(_ query: String, scope: SearchScope) async throws -> [Track]
    func catalogItems(for item: Track) async throws -> [Track]
    func requestAuthorization() async throws -> ProviderStatus
    func currentStatus() async throws -> ProviderStatus
    func configureBackendSession(arl: String) async throws -> ProviderStatus
    func lyrics(for track: Track) async throws -> TrackLyrics
    func prepare(_ tracks: [Track]) async
    func play(_ track: Track) async throws
    func resume() async throws
    func pause() async
    func stop() async
    func seek(to time: TimeInterval) async
    func currentPlaybackTime() -> TimeInterval?
}

enum MusicProviderError: LocalizedError {
    case trackUnavailable
    case authorizationDenied
    case subscriptionRequired
    case playbackDidNotStart(String)
    case providerNotReady(String)

    var errorDescription: String? {
        switch self {
        case .trackUnavailable:
            "This track is not available from the current music provider."
        case .authorizationDenied:
            "Music provider access was not granted."
        case .subscriptionRequired:
            "The current music provider is not ready for playback."
        case .playbackDidNotStart(let status):
            "The music provider accepted the track, but playback did not start. Current player status: \(status)."
        case .providerNotReady(let message):
            message
        }
    }
}
