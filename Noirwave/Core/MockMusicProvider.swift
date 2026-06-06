import Foundation

final class MockMusicProvider: MusicProviding {
    let sourceName = "Noirwave Free"

    private let tracks: [Track] = [
        Track(
            id: "mock.chrome-halo",
            title: "Chrome Halo",
            artist: "NOVA UNIT",
            album: "Afterimage",
            duration: 217,
            palette: TrackPalette(baseHex: "#0D0E12", midHex: "#38433F", accentHex: "#5EE0C2", inkHex: "#EAFDF8"),
            catalogID: nil,
            previewURL: nil,
            artworkURL: "https://picsum.photos/seed/noirwave-chrome-halo/640/640"
        ),
        Track(
            id: "mock.low-orbit",
            title: "Low Orbit",
            artist: "Mara Vale",
            album: "Telemetry",
            duration: 254,
            palette: TrackPalette(baseHex: "#090C10", midHex: "#143D48", accentHex: "#5EE0C2", inkHex: "#EAFDF8"),
            catalogID: nil,
            previewURL: nil,
            artworkURL: "https://picsum.photos/seed/noirwave-low-orbit/640/640"
        ),
        Track(
            id: "mock.soft-voltage",
            title: "Soft Voltage",
            artist: "Glass Relay",
            album: "Midnight Utility",
            duration: 186,
            palette: TrackPalette(baseHex: "#111016", midHex: "#3C3149", accentHex: "#5EE0C2", inkHex: "#EAFDF8"),
            catalogID: nil,
            previewURL: nil,
            artworkURL: "https://picsum.photos/seed/noirwave-soft-voltage/640/640"
        ),
        Track(
            id: "mock.ceramic-static",
            title: "Ceramic Static",
            artist: "Iris Circuit",
            album: "No Service",
            duration: 228,
            palette: TrackPalette(baseHex: "#0F1110", midHex: "#34402E", accentHex: "#5EE0C2", inkHex: "#EAFDF8"),
            catalogID: nil,
            previewURL: nil,
            artworkURL: "https://picsum.photos/seed/noirwave-ceramic-static/640/640"
        ),
        Track(
            id: "mock.terminal-silk",
            title: "Terminal Silk",
            artist: "Vanta Choir",
            album: "Room Tone",
            duration: 242,
            palette: TrackPalette(baseHex: "#090909", midHex: "#433232", accentHex: "#5EE0C2", inkHex: "#EAFDF8"),
            catalogID: nil,
            previewURL: nil,
            artworkURL: "https://picsum.photos/seed/noirwave-terminal-silk/640/640"
        ),
        Track(
            id: "mock.black-current",
            title: "Black Current",
            artist: "North Prism",
            album: "Signal Shapes",
            duration: 205,
            palette: TrackPalette(baseHex: "#0C0E14", midHex: "#24314B", accentHex: "#5EE0C2", inkHex: "#EAFDF8"),
            catalogID: nil,
            previewURL: nil,
            artworkURL: "https://picsum.photos/seed/noirwave-black-current/640/640"
        ),
        Track(
            id: "mock.silver-rain",
            title: "Silver Rain",
            artist: "Luma District",
            album: "Refraction",
            duration: 233,
            palette: TrackPalette(baseHex: "#101112", midHex: "#4A4E50", accentHex: "#5EE0C2", inkHex: "#EAFDF8"),
            catalogID: nil,
            previewURL: nil,
            artworkURL: "https://picsum.photos/seed/noirwave-silver-rain/640/640"
        ),
        Track(
            id: "mock.subsurface",
            title: "Subsurface",
            artist: "Aster Field",
            album: "Drift Index",
            duration: 198,
            palette: TrackPalette(baseHex: "#0A1110", midHex: "#1D4B3E", accentHex: "#5EE0C2", inkHex: "#EAFDF8"),
            catalogID: nil,
            previewURL: nil,
            artworkURL: "https://picsum.photos/seed/noirwave-subsurface/640/640"
        )
    ]

    func featuredTracks() async throws -> [Track] {
        tracks
    }

    func search(_ query: String, scope: SearchScope) async throws -> [Track] {
        try await Task.sleep(for: .milliseconds(90))
        let term = query.trimmed.lowercased()

        guard !term.isEmpty else {
            return tracks
        }

        let matchingTracks = tracks.filter { track in
            track.title.lowercased().contains(term)
                || track.artist.lowercased().contains(term)
                || track.album.lowercased().contains(term)
        }

        guard scope == .smart else {
            return matchingTracks
        }

        let artists = Dictionary(grouping: matchingTracks, by: \.artist)
            .enumerated()
            .map { offset, group in
                Track(
                    id: "mock-artist.\(group.key)",
                    title: group.key,
                    artist: group.key,
                    album: "Artist",
                    duration: 0,
                    palette: group.value.first?.palette ?? .fallback,
                    catalogID: nil,
                    previewURL: nil,
                    kind: .artist,
                    artworkURL: group.value.first?.artworkURL,
                    fanCount: 100_000 - offset,
                    albumCount: Set(group.value.map(\.album)).count
                )
            }

        return SmartSearchRanker.ranked(query: query, artists: artists, tracks: matchingTracks, albums: [])
    }

    func catalogItems(for item: Track) async throws -> [Track] {
        switch item.kind {
        case .track:
            return [item]
        case .artist:
            return tracks
                .filter { $0.artist.localizedCaseInsensitiveContains(item.title) }
                .sorted { ($0.rank ?? 0) > ($1.rank ?? 0) }
        case .album:
            return tracks
                .filter { $0.album.localizedCaseInsensitiveContains(item.title) }
                .sorted { ($0.trackPosition ?? Int.max) < ($1.trackPosition ?? Int.max) }
        }
    }

    func radioTracks(seed: Track?) async throws -> [Track] {
        try await Task.sleep(for: .milliseconds(80))

        guard let seed else {
            return tracks.shuffled()
        }

        let sameArtistOrAlbum = tracks.filter {
            $0 != seed && ($0.artist == seed.artist || $0.album == seed.album)
        }
        let relatedPalette = tracks.filter {
            $0 != seed && $0.palette.accentHex == seed.palette.accentHex
        }
        let fallback = tracks.filter { $0 != seed }

        return stableRadioOrder(sameArtistOrAlbum + relatedPalette + fallback, seed: seed.id)
    }

    func requestAuthorization() async throws -> ProviderStatus {
        ProviderStatus(
            authorization: .authorized,
            canPlayCatalogContent: true,
            message: "Free local playback"
        )
    }

    func currentStatus() async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func configureBackendSession(arl: String) async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func lyrics(for track: Track) async throws -> TrackLyrics {
        TrackLyrics(
            text: [
                "\(track.title) drifts in low light",
                "\(track.artist) rides the signal",
                "Room tone holds the chorus"
            ].joined(separator: "\n"),
            lines: [
                TrackLyricsLine(milliseconds: 0, duration: 3_000, text: "\(track.title) drifts in low light"),
                TrackLyricsLine(milliseconds: 3_200, duration: 3_000, text: "\(track.artist) rides the signal"),
                TrackLyricsLine(milliseconds: 6_400, duration: 3_000, text: "Room tone holds the chorus")
            ],
            copyright: nil,
            writers: nil
        )
    }

    func play(_ track: Track) async throws {
        try await Task.sleep(for: .milliseconds(120))
    }

    func resume() async throws {
        try await Task.sleep(for: .milliseconds(40))
    }

    func pause() async {}

    func stop() async {}

    func seek(to time: TimeInterval) async {}

    func currentPlaybackTime() -> TimeInterval? {
        nil
    }

    private func stableRadioOrder(_ items: [Track], seed: String) -> [Track] {
        var seenIDs = Set<String>()
        return items
            .filter { seenIDs.insert($0.id).inserted }
            .sorted { lhsTrack, rhsTrack in
                let lhs = "\(seed).\(lhsTrack.id)".unicodeScalars.reduce(0) { $0 + Int($1.value) }
                let rhs = "\(seed).\(rhsTrack.id)".unicodeScalars.reduce(0) { $0 + Int($1.value) }
                return lhs < rhs
            }
    }
}
