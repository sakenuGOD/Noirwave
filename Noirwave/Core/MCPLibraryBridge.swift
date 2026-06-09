import Foundation

struct MCPLibraryPermissions: Codable, Equatable {
    var readLibrary = true
    var editPlaylists = true
    var editMetadata = false
    var deletePlaylists = false
    var playbackControl = false
}

struct MCPActivityEntry: Codable, Identifiable, Hashable {
    let id: String
    let timestamp: String
    let actor: String
    let action: String
    let summary: String
    let details: String?
}

struct MCPServerStatus: Codable, Equatable {
    var state: String
    var pid: Int?
    var root: String?
    var transport: String?
    var tools: [String]
    var updatedAt: String?

    static let stopped = MCPServerStatus(
        state: "stopped",
        pid: nil,
        root: nil,
        transport: "stdio",
        tools: MCPLibraryBridge.toolNames,
        updatedAt: nil
    )

    var isRunning: Bool {
        guard state == "running",
              let updatedDate,
              abs(updatedDate.timeIntervalSinceNow) < 8
        else { return false }
        return true
    }

    var displayState: String {
        isRunning ? "running" : "stopped"
    }

    var updatedDate: Date? {
        guard let updatedAt else { return nil }
        return ISO8601DateFormatter.noirwaveMCP.date(from: updatedAt)
    }
}

struct MCPTrackRecord: Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let durationLabel: String
    let kind: String
    let catalogID: String?
    let previewURL: String?
    let artistCatalogID: String?
    let albumCatalogID: String?
    let artworkURL: String?
    let rank: Int?
    let fanCount: Int?
    let albumCount: Int?
    let trackCount: Int?
    let releaseDate: String?
    let recordType: String?
    let trackPosition: Int?
    let discNumber: Int?
    let liked: Bool
    let saved: Bool
    var tags: [String]
    var metadata: [String: String]

    init(track: Track, liked: Bool, saved: Bool, tags: [String] = [], metadata: [String: String] = [:]) {
        id = track.id
        title = track.title
        artist = track.artist
        album = track.album
        duration = track.duration
        durationLabel = track.durationLabel
        kind = track.kind.rawValue
        catalogID = track.catalogID
        previewURL = track.previewURL
        artistCatalogID = track.artistCatalogID
        albumCatalogID = track.albumCatalogID
        artworkURL = track.artworkURL
        rank = track.rank
        fanCount = track.fanCount
        albumCount = track.albumCount
        trackCount = track.trackCount
        releaseDate = track.releaseDate
        recordType = track.recordType
        trackPosition = track.trackPosition
        discNumber = track.discNumber
        self.liked = liked
        self.saved = saved
        self.tags = tags
        self.metadata = metadata
    }

    var playableTrack: Track? {
        guard kind == TrackKind.track.rawValue else { return nil }
        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            palette: TrackPalette.fallback,
            catalogID: catalogID,
            previewURL: previewURL,
            artistCatalogID: artistCatalogID,
            albumCatalogID: albumCatalogID,
            kind: .track,
            artworkURL: artworkURL,
            rank: rank,
            fanCount: fanCount,
            albumCount: albumCount,
            trackCount: trackCount,
            releaseDate: releaseDate,
            recordType: recordType,
            trackPosition: trackPosition,
            discNumber: discNumber
        )
    }
}

struct MCPArtistRecord: Codable, Hashable {
    let id: String
    let name: String
    let trackCount: Int
    let albumCount: Int
}

struct MCPAlbumRecord: Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let trackCount: Int
}

struct MCPPlaylistRecord: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var trackIds: [String]
    var tracks: [MCPTrackRecord]
    let createdAt: String
    var updatedAt: String
}

struct MCPLibrarySnapshot: Codable, Equatable {
    var version: Int
    var updatedAt: String
    var tracks: [MCPTrackRecord]
    var artists: [MCPArtistRecord]
    var albums: [MCPAlbumRecord]
    var playlists: [MCPPlaylistRecord]
    var permissions: MCPLibraryPermissions
}

enum MCPLibraryBridge {
    static let version = 1

    static var rootDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Noirwave", isDirectory: true)
            .appendingPathComponent("MCP", isDirectory: true)
    }

    static var libraryURL: URL {
        rootDirectory.appendingPathComponent("library.json")
    }

    static var configURL: URL {
        rootDirectory.appendingPathComponent("mcp-config.json")
    }

    static var activityLogURL: URL {
        rootDirectory.appendingPathComponent("activity-log.json")
    }

    static var statusURL: URL {
        rootDirectory.appendingPathComponent("mcp-status.json")
    }

    static var connectionCommand: String {
        let backendRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("NoirwaveBackend", isDirectory: true)
        return "NOIRWAVE_MCP_ROOT=\"\(rootDirectory.path)\" node \"\(backendRoot.appendingPathComponent("src/mcpServer.mjs").path)\""
    }

    static let toolNames = [
        "search_tracks",
        "get_track",
        "list_playlists",
        "create_playlist",
        "rename_playlist",
        "delete_playlist",
        "add_track_to_playlist",
        "remove_track_from_playlist",
        "reorder_playlist_tracks",
        "create_smart_playlist",
        "find_similar_tracks",
        "get_library_stats",
        "tag_track",
        "update_track_metadata",
    ]

    static let resourceURIs = [
        "library://tracks",
        "library://artists",
        "library://albums",
        "library://playlists",
        "library://playlist/{id}",
        "library://track/{id}",
    ]

    static func ensureFiles(permissions: MCPLibraryPermissions = MCPLibraryPermissions()) {
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: configURL.path) {
            savePermissions(permissions)
        }
        if !FileManager.default.fileExists(atPath: activityLogURL.path) {
            saveActivityLog([])
        }
    }

    static func loadPermissions() -> MCPLibraryPermissions {
        ensureFiles()
        guard let data = try? Data(contentsOf: configURL),
              let permissions = try? JSONDecoder().decode(MCPLibraryPermissions.self, from: data)
        else {
            return MCPLibraryPermissions()
        }
        return permissions
    }

    static func savePermissions(_ permissions: MCPLibraryPermissions) {
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder.pretty.encode(permissions) {
            try? data.write(to: configURL, options: .atomic)
        }
    }

    static func loadActivityLog(limit: Int = 30) -> [MCPActivityEntry] {
        ensureFiles()
        guard let data = try? Data(contentsOf: activityLogURL),
              let entries = try? JSONDecoder().decode([MCPActivityEntry].self, from: data)
        else {
            return []
        }
        return Array(entries.prefix(limit))
    }

    static func loadServerStatus() -> MCPServerStatus {
        ensureFiles()
        guard let data = try? Data(contentsOf: statusURL),
              var status = try? JSONDecoder().decode(MCPServerStatus.self, from: data)
        else {
            return .stopped
        }

        if !status.isRunning {
            status.state = "stopped"
        }
        return status
    }

    private static func saveActivityLog(_ entries: [MCPActivityEntry]) {
        if let data = try? JSONEncoder.pretty.encode(entries) {
            try? data.write(to: activityLogURL, options: .atomic)
        }
    }

    static func loadSnapshot() -> MCPLibrarySnapshot? {
        guard let data = try? Data(contentsOf: libraryURL) else { return nil }
        return try? JSONDecoder().decode(MCPLibrarySnapshot.self, from: data)
    }

    static func saveSnapshot(_ snapshot: MCPLibrarySnapshot) {
        ensureFiles(permissions: snapshot.permissions)
        guard let data = try? JSONEncoder.pretty.encode(snapshot) else { return }
        try? data.write(to: libraryURL, options: .atomic)
    }

    static func snapshot(
        tracks: [Track],
        likedIDs: Set<String>,
        savedIDs: Set<String>,
        playlists: [LocalPlaylist],
        permissions: MCPLibraryPermissions
    ) -> MCPLibrarySnapshot {
        let previous = loadSnapshot()
        let previousByID = Dictionary(uniqueKeysWithValues: (previous?.tracks ?? []).map { ($0.id, $0) })
        let uniqueTracks = deduplicatedTracks(tracks + playlists.flatMap { $0.orderedTracks(preferredTracks: tracks) })
        let records = uniqueTracks.map { track in
            let previous = previousByID[track.id]
            return MCPTrackRecord(
                track: track,
                liked: likedIDs.contains(track.id),
                saved: savedIDs.contains(track.id),
                tags: previous?.tags ?? [],
                metadata: previous?.metadata ?? [:]
            )
        }
        let recordByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        let playlistRecords = playlists.map { playlist in
            let previous = previous?.playlists.first { $0.id == playlist.id }
            let orderedTracks = playlist.orderedTracks(preferredTracks: uniqueTracks)
            return MCPPlaylistRecord(
                id: playlist.id,
                name: playlist.title,
                description: previous?.description,
                trackIds: playlist.trackIDs,
                tracks: playlist.trackIDs.compactMap { recordByID[$0] } + orderedTracks.compactMap { recordByID[$0.id] }.filter { !playlist.trackIDs.contains($0.id) },
                createdAt: isoString(from: playlist.createdAt),
                updatedAt: isoString(from: playlist.updatedAt)
            )
        }
        return MCPLibrarySnapshot(
            version: version,
            updatedAt: isoString(from: Date()),
            tracks: records,
            artists: artists(from: records),
            albums: albums(from: records),
            playlists: playlistRecords,
            permissions: permissions
        )
    }

    static func playlists(from snapshot: MCPLibrarySnapshot) -> [LocalPlaylist] {
        snapshot.playlists.map { record in
            let tracks = record.tracks.compactMap(\.playableTrack)
            var playlist = LocalPlaylist(
                id: record.id,
                title: record.name,
                tracks: [],
                createdAt: date(from: record.createdAt) ?? Date(),
                updatedAt: date(from: record.updatedAt) ?? Date()
            )
            playlist.trackIDs = record.trackIds
            playlist.trackSnapshots = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
            playlist.normalize()
            return playlist
        }
    }

    private static func deduplicatedTracks(_ tracks: [Track]) -> [Track] {
        var result: [Track] = []
        var seenIDs: Set<String> = []
        for track in tracks where track.isPlayable && seenIDs.insert(track.id).inserted {
            result.append(track)
        }
        return result
    }

    private static func artists(from tracks: [MCPTrackRecord]) -> [MCPArtistRecord] {
        let groups = Dictionary(grouping: tracks) { $0.artist }
        return groups.map { artist, tracks in
            let albums = Set(tracks.map(\.album))
            return MCPArtistRecord(
                id: artist.searchNormalized,
                name: artist,
                trackCount: tracks.count,
                albumCount: albums.count
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func albums(from tracks: [MCPTrackRecord]) -> [MCPAlbumRecord] {
        let groups = Dictionary(grouping: tracks) { "\($0.album)\u{1F}\($0.artist)" }
        return groups.map { _, tracks in
            let first = tracks[0]
            return MCPAlbumRecord(
                id: "\(first.album)::\(first.artist)".searchNormalized,
                title: first.album,
                artist: first.artist,
                trackCount: tracks.count
            )
        }
        .sorted {
            if $0.artist == $1.artist {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
        }
    }

    private static func isoString(from date: Date) -> String {
        ISO8601DateFormatter.noirwaveMCP.string(from: date)
    }

    private static func date(from value: String) -> Date? {
        ISO8601DateFormatter.noirwaveMCP.date(from: value)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

extension ISO8601DateFormatter {
    static var noirwaveMCP: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
