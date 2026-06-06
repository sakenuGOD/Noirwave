import SwiftUI

enum TrackKind: String, Hashable {
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

struct Track: Identifiable, Hashable {
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

enum SmartSearchRanker {
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
        let dominantArtists = Set(
            uniqueArtists
                .filter { $0.title.searchNormalized == term }
                .sorted { ($0.fanCount ?? 0) > ($1.fanCount ?? 0) }
                .prefix(3)
                .map { $0.title.searchNormalized }
        )

        let items = uniqueArtists + deduplicatedItems(tracks) + deduplicatedItems(albums)
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
        if name == term || name.hasPrefix("\(term) ") {
            return true
        }

        return (artist.fanCount ?? 0) >= 50_000
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

struct TrackPalette: Hashable {
    let baseHex: String
    let midHex: String
    let accentHex: String
    let inkHex: String

    var base: Color { Color(hex: baseHex) }
    var mid: Color { Color(hex: midHex) }
    var accent: Color { Color(hex: accentHex) }
    var ink: Color { Color(hex: inkHex) }

    static let fallback = TrackPalette(
        baseHex: "#08100F",
        midHex: "#183835",
        accentHex: "#5EE0C2",
        inkHex: "#EAFDF8"
    )
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
        switch lowercased() {
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

    func containsWholePhrase(_ phrase: String) -> Bool {
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
