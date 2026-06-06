import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
    case smart = "Smart"
    case catalog = "Tracks"
    case library = "Artists"
    case albums = "Albums"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .smart:
            "magnifyingglass"
        case .catalog:
            "square.grid.2x2"
        case .library:
            "music.mic"
        case .albums:
            "rectangle.stack"
        }
    }

    var resultsTitle: String {
        switch self {
        case .smart:
            "Best Matches"
        case .catalog:
            "Track Results"
        case .library:
            "Artist Results"
        case .albums:
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

enum RepeatMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case all = "All"
    case one = "One"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .off, .all:
            "repeat"
        case .one:
            "repeat.1"
        }
    }

    var next: RepeatMode {
        switch self {
        case .off:
            .all
        case .all:
            .one
        case .one:
            .off
        }
    }
}

enum EqualizerPreset: String, CaseIterable, Identifiable {
    case flat = "Default"
    case bassBoost = "Bass boost"
    case vocal = "Vocal"
    case soft = "Soft"
    case electronic = "Electronic"

    var id: String { rawValue }

    var bandGains: [Double] {
        switch self {
        case .flat:
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bassBoost:
            [6, 5, 3, 1, 0, -1, -2, -2, -1, 0]
        case .vocal:
            [-2, -1, 1, 3, 4, 3, 1, 0, -1, -1]
        case .soft:
            [-1, 0, 1, 2, 2, 1, 0, -1, -2, -2]
        case .electronic:
            [4, 3, 1, 0, -1, 2, 4, 5, 4, 3]
        }
    }
}

struct EqualizerSettings: Equatable {
    static let bandFrequencies: [Double] = [60, 170, 310, 600, 1_000, 3_000, 6_000, 12_000, 14_000, 16_000]
    static let flat = EqualizerSettings(isEnabled: false, preset: .flat, bandGains: EqualizerPreset.flat.bandGains)

    var isEnabled: Bool
    var preset: EqualizerPreset
    var bandGains: [Double]

    var normalizedBandGains: [Double] {
        let clamped = bandGains.prefix(Self.bandFrequencies.count).map { min(max($0, -12), 12) }
        guard clamped.count < Self.bandFrequencies.count else { return clamped }
        return clamped + Array(repeating: 0, count: Self.bandFrequencies.count - clamped.count)
    }

    static func preset(_ preset: EqualizerPreset, isEnabled: Bool = true) -> EqualizerSettings {
        EqualizerSettings(isEnabled: isEnabled, preset: preset, bandGains: preset.bandGains)
    }
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
    func radioTracks(seed: Track?) async throws -> [Track]
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
    func setVolume(_ volume: Double)
    func setEqualizer(_ settings: EqualizerSettings)
    func setCrossfadeDuration(_ duration: TimeInterval)
    func crossfade(to track: Track, duration: TimeInterval) async throws
    func currentPlaybackTime() -> TimeInterval?
}

extension MusicProviding {
    func setEqualizer(_ settings: EqualizerSettings) {}

    func setCrossfadeDuration(_ duration: TimeInterval) {}

    func crossfade(to track: Track, duration: TimeInterval) async throws {
        try await play(track)
    }
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
