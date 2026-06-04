import AVFoundation
import Foundation
import Security

struct DeemixAPISearchResponse: Decodable {
    let data: [DeemixAPITrackPayload]?
    let total: Int?
    let type: String?
    let error: String?
}

struct DeemixAPIArtistSearchResponse: Decodable {
    let data: [DeemixAPIArtistPayload]?
    let total: Int?
    let type: String?
    let error: String?
}

struct DeemixAPIAlbumSearchResponse: Decodable {
    let data: [DeemixAPIAlbumPayload]?
    let total: Int?
    let type: String?
    let error: String?
}

struct DeemixAPIConnectResponse: Decodable {
    let autologin: Bool?
    let currentUser: DeemixAPILoginUser?
    let deezerAvailable: String?
    let settingsData: DeemixAPISettingsData?
    let singleUser: DeemixAPISingleUserCredentials?
}

struct DeemixAPISingleUserCredentials: Decodable {
    let arl: String?
    let accessToken: String?
}

struct DeemixAPILoginUser: Decodable {
    let id: Int?
    let name: String?
    let picture: String?
    let canStreamHQ: Bool?
    let canStreamLossless: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case picture
        case canStreamHQ = "can_stream_hq"
        case canStreamLossless = "can_stream_lossless"
    }
}

struct DeemixAPILoginArlRequest: Encodable {
    let arl: String
}

struct DeemixAPILoginArlResponse: Decodable {
    let status: Int?
    let arl: String?
    let user: DeemixAPILoginUser?
}

struct DeemixAPISettingsData: Decodable {
    let settings: DeemixAPISettings?
}

struct DeemixAPISettings: Decodable {
    let downloadLocation: String?
    let maxBitrate: Int?
}

extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }

        return nil
    }
}

struct DeemixAPITrackPayload: Decodable, Equatable {
    let id: Int?
    let readable: Bool?
    let title: String?
    let titleShort: String?
    let titleVersion: String?
    let link: String?
    let duration: TimeInterval?
    let rank: Int?
    let explicitLyrics: Bool?
    let preview: String?
    let artist: DeemixAPIArtistPayload?
    let album: DeemixAPIAlbumPayload?
    let trackPosition: Int?
    let discNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case readable
        case title
        case titleShort = "title_short"
        case titleVersion = "title_version"
        case link
        case duration
        case rank
        case explicitLyrics = "explicit_lyrics"
        case preview
        case artist
        case album
        case trackPosition = "track_position"
        case discNumber = "disk_number"
    }

    init(
        id: Int?,
        readable: Bool?,
        title: String?,
        titleShort: String?,
        titleVersion: String?,
        link: String?,
        duration: TimeInterval?,
        rank: Int?,
        explicitLyrics: Bool?,
        preview: String?,
        artist: DeemixAPIArtistPayload?,
        album: DeemixAPIAlbumPayload?,
        trackPosition: Int? = nil,
        discNumber: Int? = nil
    ) {
        self.id = id
        self.readable = readable
        self.title = title
        self.titleShort = titleShort
        self.titleVersion = titleVersion
        self.link = link
        self.duration = duration
        self.rank = rank
        self.explicitLyrics = explicitLyrics
        self.preview = preview
        self.artist = artist
        self.album = album
        self.trackPosition = trackPosition
        self.discNumber = discNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleInt(forKey: .id)
        readable = try container.decodeIfPresent(Bool.self, forKey: .readable)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        titleShort = try container.decodeIfPresent(String.self, forKey: .titleShort)
        titleVersion = try container.decodeIfPresent(String.self, forKey: .titleVersion)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        rank = container.decodeFlexibleInt(forKey: .rank)
        explicitLyrics = try container.decodeIfPresent(Bool.self, forKey: .explicitLyrics)
        preview = try container.decodeIfPresent(String.self, forKey: .preview)
        artist = try container.decodeIfPresent(DeemixAPIArtistPayload.self, forKey: .artist)
        album = try container.decodeIfPresent(DeemixAPIAlbumPayload.self, forKey: .album)
        trackPosition = container.decodeFlexibleInt(forKey: .trackPosition)
        discNumber = container.decodeFlexibleInt(forKey: .discNumber)
    }
}

struct DeemixAPIArtistPayload: Decodable, Equatable {
    let id: Int?
    let name: String?
    let link: String?
    let picture: String?
    let pictureSmall: String?
    let pictureMedium: String?
    let pictureBig: String?
    let pictureXL: String?
    let albumCount: Int?
    let fanCount: Int?
    let tracklist: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case link
        case picture
        case pictureSmall = "picture_small"
        case pictureMedium = "picture_medium"
        case pictureBig = "picture_big"
        case pictureXL = "picture_xl"
        case albumCount = "nb_album"
        case fanCount = "nb_fan"
        case tracklist
    }

    init(
        id: Int?,
        name: String?,
        link: String?,
        picture: String?,
        pictureSmall: String?,
        pictureMedium: String?,
        pictureBig: String? = nil,
        pictureXL: String? = nil,
        albumCount: Int? = nil,
        fanCount: Int? = nil,
        tracklist: String? = nil
    ) {
        self.id = id
        self.name = name
        self.link = link
        self.picture = picture
        self.pictureSmall = pictureSmall
        self.pictureMedium = pictureMedium
        self.pictureBig = pictureBig
        self.pictureXL = pictureXL
        self.albumCount = albumCount
        self.fanCount = fanCount
        self.tracklist = tracklist
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleInt(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        picture = try container.decodeIfPresent(String.self, forKey: .picture)
        pictureSmall = try container.decodeIfPresent(String.self, forKey: .pictureSmall)
        pictureMedium = try container.decodeIfPresent(String.self, forKey: .pictureMedium)
        pictureBig = try container.decodeIfPresent(String.self, forKey: .pictureBig)
        pictureXL = try container.decodeIfPresent(String.self, forKey: .pictureXL)
        albumCount = container.decodeFlexibleInt(forKey: .albumCount)
        fanCount = container.decodeFlexibleInt(forKey: .fanCount)
        tracklist = try container.decodeIfPresent(String.self, forKey: .tracklist)
    }
}

struct DeemixAPIAlbumPayload: Decodable, Equatable {
    let id: Int?
    let title: String?
    let link: String?
    let cover: String?
    let coverSmall: String?
    let coverMedium: String?
    let coverBig: String?
    let coverXL: String?
    let artist: DeemixAPIArtistPayload?
    let trackCount: Int?
    let fanCount: Int?
    let releaseDate: String?
    let recordType: String?
    let rank: Int?
    let tracklist: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case link
        case cover
        case coverSmall = "cover_small"
        case coverMedium = "cover_medium"
        case coverBig = "cover_big"
        case coverXL = "cover_xl"
        case artist
        case trackCount = "nb_tracks"
        case fanCount = "fans"
        case releaseDate = "release_date"
        case recordType = "record_type"
        case rank
        case tracklist
    }

    init(
        id: Int?,
        title: String?,
        link: String?,
        cover: String?,
        coverSmall: String?,
        coverMedium: String?,
        coverBig: String? = nil,
        coverXL: String? = nil,
        artist: DeemixAPIArtistPayload?,
        trackCount: Int? = nil,
        fanCount: Int? = nil,
        releaseDate: String? = nil,
        recordType: String? = nil,
        rank: Int? = nil,
        tracklist: String? = nil
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.cover = cover
        self.coverSmall = coverSmall
        self.coverMedium = coverMedium
        self.coverBig = coverBig
        self.coverXL = coverXL
        self.artist = artist
        self.trackCount = trackCount
        self.fanCount = fanCount
        self.releaseDate = releaseDate
        self.recordType = recordType
        self.rank = rank
        self.tracklist = tracklist
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleInt(forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        coverSmall = try container.decodeIfPresent(String.self, forKey: .coverSmall)
        coverMedium = try container.decodeIfPresent(String.self, forKey: .coverMedium)
        coverBig = try container.decodeIfPresent(String.self, forKey: .coverBig)
        coverXL = try container.decodeIfPresent(String.self, forKey: .coverXL)
        artist = try container.decodeIfPresent(DeemixAPIArtistPayload.self, forKey: .artist)
        trackCount = container.decodeFlexibleInt(forKey: .trackCount)
        fanCount = container.decodeFlexibleInt(forKey: .fanCount)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        recordType = try container.decodeIfPresent(String.self, forKey: .recordType)
        rank = container.decodeFlexibleInt(forKey: .rank)
        tracklist = try container.decodeIfPresent(String.self, forKey: .tracklist)
    }
}

struct DeemixAPIArtistDetailPayload: Decodable {
    let id: Int?
    let name: String?
    let link: String?
    let picture: String?
    let pictureMedium: String?
    let pictureBig: String?
    let pictureXL: String?
    let albumCount: Int?
    let fanCount: Int?
    let tracklist: String?
    let releases: [String: [DeemixAPIAlbumPayload]]?
    let topTracks: [DeemixAPITrackPayload]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case link
        case picture
        case pictureMedium = "picture_medium"
        case pictureBig = "picture_big"
        case pictureXL = "picture_xl"
        case albumCount = "nb_album"
        case fanCount = "nb_fan"
        case tracklist
        case releases
        case topTracks = "top_tracks"
    }

    var artistPayload: DeemixAPIArtistPayload {
        DeemixAPIArtistPayload(
            id: id,
            name: name,
            link: link,
            picture: picture,
            pictureSmall: nil,
            pictureMedium: pictureMedium,
            pictureBig: pictureBig,
            pictureXL: pictureXL,
            albumCount: albumCount,
            fanCount: fanCount,
            tracklist: tracklist
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleInt(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        picture = try container.decodeIfPresent(String.self, forKey: .picture)
        pictureMedium = try container.decodeIfPresent(String.self, forKey: .pictureMedium)
        pictureBig = try container.decodeIfPresent(String.self, forKey: .pictureBig)
        pictureXL = try container.decodeIfPresent(String.self, forKey: .pictureXL)
        albumCount = container.decodeFlexibleInt(forKey: .albumCount)
        fanCount = container.decodeFlexibleInt(forKey: .fanCount)
        tracklist = try container.decodeIfPresent(String.self, forKey: .tracklist)
        releases = try container.decodeIfPresent([String: [DeemixAPIAlbumPayload]].self, forKey: .releases)
        topTracks = try container.decodeIfPresent([DeemixAPITrackPayload].self, forKey: .topTracks)
    }
}

struct DeemixAPIAlbumDetailPayload: Decodable {
    let id: Int?
    let title: String?
    let link: String?
    let cover: String?
    let coverMedium: String?
    let coverBig: String?
    let coverXL: String?
    let artist: DeemixAPIArtistPayload?
    let trackCount: Int?
    let fanCount: Int?
    let releaseDate: String?
    let recordType: String?
    let rank: Int?
    let tracklist: String?
    let tracks: [DeemixAPITrackPayload]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case link
        case cover
        case coverMedium = "cover_medium"
        case coverBig = "cover_big"
        case coverXL = "cover_xl"
        case artist
        case trackCount = "nb_tracks"
        case fanCount = "fans"
        case releaseDate = "release_date"
        case recordType = "record_type"
        case rank
        case tracklist
        case tracks
    }

    var albumPayload: DeemixAPIAlbumPayload {
        DeemixAPIAlbumPayload(
            id: id,
            title: title,
            link: link,
            cover: cover,
            coverSmall: nil,
            coverMedium: coverMedium,
            coverBig: coverBig,
            coverXL: coverXL,
            artist: artist,
            trackCount: trackCount,
            fanCount: fanCount,
            releaseDate: releaseDate,
            recordType: recordType,
            rank: rank,
            tracklist: tracklist
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeFlexibleInt(forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        coverMedium = try container.decodeIfPresent(String.self, forKey: .coverMedium)
        coverBig = try container.decodeIfPresent(String.self, forKey: .coverBig)
        coverXL = try container.decodeIfPresent(String.self, forKey: .coverXL)
        artist = try container.decodeIfPresent(DeemixAPIArtistPayload.self, forKey: .artist)
        trackCount = container.decodeFlexibleInt(forKey: .trackCount)
        fanCount = container.decodeFlexibleInt(forKey: .fanCount)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        recordType = try container.decodeIfPresent(String.self, forKey: .recordType)
        rank = container.decodeFlexibleInt(forKey: .rank)
        tracklist = try container.decodeIfPresent(String.self, forKey: .tracklist)
        tracks = try container.decodeIfPresent([DeemixAPITrackPayload].self, forKey: .tracks)
    }
}

struct DeemixAPIAddToQueueRequest: Encodable {
    let url: String
    let bitrate: Int?
}

struct DeemixAPIAddToQueueResponse: Decodable {
    let result: Bool
    let errid: String?
    let data: DeemixAPIAddToQueueData?
}

struct DeemixAPIPlaybackResponse: Decodable {
    let result: Bool
    let streamURL: String?
    let format: String?
    let errid: String?
    let bitrate: Int?
    let error: String?
}

struct DeemixAPIPrefetchRequest: Encodable {
    let trackIds: [String]
    let format: String?
    let waitForStartup: Bool?
    let timeoutMs: Int?
}

struct DeemixAPIPrefetchResponse: Decodable {
    let result: Bool
    let format: String?
    let warmed: [DeemixAPIPrefetchItem]
}

struct DeemixAPIPrefetchItem: Decodable {
    let result: Bool
    let trackID: String
    let format: String?
    let bitrate: Int?
    let startupBytes: Int?
    let cacheHit: Bool?
    let errid: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case result
        case trackID = "trackId"
        case format
        case bitrate
        case startupBytes
        case cacheHit
        case errid
        case error
    }
}

struct DeemixAPILyricsResponse: Decodable {
    let result: Bool?
    let id: String?
    let available: Bool
    let hasSynced: Bool
    let text: String
    let lines: [DeemixAPILyricsLinePayload]
    let copyright: String?
    let writers: String?

    var trackLyrics: TrackLyrics {
        TrackLyrics(
            text: text,
            lines: lines.map(\.trackLyricsLine),
            copyright: copyright,
            writers: writers
        )
    }
}

struct DeemixAPILyricsLinePayload: Decodable, Equatable {
    let milliseconds: Int
    let duration: Int?
    let text: String

    var trackLyricsLine: TrackLyricsLine {
        TrackLyricsLine(milliseconds: milliseconds, duration: duration, text: text)
    }
}

struct DeemixAPIErrorResponse: Decodable {
    let result: Bool?
    let errid: String?
    let error: String?
    let bitrate: Int?
    let format: String?
}

struct DeemixAPIAddToQueueData: Decodable {
    let url: [String]?
    let bitrate: Int?
    let obj: [DeemixAPIQueueItem]?
}

struct DeemixAPIQueueResponse: Decodable {
    let queue: [String: DeemixAPIQueueItem]?
    let queueOrder: [String]?
    let current: DeemixAPIQueueItem?

    func item(uuid: String) -> DeemixAPIQueueItem? {
        if current?.uuid == uuid {
            return current
        }

        return queue?[uuid]
    }

    func firstItem(withUUIDPrefix prefix: String) -> DeemixAPIQueueItem? {
        let queuedItems = queue.map { Array($0.values) } ?? []
        let candidates = [current].compactMap { $0 } + queuedItems
        return candidates.first { item in
            item.uuid?.hasPrefix(prefix) == true
        }
    }
}

struct DeemixAPIQueueItem: Decodable, Equatable {
    let uuid: String?
    let status: String?
    let size: Int?
    let downloaded: Int?
    let failed: Int?
    let progress: Double?
    let files: [DeemixAPIQueueFile]?
    let extrasPath: String?
    let errors: [DeemixAPIQueueError]?
}

struct DeemixAPIQueueFile: Decodable, Equatable {
    let path: String?
    let filename: String?
}

struct DeemixAPIQueueError: Decodable, Equatable {
    let message: String?
    let error: String?
    let errid: String?
}

enum DeemixAPIDownloadedFileResolver {
    static func fileURL(from item: DeemixAPIQueueItem, fileManager: FileManager = .default) -> URL? {
        for file in item.files ?? [] {
            if let path = file.path?.nonEmpty {
                let url = URL(fileURLWithPath: path)
                if fileManager.fileExists(atPath: url.path) {
                    return url
                }
            }

            if let extrasPath = item.extrasPath?.nonEmpty,
               let filename = file.filename?.nonEmpty {
                let url = URL(fileURLWithPath: extrasPath, isDirectory: true)
                    .appendingPathComponent(filename)
                if fileManager.fileExists(atPath: url.path) {
                    return url
                }
            }
        }

        return nil
    }
}

enum DeemixAPITrackMapper {
    static func map(
        _ payload: DeemixAPITrackPayload,
        fallbackIndex: Int,
        albumContext: DeemixAPIAlbumPayload? = nil,
        artistContext: DeemixAPIArtistPayload? = nil
    ) throws -> Track {
        // The catalog payload keeps preview URLs as metadata only. Playback is
        // resolved by the local stream backend from the Deezer track id.
        guard let link = payload.link?.nonEmpty,
              URL(string: link) != nil
        else {
            throw MusicProviderError.trackUnavailable
        }

        let baseTitle = payload.title?.nonEmpty ?? payload.titleShort?.nonEmpty ?? "Untitled Track"
        let version = payload.titleVersion?.nonEmpty
        let title = version.map { baseTitle.contains($0) ? baseTitle : "\(baseTitle) \($0)" } ?? baseTitle
        let artistPayload = payload.artist ?? artistContext ?? albumContext?.artist
        let albumPayload = payload.album ?? albumContext
        let artist = artistPayload?.name?.nonEmpty ?? "Unknown Artist"
        let album = albumPayload?.title?.nonEmpty ?? "Deezer"
        let id = payload.id.map { "deemix-api.\($0)" } ?? "deemix-api.fallback-\(fallbackIndex)"

        return Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: payload.duration ?? 30,
            palette: palette(for: "\(title)\(artist)\(album)\(fallbackIndex)"),
            catalogID: link,
            previewURL: payload.preview?.nonEmpty,
            kind: .track,
            artworkURL: albumPayload?.coverXL?.nonEmpty
                ?? albumPayload?.coverBig?.nonEmpty
                ?? albumPayload?.coverMedium?.nonEmpty
                ?? albumPayload?.cover?.nonEmpty,
            rank: payload.rank,
            trackPosition: payload.trackPosition,
            discNumber: payload.discNumber
        )
    }

    static func mapArtist(_ payload: DeemixAPIArtistPayload, fallbackIndex: Int) -> Track {
        let name = payload.name?.nonEmpty ?? "Unknown Artist"
        let id = payload.id.map { "deemix-artist.\($0)" } ?? "deemix-artist.fallback-\(fallbackIndex)"
        let link = payload.link?.nonEmpty ?? payload.id.map { "https://www.deezer.com/artist/\($0)" }

        return Track(
            id: id,
            title: name,
            artist: name,
            album: "Artist",
            duration: 0,
            palette: palette(for: "\(name)artist\(fallbackIndex)"),
            catalogID: link,
            previewURL: nil,
            kind: .artist,
            artworkURL: payload.pictureXL?.nonEmpty
                ?? payload.pictureBig?.nonEmpty
                ?? payload.pictureMedium?.nonEmpty
                ?? payload.picture?.nonEmpty,
            fanCount: payload.fanCount,
            albumCount: payload.albumCount
        )
    }

    static func mapAlbum(
        _ payload: DeemixAPIAlbumPayload,
        fallbackIndex: Int,
        artistContext: DeemixAPIArtistPayload? = nil
    ) -> Track {
        let title = payload.title?.nonEmpty ?? "Unknown Album"
        let artist = payload.artist?.name?.nonEmpty ?? artistContext?.name?.nonEmpty ?? "Unknown Artist"
        let id = payload.id.map { "deemix-album.\($0)" } ?? "deemix-album.fallback-\(fallbackIndex)"
        let link = payload.link?.nonEmpty ?? payload.id.map { "https://www.deezer.com/album/\($0)" }

        return Track(
            id: id,
            title: title,
            artist: artist,
            album: "Album",
            duration: 0,
            palette: palette(for: "\(title)\(artist)album\(fallbackIndex)"),
            catalogID: link,
            previewURL: nil,
            kind: .album,
            artworkURL: payload.coverXL?.nonEmpty
                ?? payload.coverBig?.nonEmpty
                ?? payload.coverMedium?.nonEmpty
                ?? payload.cover?.nonEmpty,
            rank: payload.rank,
            fanCount: payload.fanCount,
            trackCount: payload.trackCount,
            releaseDate: payload.releaseDate,
            recordType: payload.recordType
        )
    }

    private static func palette(for seed: String) -> TrackPalette {
        let palettes = [
            TrackPalette(baseHex: "#0D0E12", midHex: "#38433F", accentHex: "#E55E70", inkHex: "#F4F0EA"),
            TrackPalette(baseHex: "#090C10", midHex: "#143D48", accentHex: "#37D1B2", inkHex: "#EAF8F4"),
            TrackPalette(baseHex: "#111016", midHex: "#3C3149", accentHex: "#F0A34A", inkHex: "#FFF3DF"),
            TrackPalette(baseHex: "#0F1110", midHex: "#34402E", accentHex: "#D9E86D", inkHex: "#F6F8DF"),
            TrackPalette(baseHex: "#090909", midHex: "#433232", accentHex: "#FF5B35", inkHex: "#F7E8DF"),
            TrackPalette(baseHex: "#0C0E14", midHex: "#24314B", accentHex: "#5EA8FF", inkHex: "#EEF5FF")
        ]

        let value = seed.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }

        return palettes[value % palettes.count]
    }
}

enum DeemixAPITrackSorter {
    static func sortedByPopularity(_ tracks: [Track]) -> [Track] {
        tracks.sorted { lhs, rhs in
            let lhsRank = lhs.rank ?? 0
            let rhsRank = rhs.rank ?? 0
            if lhsRank == rhsRank {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return lhsRank > rhsRank
        }
    }

    static func sortedByAlbumPosition(_ tracks: [Track]) -> [Track] {
        tracks.sorted { lhs, rhs in
            let lhsDisc = lhs.discNumber ?? 0
            let rhsDisc = rhs.discNumber ?? 0
            if lhsDisc != rhsDisc {
                return lhsDisc < rhsDisc
            }

            let lhsPosition = lhs.trackPosition ?? Int.max
            let rhsPosition = rhs.trackPosition ?? Int.max
            if lhsPosition != rhsPosition {
                return lhsPosition < rhsPosition
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

enum CatalogSearchResultComposer {
    static func catalogResults(term: String, tracks: [Track], artists: [Track]) -> [Track] {
        let rankedArtists = artists
            .filter { $0.kind == .artist }
            .sorted { lhs, rhs in
                let lhsScore = artistScore(lhs, term: term)
                let rhsScore = artistScore(rhs, term: term)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }

                let lhsFans = lhs.fanCount ?? 0
                let rhsFans = rhs.fanCount ?? 0
                if lhsFans != rhsFans {
                    return lhsFans > rhsFans
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(3)

        let rankedTracks = tracks
            .filter(\.isPlayable)
            .sorted { lhs, rhs in
                let lhsScore = trackScore(lhs, term: term)
                let rhsScore = trackScore(rhs, term: term)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }

                let lhsRank = lhs.rank ?? 0
                let rhsRank = rhs.rank ?? 0
                if lhsRank != rhsRank {
                    return lhsRank > rhsRank
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        return Array(rankedArtists) + rankedTracks
    }

    private static func artistScore(_ artist: Track, term: String) -> Int {
        let query = normalized(term)
        guard !query.isEmpty else {
            return 0
        }

        let tokens = queryTokens(query)
        let title = normalized(artist.title)

        if title == query {
            return 100
        }

        if title.contains(query) {
            return 90
        }

        if containsAll(tokens, in: title) {
            return 80
        }

        return 0
    }

    private static func trackScore(_ track: Track, term: String) -> Int {
        let query = normalized(term)
        guard !query.isEmpty else {
            return 0
        }

        let tokens = queryTokens(query)
        let title = normalized(track.title)
        let artist = normalized(track.artist)
        let album = normalized(track.album)

        if title == query {
            return 100
        }

        if title.contains(query) {
            return 90
        }

        if containsAll(tokens, in: title) {
            return 80
        }

        if artist == query {
            return 75
        }

        if artist.contains(query) {
            return 70
        }

        if containsAll(tokens, in: artist) {
            return 65
        }

        if album.contains(query) {
            return 50
        }

        if containsAll(tokens, in: [title, artist, album].joined(separator: " ")) {
            return 40
        }

        return 0
    }

    private static func containsAll(_ tokens: [String], in value: String) -> Bool {
        !tokens.isEmpty && tokens.allSatisfy { value.contains($0) }
    }

    private static func queryTokens(_ value: String) -> [String] {
        value.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmed
            .lowercased()
    }
}

enum DeemixAPIMediaSorter {
    static func sortedArtistsByAudience(_ artists: [Track]) -> [Track] {
        artists.sorted { lhs, rhs in
            let lhsFans = lhs.fanCount ?? 0
            let rhsFans = rhs.fanCount ?? 0
            if lhsFans == rhsFans {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return lhsFans > rhsFans
        }
    }

    static func sortedAlbumsForArtist(_ albums: [Track]) -> [Track] {
        albums.sorted { lhs, rhs in
            let lhsDate = lhs.releaseDate ?? ""
            let rhsDate = rhs.releaseDate ?? ""
            if lhsDate == rhsDate {
                return (lhs.rank ?? 0) > (rhs.rank ?? 0)
            }

            return lhsDate > rhsDate
        }
    }
}

enum DeemixAPIPlaybackFailureMapper {
    static func error(from response: DeemixAPIAddToQueueResponse) -> MusicProviderError {
        switch response.errid {
        case "NotLoggedIn":
            return .providerNotReady("Backend session inactive.")
        case "CantStream":
            let bitrate = response.data?.bitrate.map { DeemixAPIBitrate.displayLabel(for: $0) } ?? "selected bitrate"
            return .providerNotReady("The current Deezer session cannot stream \(bitrate).")
        case let errid?:
            return .providerNotReady("Backend playback failed: \(errid).")
        case nil:
            return .providerNotReady("Backend playback failed.")
        }
    }

    static func error(from response: DeemixAPIPlaybackResponse) -> MusicProviderError {
        error(errid: response.errid, bitrate: response.bitrate, message: response.error)
    }

    static func error(from response: DeemixAPIErrorResponse) -> MusicProviderError {
        error(errid: response.errid, bitrate: response.bitrate, message: response.error)
    }

    private static func error(errid: String?, bitrate: Int?, message: String?) -> MusicProviderError {
        switch errid {
        case "NetworkUnavailable":
            return .providerNotReady("Deezer network request timed out. Try again in a moment.")
        case "CatalogTimeout":
            return .providerNotReady("Catalog request timed out. Try a narrower search.")
        case "NotLoggedIn":
            return .providerNotReady("Backend session inactive.")
        case "CantStream":
            let bitrate = bitrate.map { DeemixAPIBitrate.displayLabel(for: $0) } ?? "selected bitrate"
            return .providerNotReady("The current Deezer session cannot stream \(bitrate).")
        case let errid?:
            return .providerNotReady(message?.nonEmpty ?? "Backend playback failed: \(errid).")
        case nil:
            return .providerNotReady(message?.nonEmpty ?? "Backend playback failed.")
        }
    }
}

enum DeemixAPIBitrate {
    static let mp3_320 = 3
    static let mp3_128 = 1
    static let fullTrackPlaybackPreferences = [mp3_320]

    static func displayLabel(for bitrate: Int) -> String {
        switch bitrate {
        case mp3_320:
            "320 kbps"
        case mp3_128:
            "128 kbps"
        default:
            "\(bitrate)"
        }
    }
}

enum DeemixAPIPlaybackURLResolver {
    static func previewURL(for track: Track) -> URL? {
        guard let value = track.previewURL?.nonEmpty,
              let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased())
        else {
            return nil
        }

        return url
    }

    static func shouldUsePreviewFallback(after _: Error) -> Bool {
        false
    }
}

enum DeemixAPIStreamURLResolver {
    static func streamURL(baseURL: URL, track: Track, format: String? = nil) throws -> URL {
        guard let trackID = deezerTrackID(from: track) else {
            throw MusicProviderError.trackUnavailable
        }

        return try streamURL(baseURL: baseURL, trackID: trackID, format: format)
    }

    static func streamURL(baseURL: URL, trackID: String, format: String? = nil) throws -> URL {
        guard trackID.range(of: #"^\d+$"#, options: .regularExpression) != nil else {
            throw MusicProviderError.trackUnavailable
        }

        guard var components = URLComponents(
            url: baseURL
                .appendingPathComponent("api")
                .appendingPathComponent("stream")
                .appendingPathComponent(trackID),
            resolvingAgainstBaseURL: false
        ) else {
            throw MusicProviderError.providerNotReady("Invalid backend stream URL.")
        }

        if let format = format?.nonEmpty {
            components.queryItems = [URLQueryItem(name: "format", value: format)]
        }

        guard let url = components.url else {
            throw MusicProviderError.providerNotReady("Invalid backend stream request.")
        }

        return url
    }

    private static func deezerTrackID(from track: Track) -> String? {
        guard track.id.hasPrefix("deemix-api.") else {
            return nil
        }

        let id = String(track.id.dropFirst("deemix-api.".count))
        return id.hasPrefix("fallback-") ? nil : id
    }
}

enum DeemixAPISessionSecret {
    private static let minimumLength = 32

    static func normalizedARL(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= minimumLength,
              normalized.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else {
            return nil
        }

        return normalized
    }
}

enum DeemixAPISessionVaultError: LocalizedError {
    case invalidARL
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidARL:
            "Enter a valid Deezer session token."
        case .keychainFailure(let status):
            "Could not save Deezer session in Keychain (status \(status))."
        }
    }
}

struct DeemixAPISessionVault {
    static let app = DeemixAPISessionVault(
        service: "com.fsociety.noirwave.deezer",
        account: "arl"
    )

    let service: String
    let account: String

    func savedARL() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw DeemixAPISessionVaultError.keychainFailure(status)
        }

        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return DeemixAPISessionSecret.normalizedARL(value)
    }

    func saveARL(_ value: String) throws {
        guard let normalizedARL = DeemixAPISessionSecret.normalizedARL(value) else {
            throw DeemixAPISessionVaultError.invalidARL
        }

        let data = Data(normalizedARL.utf8)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw DeemixAPISessionVaultError.keychainFailure(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw DeemixAPISessionVaultError.keychainFailure(addStatus)
        }
    }

    func deleteSavedARL() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeemixAPISessionVaultError.keychainFailure(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum DeemixAPISessionState {
    static func playbackMessage(autologin: Bool?, savedARL: String?) -> String {
        if autologin != true {
            return "playback session ready"
        }

        return DeemixAPISessionSecret.normalizedARL(savedARL ?? "") == nil
            ? "playback session inactive"
            : "playback session ready"
    }
}

struct DeemixAPIClient {
    let baseURL: URL
    var session: URLSession = .shared
    private let requestTimeout: TimeInterval = 45

    func connect() async throws -> DeemixAPIConnectResponse {
        try await get("connect", queryItems: [])
    }

    func searchTracks(term: String, start: Int = 0, count: Int = 30) async throws -> [DeemixAPITrackPayload] {
        let response: DeemixAPISearchResponse = try await get(
            "search",
            queryItems: [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "type", value: "track"),
                URLQueryItem(name: "start", value: String(start)),
                URLQueryItem(name: "nb", value: String(count))
            ]
        )

        if let error = response.error?.nonEmpty {
            throw MusicProviderError.providerNotReady(error)
        }

        return response.data ?? []
    }

    func searchArtists(term: String, start: Int = 0, count: Int = 30) async throws -> [DeemixAPIArtistPayload] {
        let response: DeemixAPIArtistSearchResponse = try await get(
            "search",
            queryItems: [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "type", value: "artist"),
                URLQueryItem(name: "start", value: String(start)),
                URLQueryItem(name: "nb", value: String(count))
            ]
        )

        if let error = response.error?.nonEmpty {
            throw MusicProviderError.providerNotReady(error)
        }

        return response.data ?? []
    }

    func searchAlbums(term: String, start: Int = 0, count: Int = 30) async throws -> [DeemixAPIAlbumPayload] {
        let response: DeemixAPIAlbumSearchResponse = try await get(
            "search",
            queryItems: [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "type", value: "album"),
                URLQueryItem(name: "start", value: String(start)),
                URLQueryItem(name: "nb", value: String(count))
            ]
        )

        if let error = response.error?.nonEmpty {
            throw MusicProviderError.providerNotReady(error)
        }

        return response.data ?? []
    }

    func artistDetail(id: String) async throws -> DeemixAPIArtistDetailPayload {
        try await get(
            "getTracklist",
            queryItems: [
                URLQueryItem(name: "type", value: "artist"),
                URLQueryItem(name: "id", value: id)
            ]
        )
    }

    func albumDetail(id: String) async throws -> DeemixAPIAlbumDetailPayload {
        try await get(
            "getTracklist",
            queryItems: [
                URLQueryItem(name: "type", value: "album"),
                URLQueryItem(name: "id", value: id)
            ]
        )
    }

    func addToQueue(url: String, bitrate: Int? = nil) async throws -> DeemixAPIAddToQueueResponse {
        try await post("addToQueue", body: DeemixAPIAddToQueueRequest(url: url, bitrate: bitrate))
    }

    func loginArl(_ arl: String) async throws -> DeemixAPILoginArlResponse {
        try await post("loginArl", body: DeemixAPILoginArlRequest(arl: arl))
    }

    func queue() async throws -> DeemixAPIQueueResponse {
        try await get("getQueue", queryItems: [])
    }

    func playback(trackID: String) async throws -> DeemixAPIPlaybackResponse {
        try await get("playback/\(trackID)", queryItems: [])
    }

    func prefetch(
        trackIDs: [String],
        format: String? = "MP3_320",
        waitForStartup: Bool? = nil,
        timeoutMs: Int? = nil
    ) async throws -> DeemixAPIPrefetchResponse {
        try await post(
            "prefetch",
            body: DeemixAPIPrefetchRequest(
                trackIds: trackIDs,
                format: format,
                waitForStartup: waitForStartup,
                timeoutMs: timeoutMs
            )
        )
    }

    func streamURL(trackID: String, format: String? = nil) throws -> URL {
        try DeemixAPIStreamURLResolver.streamURL(baseURL: baseURL, trackID: trackID, format: format)
    }

    func lyrics(trackID: String) async throws -> DeemixAPILyricsResponse {
        try await get("lyrics/\(trackID)", queryItems: [])
    }

    private func get<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api").appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        ) else {
            throw MusicProviderError.providerNotReady("Invalid backend API URL.")
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw MusicProviderError.providerNotReady("Invalid backend API request.")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            if let error = try? JSONDecoder().decode(DeemixAPIErrorResponse.self, from: data) {
                throw DeemixAPIPlaybackFailureMapper.error(from: error)
            }
            throw MusicProviderError.providerNotReady("Backend API did not accept the request.")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable, Body: Encodable>(_ endpoint: String, body: Body) async throws -> T {
        let url = baseURL.appendingPathComponent("api").appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            if let error = try? JSONDecoder().decode(DeemixAPIErrorResponse.self, from: data) {
                throw DeemixAPIPlaybackFailureMapper.error(from: error)
            }
            throw MusicProviderError.providerNotReady("Backend API did not accept the request.")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

@MainActor
final class DeemixAPIProvider: MusicProviding {
    let sourceName = "Deezer Stream"

    private static let apiBaseEnvironmentKey = "NOIRWAVE_BACKEND_API_BASE"
    private static let arlEnvironmentKey = "NOIRWAVE_DEEZER_ARL"
    private let client: DeemixAPIClient
    private let downloadTimeout: TimeInterval
    private let immediatePlaybackPrefetchTimeoutMs = 350
    private let sessionVault: DeemixAPISessionVault
    private var player: AVPlayer?
    private var lastPlaybackFileURL: URL?
    private var didAttemptDownloadLogin = false

    private let seedQueries = [
        "Daft Punk Around the World",
        "Nirvana Come As You Are"
    ]

    init(
        client: DeemixAPIClient = DeemixAPIClient(baseURL: DeemixAPIProvider.defaultBaseURL()),
        downloadTimeout: TimeInterval = 180,
        sessionVault: DeemixAPISessionVault = .app
    ) {
        self.client = client
        self.downloadTimeout = downloadTimeout
        self.sessionVault = sessionVault
    }

    func featuredTracks() async throws -> [Track] {
        var tracks: [Track] = []

        for query in seedQueries {
            let payloads = try await client.searchTracks(term: query, count: 2)
            let mappedTracks = payloads.enumerated().compactMap { index, payload in
                try? DeemixAPITrackMapper.map(payload, fallbackIndex: tracks.count + index)
            }
            tracks.append(contentsOf: mappedTracks.prefix(1))
        }

        if !tracks.isEmpty {
            return tracks
        }

        return try await search("electronic", scope: .catalog)
    }

    func search(_ query: String, scope: SearchScope) async throws -> [Track] {
        let term = query.trimmed
        guard !term.isEmpty else {
            return []
        }

        switch scope {
        case .catalog:
            async let trackPayloads = client.searchTracks(term: term, count: 30)
            async let artistPayloads = client.searchArtists(term: term, count: 6)

            let payloads = try await trackPayloads
            let tracks = payloads.enumerated().compactMap { index, payload in
                try? DeemixAPITrackMapper.map(payload, fallbackIndex: index)
            }
            let artists = ((try? await artistPayloads) ?? []).enumerated().map { index, payload in
                DeemixAPITrackMapper.mapArtist(payload, fallbackIndex: index)
            }
            return CatalogSearchResultComposer.catalogResults(term: term, tracks: tracks, artists: artists)
        case .library:
            let payloads = try await client.searchArtists(term: term, count: 30)
            let artists = payloads.enumerated().map { index, payload in
                DeemixAPITrackMapper.mapArtist(payload, fallbackIndex: index)
            }
            return DeemixAPIMediaSorter.sortedArtistsByAudience(artists)
        case .playlists:
            let payloads = try await client.searchAlbums(term: term, count: 30)
            let albums = payloads.enumerated().map { index, payload in
                DeemixAPITrackMapper.mapAlbum(payload, fallbackIndex: index)
            }
            return DeemixAPIMediaSorter.sortedAlbumsForArtist(albums)
        }
    }

    func catalogItems(for item: Track) async throws -> [Track] {
        switch item.kind {
        case .track:
            return [item]
        case .artist:
            guard let artistID = deemixID(from: item, prefix: "deemix-artist.") else {
                return try await search(item.title, scope: .catalog)
            }

            let detail = try await client.artistDetail(id: artistID)
            let artistPayload = detail.artistPayload
            let popularTracks: [Track]
            if let topTrackPayloads = detail.topTracks {
                popularTracks = topTrackPayloads.enumerated().compactMap { index, payload in
                    try? DeemixAPITrackMapper.map(payload, fallbackIndex: index, artistContext: artistPayload)
                }
            } else {
                popularTracks = try await artistTopTracks(artistPayload)
            }
            let releases = (detail.releases?["all"] ?? detail.releases?.values.flatMap { $0 } ?? [])
            let uniqueAlbums = deduplicatedAlbums(releases)
            let albums = uniqueAlbums.enumerated().map { index, payload in
                DeemixAPITrackMapper.mapAlbum(payload, fallbackIndex: index, artistContext: artistPayload)
            }

            let topTracks = Array(DeemixAPITrackSorter.sortedByPopularity(popularTracks).prefix(12))
            return topTracks + DeemixAPIMediaSorter.sortedAlbumsForArtist(albums)
        case .album:
            guard let albumID = deemixID(from: item, prefix: "deemix-album.") else {
                return try await search([item.title, item.artist].joined(separator: " "), scope: .catalog)
            }

            let detail = try await client.albumDetail(id: albumID)
            let albumPayload = detail.albumPayload
            let tracks = (detail.tracks ?? []).enumerated().compactMap { index, payload in
                try? DeemixAPITrackMapper.map(payload, fallbackIndex: index, albumContext: albumPayload)
            }
            return DeemixAPITrackSorter.sortedByAlbumPosition(tracks)
        }
    }

    func requestAuthorization() async throws -> ProviderStatus {
        try await currentStatus()
    }

    func currentStatus() async throws -> ProviderStatus {
        do {
            let response = try await client.connect()
            return providerStatus(from: response)
        } catch {
            if let restoredStatus = await restoreSavedSessionStatus() {
                return restoredStatus
            }

            if Self.isMissingSessionError(error) {
                return ProviderStatus(
                    authorization: .authorized,
                    canPlayCatalogContent: false,
                    message: "Backend session inactive."
                )
            }

            return ProviderStatus(
                authorization: .unsupported,
                canPlayCatalogContent: false,
                message: "Start local stream service on \(client.baseURL.absoluteString)."
            )
        }
    }

    func configureBackendSession(arl: String) async throws -> ProviderStatus {
        guard let normalizedARL = DeemixAPISessionSecret.normalizedARL(arl) else {
            throw MusicProviderError.providerNotReady("Enter a valid Deezer session token.")
        }

        try await activateBackendSession(normalizedARL)
        try sessionVault.saveARL(normalizedARL)
        return try await currentStatus()
    }

    func lyrics(for track: Track) async throws -> TrackLyrics {
        guard let trackID = deezerTrackID(from: track) else {
            throw MusicProviderError.trackUnavailable
        }

        let response = try await client.lyrics(trackID: trackID)
        return response.available ? response.trackLyrics : TrackLyrics(text: "", lines: [], copyright: nil, writers: nil)
    }

    func prepare(_ tracks: [Track]) async {
        var seenTrackIDs = Set<String>()
        let trackIDs = tracks.compactMap { track -> String? in
            guard let trackID = deezerTrackID(from: track),
                  seenTrackIDs.insert(trackID).inserted
            else { return nil }

            return trackID
        }

        guard !trackIDs.isEmpty else { return }
        _ = try? await client.prefetch(trackIDs: trackIDs)
    }

    private func prepareForImmediatePlayback(_ track: Track) async {
        guard let trackID = deezerTrackID(from: track) else { return }

        _ = try? await client.prefetch(
            trackIDs: [trackID],
            waitForStartup: true,
            timeoutMs: immediatePlaybackPrefetchTimeoutMs
        )
    }

    func play(_ track: Track) async throws {
        guard track.isPlayable else {
            throw MusicProviderError.trackUnavailable
        }

        await prepareForImmediatePlayback(track)

        let playbackURL = try DeemixAPIStreamURLResolver.streamURL(baseURL: client.baseURL, track: track)
        let item = AVPlayerItem(url: playbackURL)
        item.preferredForwardBufferDuration = 0.75
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        let streamPlayer = AVPlayer(playerItem: item)
        streamPlayer.automaticallyWaitsToMinimizeStalling = false

        cleanupLastPlaybackFile()
        player = streamPlayer
        lastPlaybackFileURL = nil
        streamPlayer.playImmediately(atRate: 1)
        try await waitUntilPlaybackAccepted(item, player: streamPlayer)
    }

    func resume() async throws {
        guard let player else {
            throw MusicProviderError.trackUnavailable
        }

        player.play()
    }

    func pause() async {
        player?.pause()
    }

    func stop() async {
        player?.pause()
        player = nil
        cleanupLastPlaybackFile()
    }

    func seek(to time: TimeInterval) async {
        await player?.seek(to: CMTime(seconds: max(time, 0), preferredTimescale: 600))
    }

    func currentPlaybackTime() -> TimeInterval? {
        let seconds = player?.currentTime().seconds
        return seconds?.isFinite == true ? seconds : nil
    }

    private func providerStatus(from response: DeemixAPIConnectResponse) -> ProviderStatus {
        let available = response.deezerAvailable ?? "unknown"
        let savedARL = ProcessInfo.processInfo.environment[Self.arlEnvironmentKey]
            ?? (try? sessionVault.savedARL())
            ?? response.singleUser?.arl
        let loginMessage = DeemixAPISessionState.playbackMessage(
            autologin: response.autologin,
            savedARL: savedARL
        )
        let qualityMessage = response.currentUser?.canStreamHQ == false
            ? "MP3 320 required; session reports HQ unavailable"
            : "MP3 320 ready"

        return ProviderStatus(
            authorization: .authorized,
            canPlayCatalogContent: true,
            message: "Source ready: \(available), \(loginMessage), \(qualityMessage)"
        )
    }

    private func restoreSavedSessionStatus() async -> ProviderStatus? {
        guard let savedARL = try? sessionVault.savedARL() else {
            return nil
        }

        do {
            try await activateBackendSession(savedARL)
            return providerStatus(from: try await client.connect())
        } catch {
            return nil
        }
    }

    private func activateBackendSession(_ arl: String) async throws {
        let login = try await client.loginArl(arl)
        guard let status = login.status,
              [1, 2, 3].contains(status)
        else {
            throw MusicProviderError.providerNotReady("Backend session activation failed.")
        }

        didAttemptDownloadLogin = false
    }

    private static func isMissingSessionError(_ error: Error) -> Bool {
        let message = error.localizedDescription
        return message.localizedCaseInsensitiveContains("no deezer session")
            || message.localizedCaseInsensitiveContains("session inactive")
            || message.localizedCaseInsensitiveContains("session token")
            || message.localizedCaseInsensitiveContains("notloggedin")
    }

    private static func defaultBaseURL() -> URL {
        if let value = ProcessInfo.processInfo.environment[apiBaseEnvironmentKey],
           let url = URL(string: value) {
            return url
        }

        return URL(string: "http://127.0.0.1:6605")!
    }

    private func fullTrackURL(for track: Track) async throws -> URL {
        guard let trackID = deezerTrackID(from: track) else {
            throw MusicProviderError.trackUnavailable
        }

        let response = try await client.playback(trackID: trackID)
        guard response.result else {
            throw DeemixAPIPlaybackFailureMapper.error(from: response)
        }

        guard let value = response.streamURL?.nonEmpty,
              let url = URL(string: value)
        else {
            throw MusicProviderError.providerNotReady("Backend did not return a stream URL.")
        }

        return url
    }

    private func waitUntilPlaybackAccepted(
        _ item: AVPlayerItem,
        player: AVPlayer,
        timeout: TimeInterval = 1.5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            try Task.checkCancellation()

            switch item.status {
            case .readyToPlay:
                if player.timeControlStatus == .playing {
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            case .failed:
                throw MusicProviderError.providerNotReady(
                    item.error?.localizedDescription.nonEmpty ?? "Backend stream failed before audio playback."
                )
            case .unknown:
                if player.timeControlStatus == .playing {
                    return
                }
                try await Task.sleep(for: .milliseconds(100))
            @unknown default:
                throw MusicProviderError.playbackDidNotStart("unknown AVPlayerItem status")
            }
        }

        if item.status == .failed {
            throw MusicProviderError.providerNotReady(
                item.error?.localizedDescription.nonEmpty ?? "Backend stream failed before audio playback."
            )
        }

        if player.timeControlStatus != .playing {
            throw MusicProviderError.playbackDidNotStart(player.timeControlStatus.noirwaveDescription)
        }
    }

    private func existingDownloadedFileURL(for track: Track) async throws -> URL? {
        guard let exactUUID = expectedQueueUUID(for: track, bitrate: DeemixAPIBitrate.mp3_320) else {
            return nil
        }

        let queue = try await client.queue()
        guard let item = queue.item(uuid: exactUUID) else {
            return nil
        }

        return DeemixAPIDownloadedFileResolver.fileURL(from: item)
    }

    private func ensureDownloadSession() async throws {
        let response = try await client.connect()
        guard response.autologin == true else {
            return
        }

        guard !didAttemptDownloadLogin else {
            throw MusicProviderError.providerNotReady("Backend session inactive.")
        }

        didAttemptDownloadLogin = true

        guard let arl = ProcessInfo.processInfo.environment[Self.arlEnvironmentKey]?.nonEmpty
            ?? response.singleUser?.arl?.nonEmpty
        else {
            throw MusicProviderError.providerNotReady("Backend session inactive.")
        }

        let login = try await client.loginArl(arl)
        guard let status = login.status,
              [1, 2, 3].contains(status)
        else {
            throw MusicProviderError.providerNotReady("Backend session expired.")
        }
    }

    private func waitForDownloadedFile(uuid: String, track: Track) async throws -> URL {
        let deadline = Date().addingTimeInterval(downloadTimeout)
        var lastStatus = "queued"

        while Date() < deadline {
            try Task.checkCancellation()

            let queue = try await client.queue()
            if let item = queue.item(uuid: uuid) {
                if let fileURL = DeemixAPIDownloadedFileResolver.fileURL(from: item) {
                    return fileURL
                }

                lastStatus = item.status ?? lastStatus
                if ["failed", "withErrors"].contains(lastStatus) {
                    throw MusicProviderError.providerNotReady(downloadFailureMessage(for: item, track: track))
                }
            }

            try await Task.sleep(for: .seconds(1))
        }

        throw MusicProviderError.providerNotReady(
            "Timed out waiting for backend playback cache for \(track.artist) - \(track.title). Last queue status: \(lastStatus)."
        )
    }

    private func expectedQueueUUID(for track: Track, bitrate: Int?) -> String? {
        guard let deezerTrackID = deezerTrackID(from: track),
              let bitrate
        else {
            return nil
        }

        return "track_\(deezerTrackID)_\(bitrate)"
    }

    private func deezerTrackID(from track: Track) -> String? {
        deemixID(from: track, prefix: "deemix-api.")
    }

    private func deemixID(from track: Track, prefix: String) -> String? {
        guard track.id.hasPrefix(prefix) else {
            return nil
        }

        let id = String(track.id.dropFirst(prefix.count))
        return id.hasPrefix("fallback-") ? nil : id
    }

    private func artistTopTracks(_ artist: DeemixAPIArtistPayload) async throws -> [Track] {
        let term = artist.name?.nonEmpty ?? ""
        guard !term.isEmpty else { return [] }

        let payloads = try await client.searchTracks(term: term, count: 50)
        return payloads.enumerated().compactMap { index, payload in
            let sameArtistID = payload.artist?.id == artist.id
            let sameArtistName = payload.artist?.name?.localizedCaseInsensitiveCompare(term) == .orderedSame
            guard sameArtistID || sameArtistName else { return nil }
            return try? DeemixAPITrackMapper.map(payload, fallbackIndex: index, artistContext: artist)
        }
    }

    private func deduplicatedAlbums(_ payloads: [DeemixAPIAlbumPayload]) -> [DeemixAPIAlbumPayload] {
        var seenIDs = Set<Int>()
        return payloads.filter { payload in
            guard let id = payload.id else { return true }
            return seenIDs.insert(id).inserted
        }
    }

    private func cleanupLastPlaybackFile(except currentURL: URL? = nil) {
        guard let lastPlaybackFileURL,
              lastPlaybackFileURL != currentURL,
              isPlaybackCacheFile(lastPlaybackFileURL)
        else {
            return
        }

        try? FileManager.default.removeItem(at: lastPlaybackFileURL)
        self.lastPlaybackFileURL = nil
    }

    private func isPlaybackCacheFile(_ url: URL) -> Bool {
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Noirwave", isDirectory: true)
            .appendingPathComponent("DeemixStreamCache", isDirectory: true)
            .standardizedFileURL

        guard let cacheRoot else { return false }
        return url.standardizedFileURL.path.hasPrefix(cacheRoot.path)
    }

    private func addToQueueError(from response: DeemixAPIAddToQueueResponse) -> MusicProviderError {
        DeemixAPIPlaybackFailureMapper.error(from: response)
    }

    private func downloadFailureMessage(for item: DeemixAPIQueueItem, track: Track) -> String {
        if let message = item.errors?.compactMap(\.message).first(where: { !$0.isEmpty }) {
            return message
        }

        if let errid = item.errors?.compactMap(\.errid).first(where: { !$0.isEmpty }) {
            return "Backend failed to cache \(track.artist) - \(track.title): \(errid)."
        }

        return "Backend failed to cache \(track.artist) - \(track.title)."
    }
}

private extension AVPlayer.TimeControlStatus {
    var noirwaveDescription: String {
        switch self {
        case .paused:
            "paused"
        case .waitingToPlayAtSpecifiedRate:
            "waiting for backend stream"
        case .playing:
            "playing"
        @unknown default:
            "unknown"
        }
    }
}
