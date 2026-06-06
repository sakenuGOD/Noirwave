import SwiftUI

enum TrackKind: String, Codable, Hashable {
    case track = "Track"
    case artist = "Artist"
    case album = "Album"

    var systemImage: String {
        switch self {
        case .track:
            "music.note"
        case .artist:
            "music.mic"
        case .album:
            "square.stack"
        }
    }
}

struct Track: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let palette: TrackPalette
    let catalogID: String?
    let previewURL: String?
    let kind: TrackKind
    let artworkURL: String?
    let rank: Int?
    let fanCount: Int?
    let albumCount: Int?
    let trackCount: Int?
    let releaseDate: String?
    let recordType: String?
    let trackPosition: Int?
    let discNumber: Int?

    init(
        id: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        palette: TrackPalette,
        catalogID: String?,
        previewURL: String?,
        kind: TrackKind = .track,
        artworkURL: String? = nil,
        rank: Int? = nil,
        fanCount: Int? = nil,
        albumCount: Int? = nil,
        trackCount: Int? = nil,
        releaseDate: String? = nil,
        recordType: String? = nil,
        trackPosition: Int? = nil,
        discNumber: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.palette = palette
        self.catalogID = catalogID
        self.previewURL = previewURL
        self.kind = kind
        self.artworkURL = artworkURL
        self.rank = rank
        self.fanCount = fanCount
        self.albumCount = albumCount
        self.trackCount = trackCount
        self.releaseDate = releaseDate
        self.recordType = recordType
        self.trackPosition = trackPosition
        self.discNumber = discNumber
    }

    var durationLabel: String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }

    var isPlayable: Bool {
        kind == .track
    }

    var detailLabel: String {
        switch kind {
        case .track:
            return "\(artist) · \(album)"
        case .artist:
            let listeners = fanCount.map { "\($0.compactCountLabel) listeners" }
            let albums = albumCount.map { "\($0) album\($0 == 1 ? "" : "s")" }
            return [listeners, albums].compactMap(\.self).joined(separator: " · ").nonEmpty ?? "Artist"
        case .album:
            let type = recordType?.displayRecordType ?? "Album"
            let tracks = trackCount.map { "\($0) track\($0 == 1 ? "" : "s")" }
            let year = releaseDate?.releaseYear
            let metadata = [artist == "Unknown Artist" ? nil : artist, type, tracks, year]
                .compactMap { $0?.nonEmpty }
                .joined(separator: " · ")
            return metadata.nonEmpty ?? "Album"
        }
    }
}

struct LocalPlaylist: Codable, Identifiable, Hashable {
    static let fallbackTitle = "New Playlist"

    let id: String
    var title: String
    var trackIDs: [String]
    var trackSnapshots: [String: Track]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        tracks: [Track] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = Self.normalizedTitle(title)
        self.trackIDs = []
        self.trackSnapshots = [:]
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        append(tracks, updatedAt: updatedAt)
    }

    var trackCount: Int {
        trackIDs.count
    }

    var artworkTracks: [Track] {
        Array(orderedTracks(preferredTracks: []).prefix(4))
    }

    func orderedTracks(preferredTracks: [Track]) -> [Track] {
        let trackedIDs = Set(trackIDs)
        var trackByID = trackSnapshots.filter { trackedIDs.contains($0.key) }
        for track in preferredTracks where trackedIDs.contains(track.id) {
            trackByID[track.id] = track
        }

        var seenIDs: Set<String> = []
        return trackIDs.compactMap { id in
            guard seenIDs.insert(id).inserted,
                  let track = trackByID[id],
                  track.isPlayable
            else { return nil }

            return track
        }
    }

    mutating func rename(to title: String, updatedAt: Date = Date()) -> Bool {
        let normalizedTitle = Self.normalizedTitle(title)
        guard normalizedTitle != self.title else { return false }

        self.title = normalizedTitle
        self.updatedAt = updatedAt
        return true
    }

    mutating func append(_ track: Track, updatedAt: Date = Date()) -> Bool {
        append([track], updatedAt: updatedAt)
    }

    @discardableResult
    mutating func append(_ tracks: [Track], updatedAt: Date = Date()) -> Bool {
        var changed = false
        var existingIDs = Set(trackIDs)

        for track in tracks {
            guard track.isPlayable,
                  existingIDs.insert(track.id).inserted
            else { continue }

            trackIDs.append(track.id)
            trackSnapshots[track.id] = track
            changed = true
        }

        if changed {
            self.updatedAt = updatedAt
        }

        return changed
    }

    @discardableResult
    mutating func remove(_ track: Track, updatedAt: Date = Date()) -> Bool {
        let originalCount = trackIDs.count
        trackIDs.removeAll { $0 == track.id }
        trackSnapshots.removeValue(forKey: track.id)
        guard trackIDs.count != originalCount else { return false }

        self.updatedAt = updatedAt
        return true
    }

    mutating func normalize() {
        title = Self.normalizedTitle(title)

        var seenIDs: Set<String> = []
        trackIDs = trackIDs.filter { seenIDs.insert($0).inserted }
        let validIDs = Set(trackIDs)
        trackSnapshots = trackSnapshots.filter { validIDs.contains($0.key) && $0.value.isPlayable }
    }

    static func normalizedTitle(_ title: String) -> String {
        title.nonEmpty ?? fallbackTitle
    }
}

struct ArtistReleaseGroups: Equatable {
    let studioAlbums: [Track]
    let otherReleases: [Track]
}

enum ArtistReleaseClassifier {
    private static let liveMarkers = Set(["live", "unplugged", "session", "sessions"])
    private static let reissueMarkers = Set(["deluxe", "expanded", "anniversary", "edition", "bonus", "demo", "demos", "outtake", "outtakes"])
    private static let compilationMarkers = Set(["collection", "anthology", "rarities"])

    static func groups(from releases: [Track]) -> ArtistReleaseGroups {
        var studioKeys: [String] = []
        var studioByKey: [String: Track] = [:]
        var otherReleases: [Track] = []

        for release in releases where release.kind == .album {
            let key = canonicalReleaseKey(release.title)
            guard !key.isEmpty, isStudioAlbumCandidate(release) else {
                otherReleases.append(release)
                continue
            }

            if let current = studioByKey[key] {
                if prefersStudioRelease(release, over: current) {
                    studioByKey[key] = release
                    otherReleases.append(current)
                } else {
                    otherReleases.append(release)
                }
            } else {
                studioKeys.append(key)
                studioByKey[key] = release
            }
        }

        let studioAlbums = studioKeys.compactMap { studioByKey[$0] }
        return ArtistReleaseGroups(studioAlbums: studioAlbums, otherReleases: otherReleases)
    }

    private static func isStudioAlbumCandidate(_ release: Track) -> Bool {
        let recordType = release.recordType?.searchNormalized ?? "album"
        let titleTokens = tokens(in: release.title)

        if recordType.contains("single") || recordType == "ep" || recordType.contains("compilation") {
            return false
        }

        if recordType.contains("live") || recordType.contains("reissue") {
            return false
        }

        if intersects(titleTokens, liveMarkers) || intersects(titleTokens, reissueMarkers) || intersects(titleTokens, compilationMarkers) {
            return false
        }

        if release.trackCount.map({ $0 < 6 }) == true {
            return false
        }

        return recordType.contains("studio") || recordType == "album"
    }

    private static func canonicalReleaseKey(_ title: String) -> String {
        tokenList(in: title)
            .filter { token in
                !liveMarkers.contains(token)
                    && !reissueMarkers.contains(token)
                    && !compilationMarkers.contains(token)
                    && !["remaster", "remastered", "super", "special", "explicit", "clean", "version"].contains(token)
                    && !isOrdinalToken(token)
            }
            .joined(separator: " ")
    }

    private static func prefersStudioRelease(_ candidate: Track, over current: Track) -> Bool {
        let candidatePenalty = variantPenalty(candidate)
        let currentPenalty = variantPenalty(current)
        if candidatePenalty != currentPenalty {
            return candidatePenalty < currentPenalty
        }

        if let candidateDate = candidate.releaseDate?.nonEmpty,
           let currentDate = current.releaseDate?.nonEmpty,
           candidateDate != currentDate {
            return candidateDate < currentDate
        }

        let candidateTracks = candidate.trackCount ?? 0
        let currentTracks = current.trackCount ?? 0
        if candidateTracks != currentTracks {
            return candidateTracks > currentTracks
        }

        return candidate.title.localizedCaseInsensitiveCompare(current.title) == .orderedAscending
    }

    private static func variantPenalty(_ release: Track) -> Int {
        let titleTokens = tokens(in: release.title)
        var penalty = release.title.contains("(") || release.title.contains("[") ? 2 : 0
        if intersects(titleTokens, reissueMarkers) || titleTokens.contains(where: isOrdinalToken) {
            penalty += 4
        }
        if intersects(titleTokens, liveMarkers) {
            penalty += 8
        }
        return penalty
    }

    private static func tokens(in value: String) -> Set<String> {
        Set(tokenList(in: value))
    }

    private static func tokenList(in value: String) -> [String] {
        value.searchNormalized.split(separator: " ").map(String.init)
    }

    private static func intersects(_ tokens: Set<String>, _ markers: Set<String>) -> Bool {
        !tokens.isDisjoint(with: markers)
    }

    private static func isOrdinalToken(_ token: String) -> Bool {
        token.range(of: #"^\d+(st|nd|rd|th)$"#, options: .regularExpression) != nil
    }
}

enum SmartSearchRanker {
    private static let weakArtistPrefixMinimumFans = 5_000
    private static let weakArtistContainsMinimumFans = 50_000

    static func ranked(
        query: String,
        artists: [Track],
        tracks: [Track],
        albums: [Track],
        limit: Int = 50
    ) -> [Track] {
        let term = query.searchNormalized
        guard !term.isEmpty else { return [] }

        let uniqueArtists = deduplicatedArtists(artists)
            .filter { allowsArtist($0, term: term) }
        let uniqueTracks = deduplicatedItems(tracks)
        let uniqueAlbums = deduplicatedItems(albums)
        let dominantArtists = Set(
            (
                uniqueArtists
                .filter { $0.title.searchNormalized == term }
                .sorted { ($0.fanCount ?? 0) > ($1.fanCount ?? 0) }
                .prefix(3)
                .map { $0.title.searchNormalized }
            )
            + inferredDominantArtistNames(term: term, tracks: uniqueTracks, albums: uniqueAlbums)
        )

        let items = uniqueArtists + uniqueTracks + uniqueAlbums
        return items
            .compactMap { item -> (item: Track, score: Int)? in
                guard let score = score(item, term: term, dominantArtists: dominantArtists) else {
                    return nil
                }
                return (item, score)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title) == .orderedAscending
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map(\.item)
    }

    private static func score(_ item: Track, term: String, dominantArtists: Set<String>) -> Int? {
        let titleScore = matchScore(term: term, text: item.title)
        let artistScore = matchScore(term: term, text: item.artist)
        let albumScore = matchScore(term: term, text: item.album)
        guard max(titleScore, artistScore, albumScore) > 0 else { return nil }

        switch item.kind {
        case .artist:
            return 1_700_000 + titleScore + audienceWeight(item.fanCount)
        case .track:
            let normalizedArtist = item.artist.searchNormalized
            var score = 480_000
                + max(titleScore, albumScore / 2)
                + artistScore
                + popularityWeight(item.rank)

            if dominantArtists.contains(normalizedArtist) {
                score += 650_000
            } else if !dominantArtists.isEmpty, titleScore >= 700_000 {
                score -= 520_000
            }

            return score
        case .album:
            let normalizedArtist = item.artist.searchNormalized
            var score = 360_000
                + max(titleScore, artistScore)
                + popularityWeight(item.rank)
                + audienceWeight(item.fanCount) / 2

            if dominantArtists.contains(normalizedArtist) {
                score += 300_000
            }

            return score
        }
    }

    private static func allowsArtist(_ artist: Track, term: String) -> Bool {
        let name = artist.title.searchNormalized
        guard matchScore(term: term, text: artist.title) > 0 else { return false }
        if name == term {
            return true
        }

        if name.hasPrefix("\(term) ") {
            return (artist.fanCount ?? 0) >= weakArtistPrefixMinimumFans
        }

        return (artist.fanCount ?? 0) >= weakArtistContainsMinimumFans
    }

    private static func inferredDominantArtistNames(term: String, tracks: [Track], albums: [Track]) -> [String] {
        var scoreByArtist: [String: Int] = [:]

        for track in tracks where track.artist.searchNormalized == term {
            scoreByArtist[term, default: 0] += 220_000 + popularityWeight(track.rank)
        }

        for album in albums where album.artist.searchNormalized == term {
            scoreByArtist[term, default: 0] += 120_000 + popularityWeight(album.rank)
        }

        return scoreByArtist
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(3)
            .map(\.key)
    }

    private static func matchScore(term: String, text: String) -> Int {
        let value = text.searchNormalized
        guard !value.isEmpty else { return 0 }

        if value == term {
            return 700_000
        }

        if value.hasPrefix(term) {
            return 500_000
        }

        if value.containsWholePhrase(term) {
            return 300_000
        }

        let termTokens = term.split(separator: " ").map(String.init)
        let valueTokens = Set(value.split(separator: " ").map(String.init))
        guard !termTokens.isEmpty else { return 0 }

        if termTokens.allSatisfy({ valueTokens.contains($0) || value.contains($0) }) {
            return 180_000 + (termTokens.count * 20_000)
        }

        let hits = termTokens.filter { valueTokens.contains($0) || value.contains($0) }.count
        return hits > 0 ? hits * 30_000 : 0
    }

    private static func audienceWeight(_ count: Int?) -> Int {
        min(max(count ?? 0, 0) / 80, 350_000)
    }

    private static func popularityWeight(_ rank: Int?) -> Int {
        min(max(rank ?? 0, 0) / 8, 160_000)
    }

    private static func deduplicatedArtists(_ artists: [Track]) -> [Track] {
        deduplicated(artists, key: { $0.title.searchNormalized }) { candidate, current in
            let candidateFans = candidate.fanCount ?? 0
            let currentFans = current.fanCount ?? 0
            if candidateFans == currentFans {
                return (candidate.albumCount ?? 0) > (current.albumCount ?? 0)
            }
            return candidateFans > currentFans
        }
    }

    private static func deduplicatedItems(_ items: [Track]) -> [Track] {
        deduplicated(items, key: { item in
            item.catalogID?.nonEmpty ?? "\(item.kind.rawValue).\(item.title.searchNormalized).\(item.artist.searchNormalized)"
        }) { candidate, current in
            let candidateRank = candidate.rank ?? candidate.fanCount ?? 0
            let currentRank = current.rank ?? current.fanCount ?? 0
            return candidateRank > currentRank
        }
    }

    private static func deduplicated(
        _ items: [Track],
        key: (Track) -> String,
        prefers candidate: (Track, Track) -> Bool
    ) -> [Track] {
        var keys: [String] = []
        var bestByKey: [String: Track] = [:]

        for item in items {
            let itemKey = key(item)
            guard !itemKey.isEmpty else { continue }

            if let current = bestByKey[itemKey] {
                if candidate(item, current) {
                    bestByKey[itemKey] = item
                }
            } else {
                keys.append(itemKey)
                bestByKey[itemKey] = item
            }
        }

        return keys.compactMap { bestByKey[$0] }
    }
}

enum LibrarySearchFilter {
    static func filteredTracks(_ tracks: [Track], query: String) -> [Track] {
        let term = query.searchNormalized
        guard !term.isEmpty else { return tracks }

        let tokens = term.split(separator: " ").map(String.init)
        return tracks.filter { track in
            let searchableText = [
                track.title,
                track.artist,
                track.album
            ]
            .joined(separator: " ")
            .searchNormalized

            return searchableText.containsWholePhrase(term)
                || tokens.allSatisfy { searchableText.contains($0) }
        }
    }
}

enum PlaylistTrackFilter {
    static func filteredTracks(_ tracks: [Track], query: String) -> [Track] {
        LibrarySearchFilter.filteredTracks(tracks, query: query)
    }
}

enum PlaylistSortMode: String, CaseIterable, Identifiable {
    case playlistOrder
    case title
    case artist
    case album
    case duration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playlistOrder:
            "Playlist Order"
        case .title:
            "Title"
        case .artist:
            "Artist"
        case .album:
            "Album"
        case .duration:
            "Duration"
        }
    }

    var systemImage: String {
        switch self {
        case .playlistOrder:
            "line.3.horizontal"
        case .title:
            "textformat"
        case .artist:
            "music.mic"
        case .album:
            "square.stack"
        case .duration:
            "timer"
        }
    }

    fileprivate var librarySortMode: LibrarySortMode? {
        switch self {
        case .playlistOrder:
            nil
        case .title:
            .title
        case .artist:
            .artist
        case .album:
            .album
        case .duration:
            .duration
        }
    }
}

enum LibrarySortMode: String, CaseIterable, Identifiable {
    case recentlyAdded
    case title
    case artist
    case album
    case duration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyAdded:
            "Recently Added"
        case .title:
            "Title"
        case .artist:
            "Artist"
        case .album:
            "Album"
        case .duration:
            "Duration"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyAdded:
            "clock.arrow.circlepath"
        case .title:
            "textformat"
        case .artist:
            "music.mic"
        case .album:
            "square.stack"
        case .duration:
            "timer"
        }
    }
}

enum LibraryTrackOrganizer {
    static func tracks(_ tracks: [Track], query: String, sortMode: LibrarySortMode) -> [Track] {
        TrackSortOrder.sortedTracks(
            LibrarySearchFilter.filteredTracks(tracks, query: query),
            sortMode: sortMode
        )
    }
}

enum PlaylistTrackOrganizer {
    static func tracks(_ tracks: [Track], query: String, sortMode: PlaylistSortMode) -> [Track] {
        let filteredTracks = PlaylistTrackFilter.filteredTracks(tracks, query: query)
        guard let librarySortMode = sortMode.librarySortMode else { return filteredTracks }
        return TrackSortOrder.sortedTracks(filteredTracks, sortMode: librarySortMode)
    }
}

enum TrackSortOrder {
    static func sortedTracks(_ tracks: [Track], sortMode: LibrarySortMode) -> [Track] {
        switch sortMode {
        case .recentlyAdded:
            return tracks
        case .title:
            return tracks.sorted { compare($0.title, $1.title, lhsID: $0.id, rhsID: $1.id) }
        case .artist:
            return tracks.sorted {
                compare(
                    [$0.artist, $0.title, $0.album],
                    [$1.artist, $1.title, $1.album],
                    lhsID: $0.id,
                    rhsID: $1.id
                )
            }
        case .album:
            return tracks.sorted { compareAlbum($0, $1) }
        case .duration:
            return tracks.sorted {
                if $0.duration == $1.duration {
                    return compare($0.title, $1.title, lhsID: $0.id, rhsID: $1.id)
                }
                return $0.duration < $1.duration
            }
        }
    }

    private static func compare(_ lhs: String, _ rhs: String, lhsID: String, rhsID: String) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result == .orderedSame {
            return lhsID < rhsID
        }
        return result == .orderedAscending
    }

    private static func compare(_ lhs: [String], _ rhs: [String], lhsID: String, rhsID: String) -> Bool {
        for (leftValue, rightValue) in zip(lhs, rhs) {
            let result = leftValue.localizedCaseInsensitiveCompare(rightValue)
            if result != .orderedSame {
                return result == .orderedAscending
            }
        }
        return lhsID < rhsID
    }

    private static func compareAlbum(_ lhs: Track, _ rhs: Track) -> Bool {
        let albumResult = lhs.album.localizedCaseInsensitiveCompare(rhs.album)
        if albumResult != .orderedSame {
            return albumResult == .orderedAscending
        }

        if let discResult = compareOptionalInt(lhs.discNumber, rhs.discNumber) {
            return discResult
        }

        if let positionResult = compareOptionalInt(lhs.trackPosition, rhs.trackPosition) {
            return positionResult
        }

        return compare(lhs.title, rhs.title, lhsID: lhs.id, rhsID: rhs.id)
    }

    private static func compareOptionalInt(_ lhs: Int?, _ rhs: Int?) -> Bool? {
        switch (lhs, rhs) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return nil
        }
    }
}

enum QueueSearchFilter {
    static func filteredTracks(_ tracks: [Track], query: String) -> [Track] {
        LibrarySearchFilter.filteredTracks(tracks, query: query)
    }
}

extension Int {
    var compactCountLabel: String {
        let value = Double(self)
        if self >= 1_000_000 {
            return "\(String(format: "%.1f", value / 1_000_000).trimmedTrailingZero)M"
        }

        if self >= 1_000 {
            return "\(String(format: "%.1f", value / 1_000).trimmedTrailingZero)K"
        }

        return String(self)
    }
}

struct TrackPalette: Codable, Hashable {
    let baseHex: String
    let midHex: String
    let accentHex: String
    let inkHex: String

    var base: Color { Color(hex: baseHex) }
    var mid: Color { Color(hex: midHex) }
    var accent: Color { Color(hex: accentHex) }
    var ink: Color { Color(hex: inkHex) }

    static let fallback = TrackPalette(
        baseHex: "#101014",
        midHex: "#28312D",
        accentHex: NoirwaveTheme.primaryAccentHex,
        inkHex: "#F4F0EA"
    )
}

enum NoirwaveTheme {
    static let primaryAccentHex = "#5EE0C2"

    static var primaryAccent: Color {
        Color(hex: primaryAccentHex)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch cleaned.count {
        case 3:
            red = Double((value >> 8) & 0xF) / 15
            green = Double((value >> 4) & 0xF) / 15
            blue = Double(value & 0xF) / 15
            alpha = 1
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        default:
            red = 1
            green = 1
            blue = 1
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nonEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    var releaseYear: String? {
        let value = trimmed
        guard value.count >= 4 else { return nil }
        let prefix = String(value.prefix(4))
        return Int(prefix) == nil ? nil : prefix
    }

    var displayRecordType: String {
        switch searchNormalized {
        case "studio", "studio album":
            "Studio Album"
        case "live", "live album":
            "Live Album"
        case "reissue":
            "Reissue"
        case "single":
            "Single"
        case "ep":
            "EP"
        case "compilation":
            "Compilation"
        default:
            "Album"
        }
    }

    fileprivate var trimmedTrailingZero: String {
        if hasSuffix(".0") {
            return String(dropLast(2))
        }

        return self
    }

    var searchNormalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    fileprivate func containsWholePhrase(_ phrase: String) -> Bool {
        let paddedValue = " \(self) "
        let paddedPhrase = " \(phrase) "
        return paddedValue.contains(paddedPhrase)
    }
}

extension TimeInterval {
    var playbackLabel: String {
        let totalSeconds = max(Int(rounded()), 0)
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}
