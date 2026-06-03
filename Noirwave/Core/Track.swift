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
        baseHex: "#101014",
        midHex: "#28312D",
        accentHex: "#E45D73",
        inkHex: "#F4F0EA"
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
}

extension TimeInterval {
    var playbackLabel: String {
        let totalSeconds = max(Int(rounded()), 0)
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}
