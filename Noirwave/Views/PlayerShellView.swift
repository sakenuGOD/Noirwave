import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum ShellDestination: String, CaseIterable, Identifiable {
    case listenNow = "Listen Now"
    case search = "Catalog"
    case library = "Library"
    case profile = "Profile"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .listenNow:
            "play.circle.fill"
        case .search:
            "magnifyingglass"
        case .library:
            "rectangle.stack.fill"
        case .profile:
            "person.crop.circle"
        }
    }

    var caption: String {
        switch self {
        case .listenNow:
            "Home"
        case .search:
            "Catalog"
        case .library:
            "Albums & artists"
        case .profile:
            "Settings"
        }
    }
}

enum ContentDeckRouting {
    static func showsCatalogDetail(
        selectionIsCatalog: Bool,
        hasCatalogContext: Bool
    ) -> Bool {
        selectionIsCatalog && hasCatalogContext
    }

    static func showsSearchResults(
        selectionIsCatalog: Bool,
        hasCatalogContext: Bool,
        searchQuery: String
    ) -> Bool {
        selectionIsCatalog && !hasCatalogContext && !searchQuery.trimmed.isEmpty
    }
}

private enum NowPlayingPanelMode: String, CaseIterable, Identifiable {
    case lyrics = "Lyrics"
    case queue = "Queue"
    case sound = "Sound"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .lyrics:
            "text.quote"
        case .queue:
            "text.line.last.and.arrowtriangle.forward"
        case .sound:
            "slider.horizontal.3"
        }
    }
}

extension Notification.Name {
    static let noirwaveFocusSearch = Notification.Name("noirwave.focusSearch")
}

enum MiniPlayerVisualStyle {
    static let materialTintOpacity = 0.003
    static let legacyDimOpacity = 0.0
    static let inactiveControlOpacity = 0.74
    static let inactiveControlHoverOpacity = 0.92
    static let inactiveFillOpacity = 0.0
    static let inactiveFillHoverOpacity = 0.040
    static let inactiveControlStrokeOpacity = 0.0
    static let inactiveControlHoverStrokeOpacity = 0.070
    static let activeControlFillOpacity = 0.10
    static let activeControlStrokeOpacity = 0.18
    static let progressTrackOpacity = 0.16
    static let progressHoverTrackOpacity = 0.30
    static let progressAccentOpacity = 0.62
    static let progressHeight: CGFloat = 1.0
    static let progressHoverHeight: CGFloat = 4
    static let progressHitHeight: CGFloat = 30
    static let progressHorizontalInset: CGFloat = 10
    static let progressThumbSize: CGFloat = 3.5
    static let progressHoverThumbSize: CGFloat = 9
    static let progressTimeWidth: CGFloat = 42
    static let progressMaxWidth: CGFloat = 520
    static let progressTopPadding: CGFloat = 0
    static let progressCompactHeight: CGFloat = 10
    static let progressExpandedHeight: CGFloat = 46
    static let primaryControlVisualSize: CGFloat = 37
    static let primaryControlHitSize: CGFloat = 46
    static let primaryIconSize: CGFloat = 14.5
    static let primaryControlStrokeOpacity = 0.34
    static let primaryControlShadowOpacity = 0.10
}

struct LiquidGlassPanelAppearance {
    let materialOpacity: Double
    let dimOpacity: Double
    let innerHighlightOpacity: Double
    let diagonalHighlightOpacity: Double
    let mintGlowOpacity: Double
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat
}

enum LiquidGlassPanelStyle {
    static let material: NSVisualEffectView.Material = .hudWindow
    static let materialOpacity = 0.78
    static let dimOpacity = 0.020
    static let borderOpacity = 0.18
    static let topHighlightOpacity = 0.24
    static let innerHighlightOpacity = 0.026
    static let diagonalHighlightOpacity = 0.006
    static let mintGlowOpacity = 0.0
    static let shadowOpacity = 0.14
    static let shadowRadius: CGFloat = 26
    static let shadowYOffset: CGFloat = 14
    static let topHighlightHeight: CGFloat = 18
    static let appearance = LiquidGlassPanelAppearance(
        materialOpacity: materialOpacity,
        dimOpacity: dimOpacity,
        innerHighlightOpacity: innerHighlightOpacity,
        diagonalHighlightOpacity: diagonalHighlightOpacity,
        mintGlowOpacity: mintGlowOpacity,
        shadowOpacity: shadowOpacity,
        shadowRadius: shadowRadius,
        shadowYOffset: shadowYOffset
    )
}

enum NowPlayingPanelVisualStyle {
    static let panelMaterial = LiquidGlassPanelStyle.material
    static let panelAppearance = LiquidGlassPanelAppearance(
        materialOpacity: 0.82,
        dimOpacity: 0.024,
        innerHighlightOpacity: 0.032,
        diagonalHighlightOpacity: 0.006,
        mintGlowOpacity: 0.0,
        shadowOpacity: 0.14,
        shadowRadius: 30,
        shadowYOffset: 18
    )
    static let innerCardFillOpacity = 0.034
    static let innerCardStrokeOpacity = 0.10
    static let selectedFillOpacity = 0.056
    static let selectedStrokeOpacity = 0.16
    static let hoverFillOpacity = 0.034
}

enum GraphiteSurfaceStyle {
    static let shellTopHex = "#3D3D3A"
    static let shellMidHex = "#272725"
    static let shellBaseHex = "#1F1F1E"
    static let centerTopHex = "#2B2B29"
    static let centerMidHex = "#232321"
    static let centerBaseHex = "#1F1F1E"
    static let centerFloorHex = "#1F1F1E"
    static let raisedTopHex = "#353532"
    static let raisedBaseHex = "#30302E"
    static let contentFillOpacity = 0.052
    static let contentStrongFillOpacity = 0.074
    static let contentStrokeOpacity = 0.075
    static let contentStrongStrokeOpacity = 0.110
}

enum ArtworkFallbackStyle {
    static let backgroundHex = NoirwaveTheme.backgroundHex
    static let usesGeneratedArtwork = false
    static let iconOpacity = 0.42
    static let borderOpacity = 0.12
}

enum VolumeIcon {
    static func symbol(for volume: Double) -> String {
        let clampedVolume = min(max(volume, 0), 1)
        if clampedVolume <= 0 {
            return "speaker.slash.fill"
        } else if clampedVolume < 0.34 {
            return "speaker.wave.1.fill"
        } else if clampedVolume < 0.68 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

struct SearchResultsPresentation {
    static let maxArtists = 6
    static let maxAlbums = 4
    static let maxTracks = 8

    let bestMatch: Track?
    let artists: [Track]
    let albums: [Track]
    let tracks: [Track]

    init(items: [Track], query: String = "") {
        let term = query.searchNormalized
        let artistCandidates = SearchResultDerivedEntityBuilder.deduplicated(
            items.filter { $0.kind == .artist }
                + SearchResultDerivedEntityBuilder.artists(from: items, term: term)
        )
        let albumCandidates = SearchResultDerivedEntityBuilder.deduplicated(
            items.filter { $0.kind == .album }
                + SearchResultDerivedEntityBuilder.albums(from: items, term: term)
        )

        artists = Array(artistCandidates.prefix(Self.maxArtists))
        tracks = Array(items.filter(\.isPlayable).prefix(Self.maxTracks))
        albums = artists.isEmpty
            ? Array(albumCandidates.prefix(Self.maxAlbums))
            : []
        bestMatch = SearchResultBestMatchPicker.pick(
            from: items,
            artists: artists,
            albums: albumCandidates,
            tracks: tracks,
            term: term
        )
    }

    var isEmpty: Bool {
        bestMatch == nil && artists.isEmpty && albums.isEmpty && tracks.isEmpty
    }
}

private enum SearchResultDerivedEntityBuilder {
    static func artists(from items: [Track], term: String) -> [Track] {
        guard !term.isEmpty else { return [] }
        var seedByCatalogID: [String: (track: Track, count: Int)] = [:]

        for track in items where track.isPlayable {
            guard let catalogID = track.artistCatalogID?.nonEmpty,
                  SearchTextMatcher.matches(normalizedQuery: term, normalizedText: track.artist.searchNormalized)
            else { continue }

            var seed = seedByCatalogID[catalogID] ?? (track: track, count: 0)
            seed.count += 1
            seedByCatalogID[catalogID] = seed
        }

        return seedByCatalogID.values
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.track.artist.localizedCaseInsensitiveCompare(rhs.track.artist) == .orderedAscending
            }
            .map { seed in
                Track(
                    id: "derived-artist.\(seed.track.artist.searchNormalized)",
                    title: seed.track.artist,
                    artist: seed.track.artist,
                    album: "Artist",
                    duration: 0,
                    palette: seed.track.palette,
                    catalogID: seed.track.artistCatalogID,
                    previewURL: nil,
                    kind: .artist,
                    artworkURL: seed.track.artworkURL
                )
            }
    }

    static func albums(from items: [Track], term: String) -> [Track] {
        guard !term.isEmpty else { return [] }
        var seedByCatalogID: [String: (track: Track, count: Int)] = [:]

        for track in items where track.isPlayable {
            guard let catalogID = track.albumCatalogID?.nonEmpty else { continue }
            let albumText = [track.album, track.artist].joined(separator: " ").searchNormalized
            guard SearchTextMatcher.matches(normalizedQuery: term, normalizedText: albumText) else { continue }

            var seed = seedByCatalogID[catalogID] ?? (track: track, count: 0)
            seed.count += 1
            seedByCatalogID[catalogID] = seed
        }

        return seedByCatalogID.values
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.track.album.localizedCaseInsensitiveCompare(rhs.track.album) == .orderedAscending
            }
            .map { seed in
                Track(
                    id: "derived-album.\(seed.track.album.searchNormalized).\(seed.track.artist.searchNormalized)",
                    title: seed.track.album,
                    artist: seed.track.artist,
                    album: "Album",
                    duration: 0,
                    palette: seed.track.palette,
                    catalogID: seed.track.albumCatalogID,
                    previewURL: nil,
                    kind: .album,
                    artworkURL: seed.track.artworkURL,
                    trackCount: seed.count
                )
            }
    }

    static func deduplicated(_ items: [Track]) -> [Track] {
        var result: [Track] = []
        var seenKeys = Set<String>()

        for item in items {
            let key = [
                item.kind.rawValue,
                item.catalogID?.nonEmpty ?? item.title.searchNormalized,
                item.artist.searchNormalized
            ].joined(separator: "::")

            guard seenKeys.insert(key).inserted else { continue }
            result.append(item)
        }

        return result
    }
}

private enum SearchResultBestMatchPicker {
    static func pick(from items: [Track], artists: [Track], albums: [Track], tracks: [Track], term: String) -> Track? {
        guard !term.isEmpty else { return items.first }

        let candidates = SearchResultDerivedEntityBuilder.deduplicated(artists + albums + tracks)
        let ranked = candidates
            .map { item in (item: item, score: score(item, term: term)) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return priority(lhs.item) > priority(rhs.item)
            }

        guard let best = ranked.first, best.score > 0 else {
            return items.first
        }
        return best.item
    }

    private static func score(_ item: Track, term: String) -> Int {
        let title = item.title.searchNormalized
        let artist = item.artist.searchNormalized
        let album = item.album.searchNormalized
        let titleScore = SearchTextMatcher.matchScore(normalizedQuery: term, normalizedText: title)
        let artistScore = SearchTextMatcher.matchScore(normalizedQuery: term, normalizedText: artist)
        let albumScore = SearchTextMatcher.matchScore(normalizedQuery: term, normalizedText: album)
        let exactTitleBonus = title == term ? exactBonus(for: item.kind) : 0

        return exactTitleBonus
            + titleScore * 100
            + artistScore * 70
            + albumScore * 45
            + priority(item)
    }

    private static func exactBonus(for kind: TrackKind) -> Int {
        switch kind {
        case .artist:
            10_000
        case .album:
            8_000
        case .track:
            6_000
        }
    }

    private static func priority(_ item: Track) -> Int {
        switch item.kind {
        case .artist:
            3_000
        case .album:
            2_000
        case .track:
            1_000
        }
    }
}

enum SidebarVisualStyle {
    static let panelMaterial: NSVisualEffectView.Material = .sidebar
    static let panelAppearance = LiquidGlassPanelAppearance(
        materialOpacity: 0.82,
        dimOpacity: 0.022,
        innerHighlightOpacity: 0.026,
        diagonalHighlightOpacity: 0.006,
        mintGlowOpacity: 0.0,
        shadowOpacity: 0.075,
        shadowRadius: 20,
        shadowYOffset: 10
    )
    static let materialDimOpacity = panelAppearance.dimOpacity
    static let brandFillOpacity = 0.045
    static let brandStrokeOpacity = 0.12
    static let activeAccentOpacity = 0.78
    static let activeAccentFillOpacity = 0.040
    static let activeGlowOpacity = 0.10
    static let activeStrokeOpacity = 0.105
    static let activeTextOpacity = 0.98
    static let inactiveTextOpacity = 0.72
    static let inactiveTextHoverOpacity = 0.88
    static let inactiveIconOpacity = 0.64
    static let inactiveIconHoverOpacity = 0.86
    static let hoverFillOpacity = 0.020
    static let hoverStrokeOpacity = 0.060
    static let searchRestFillOpacity = 0.040
    static let searchFocusedFillOpacity = 0.065
    static let searchRestStrokeOpacity = 0.095
    static let searchFocusedStrokeOpacity = 0.34
}

enum ArtistHeaderLayoutMetrics {
    static let desktopViewportHeight: CGFloat = 900
    static let shellChromeReservation: CGFloat = 300
    static let availableDesktopContentHeight = desktopViewportHeight - shellChromeReservation
    static let detailSectionSpacing: CGFloat = 18
    static let heroMinHeight: CGFloat = 272
    static let heroPadding: CGFloat = 22
    static let heroContentSpacing: CGFloat = 14
    static let heroColumnSpacing: CGFloat = 20
    static let heroCornerRadius: CGFloat = 16
    static let backgroundArtworkSize: CGFloat = 340
    static let foregroundArtworkSize: CGFloat = 148
    static let foregroundArtworkCornerRadius: CGFloat = foregroundArtworkSize / 2
    static let titleFontSize: CGFloat = 46
    static let actionHeight: CGFloat = 36
    static let actionCornerRadius: CGFloat = 9
    static let latestReleaseArtworkSize: CGFloat = 64
    static let latestReleaseVerticalPadding: CGFloat = 10
    static let latestReleaseEstimatedHeight = latestReleaseArtworkSize + latestReleaseVerticalPadding * 2
    static let popularTracksLeadInHeight: CGFloat = 86
    static let aboveFoldStackHeight = heroMinHeight
        + detailSectionSpacing
        + latestReleaseEstimatedHeight
        + detailSectionSpacing
        + popularTracksLeadInHeight
}

enum LibraryPlaylistSelection: Equatable {
    static let likedSongsID = "liked.songs"

    case likedSongs
    case localPlaylist(String)

    var localPlaylistID: String? {
        guard case let .localPlaylist(id) = self else { return nil }
        return id
    }
}

enum PlaylistTargetMenuBuilder {
    static func targetPlaylists(_ playlists: [LocalPlaylist], excludingPlaylistID: String?) -> [LocalPlaylist] {
        playlists.filter { $0.id != excludingPlaylistID }
    }
}

private typealias PlaylistCreationRequest = @MainActor @Sendable (Track) -> Void
private typealias PlaylistTracksCreationRequest = @MainActor @Sendable ([Track]) -> Void

private enum NoirwaveDiagnostics {
    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[Noirwave] \(message())")
        #endif
    }
}

private struct PlaylistCreationRequestKey: EnvironmentKey {
    static let defaultValue: PlaylistCreationRequest = { _ in }
}

private struct PlaylistTracksCreationRequestKey: EnvironmentKey {
    static let defaultValue: PlaylistTracksCreationRequest = { _ in }
}

private extension EnvironmentValues {
    var requestPlaylistCreationFromTrack: PlaylistCreationRequest {
        get { self[PlaylistCreationRequestKey.self] }
        set { self[PlaylistCreationRequestKey.self] = newValue }
    }

    var requestPlaylistCreationFromTracks: PlaylistTracksCreationRequest {
        get { self[PlaylistTracksCreationRequestKey.self] }
        set { self[PlaylistTracksCreationRequestKey.self] = newValue }
    }
}

struct PlayerShellView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var selectedDestination: ShellDestination = .listenNow
    @State private var selectedPlaylist: LibraryPlaylistSelection?
    @State private var isShowingNowPlaying = false
    @State private var isShowingTrackWidget = false
    @State private var nowPlayingPanelMode: NowPlayingPanelMode = .lyrics
    @State private var playlistEditor: PlaylistEditor?
    @State private var searchFocusRequest = 0
    @State private var isProgressStripExpanded = false

    private var palette: TrackPalette {
        store.currentTrack?.palette ?? .fallback
    }

    private var miniPlayerDisplayTrack: Track? {
        store.currentTrack
            ?? store.visibleTracks.first(where: \.isPlayable)
            ?? store.featuredTracks.first(where: \.isPlayable)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
            DynamicStudioBackground(palette: palette)

            HStack(spacing: 0) {
                SidebarView(
                    selection: $selectedDestination,
                    selectedPlaylist: $selectedPlaylist,
                    searchFocusRequest: searchFocusRequest
                ) {
                    playlistEditor = PlaylistEditor(
                        playlistID: nil,
                        title: LocalPlaylist.fallbackTitle
                    )
                }
                .frame(width: 216)
                .padding(.leading, 10)
                .padding(.vertical, 12)

                VStack(spacing: 0) {
                    TopBarView(selection: $selectedDestination)
                        .padding(.horizontal, 30)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    ZStack(alignment: .bottom) {
                        ContentDeckView(
                            selection: selectedDestination,
                            selectedPlaylist: $selectedPlaylist
                        )
                        .environment(\.requestPlaylistCreationFromTrack) { track in
                            playlistEditor = PlaylistEditor(
                                playlistID: nil,
                                title: LocalPlaylist.fallbackTitle,
                                tracks: [track]
                            )
                        }
                        .environment(\.requestPlaylistCreationFromTracks) { tracks in
                            playlistEditor = PlaylistEditor(
                                playlistID: nil,
                                title: LocalPlaylist.fallbackTitle,
                                tracks: tracks
                            )
                        }

                        if miniPlayerDisplayTrack != nil {
                            MiniPlayerBar(
                                isProgressExpanded: $isProgressStripExpanded,
                                selectedPanel: $nowPlayingPanelMode,
                                isShowingNowPlaying: $isShowingNowPlaying,
                                isShowingTrackWidget: $isShowingTrackWidget,
                                onOpenCatalogTarget: { target in
                                    selectedDestination = .search
                                    selectedPlaylist = nil
                                    isShowingTrackWidget = false
                                    store.activate(target)
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 36)
                            .animation(.easeOut(duration: 0.16), value: isProgressStripExpanded)
                            .zIndex(3)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isShowingNowPlaying {
                let panelWidth = min(max(proxy.size.width * 0.30, 360), 430)
                NowPlayingPanel(
                    selectedPanel: $nowPlayingPanelMode,
                    isShowingNowPlaying: $isShowingNowPlaying
                )
                .environmentObject(store)
                .frame(width: panelWidth)
                .padding(.trailing, 18)
                .padding(.top, 72)
                .padding(.bottom, 86)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(4)
            }

            if isShowingTrackWidget, let track = store.currentTrack {
                CurrentTrackWidgetOverlay(track: track, isPresented: $isShowingTrackWidget)
                    .zIndex(6)
            }
            }
        }
        .animation(.easeOut(duration: 0.16), value: isShowingNowPlaying)
        .animation(.easeOut(duration: 0.12), value: isShowingTrackWidget)
        .background(
            TrackpadSwipeBackHandler {
                navigateBackFromGesture()
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .noirwaveFocusSearch)) { _ in
            selectedDestination = .search
            selectedPlaylist = nil
            searchFocusRequest += 1
        }
        .onAppear(perform: prefetchArtwork)
        .onChange(of: store.currentTrack) { _, _ in prefetchArtwork() }
        .onChange(of: store.queue) { _, _ in prefetchArtwork() }
        .onChange(of: store.visibleTracks) { _, _ in prefetchArtwork() }
        .onChange(of: store.featuredTracks) { _, _ in prefetchArtwork() }
        .onChange(of: store.localPlaylists) { _, _ in prefetchArtwork() }
        .sheet(item: $playlistEditor) { editor in
            PlaylistTitleSheet(title: editor.title, primaryLabel: "Create") { title in
                let playlist = store.createPlaylist(title: title, tracks: editor.tracks)
                selectedDestination = .library
                selectedPlaylist = .localPlaylist(playlist.id)
                store.leaveCatalogContext()
                playlistEditor = nil
            } onCancel: {
                playlistEditor = nil
            }
        }
    }

    private func navigateBackFromGesture() {
        if isShowingTrackWidget {
            isShowingTrackWidget = false
            return
        }

        if isShowingNowPlaying {
            isShowingNowPlaying = false
            return
        }

        if selectedPlaylist != nil {
            selectedPlaylist = nil
            return
        }

        if store.catalogContext != nil {
            store.leaveCatalogContext()
            selectedDestination = .search
        }
    }

    private func prefetchArtwork() {
        if let currentTrack = store.currentTrack {
            ArtworkImagePipeline.shared.prefetch(
                [currentTrack],
                targetPixelSize: 720,
                priority: .high
            )
        }

        let visibleAndNextTracks = store.visibleTracks + store.queue + store.featuredTracks
        ArtworkImagePipeline.shared.prefetch(
            visibleAndNextTracks,
            targetPixelSize: 360,
            priority: .visible
        )

        let libraryTracks = store.likedTracks(limit: Int.max)
            + store.localPlaylists.flatMap { $0.orderedTracks(preferredTracks: []) }
        ArtworkImagePipeline.shared.prefetch(
            libraryTracks,
            targetPixelSize: 280,
            priority: .low
        )
    }
}

private struct DynamicStudioBackground: View {
    let palette: TrackPalette

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: GraphiteSurfaceStyle.centerBaseHex))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: GraphiteSurfaceStyle.shellTopHex),
                            Color(hex: GraphiteSurfaceStyle.shellMidHex),
                            Color(hex: GraphiteSurfaceStyle.centerBaseHex),
                            Color(hex: GraphiteSurfaceStyle.shellBaseHex)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.018),
                    Color(hex: GraphiteSurfaceStyle.centerTopHex).opacity(0.18),
                    .clear,
                    Color(hex: GraphiteSurfaceStyle.centerFloorHex).opacity(0.30)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.018),
                    Color(hex: GraphiteSurfaceStyle.centerTopHex).opacity(0.12),
                    .clear
                ],
                center: UnitPoint(x: 0.62, y: 0.08),
                startRadius: 80,
                endRadius: 760
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.010),
                    Color(hex: GraphiteSurfaceStyle.centerMidHex).opacity(0.075),
                    .clear
                ],
                center: UnitPoint(x: 0.32, y: 0.94),
                startRadius: 120,
                endRadius: 820
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.008),
                    .clear
                ],
                center: UnitPoint(x: 0.08, y: 0.18),
                startRadius: 60,
                endRadius: 420
            )

            GraphiteNoiseLayer(opacity: 0.030, sampleCount: 340)

            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.025)).frame(height: 1)
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.006),
                        Color(hex: GraphiteSurfaceStyle.centerFloorHex).opacity(0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 84)
            }
        }
        .ignoresSafeArea()
    }
}

private struct MainCenterGraphiteBackground: View {
    let palette: TrackPalette

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: GraphiteSurfaceStyle.centerBaseHex))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: GraphiteSurfaceStyle.centerTopHex),
                            Color(hex: GraphiteSurfaceStyle.centerMidHex),
                            Color(hex: GraphiteSurfaceStyle.centerBaseHex),
                            Color(hex: GraphiteSurfaceStyle.centerFloorHex)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.014),
                    Color(hex: GraphiteSurfaceStyle.raisedBaseHex).opacity(0.12),
                    .clear
                ],
                center: UnitPoint(x: 0.66, y: 0.12),
                startRadius: 70,
                endRadius: 700
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.012),
                    .clear
                ],
                center: UnitPoint(x: 0.38, y: 0.96),
                startRadius: 120,
                endRadius: 760
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.006),
                    .clear
                ],
                center: UnitPoint(x: 0.92, y: 0.34),
                startRadius: 80,
                endRadius: 560
            )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.022),
                            .clear,
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)

            GraphiteNoiseLayer(opacity: 0.032, sampleCount: 340)
        }
    }
}

private struct GraphiteNoiseLayer: View {
    let opacity: Double
    let sampleCount: Int

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0, sampleCount > 0 else { return }

            for index in 0..<sampleCount {
                let xSeed = Self.unitNoise(index: index, salt: 17)
                let ySeed = Self.unitNoise(index: index, salt: 53)
                let alphaSeed = Self.unitNoise(index: index, salt: 97)
                let x = xSeed * size.width
                let y = ySeed * size.height
                let side = 0.45 + Self.unitNoise(index: index, salt: 131) * 0.95
                let alpha = opacity * (0.20 + alphaSeed * 0.80)
                let rect = CGRect(x: x, y: y, width: side, height: side)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
            }
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }

    private static func unitNoise(index: Int, salt: Int) -> Double {
        let value = sin(Double(index * 12_989 + salt * 78_233)) * 43_758.5453
        return value - floor(value)
    }
}

private struct TrackpadSwipeBackHandler: NSViewRepresentable {
    let onBack: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBack: onBack)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onBack = onBack
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var onBack: () -> Void
        private var monitor: Any?
        private var lastSwipeDate = Date.distantPast

        init(onBack: @escaping () -> Void) {
            self.onBack = onBack
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(_ event: NSEvent) {
            guard !Self.isTextInputFocused else { return }
            guard !Self.isInsideScrollView(event) else { return }

            let horizontal = event.scrollingDeltaX
            let vertical = event.scrollingDeltaY
            guard horizontal > 150,
                  abs(horizontal) > abs(vertical) * 3.2
            else { return }

            let now = Date()
            guard now.timeIntervalSince(lastSwipeDate) > 0.9 else { return }
            lastSwipeDate = now
            onBack()
        }

        private static var isTextInputFocused: Bool {
            MainActor.assumeIsolated {
                guard let responder = NSApp.keyWindow?.firstResponder else { return false }
                return responder is NSTextView || responder is NSTextField
            }
        }

        private static func isInsideScrollView(_ event: NSEvent) -> Bool {
            guard let contentView = event.window?.contentView else { return false }
            var view = contentView.hitTest(event.locationInWindow)
            while let currentView = view {
                if currentView is NSScrollView {
                    return true
                }
                view = currentView.superview
            }
            return false
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: ShellDestination
    @Binding var selectedPlaylist: LibraryPlaylistSelection?
    let searchFocusRequest: Int
    let onCreatePlaylist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(SidebarVisualStyle.brandFillOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.white.opacity(SidebarVisualStyle.brandStrokeOpacity), lineWidth: 1)
                        )
                    Image(systemName: "waveform")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(NoirwaveTheme.primaryAccent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Noirwave")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(store.currentTrack?.artist.nonEmpty ?? "music")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 8)

            SidebarSearchField(selection: $selection, focusRequest: searchFocusRequest)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(ShellDestination.allCases.filter { $0 != .profile }) { destination in
                    SidebarItem(
                        title: destination.rawValue,
                        symbol: destination.symbol,
                        active: selection == destination
                    ) {
                        selection = destination
                        selectedPlaylist = nil
                        store.leaveCatalogContext()
                    }
                }
            }

            SidebarPlaylistPreview(
                selection: $selection,
                selectedPlaylist: $selectedPlaylist,
                onCreatePlaylist: onCreatePlaylist
            )

            Spacer(minLength: 10)

            SidebarProfileAccountBlock(active: selection == .profile) {
                selection = .profile
                selectedPlaylist = nil
                store.leaveCatalogContext()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .foregroundStyle(.white)
        .noirwaveSidebarGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            appearance: SidebarVisualStyle.panelAppearance
        )
    }
}

private struct SidebarSearchField: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: ShellDestination
    let focusRequest: Int
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(SidebarVisualStyle.inactiveIconOpacity))

            TextField(
                "Search catalog",
                text: Binding(
                    get: { store.searchQuery },
                    set: { value in
                        store.updateSearchQuery(value)
                        if !value.trimmed.isEmpty {
                            selection = .search
                            store.leaveCatalogContext()
                        }
                    }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .focused($isFocused)

            if store.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.58)
                    .frame(width: 12, height: 12)
            }

            if !store.searchQuery.trimmed.isEmpty {
                Button {
                    store.updateSearchQuery("")
                    isFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(SidebarVisualStyle.inactiveIconOpacity))
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            .white.opacity(isFocused ? SidebarVisualStyle.searchFocusedFillOpacity : SidebarVisualStyle.searchRestFillOpacity),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    isFocused
                        ? NoirwaveTheme.primaryAccent.opacity(SidebarVisualStyle.searchFocusedStrokeOpacity)
                        : .white.opacity(SidebarVisualStyle.searchRestStrokeOpacity),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 5)
        .onChange(of: focusRequest) { _, _ in
            selection = .search
            isFocused = true
        }
    }
}

private struct SidebarGlassSelectionBackground<S: InsettableShape>: View {
    let shape: S
    let isActive: Bool
    let isHovered: Bool

    private var fillOpacity: Double {
        if isActive { return 0.034 }
        return isHovered ? SidebarVisualStyle.hoverFillOpacity : 0
    }

    private var strokeOpacity: Double {
        if isActive { return SidebarVisualStyle.activeStrokeOpacity }
        return isHovered ? SidebarVisualStyle.hoverStrokeOpacity : 0
    }

    @ViewBuilder
    var body: some View {
        if isActive || isHovered {
            ZStack {
                selectionMaterial

                shape
                    .fill(NoirwaveTheme.primaryAccent.opacity(isActive ? SidebarVisualStyle.activeAccentFillOpacity : 0))

                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(fillOpacity),
                                .white.opacity(fillOpacity * 0.36),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                shape
                    .strokeBorder(
                        LinearGradient(
                                colors: [
                                    isActive
                                    ? NoirwaveTheme.primaryAccent.opacity(0.13)
                                    : .white.opacity(strokeOpacity),
                                .white.opacity(strokeOpacity * 0.42),
                                .white.opacity(strokeOpacity * 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                shape
                    .stroke(.white.opacity(isActive ? 0.060 : 0.035), lineWidth: 1)
                    .blur(radius: 0.35)
                    .mask(alignment: .top) {
                        Rectangle().frame(height: isActive ? 12 : 7)
                    }
            }
            .clipShape(shape)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var selectionMaterial: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            shape
                .fill(.white.opacity(isActive ? 0.008 : 0.003))
                .glassEffect(
                    .regular
                        .tint(Color.white.opacity(isActive ? 0.004 : 0.002))
                        .interactive(false),
                    in: shape
                )
        } else {
            fallbackSelectionMaterial
        }
#else
        fallbackSelectionMaterial
#endif
    }

    @ViewBuilder
    private var fallbackSelectionMaterial: some View {
        if isActive {
            NoirwaveVisualEffectMaterial(material: SidebarVisualStyle.panelMaterial, blendingMode: .withinWindow)
                .opacity(0.12)
                .clipShape(shape)
        } else if isHovered {
            NoirwaveVisualEffectMaterial(material: SidebarVisualStyle.panelMaterial, blendingMode: .withinWindow)
                .opacity(0.060)
                .clipShape(shape)
        }
    }
}

private struct SidebarItem: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovered = false
    let title: String
    let symbol: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Capsule()
                    .fill(active ? NoirwaveTheme.primaryAccent.opacity(SidebarVisualStyle.activeAccentOpacity) : .clear)
                    .frame(width: 2, height: 18)

                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        active
                            ? NoirwaveTheme.primaryAccent.opacity(0.95)
                            : .white.opacity(isHovered ? SidebarVisualStyle.inactiveIconHoverOpacity : SidebarVisualStyle.inactiveIconOpacity)
                    )
                    .frame(width: 17)

                Text(title)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))

                Spacer()
            }
            .foregroundStyle(
                active
                    ? .white.opacity(SidebarVisualStyle.activeTextOpacity)
                    : .white.opacity(isHovered ? SidebarVisualStyle.inactiveTextHoverOpacity : SidebarVisualStyle.inactiveTextOpacity)
            )
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background {
                SidebarGlassSelectionBackground(
                    shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                    isActive: active,
                    isHovered: isHovered
                )
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.14), value: isHovered)
    }
}

private struct SidebarProfileAccountBlock: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovered = false
    let active: Bool
    let action: () -> Void

    private var subtitle: String {
        store.currentTrack?.artist.nonEmpty ?? "Account"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(active ? 0.070 : (isHovered ? 0.060 : 0.040)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(active ? 0.12 : 0.075), lineWidth: 1)
                        )
                    Image(systemName: ShellDestination.profile.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(active ? .white.opacity(0.92) : .white.opacity(0.62))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Profile")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(active ? .white.opacity(0.96) : .white.opacity(0.78))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Capsule()
                    .fill(active ? NoirwaveTheme.primaryAccent.opacity(SidebarVisualStyle.activeAccentOpacity) : .clear)
                    .frame(width: 2, height: 18)
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background {
                SidebarGlassSelectionBackground(
                    shape: RoundedRectangle(cornerRadius: 11, style: .continuous),
                    isActive: active,
                    isHovered: isHovered
                )
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Profile")
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.14), value: isHovered)
    }
}

struct SidebarPlaylistPreviewItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let artworkTracks: [Track]
    let selection: LibraryPlaylistSelection

    init(
        id: String,
        title: String,
        subtitle: String,
        symbol: String,
        artworkTracks: [Track],
        selection: LibraryPlaylistSelection
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.artworkTracks = artworkTracks
        self.selection = selection
    }
}

enum SidebarPlaylistPreviewBuilder {
    static let collapsedLimit = 5

    static func allItems(
        localPlaylists: [LocalPlaylist],
        tracksForPlaylist: (LocalPlaylist) -> [Track]
    ) -> [SidebarPlaylistPreviewItem] {
        localPlaylists.map { playlist in
            let tracks = tracksForPlaylist(playlist)
            return SidebarPlaylistPreviewItem(
                id: "playlist.\(playlist.id)",
                title: playlist.title,
                subtitle: "\(playlist.trackCount) track\(playlist.trackCount == 1 ? "" : "s")",
                symbol: "music.note.list",
                artworkTracks: Array(tracks.prefix(4)),
                selection: .localPlaylist(playlist.id)
            )
        }
    }

    static func visibleItems(
        localPlaylists: [LocalPlaylist],
        isExpanded: Bool,
        tracksForPlaylist: (LocalPlaylist) -> [Track]
    ) -> [SidebarPlaylistPreviewItem] {
        let items = allItems(localPlaylists: localPlaylists, tracksForPlaylist: tracksForPlaylist)
        guard !isExpanded else { return items }
        return Array(items.prefix(collapsedLimit))
    }
}

private struct SidebarPlaylistPreview: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: ShellDestination
    @Binding var selectedPlaylist: LibraryPlaylistSelection?
    let onCreatePlaylist: () -> Void

    private var allPlaylists: [SidebarPlaylistPreviewItem] {
        SidebarPlaylistPreviewBuilder.allItems(
            localPlaylists: store.localPlaylists,
            tracksForPlaylist: { playlist in
                store.playlistTracks(playlistID: playlist.id)
            }
        )
    }

    private var playlists: [SidebarPlaylistPreviewItem] {
        SidebarPlaylistPreviewBuilder.visibleItems(
            localPlaylists: store.localPlaylists,
            isExpanded: false,
            tracksForPlaylist: { playlist in
                store.playlistTracks(playlistID: playlist.id)
            }
        )
    }

    private var accent: Color {
        NoirwaveTheme.primaryAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Playlists")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Button(action: onCreatePlaylist) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(.white.opacity(0.055), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(SidebarVisualStyle.hoverStrokeOpacity), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(NoirwaveTheme.primaryAccent)
                .help("Create playlist")
                .accessibilityLabel("Create playlist")

                Text("\(allPlaylists.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(.horizontal, 8)

            if playlists.isEmpty {
                SidebarPlaylistEmptyRow(accent: accent, action: onCreatePlaylist)
            } else {
                VStack(spacing: 4) {
                    ForEach(playlists) { playlist in
                        let isSelected = selection == .library
                            && selectedPlaylist == playlist.selection
                        SidebarPlaylistRow(playlist: playlist, isSelected: isSelected) {
                            selectedPlaylist = playlist.selection
                            selection = .library
                            store.leaveCatalogContext()
                        }
                    }
                }
            }
        }
    }
}

private struct SidebarPlaylistRow: View {
    @State private var isHovered = false
    let playlist: SidebarPlaylistPreviewItem
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        NoirwaveTheme.primaryAccent
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                LibraryMosaicArtwork(tracks: playlist.artworkTracks, size: 30, accent: accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(isSelected ? SidebarVisualStyle.activeTextOpacity : 0.84))
                        .lineLimit(1)
                    Text(playlist.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(isSelected ? SidebarVisualStyle.inactiveIconOpacity : 0.45))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: playlist.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? NoirwaveTheme.primaryAccent.opacity(0.92)
                            : .white.opacity(isHovered ? SidebarVisualStyle.inactiveIconOpacity : 0.38)
                    )
                    .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background {
                SidebarGlassSelectionBackground(
                    shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                    isActive: isSelected,
                    isHovered: isHovered
                )
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(playlist.title)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.14), value: isHovered)
    }
}

private struct SidebarPlaylistEmptyRow: View {
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.68))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create playlist")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                    Text("No playlists yet")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background {
                SidebarGlassSelectionBackground(
                    shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                    isActive: false,
                    isHovered: true
                )
            }
        }
        .buttonStyle(.plain)
        .help("Create playlist")
    }
}

private struct TopBarView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: ShellDestination

    var body: some View {
        HStack(spacing: 12) {
            if ContentDeckRouting.showsCatalogDetail(
                selectionIsCatalog: selection == .search,
                hasCatalogContext: store.catalogContext != nil
            ) {
                Button {
                    store.leaveCatalogContext()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help("Back")
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ContentDeckView: View {
    @EnvironmentObject private var store: PlayerStore
    let selection: ShellDestination
    @Binding var selectedPlaylist: LibraryPlaylistSelection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.needsBackendSession,
                   let errorMessage = store.errorMessage?.nonEmpty {
                    PlaybackErrorBanner(message: errorMessage)
                }

                if ContentDeckRouting.showsCatalogDetail(
                    selectionIsCatalog: selection == .search,
                    hasCatalogContext: store.catalogContext != nil
                ), let context = store.catalogContext {
                    CatalogDetailContent(context: context)
                } else if ContentDeckRouting.showsSearchResults(
                    selectionIsCatalog: selection == .search,
                    hasCatalogContext: store.catalogContext != nil,
                    searchQuery: store.searchQuery
                ) {
                    SearchResultsView(items: store.visibleTracks, isLoading: store.isSearching)
                } else {
                    switch selection {
                    case .listenNow:
                        ListenNowView()
                    case .search:
                        CatalogLandingView()
                    case .library:
                        LibraryView(selectedPlaylistSelection: $selectedPlaylist)
                    case .profile:
                        ProfileSettingsView()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 132)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

private struct CatalogDetailContent: View {
    @EnvironmentObject private var store: PlayerStore
    let context: Track

    var body: some View {
        switch context.kind {
        case .artist:
            ArtistDetailView(artist: context, items: store.visibleTracks, isLoading: store.isSearching)
        case .album:
            AlbumDetailView(album: context, items: store.visibleTracks, isLoading: store.isSearching)
        case .track:
            TrackListSection(title: "Track", subtitle: context.artist, tracks: [context], numbered: false)
        }
    }
}

private struct ListenNowView: View {
    @EnvironmentObject private var store: PlayerStore

    private var tracks: [Track] {
        store.featuredTracks.filter(\.isPlayable)
    }

    var body: some View {
        if store.isLoadingFeaturedTracks && tracks.isEmpty {
            CatalogLoadingSkeletonView(title: "Loading catalog", subtitle: store.provider.sourceName, showsHero: true)
        } else if store.featuredTracks.isEmpty {
            MusicConnectPanel()
        } else {
            VStack(alignment: .leading, spacing: 24) {
                WaveLaunchHero(tracks: tracks)

                let likedTracks = store.likedTracks(limit: Int.max)
                if !likedTracks.isEmpty {
                    FeaturedTrackShelf(title: "Любимое", tracks: likedTracks)
                }

                FeaturedTrackShelf(title: "Рекомендации", tracks: tracks)
                TrackListSection(title: "Новые релизы", subtitle: "\(tracks.count)", tracks: tracks, numbered: true)
            }
        }
    }
}

private struct WaveLaunchHero: View {
    @EnvironmentObject private var store: PlayerStore
    let tracks: [Track]

    private var heroTrack: Track? {
        store.currentTrack ?? tracks.first
    }

    var body: some View {
        if let track = heroTrack {
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: 0) {
                    Spacer()
                    ArtworkTile(track: track, size: 270, cornerRadius: 18)
                        .rotationEffect(.degrees(-4))
                        .shadow(color: NoirwaveTheme.primaryAccent.opacity(0.18), radius: 38, x: 0, y: 22)
                        .padding(.trailing, 58)
                        .padding(.vertical, 34)
                }

                LinearGradient(
                    colors: [
                        Color(hex: GraphiteSurfaceStyle.centerTopHex).opacity(0.24),
                        track.palette.base.opacity(0.48),
                        Color(hex: GraphiteSurfaceStyle.centerBaseHex).opacity(0.50)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Твоя волна")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        Text(track.artist)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        Button {
                            store.startWave()
                        } label: {
                            Label("Запустить волну", systemImage: "play.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 20)
                                .frame(height: 50)
                                .background(NoirwaveTheme.primaryAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Start wave")

                        Button {
                            store.toggleLike(track)
                        } label: {
                            Image(systemName: store.isLiked(track) ? "heart.fill" : "heart")
                                .font(.system(size: 17, weight: .bold))
                                .frame(width: 50, height: 50)
                                .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(store.isLiked(track) ? NoirwaveTheme.primaryAccent : .white.opacity(0.82))
                        .help(store.isLiked(track) ? "Unlike" : "Like")
                    }
                }
                .padding(30)
            }
            .frame(maxWidth: .infinity, minHeight: 330, alignment: .bottomLeading)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(
                Color.white.opacity(0.018),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

private struct CatalogLandingView: View {
    @EnvironmentObject private var store: PlayerStore

    private var tracks: [Track] {
        store.featuredTracks.filter(\.isPlayable)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SearchPromptStage()

            if store.isLoadingFeaturedTracks && tracks.isEmpty {
                CatalogLoadingSkeletonView(title: "Loading catalog", subtitle: store.provider.sourceName, showsHero: false)
            } else if store.featuredTracks.isEmpty {
                MusicConnectPanel()
            } else {
                CollectionActionCluster(
                    tracks: tracks,
                    accent: NoirwaveTheme.primaryAccent,
                    primaryLabel: "Play"
                )
                FeaturedTrackShelf(title: "Можно включить", tracks: tracks)
            }
        }
    }
}

private struct SearchPromptStage: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Catalog")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Use the sidebar search field for artists, albums, and tracks.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
        }
        .padding(.top, 18)
    }
}

private struct SearchResultsView: View {
    @EnvironmentObject private var store: PlayerStore
    let items: [Track]
    let isLoading: Bool

    private var presentation: SearchResultsPresentation {
        SearchResultsPresentation(items: items, query: store.searchQuery)
    }

    var body: some View {
        if presentation.isEmpty {
            EmptySearchView(isSearching: isLoading)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if let best = presentation.bestMatch {
                    SearchBestMatchRow(item: best)
                }

                SearchResultListSection(title: "Исполнители", items: presentation.artists)
                SearchResultListSection(title: "Треки", items: presentation.tracks)
                SearchResultListSection(title: "Альбомы", items: presentation.albums)
            }
        }
    }
}

private struct SearchBestMatchRow: View {
    @EnvironmentObject private var store: PlayerStore
    let item: Track

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        Button {
            store.activate(item)
        } label: {
            HStack(spacing: 12) {
                ArtworkTile(track: item, size: 58, cornerRadius: item.kind == .artist ? 29 : 9)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        MediaKindBadge(kind: item.kind)
                        Text("Best match")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.42))
                            .textCase(.uppercase)
                    }

                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(item.detailLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Image(systemName: item.isPlayable ? "play.fill" : "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black.opacity(0.82))
                    .frame(width: 34, height: 34)
                    .background(NoirwaveTheme.primaryAccent, in: Circle())
                    .shadow(color: NoirwaveTheme.primaryAccent.opacity(0.16), radius: 10, x: 0, y: 0)
            }
            .padding(12)
            .noirwaveContentGlass(
                in: cardShape,
                fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
                strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
            )
            .overlay(
                cardShape
                    .strokeBorder(NoirwaveTheme.primaryAccent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(item.isPlayable ? "Play \(item.title)" : "Open \(item.title)")
    }
}

private struct SearchResultListSection: View {
    let title: String
    let items: [Track]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: title, subtitle: "\(items.count)")

                VStack(spacing: 6) {
                    ForEach(items) { item in
                        SearchResultRow(item: item)
                    }
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    @EnvironmentObject private var store: PlayerStore
    let item: Track

    var body: some View {
        let rowShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        Button {
            store.activate(item)
        } label: {
            HStack(spacing: 10) {
                ArtworkTile(track: item, size: 42, cornerRadius: item.kind == .artist ? 21 : 7)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)

                    Text(item.detailLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                MediaKindBadge(kind: item.kind)

                Image(systemName: item.isPlayable ? "play.fill" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NoirwaveTheme.primaryAccent.opacity(0.86))
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .noirwaveContentGlass(
                in: rowShape,
                fillOpacity: 0.025,
                strokeOpacity: 0.060
            )
        }
        .buttonStyle(.plain)
        .help(item.isPlayable ? "Play \(item.title)" : "Open \(item.title)")
    }
}

private struct PlaylistEditor: Identifiable {
    let id = UUID()
    let playlistID: String?
    let title: String
    let tracks: [Track]

    init(playlistID: String?, title: String, tracks: [Track] = []) {
        self.playlistID = playlistID
        self.title = title
        self.tracks = tracks
    }
}

enum LibrarySurfaceSection: String, Identifiable, Equatable {
    case collections
    case favoriteTracks
    case playlists

    var id: String { rawValue }
}

enum LibrarySurfaceLayout {
    static func sections(hasTracks: Bool, hasSavedCollections: Bool, hasLocalPlaylists: Bool) -> [LibrarySurfaceSection] {
        var sections: [LibrarySurfaceSection] = []
        if hasTracks {
            sections.append(.favoriteTracks)
        }
        if hasTracks || hasSavedCollections || hasLocalPlaylists {
            sections.append(.playlists)
        }
        if hasSavedCollections {
            sections.append(.collections)
        }
        return sections
    }
}

struct LibraryPlaylistShelfItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let artworkTracks: [Track]
    let searchText: String
    let selection: LibraryPlaylistSelection
}

enum LibraryPlaylistShelfBuilder {
    static func items(likedTracks: [Track], localPlaylists: [LocalPlaylist], query: String) -> [LibraryPlaylistShelfItem] {
        let term = query.searchNormalized
        _ = likedTracks
        let localItems = localPlaylists.map(localPlaylistItem)

        guard !term.isEmpty else { return localItems }

        return localItems.filter { item in
            let searchableText = item.searchText.searchNormalized
            let tokens = term.split(separator: " ").map(String.init)
            return searchableText.contains(term)
                || tokens.allSatisfy { searchableText.contains($0) }
        }
    }

    private static func localPlaylistItem(_ playlist: LocalPlaylist) -> LibraryPlaylistShelfItem {
        let tracks = playlist.orderedTracks(preferredTracks: [])
        return LibraryPlaylistShelfItem(
            id: "playlist.\(playlist.id)",
            title: playlist.title,
            subtitle: "\(playlist.trackCount) track\(playlist.trackCount == 1 ? "" : "s")",
            symbol: "music.note.list",
            artworkTracks: Array(tracks.prefix(4)),
            searchText: searchableText(
                title: playlist.title,
                subtitle: "\(playlist.trackCount) track\(playlist.trackCount == 1 ? "" : "s")",
                aliases: [],
                tracks: tracks
            ),
            selection: .localPlaylist(playlist.id)
        )
    }

    private static func searchableText(title: String, subtitle: String, aliases: [String], tracks: [Track]) -> String {
        ([title, subtitle] + aliases + tracks.flatMap { [$0.title, $0.artist, $0.album] })
            .joined(separator: " ")
    }
}

enum LibrarySectionExpansion {
    static let collapsedLimit = 6

    static func visibleItems<T>(_ items: [T], isExpanded: Bool) -> [T] {
        isExpanded ? items : Array(items.prefix(collapsedLimit))
    }

    static func showsToggle(totalCount: Int) -> Bool {
        totalCount > collapsedLimit
    }
}

private struct LibraryView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedPlaylistSelection: LibraryPlaylistSelection?
    @State private var favoriteTracksQuery = ""
    @State private var playlistShelfQuery = ""
    @State private var librarySortMode: LibrarySortMode = .recentlyAdded
    @State private var playlistEditor: PlaylistEditor?
    @State private var overflowSheet: LibraryOverflowSheet?

    private var likedTracks: [Track] {
        store.likedTracks(limit: Int.max)
    }

    private var localPlaylists: [LocalPlaylist] {
        store.localPlaylists
    }

    private var selectedLocalPlaylist: LocalPlaylist? {
        guard let playlistID = selectedPlaylistSelection?.localPlaylistID else { return nil }
        return localPlaylists.first { $0.id == playlistID }
    }

    private var savedCollections: [Track] {
        store.savedCollections(limit: 16)
    }

    private var filteredTracks: [Track] {
        LibraryTrackOrganizer.tracks(likedTracks, query: "", sortMode: librarySortMode)
    }

    private var favoriteTracks: [Track] {
        FavoriteTracksOrganizer.tracks(
            likedTracks,
            libraryQuery: "",
            localQuery: favoriteTracksQuery,
            sortMode: librarySortMode
        )
    }

    private var allPlaylistShelfItems: [LibraryPlaylistShelfItem] {
        LibraryPlaylistShelfBuilder.items(
            likedTracks: likedTracks,
            localPlaylists: localPlaylists,
            query: ""
        )
    }

    private var playlistShelfItems: [LibraryPlaylistShelfItem] {
        LibraryPlaylistShelfBuilder.items(
            likedTracks: likedTracks,
            localPlaylists: localPlaylists,
            query: playlistShelfQuery
        )
    }

    private var filteredSavedCollections: [Track] {
        savedCollections
    }

    private var albums: [Track] {
        DerivedLibraryEntities.albums(from: filteredTracks)
    }

    private var artists: [Track] {
        DerivedLibraryEntities.artists(from: filteredTracks)
    }

    private var surfaceSections: [LibrarySurfaceSection] {
        LibrarySurfaceLayout.sections(
            hasTracks: !likedTracks.isEmpty,
            hasSavedCollections: !savedCollections.isEmpty,
            hasLocalPlaylists: !localPlaylists.isEmpty
        )
    }

    var body: some View {
        if selectedPlaylistSelection == .likedSongs {
            LocalPlaylistDetailView(
                playlist: .likedSongs(trackCount: likedTracks.count),
                tracks: likedTracks,
                onBack: {
                    selectedPlaylistSelection = nil
                }
            )
        } else if let selectedLocalPlaylist {
            LocalPlaylistDetailView(
                playlist: .local(selectedLocalPlaylist),
                tracks: store.playlistTracks(playlistID: selectedLocalPlaylist.id),
                onBack: {
                    selectedPlaylistSelection = nil
                },
                onRename: {
                    playlistEditor = PlaylistEditor(playlistID: selectedLocalPlaylist.id, title: selectedLocalPlaylist.title)
                },
                onDelete: {
                    store.deletePlaylist(playlistID: selectedLocalPlaylist.id)
                    selectedPlaylistSelection = nil
                }
            )
            .sheet(item: $playlistEditor) { editor in
                PlaylistTitleSheet(title: editor.title, primaryLabel: "Rename") { title in
                    if let playlistID = editor.playlistID {
                        store.renamePlaylist(playlistID: playlistID, title: title)
                    }
                    playlistEditor = nil
                } onCancel: {
                    playlistEditor = nil
                }
            }
        } else if likedTracks.isEmpty && savedCollections.isEmpty && localPlaylists.isEmpty {
            EmptyLibraryPanel {
                playlistEditor = PlaylistEditor(playlistID: nil, title: LocalPlaylist.fallbackTitle)
            }
            .sheet(item: $playlistEditor) { editor in
                PlaylistTitleSheet(title: editor.title, primaryLabel: "Create") { title in
                    let playlist = store.createPlaylist(title: title)
                    selectedPlaylistSelection = .localPlaylist(playlist.id)
                    playlistEditor = nil
                } onCancel: {
                    playlistEditor = nil
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 24) {
                LibraryHeaderView(
                    sortMode: $librarySortMode,
                    totalCount: likedTracks.count + savedCollections.count + localPlaylists.count,
                ) {
                    playlistEditor = PlaylistEditor(playlistID: nil, title: LocalPlaylist.fallbackTitle)
                }

                LibraryStatsView(playlists: allPlaylistShelfItems.count, artists: artists, albums: albums, tracks: filteredTracks)

                if surfaceSections.isEmpty {
                    EmptyLibraryPanel {
                        playlistEditor = PlaylistEditor(playlistID: nil, title: LocalPlaylist.fallbackTitle)
                    }
                } else {
                    ForEach(surfaceSections) { section in
                        librarySurfaceSection(section)
                    }
                }
            }
            .sheet(item: $playlistEditor) { editor in
                PlaylistTitleSheet(title: editor.title, primaryLabel: "Create") { title in
                    let playlist = store.createPlaylist(title: title)
                    selectedPlaylistSelection = .localPlaylist(playlist.id)
                    playlistEditor = nil
                } onCancel: {
                    playlistEditor = nil
                }
            }
            .sheet(item: $overflowSheet) { sheet in
                switch sheet {
                case .favoriteTracks:
                    LibraryFavoriteTracksOverflowSheet(
                        query: $favoriteTracksQuery,
                        tracks: favoriteTracks,
                        totalTracks: filteredTracks.count,
                        accent: NoirwaveTheme.primaryAccent
                    )
                case .playlists:
                    LibraryPlaylistsOverflowSheet(
                        query: $playlistShelfQuery,
                        items: playlistShelfItems,
                        totalCount: allPlaylistShelfItems.count,
                        onCreatePlaylist: {
                            playlistEditor = PlaylistEditor(playlistID: nil, title: LocalPlaylist.fallbackTitle)
                        }
                    ) { selection in
                        selectedPlaylistSelection = selection
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func librarySurfaceSection(_ section: LibrarySurfaceSection) -> some View {
        switch section {
        case .collections:
            LibraryCollectionsShelf(
                tracks: filteredTracks,
                savedCollections: filteredSavedCollections,
                albums: albums,
                artists: artists
            )
        case .favoriteTracks:
            FavoriteTracksLibrarySection(
                query: $favoriteTracksQuery,
                tracks: favoriteTracks,
                totalTracks: filteredTracks.count,
                accent: NoirwaveTheme.primaryAccent,
                primaryLabel: "Play Favorites"
            ) {
                overflowSheet = .favoriteTracks
            }
        case .playlists:
            LibraryPlaylistsShelf(
                query: $playlistShelfQuery,
                items: playlistShelfItems,
                totalCount: allPlaylistShelfItems.count,
                onCreatePlaylist: {
                    playlistEditor = PlaylistEditor(playlistID: nil, title: LocalPlaylist.fallbackTitle)
                },
                onShowAll: {
                    overflowSheet = .playlists
                }
            ) { selection in
                selectedPlaylistSelection = selection
            }
        }
    }

}

private enum LibraryOverflowSheet: String, Identifiable {
    case favoriteTracks
    case playlists

    var id: String { rawValue }
}

private struct EmptyLibraryPanel: View {
    let onCreatePlaylist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Library")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Saved music will appear here.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))

            Button {
                onCreatePlaylist()
            } label: {
                Label("New Playlist", systemImage: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(NoirwaveTheme.primaryAccent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
    }
}

private struct PlaylistTitleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftTitle: String
    let primaryLabel: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    init(
        title: String,
        primaryLabel: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draftTitle = State(initialValue: title)
        self.primaryLabel = primaryLabel
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        let sheetShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        VStack(alignment: .leading, spacing: 18) {
            Text(primaryLabel == "Create" ? "New Playlist" : "Rename Playlist")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            TextField("Playlist name", text: $draftTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, weight: .medium))

            HStack(spacing: 8) {
                Spacer()

                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(primaryLabel) {
                    onSave(draftTitle)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 360)
        .noirwaveContentGlass(
            in: sheetShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct PlaylistDetailModel {
    let id: String?
    let title: String
    let trackCount: Int
    let kindLabel: String
    let originLabel: String

    static func local(_ playlist: LocalPlaylist) -> PlaylistDetailModel {
        PlaylistDetailModel(
            id: playlist.id,
            title: playlist.title,
            trackCount: playlist.trackCount,
            kindLabel: "Playlist",
            originLabel: "Local"
        )
    }

    static func likedSongs(trackCount: Int) -> PlaylistDetailModel {
        PlaylistDetailModel(
            id: nil,
            title: "Liked Songs",
            trackCount: trackCount,
            kindLabel: "Favorites",
            originLabel: "Dynamic"
        )
    }
}

private struct LocalPlaylistDetailView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var playlistQuery = ""
    @State private var playlistSortMode: PlaylistSortMode = .playlistOrder
    @State private var isConfirmingDelete = false
    let playlist: PlaylistDetailModel
    let tracks: [Track]
    let onBack: () -> Void
    let onRename: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        playlist: PlaylistDetailModel,
        tracks: [Track],
        onBack: @escaping () -> Void,
        onRename: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.playlist = playlist
        self.tracks = tracks
        self.onBack = onBack
        self.onRename = onRename
        self.onDelete = onDelete
    }

    private var accent: Color {
        NoirwaveTheme.primaryAccent
    }

    private var trackCountLabel: String {
        "\(playlist.trackCount) track\(playlist.trackCount == 1 ? "" : "s")"
    }

    private var visibleTracks: [Track] {
        PlaylistTrackOrganizer.tracks(tracks, query: playlistQuery, sortMode: playlistSortMode)
    }

    private var isFiltering: Bool {
        !playlistQuery.trimmed.isEmpty
    }

    private var actionTracks: [Track] {
        visibleTracks
    }

    private var visibleTrackCountLabel: String {
        isFiltering ? "\(visibleTracks.count) of \(tracks.count)" : trackCountLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArtistHeaderLayoutMetrics.detailSectionSpacing) {
            Button(action: onBack) {
                Label("Library", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Back to Library")

            HStack(alignment: .top, spacing: 24) {
                LibraryMosaicArtwork(tracks: Array(tracks.prefix(4)), size: 188, accent: accent)
                    .shadow(color: accent.opacity(0.26), radius: 26, x: 0, y: 18)

                VStack(alignment: .leading, spacing: 14) {
                    InfoPill(symbol: "music.note.list", text: playlist.kindLabel)

                    Text(playlist.title)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.58)

                    HStack(spacing: 8) {
                        InfoPill(symbol: "music.note", text: trackCountLabel)
                        InfoPill(symbol: "clock.arrow.circlepath", text: playlist.originLabel)
                    }

                    LocalPlaylistActionBar(
                        tracks: actionTracks,
                        accent: accent,
                        playlistID: playlist.id,
                        isFiltered: isFiltering,
                        onRename: onRename,
                        onDelete: onDelete == nil ? nil : {
                            isConfirmingDelete = true
                        }
                    )
                    .padding(.top, 4)
                }

                Spacer(minLength: 12)
            }
            .padding(.top, 2)

            if tracks.isEmpty {
                EmptyPlaylistTracksPanel(accent: accent)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    LocalLibrarySearchField(
                        query: $playlistQuery,
                        placeholder: "Find in playlist",
                        clearHelp: "Clear playlist search"
                    )
                    .frame(maxWidth: 360)

                    PlaylistSortMenu(selection: $playlistSortMode)

                    if isFiltering {
                        InfoPill(symbol: "line.3.horizontal.decrease.circle", text: visibleTrackCountLabel)
                    }

                    Spacer(minLength: 0)
                }

                if visibleTracks.isEmpty {
                    EmptyPlaylistSearchPanel(accent: accent)
                } else {
                    TrackListSection(
                        title: "Треки",
                        subtitle: visibleTrackCountLabel,
                        tracks: visibleTracks,
                        numbered: true,
                        playlistID: playlist.id
                    )
                }
            }
        }
        .confirmationDialog("Delete playlist?", isPresented: $isConfirmingDelete) {
            Button("Delete Playlist", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct EmptyPlaylistSearchPanel: View {
    let accent: Color

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 42, height: 42)
                .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("No matching tracks")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("0 found")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()
        }
        .padding(16)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct LocalPlaylistActionBar: View {
    @EnvironmentObject private var store: PlayerStore
    let tracks: [Track]
    let accent: Color
    let playlistID: String?
    let isFiltered: Bool
    let onRename: (() -> Void)?
    let onDelete: (() -> Void)?

    private var playableTracks: [Track] {
        tracks.filter(\.isPlayable)
    }

    private var primaryLabel: String {
        isFiltered ? "Play Matches" : "Play"
    }

    private var playHelp: String {
        isFiltered ? "Play matching tracks" : "Play playlist"
    }

    private var shuffleHelp: String {
        isFiltered ? "Shuffle matching tracks" : "Shuffle playlist"
    }

    private var playNextHelp: String {
        isFiltered ? "Play matching tracks next" : "Play next"
    }

    private var queueHelp: String {
        isFiltered ? "Add matching tracks to queue" : "Add playlist to queue"
    }

    var body: some View {
        HStack(spacing: 8) {
            if !playableTracks.isEmpty {
                Button {
                    store.playAll(playableTracks)
                } label: {
                    Label(primaryLabel, systemImage: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(playHelp)

                Button {
                    store.shufflePlay(playableTracks)
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help(shuffleHelp)

                Button {
                    store.playNext(playableTracks)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help(playNextHelp)

                Button {
                    store.enqueue(playableTracks)
                } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help(queueHelp)

                AddTracksToPlaylistMenu(
                    tracks: playableTracks,
                    excludingPlaylistID: playlistID,
                    help: "Add visible tracks to playlist",
                    size: 36
                )
            }

            if onRename != nil || onDelete != nil {
                Menu {
                    if let onRename {
                        Button(action: onRename) {
                            Label("Rename", systemImage: "pencil")
                        }
                    }

                    if onRename != nil, onDelete != nil {
                        Divider()
                    }

                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Playlist", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Playlist actions")
            }
        }
    }
}

private struct EmptyPlaylistTracksPanel: View {
    let accent: Color

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 42, height: 42)
                .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Empty playlist")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("0 tracks")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()
        }
        .padding(16)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct LibraryHeaderView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var sortMode: LibrarySortMode
    let totalCount: Int
    let onCreatePlaylist: () -> Void

    private var countLabel: String {
        "\(totalCount) items · \(sortMode.title)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Библиотека")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(countLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer(minLength: 0)

            LibraryCreatePlaylistMenu(onCreatePlaylist: onCreatePlaylist)
            LibrarySortMenu(selection: $sortMode)
        }
        .padding(.top, 10)
    }
}

private struct LibraryCreatePlaylistMenu: View {
    @EnvironmentObject private var store: PlayerStore
    let onCreatePlaylist: () -> Void

    private var accent: Color {
        NoirwaveTheme.primaryAccent
    }

    var body: some View {
        Menu {
            Button(action: onCreatePlaylist) {
                Label("New Playlist", systemImage: "plus")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("New playlist")
    }
}

private struct LibrarySortMenu: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: LibrarySortMode

    private var accent: Color {
        NoirwaveTheme.primaryAccent
    }

    var body: some View {
        Menu {
            ForEach(LibrarySortMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Label(mode.title, systemImage: selection == mode ? "checkmark" : mode.systemImage)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selection.systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)

                Text(selection.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.44))
            }
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.085), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Sort library")
    }
}

private struct PlaylistSortMenu: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: PlaylistSortMode

    private var accent: Color {
        NoirwaveTheme.primaryAccent
    }

    var body: some View {
        Menu {
            ForEach(PlaylistSortMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Label(mode.title, systemImage: selection == mode ? "checkmark" : mode.systemImage)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selection.systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)

                Text(selection.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.44))
            }
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.085), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Sort playlist")
    }
}

private struct LocalLibrarySearchField: View {
    @EnvironmentObject private var store: PlayerStore
    @FocusState private var isFocused: Bool
    @Binding var query: String
    let placeholder: String
    let clearHelp: String

    private var accent: Color {
        NoirwaveTheme.primaryAccent
    }

    private var borderColor: Color {
        isFocused ? accent.opacity(0.34) : .white.opacity(!query.trimmed.isEmpty ? 0.12 : 0.085)
    }

    init(
        query: Binding<String>,
        placeholder: String = "Search",
        clearHelp: String = "Clear search"
    ) {
        _query = query
        self.placeholder = placeholder
        self.clearHelp = clearHelp
    }

    var body: some View {
        let fieldShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .focused($isFocused)

            if !query.trimmed.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.52))
                .help(clearHelp)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 34)
        .noirwaveContentGlass(in: fieldShape, fillOpacity: 0.042, strokeOpacity: 0.060)
        .overlay(
            fieldShape
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

private struct FavoriteTracksLibrarySection: View {
    @Binding var query: String
    let tracks: [Track]
    let totalTracks: Int
    let accent: Color
    let primaryLabel: String
    let onShowAll: () -> Void

    private var isFiltering: Bool {
        !query.trimmed.isEmpty
    }

    private var countLabel: String {
        isFiltering ? "\(tracks.count) of \(totalTracks)" : "\(totalTracks)"
    }

    private var visibleTracks: [Track] {
        LibrarySectionExpansion.visibleItems(tracks, isExpanded: false)
    }

    private var showsToggle: Bool {
        LibrarySectionExpansion.showsToggle(totalCount: tracks.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LikedSongsFeatureBlock(
                tracks: tracks,
                totalTracks: totalTracks,
                accent: accent,
                primaryLabel: primaryLabel
            )

            HStack(alignment: .center, spacing: 12) {
                ExpandableSectionTitle(
                    title: "Любимые треки",
                    subtitle: countLabel,
                    isExpanded: false,
                    showsToggle: showsToggle
                ) { onShowAll() }

                Spacer(minLength: 12)
                LocalLibrarySearchField(
                    query: $query,
                    placeholder: "Find in favorites",
                    clearHelp: "Clear favorites search"
                )
                .frame(minWidth: 220, maxWidth: 320)
            }

            if tracks.isEmpty {
                EmptyFavoriteTracksSearchPanel(accent: accent)
            } else {
                trackGrid
                    .transition(.opacity)
            }
        }
    }

    private static let trackColumns = [
        GridItem(.adaptive(minimum: 340), spacing: 9, alignment: .top)
    ]

    private var trackGrid: some View {
        LazyVGrid(columns: Self.trackColumns, alignment: .leading, spacing: 9) {
            ForEach(Array(visibleTracks.enumerated()), id: \.element.id) { index, track in
                TrackRowView(track: track, index: index + 1, playbackContext: tracks)
            }
        }
    }
}

private struct LikedSongsFeatureBlock: View {
    let tracks: [Track]
    let totalTracks: Int
    let accent: Color
    let primaryLabel: String

    private var subtitle: String {
        "\(totalTracks) liked track\(totalTracks == 1 ? "" : "s")"
    }

    var body: some View {
        let blockShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(alignment: .center, spacing: 14) {
            LibraryMosaicArtwork(tracks: Array(tracks.prefix(4)), size: 86, accent: accent)
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Мне нравится")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.54))
                }

                CollectionActionCluster(tracks: tracks, accent: accent, primaryLabel: primaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .noirwaveContentGlass(
            in: blockShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct EmptyFavoriteTracksSearchPanel: View {
    let accent: Color

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 42, height: 42)
                .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("No matching favorites")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("0 found")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()
        }
        .padding(16)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct LibraryCollectionsShelf: View {
    @EnvironmentObject private var store: PlayerStore
    let tracks: [Track]
    let savedCollections: [Track]
    let albums: [Track]
    let artists: [Track]

    private var collectionCount: Int {
        min(savedCollections.count, 10)
    }

    var body: some View {
        if !savedCollections.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Коллекции", subtitle: "\(collectionCount)")

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(savedCollections.prefix(10)) { collection in
                            let collectionTracks = savedCollectionTracks(for: collection)
                            LibraryCollectionCard(
                                title: collection.title,
                                subtitle: savedCollectionSubtitle(for: collection, matchingTracks: collectionTracks),
                                symbol: collection.kind == .artist ? "music.mic" : "square.stack.fill",
                                artworkTracks: collectionTracks,
                                accent: NoirwaveTheme.primaryAccent
                            ) {
                                store.activate(collection)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func savedCollectionTracks(for collection: Track) -> [Track] {
        switch collection.kind {
        case .track:
            []
        case .artist:
            tracks.filter { $0.artist.searchNormalized == collection.title.searchNormalized }
        case .album:
            tracks.filter {
                let sameAlbum = $0.album.searchNormalized == collection.title.searchNormalized
                let sameArtist = collection.artist.searchNormalized.isEmpty
                    || collection.artist.searchNormalized == "unknown artist"
                    || $0.artist.searchNormalized == collection.artist.searchNormalized
                return sameAlbum && sameArtist
            }
        }
    }

    private func savedCollectionSubtitle(for collection: Track, matchingTracks: [Track]) -> String {
        if !matchingTracks.isEmpty {
            return "\(matchingTracks.count) liked track\(matchingTracks.count == 1 ? "" : "s")"
        }

        switch collection.kind {
        case .artist:
            return "Saved artist"
        case .album:
            return "Saved album"
        case .track:
            return collection.detailLabel
        }
    }
}

private struct LibraryPlaylistsShelf: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var query: String
    let items: [LibraryPlaylistShelfItem]
    let totalCount: Int
    let onCreatePlaylist: () -> Void
    let onShowAll: () -> Void
    let onSelectPlaylist: (LibraryPlaylistSelection) -> Void

    private var isFiltering: Bool {
        !query.trimmed.isEmpty
    }

    private var countLabel: String {
        isFiltering ? "\(items.count) of \(totalCount)" : "\(totalCount)"
    }

    private var visibleItems: [LibraryPlaylistShelfItem] {
        LibrarySectionExpansion.visibleItems(items, isExpanded: false)
    }

    private var showsToggle: Bool {
        LibrarySectionExpansion.showsToggle(totalCount: items.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ExpandableSectionTitle(
                    title: "Мои плейлисты",
                    subtitle: countLabel,
                    isExpanded: false,
                    showsToggle: showsToggle
                ) { onShowAll() }

                Spacer(minLength: 12)

                LocalLibrarySearchField(
                    query: $query,
                    placeholder: "Search playlists",
                    clearHelp: "Clear playlist search"
                )
                .frame(minWidth: 220, maxWidth: 320)
            }

            if visibleItems.isEmpty && isFiltering {
                EmptyLibraryPlaylistSearchPanel()
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        LibraryCreatePlaylistTile(action: onCreatePlaylist)

                        ForEach(visibleItems) { item in
                            LibraryCollectionCard(
                                title: item.title,
                                subtitle: item.subtitle,
                                symbol: item.symbol,
                                artworkTracks: item.artworkTracks,
                                accent: NoirwaveTheme.primaryAccent
                            ) {
                                onSelectPlaylist(item.selection)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct LibraryFavoriteTracksOverflowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var query: String
    let tracks: [Track]
    let totalTracks: Int
    let accent: Color

    private static let columns = [
        GridItem(.adaptive(minimum: 340), spacing: 9, alignment: .top)
    ]

    private var countLabel: String {
        query.trimmed.isEmpty ? "\(totalTracks)" : "\(tracks.count) of \(totalTracks)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LibraryOverflowHeader(
                title: "Любимые треки",
                subtitle: countLabel,
                onClose: { dismiss() }
            )

            LocalLibrarySearchField(
                query: $query,
                placeholder: "Find in favorites",
                clearHelp: "Clear favorites search"
            )

            ScrollView(.vertical) {
                LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 9) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(track: track, index: index + 1, playbackContext: tracks)
                    }
                }
                .padding(.trailing, 4)
            }
            .scrollIndicators(.visible)
        }
        .padding(18)
        .frame(width: 760, height: 560, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct LibraryPlaylistsOverflowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var query: String
    let items: [LibraryPlaylistShelfItem]
    let totalCount: Int
    let onCreatePlaylist: () -> Void
    let onSelectPlaylist: (LibraryPlaylistSelection) -> Void

    private static let columns = [
        GridItem(.adaptive(minimum: 190), spacing: 14, alignment: .top)
    ]

    private var countLabel: String {
        query.trimmed.isEmpty ? "\(totalCount)" : "\(items.count) of \(totalCount)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LibraryOverflowHeader(
                title: "Мои плейлисты",
                subtitle: countLabel,
                onClose: { dismiss() }
            )

            LocalLibrarySearchField(
                query: $query,
                placeholder: "Search playlists",
                clearHelp: "Clear playlist search"
            )

            ScrollView(.vertical) {
                LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 14) {
                    LibraryCreatePlaylistTile {
                        dismiss()
                        onCreatePlaylist()
                    }

                    ForEach(items) { item in
                        LibraryCollectionCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            symbol: item.symbol,
                            artworkTracks: item.artworkTracks,
                            accent: NoirwaveTheme.primaryAccent
                        ) {
                            dismiss()
                            onSelectPlaylist(item.selection)
                        }
                    }
                }
                .padding(.trailing, 4)
            }
            .scrollIndicators(.visible)
        }
        .padding(18)
        .frame(width: 760, height: 560, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NoirwaveTheme.primaryAccent.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct LibraryOverflowHeader: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close")
        }
    }
}

private struct ExpandableSectionTitle: View {
    let title: String
    let subtitle: String
    let isExpanded: Bool
    let showsToggle: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
            if showsToggle {
                Button(action: onToggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(NoirwaveTheme.primaryAccent)
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse" : "Show all")
                .accessibilityLabel(isExpanded ? "Collapse section" : "Show all")
            }
        }
    }
}

private struct EmptyLibraryPlaylistSearchPanel: View {
    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 42, height: 42)
                .background(NoirwaveTheme.primaryAccent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("No matching playlists")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("Try another playlist name or track")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()
        }
        .padding(16)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct LibraryCreatePlaylistTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white.opacity(0.038))
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NoirwaveTheme.primaryAccent)
                        .frame(width: 40, height: 40)
                        .background(NoirwaveTheme.primaryAccent.opacity(0.10), in: Circle())
                }
                .frame(width: 132, height: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.white.opacity(0.075), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create playlist")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("Start empty")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }
            }
            .frame(width: 132, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help("New playlist")
    }
}

private struct LibraryCollectionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let artworkTracks: [Track]
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    LibraryMosaicArtwork(tracks: artworkTracks, size: 132, accent: accent)

                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.075), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
                        .padding(7)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }
            }
            .frame(width: 132, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct LibraryMosaicArtwork: View {
    let tracks: [Track]
    let size: CGFloat
    let accent: Color

    var body: some View {
        let tiles = Array(tracks.prefix(4))

        ZStack {
            if tiles.count >= 4 {
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ArtworkTile(track: tiles[0], size: (size - 2) / 2, cornerRadius: 0)
                        ArtworkTile(track: tiles[1], size: (size - 2) / 2, cornerRadius: 0)
                    }
                    HStack(spacing: 2) {
                        ArtworkTile(track: tiles[2], size: (size - 2) / 2, cornerRadius: 0)
                        ArtworkTile(track: tiles[3], size: (size - 2) / 2, cornerRadius: 0)
                    }
                }
            } else if let track = tiles.first {
                ArtworkTile(track: track, size: size, cornerRadius: 12)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.040))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct EmptyLibrarySearchPanel: View {
    let query: String

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.36))
            Text("Ничего не найдено")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.64))
            Text(query)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private enum DerivedLibraryEntities {
    static func albums(from tracks: [Track]) -> [Track] {
        var order: [String] = []
        var grouped: [String: [Track]] = [:]

        for track in tracks {
            let key = "\(track.album.searchNormalized).\(track.artist.searchNormalized)"
            guard !key.isEmpty else { continue }
            if grouped[key] == nil {
                order.append(key)
                grouped[key] = []
            }
            grouped[key]?.append(track)
        }

        return order.compactMap { key in
            guard let tracks = grouped[key], let first = tracks.first else { return nil }
            return Track(
                id: "derived-album.\(key)",
                title: first.album,
                artist: first.artist,
                album: "Album",
                duration: 0,
                palette: first.palette,
                catalogID: nil,
                previewURL: nil,
                kind: .album,
                artworkURL: first.artworkURL,
                rank: first.rank,
                fanCount: nil,
                albumCount: nil,
                trackCount: tracks.count,
                releaseDate: first.releaseDate,
                recordType: "album",
                trackPosition: nil,
                discNumber: nil
            )
        }
    }

    static func artists(from tracks: [Track]) -> [Track] {
        var order: [String] = []
        var grouped: [String: [Track]] = [:]

        for track in tracks {
            let key = track.artist.searchNormalized
            guard !key.isEmpty else { continue }
            if grouped[key] == nil {
                order.append(key)
                grouped[key] = []
            }
            grouped[key]?.append(track)
        }

        return order.compactMap { key in
            guard let tracks = grouped[key], let first = tracks.first else { return nil }
            let albumCount = Set(tracks.map { $0.album.searchNormalized }).count
            return Track(
                id: "derived-artist.\(key)",
                title: first.artist,
                artist: first.artist,
                album: "Artist",
                duration: 0,
                palette: first.palette,
                catalogID: nil,
                previewURL: nil,
                kind: .artist,
                artworkURL: first.artworkURL,
                rank: first.rank,
                fanCount: nil,
                albumCount: albumCount,
                trackCount: tracks.count,
                releaseDate: nil,
                recordType: nil,
                trackPosition: nil,
                discNumber: nil
            )
        }
    }
}

private struct LibraryStatsView: View {
    let playlists: Int
    let artists: [Track]
    let albums: [Track]
    let tracks: [Track]

    var body: some View {
        HStack(spacing: 8) {
            MetricTile(title: "Playlists", value: "\(playlists)", symbol: "music.note.list")
            MetricTile(title: "Artists", value: "\(artists.count)", symbol: "music.mic")
            MetricTile(title: "Albums", value: "\(albums.count)", symbol: "square.stack")
            MetricTile(title: "Tracks", value: "\(tracks.count)", symbol: "music.note")
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        let tileShape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NoirwaveTheme.primaryAccent.opacity(0.72))
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.38))
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .noirwaveContentGlass(
            in: tileShape,
            fillOpacity: 0.028,
            strokeOpacity: 0.058
        )
    }
}

private struct NowPlayingHero: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        let heroShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        if let track = store.currentTrack {
            HStack(alignment: .center, spacing: 22) {
                ArtworkTile(track: track, size: 210, cornerRadius: 14)
                    .shadow(color: NoirwaveTheme.primaryAccent.opacity(0.16), radius: 26, x: 0, y: 18)

                VStack(alignment: .leading, spacing: 14) {
                    MediaKindBadge(kind: track.kind)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.62)

                        Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        Button {
                            store.togglePlayPause()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: store.playbackState == .playing ? "pause.fill" : "play.fill")
                                Text(store.playbackState == .playing ? "Pause" : "Play")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(NoirwaveTheme.primaryAccent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.enqueue(track)
                        } label: {
                            Label("Queue", systemImage: "text.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    ProgressStack(track: track)
                        .frame(maxWidth: 520)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .noirwaveContentGlass(
                in: heroShape,
                fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
                strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
            )
        } else {
            MusicConnectPanel()
        }
    }
}

private struct BestMatchCard: View {
    @EnvironmentObject private var store: PlayerStore
    let item: Track

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        Button {
            store.activate(item)
        } label: {
            HStack(spacing: 16) {
                ArtworkTile(track: item, size: 96, cornerRadius: item.kind == .artist ? 48 : 10)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        MediaKindBadge(kind: item.kind)
                        Text("Best Match")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.42))
                            .textCase(.uppercase)
                    }

                    Text(item.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(item.detailLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: item.isPlayable ? "play.fill" : "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(NoirwaveTheme.primaryAccent, in: Circle())
            }
            .padding(16)
            .noirwaveContentGlass(
                in: cardShape,
                fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
                strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
            )
            .overlay(
                cardShape
                    .strokeBorder(NoirwaveTheme.primaryAccent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(item.isPlayable ? "Play \(item.title)" : "Open \(item.title)")
        .contextMenu {
            Button {
                store.activate(item)
            } label: {
                Label(item.isPlayable ? "Play" : "Open", systemImage: item.isPlayable ? "play.fill" : "chevron.right")
            }

            if !item.isPlayable {
                Button {
                    store.toggleSavedCollection(item)
                } label: {
                    Label(store.isSavedCollection(item) ? "Remove from Library" : "Save to Library", systemImage: store.isSavedCollection(item) ? "checkmark" : "plus")
                }
            }
        }
    }
}

private struct FeaturedTrackShelf: View {
    let title: String
    let tracks: [Track]

    var body: some View {
        if !tracks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: title, subtitle: "\(tracks.count) tracks")

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(tracks) { track in
                            TrackFeatureCard(track: track)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct TrackFeatureCard: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track

    var body: some View {
        Button {
            store.activate(track)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ArtworkTile(track: track, size: 166, cornerRadius: 10)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: store.currentTrack == track && store.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 30, height: 30)
                            .background(NoirwaveTheme.primaryAccent, in: Circle())
                            .padding(8)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(width: 166, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help("Play \(track.title)")
        .contextMenu {
            Button {
                store.activate(track)
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                store.toggleLike(track)
            } label: {
                Label(store.isLiked(track) ? "Remove from Favorites" : "Add to Favorites", systemImage: store.isLiked(track) ? "heart.fill" : "heart")
            }

            Button {
                store.playNext(track)
            } label: {
                Label("Play Next", systemImage: "forward.end.fill")
            }

            Button {
                store.enqueue(track)
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }

            AddToPlaylistMenu(track: track, excludingPlaylistID: nil)
        }
    }
}

private struct EntityShelf: View {
    let title: String
    let items: [Track]
    let cardSize: CGFloat
    let roundArtists: Bool

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: title, subtitle: "\(items.count)")

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(items) { item in
                            EntityCard(item: item, size: cardSize, roundArtwork: roundArtists && item.kind == .artist)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct EntityGridSection: View {
    let title: String
    let items: [Track]
    let cardSize: CGFloat

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardSize), spacing: 18, alignment: .top)]
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: title, subtitle: "\(items.count)")

                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(items) { item in
                        EntityCard(item: item, size: cardSize, roundArtwork: item.kind == .artist)
                    }
                }
            }
        }
    }
}

private struct EntityCard: View {
    @EnvironmentObject private var store: PlayerStore
    let item: Track
    let size: CGFloat
    let roundArtwork: Bool

    var body: some View {
        Button {
            store.activate(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ArtworkTile(track: item, size: size, cornerRadius: roundArtwork ? size / 2 : 10)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: item.isPlayable ? "play.fill" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.86))
                            .frame(width: 28, height: 28)
                            .background(.thinMaterial, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                            .padding(8)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(item.detailLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(2)
                }
            }
            .frame(width: size, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help(item.isPlayable ? "Play \(item.title)" : "Open \(item.title)")
        .contextMenu {
            Button {
                store.activate(item)
            } label: {
                Label(item.isPlayable ? "Play" : "Open", systemImage: item.isPlayable ? "play.fill" : "chevron.right")
            }

            if !item.isPlayable {
                Button {
                    store.toggleSavedCollection(item)
                } label: {
                    Label(store.isSavedCollection(item) ? "Remove from Library" : "Save to Library", systemImage: store.isSavedCollection(item) ? "checkmark" : "plus")
                }
            }
        }
    }
}

private struct TrackListSection: View {
    let title: String
    let subtitle: String
    let tracks: [Track]
    let numbered: Bool
    let playlistID: String?

    init(title: String, subtitle: String, tracks: [Track], numbered: Bool, playlistID: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.tracks = tracks
        self.numbered = numbered
        self.playlistID = playlistID
    }

    var body: some View {
        if tracks.isEmpty {
            EmptySearchView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: title, subtitle: subtitle)
                TrackRowsStack(tracks: tracks, numbered: numbered, playlistID: playlistID)
            }
        }
    }
}

private struct TrackRowsStack: View {
    let tracks: [Track]
    let numbered: Bool
    let playlistID: String?

    init(tracks: [Track], numbered: Bool, playlistID: String? = nil) {
        self.tracks = tracks
        self.numbered = numbered
        self.playlistID = playlistID
    }

    var body: some View {
        VStack(spacing: 7) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                TrackRowView(
                    track: track,
                    index: numbered ? index + 1 : nil,
                    playlistID: playlistID,
                    playbackContext: tracks
                )
            }
        }
    }
}

private struct TrackRowView: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track
    let index: Int?
    let playlistID: String?
    let playbackContext: [Track]

    init(track: Track, index: Int?, playlistID: String? = nil, playbackContext: [Track] = []) {
        self.track = track
        self.index = index
        self.playlistID = playlistID
        self.playbackContext = playbackContext
    }

    private var isCurrent: Bool {
        track.isPlayable && store.currentTrack == track
    }

    var body: some View {
        let rowShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 12) {
            if let index {
                Text("\(index)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(width: 24, alignment: .trailing)
            }

            Button {
                store.activate(track, in: playbackContext)
            } label: {
                ZStack {
                    ArtworkTile(track: track, size: 48, cornerRadius: track.kind == .artist ? 24 : 8)
                    if isCurrent {
                        Image(systemName: store.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else if !track.isPlayable {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.84))
                    }
                }
            }
            .buttonStyle(.plain)
            .help(track.isPlayable ? "Play \(track.title)" : "Open \(track.title)")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    MediaKindBadge(kind: track.kind)
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(track.detailLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
            }

            Spacer()

            if track.isPlayable {
                Text(track.durationLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(width: 42, alignment: .trailing)

                FavoriteButton(track: track, size: 28)

                Button {
                    store.enqueue(track)
                } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.62))
                .help("Add to queue")
            } else {
                Image(systemName: track.kind.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .noirwaveContentGlass(
            in: rowShape,
            fillOpacity: isCurrent ? GraphiteSurfaceStyle.contentStrongFillOpacity : GraphiteSurfaceStyle.contentFillOpacity,
            strokeOpacity: isCurrent ? GraphiteSurfaceStyle.contentStrongStrokeOpacity : GraphiteSurfaceStyle.contentStrokeOpacity
        )
        .background {
            if isCurrent {
                rowShape
                    .fill(NoirwaveTheme.primaryAccent.opacity(0.055))
                    .allowsHitTesting(false)
            }
        }
        .overlay(
            rowShape
                .strokeBorder(isCurrent ? NoirwaveTheme.primaryAccent.opacity(0.22) : .white.opacity(0.035), lineWidth: 1)
        )
        .contextMenu {
            Button {
                store.activate(track, in: playbackContext)
            } label: {
                Label(track.isPlayable ? "Play" : "Open", systemImage: track.isPlayable ? "play.fill" : "chevron.right")
            }

            if track.isPlayable {
                Button {
                    store.toggleLike(track)
                } label: {
                    Label(store.isLiked(track) ? "Remove from Favorites" : "Add to Favorites", systemImage: store.isLiked(track) ? "heart.fill" : "heart")
                }

                Button {
                    store.playNext(track)
                } label: {
                    Label("Play Next", systemImage: "forward.end.fill")
                }

                Button {
                    store.enqueue(track)
                } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                }

                AddToPlaylistMenu(track: track, excludingPlaylistID: playlistID)

                if let playlistID {
                    Button {
                        store.removeFromPlaylist(track, playlistID: playlistID)
                    } label: {
                        Label("Remove from Playlist", systemImage: "minus.circle")
                    }
                }
            }
        }
    }
}

private struct AddToPlaylistMenu: View {
    @EnvironmentObject private var store: PlayerStore
    @Environment(\.requestPlaylistCreationFromTrack) private var requestPlaylistCreationFromTrack
    let track: Track
    let excludingPlaylistID: String?

    private var targetPlaylists: [LocalPlaylist] {
        PlaylistTargetMenuBuilder.targetPlaylists(store.localPlaylists, excludingPlaylistID: excludingPlaylistID)
    }

    var body: some View {
        Menu {
            ForEach(targetPlaylists) { playlist in
                Button {
                    store.addToPlaylist(track, playlistID: playlist.id)
                } label: {
                    Label(playlist.title, systemImage: "music.note.list")
                }
            }

            if !targetPlaylists.isEmpty {
                Divider()
            }

            Button {
                requestPlaylistCreationFromTrack(track)
            } label: {
                Label("New Playlist...", systemImage: "plus")
            }
        } label: {
            Label("Add to Playlist", systemImage: "music.note.list")
        }
    }
}

private struct AddTracksToPlaylistMenu: View {
    @EnvironmentObject private var store: PlayerStore
    @Environment(\.requestPlaylistCreationFromTracks) private var requestPlaylistCreationFromTracks
    let tracks: [Track]
    let excludingPlaylistID: String?
    let help: String
    let size: CGFloat

    private var playableTracks: [Track] {
        tracks.filter(\.isPlayable)
    }

    private var targetPlaylists: [LocalPlaylist] {
        PlaylistTargetMenuBuilder.targetPlaylists(store.localPlaylists, excludingPlaylistID: excludingPlaylistID)
    }

    var body: some View {
        if !playableTracks.isEmpty {
            Menu {
                ForEach(targetPlaylists) { playlist in
                    Button {
                        store.addToPlaylist(playableTracks, playlistID: playlist.id)
                    } label: {
                        Label(playlist.title, systemImage: "music.note.list")
                    }
                }

                if !targetPlaylists.isEmpty {
                    Divider()
                }

                Button {
                    requestPlaylistCreationFromTracks(playableTracks)
                } label: {
                    Label("New Playlist...", systemImage: "plus")
                }
            } label: {
                Image(systemName: "music.note.list")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: size, height: size)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help(help)
        }
    }
}

enum ArtistPopularTracksCopy {
    static func subtitle(count: Int) -> String {
        let safeCount = max(count, 0)
        switch safeCount {
        case 0:
            return "No Deezer top tracks loaded"
        case 1:
            return "1 Deezer top track"
        default:
            return "\(safeCount) Deezer top tracks"
        }
    }
}

enum ArtistPopularTracksPresentation {
    static let defaultVisibleCount = 5

    static func visibleTracks(from tracks: [Track], isExpanded: Bool) -> [Track] {
        guard !isExpanded else { return tracks }
        return Array(tracks.prefix(defaultVisibleCount))
    }

    static func showsToggle(totalCount: Int) -> Bool {
        totalCount > defaultVisibleCount
    }

    static func toggleTitle(totalCount: Int, isExpanded: Bool) -> String {
        isExpanded ? "Show less" : "Show more"
    }
}

private struct ArtistDetailView: View {
    let artist: Track
    let items: [Track]
    let isLoading: Bool

    private var tracks: [Track] {
        items.filter(\.isPlayable)
    }

    private var releases: [Track] {
        items.filter { $0.kind == .album }
    }

    private var releaseGroups: ArtistReleaseGroups {
        ArtistReleaseClassifier.groups(from: releases)
    }

    private var latestRelease: Track? {
        releases.sorted { lhs, rhs in
            let lhsDate = lhs.releaseDate ?? ""
            let rhsDate = rhs.releaseDate ?? ""
            if lhsDate == rhsDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhsDate > rhsDate
        }.first
    }

    var body: some View {
        let groups = releaseGroups

        VStack(alignment: .leading, spacing: ArtistHeaderLayoutMetrics.detailSectionSpacing) {
            ArtistHeroView(
                artist: artist,
                tracks: tracks,
                releases: releases,
                studioAlbums: groups.studioAlbums,
                latestRelease: latestRelease,
                isLoading: isLoading
            )

            if tracks.isEmpty && releases.isEmpty && isLoading {
                CatalogLoadingView(title: "Loading artist", subtitle: "Fetching releases and popular tracks")
            } else if tracks.isEmpty && releases.isEmpty {
                EmptySearchView()
            } else {
                if let latestRelease {
                    ArtistLatestReleaseFeature(release: latestRelease)
                }
                ArtistPopularTracksSection(tracks: tracks)
                EntityShelf(title: "Studio Albums", items: groups.studioAlbums, cardSize: 214, roundArtists: false)
                EntityShelf(title: "Reissues & Live", items: groups.otherReleases, cardSize: 178, roundArtists: false)
            }
        }
    }
}

private struct ArtistPopularTracksSection: View {
    @State private var isExpanded = false
    let tracks: [Track]

    private var visibleTracks: [Track] {
        ArtistPopularTracksPresentation.visibleTracks(from: tracks, isExpanded: isExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrackListSection(
                title: "Popular Tracks",
                subtitle: ArtistPopularTracksCopy.subtitle(count: tracks.count),
                tracks: visibleTracks,
                numbered: true
            )

            if ArtistPopularTracksPresentation.showsToggle(totalCount: tracks.count) {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text(ArtistPopularTracksPresentation.toggleTitle(totalCount: tracks.count, isExpanded: isExpanded))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse popular tracks" : "Show all popular tracks")
            }
        }
    }
}

private struct ArtistHeroView: View {
    @EnvironmentObject private var store: PlayerStore
    let artist: Track
    let tracks: [Track]
    let releases: [Track]
    let studioAlbums: [Track]
    let latestRelease: Track?
    let isLoading: Bool

    private var listenersLabel: String {
        artist.fanCount.map { "\($0.compactCountLabel) listeners" } ?? "Listeners unknown"
    }

    private var albumLabel: String {
        if studioAlbums.isEmpty && releases.isEmpty && isLoading {
            return "Loading releases"
        }
        if !studioAlbums.isEmpty {
            return "\(studioAlbums.count) studio album\(studioAlbums.count == 1 ? "" : "s")"
        }
        if let albumCount = artist.albumCount {
            return "\(albumCount) release\(albumCount == 1 ? "" : "s")"
        }
        return releases.isEmpty ? "Albums loading" : "\(releases.count) releases"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 0) {
                Spacer()
                ArtworkTile(
                    track: artist,
                    size: ArtistHeaderLayoutMetrics.backgroundArtworkSize,
                    cornerRadius: 30
                )
                    .blur(radius: 18)
                    .opacity(0.3)
                    .scaleEffect(1.14)
                    .offset(x: 42, y: -2)
            }
            .clipped()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.018),
                    artist.palette.base.opacity(0.40),
                    Color(hex: GraphiteSurfaceStyle.centerBaseHex).opacity(0.58)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            HStack(alignment: .bottom, spacing: ArtistHeaderLayoutMetrics.heroColumnSpacing) {
                VStack(alignment: .leading, spacing: ArtistHeaderLayoutMetrics.heroContentSpacing) {
                    HStack(spacing: 8) {
                        MediaKindBadge(kind: artist.kind)
                        Text(listenersLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    Text(artist.title)
                        .font(.system(size: ArtistHeaderLayoutMetrics.titleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)

                    HStack(spacing: 8) {
                        InfoPill(symbol: "square.stack.fill", text: albumLabel)
                        InfoPill(symbol: "music.note.list", text: "\(tracks.count) tracks")
                        if let latestRelease {
                            InfoPill(
                                symbol: "sparkle",
                                text: latestRelease.releaseDate?.releaseYear.map { "Latest \($0)" } ?? "Latest release"
                            )
                        }
                    }

                    ArtistHeroActionBar(artist: artist, tracks: tracks)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ArtworkTile(
                    track: artist,
                    size: ArtistHeaderLayoutMetrics.foregroundArtworkSize,
                    cornerRadius: ArtistHeaderLayoutMetrics.foregroundArtworkCornerRadius
                )
                    .shadow(color: NoirwaveTheme.primaryAccent.opacity(0.20), radius: 24, x: 0, y: 14)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .padding(ArtistHeaderLayoutMetrics.heroPadding)
        }
        .frame(maxWidth: .infinity, minHeight: ArtistHeaderLayoutMetrics.heroMinHeight, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: ArtistHeaderLayoutMetrics.heroCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ArtistHeaderLayoutMetrics.heroCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ArtistHeroActionBar: View {
    @EnvironmentObject private var store: PlayerStore
    let artist: Track
    let tracks: [Track]

    private var playableTracks: [Track] {
        tracks.filter(\.isPlayable)
    }

    private var isSaved: Bool {
        store.isSavedCollection(artist)
    }

    var body: some View {
        HStack(spacing: 9) {
            Button {
                store.playAll(playableTracks)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: ArtistHeaderLayoutMetrics.actionHeight)
                    .background(NoirwaveTheme.primaryAccent.opacity(playableTracks.isEmpty ? 0.48 : 1), in: RoundedRectangle(cornerRadius: ArtistHeaderLayoutMetrics.actionCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(playableTracks.isEmpty)
            .help("Play \(artist.title)")

            Button {
                store.shufflePlay(playableTracks)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(playableTracks.isEmpty ? 0.36 : 0.84))
                    .padding(.horizontal, 12)
                    .frame(height: ArtistHeaderLayoutMetrics.actionHeight)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: ArtistHeaderLayoutMetrics.actionCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ArtistHeaderLayoutMetrics.actionCornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(playableTracks.isEmpty)
            .help("Shuffle \(artist.title)")

            Button {
                store.toggleSavedCollection(artist)
            } label: {
                Label(isSaved ? "Following" : "Follow", systemImage: isSaved ? "checkmark" : "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 12)
                    .frame(height: ArtistHeaderLayoutMetrics.actionHeight)
                    .background(.white.opacity(isSaved ? 0.14 : 0.075), in: RoundedRectangle(cornerRadius: ArtistHeaderLayoutMetrics.actionCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ArtistHeaderLayoutMetrics.actionCornerRadius, style: .continuous)
                            .stroke(.white.opacity(isSaved ? 0.18 : 0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(isSaved ? "Remove from Library" : "Save to Library")
        }
    }
}

private struct ArtistLatestReleaseFeature: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovered = false
    let release: Track

    private var metadata: String {
        [release.recordType?.displayRecordType, release.releaseDate?.releaseYear, release.trackCount.map { "\($0) tracks" }]
            .compactMap { $0?.nonEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        let featureShape = RoundedRectangle(cornerRadius: 11, style: .continuous)

        Button {
            store.activate(release)
        } label: {
            HStack(spacing: 12) {
                ArtworkTile(
                    track: release,
                    size: ArtistHeaderLayoutMetrics.latestReleaseArtworkSize,
                    cornerRadius: 9
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest Release")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.44))
                        .textCase(.uppercase)
                    Text(release.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(metadata)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(isHovered ? 0.78 : 0.42))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(isHovered ? 0.09 : 0.055), in: Circle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, ArtistHeaderLayoutMetrics.latestReleaseVerticalPadding)
            .noirwaveContentGlass(
                in: featureShape,
                fillOpacity: isHovered ? GraphiteSurfaceStyle.contentStrongFillOpacity : GraphiteSurfaceStyle.contentFillOpacity,
                strokeOpacity: isHovered ? GraphiteSurfaceStyle.contentStrongStrokeOpacity : GraphiteSurfaceStyle.contentStrokeOpacity
            )
            .overlay(
                featureShape
                    .stroke(.white.opacity(isHovered ? 0.16 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Open \(release.title)")
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.14), value: isHovered)
    }
}

private struct AlbumDetailView: View {
    let album: Track
    let items: [Track]
    let isLoading: Bool

    private var tracks: [Track] {
        items.filter(\.isPlayable)
    }

    private var trackSubtitle: String {
        if let expected = album.trackCount, expected > tracks.count {
            return "\(tracks.count) of \(expected) loaded"
        }
        return "\(tracks.count) track\(tracks.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            AlbumHeroView(album: album, tracks: tracks, isLoading: isLoading)

            if tracks.isEmpty && isLoading {
                AlbumTracklistSkeleton(expectedCount: album.trackCount)
            } else if tracks.isEmpty {
                EmptySearchView()
            } else {
                TrackListSection(title: "Tracks", subtitle: trackSubtitle, tracks: tracks, numbered: true)
                if isLoading {
                    AlbumTracklistRefreshingPill()
                }
            }
        }
    }
}

private struct AlbumTracklistSkeleton: View {
    let expectedCount: Int?

    private var subtitle: String {
        if let expectedCount {
            return "Preparing \(expectedCount) tracks"
        }
        return "Preparing tracklist"
    }

    var body: some View {
        let skeletonShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Tracks", subtitle: subtitle)

            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 12) {
                        LoadingSkeletonBlock(width: 36, height: 36, cornerRadius: 7)
                        VStack(alignment: .leading, spacing: 6) {
                            LoadingSkeletonBlock(width: 220 - CGFloat(index * 12), height: 13, cornerRadius: 5)
                            LoadingSkeletonBlock(width: 140 - CGFloat(index * 8), height: 11, cornerRadius: 5)
                        }
                        Spacer()
                        LoadingSkeletonBlock(width: 48, height: 12, cornerRadius: 5)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 52)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(14)
        .noirwaveContentGlass(
            in: skeletonShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct AlbumTracklistRefreshingPill: View {
    var body: some View {
        HStack(spacing: 9) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.66)
            Text("Refreshing tracklist")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.56))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(NoirwaveTheme.primaryAccent.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct AlbumHeroView: View {
    @EnvironmentObject private var store: PlayerStore
    let album: Track
    let tracks: [Track]
    let isLoading: Bool

    private var releaseType: String {
        album.recordType?.displayRecordType ?? "Album"
    }

    private var year: String {
        album.releaseDate?.releaseYear ?? "Year unknown"
    }

    private var trackCountLabel: String {
        if let expected = album.trackCount {
            return "\(expected) track\(expected == 1 ? "" : "s")"
        }
        let expected = tracks.count
        if expected == 0 && isLoading {
            return "Tracklist loading"
        }
        return "\(expected) track\(expected == 1 ? "" : "s")"
    }

    var body: some View {
        let heroShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(alignment: .center, spacing: 22) {
            ArtworkTile(track: album, size: 190, cornerRadius: 14)
                .shadow(color: NoirwaveTheme.primaryAccent.opacity(0.16), radius: 26, x: 0, y: 18)

            VStack(alignment: .leading, spacing: 14) {
                MediaKindBadge(kind: album.kind)

                Text(album.title)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.58)

                Text(album.artist)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    InfoPill(symbol: "square.stack.fill", text: releaseType)
                    InfoPill(symbol: "music.note.list", text: trackCountLabel)
                    InfoPill(symbol: "calendar", text: year)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                CollectionActionCluster(
                    tracks: tracks,
                    accent: NoirwaveTheme.primaryAccent,
                    primaryLabel: "Play Album"
                )

                SavedCollectionButton(item: album, size: 38)
            }
            .frame(maxWidth: 360, alignment: .trailing)
        }
        .padding(18)
        .noirwaveContentGlass(
            in: heroShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private extension View {
    func noirwaveContentGlass<S: InsettableShape>(
        in shape: S,
        fillOpacity: Double = GraphiteSurfaceStyle.contentFillOpacity,
        strokeOpacity: Double = GraphiteSurfaceStyle.contentStrokeOpacity
    ) -> some View {
        self
            .background {
                ZStack {
                    shape
                        .fill(Color(hex: GraphiteSurfaceStyle.raisedBaseHex).opacity(fillOpacity > GraphiteSurfaceStyle.contentFillOpacity ? 0.36 : 0.28))

                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: GraphiteSurfaceStyle.raisedTopHex).opacity(fillOpacity * 0.56),
                                    .white.opacity(fillOpacity * 0.24),
                                    .black.opacity(fillOpacity * 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    shape
                        .stroke(.white.opacity(strokeOpacity + 0.020), lineWidth: 1)
                        .blur(radius: 0.45)
                        .mask(alignment: .top) {
                            Rectangle().frame(height: 16)
                        }

                    shape
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(strokeOpacity + 0.030),
                                    .white.opacity(strokeOpacity * 0.55),
                                    .white.opacity(strokeOpacity * 0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    func noirwaveLiquidGlass<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular, in: shape)
                .overlay(noirwaveGlassHighlights(in: shape))
        } else {
            self.noirwaveFallbackGlass(in: shape)
        }
        #else
        self.noirwaveFallbackGlass(in: shape)
        #endif
    }

    private func noirwaveFallbackGlass<S: Shape>(in shape: S) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .overlay(noirwaveGlassHighlights(in: shape))
            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private func noirwaveGlassHighlights<S: Shape>(in shape: S) -> some View {
        ZStack {
            shape
                .stroke(.white.opacity(0.22), lineWidth: 1)
            shape
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.34), .clear, .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            shape
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .white.opacity(0.035), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        }
    }

}

private extension View {
    func noirwaveSidebarGlass<S: InsettableShape>(
        in shape: S,
        appearance: LiquidGlassPanelAppearance
    ) -> some View {
        self
            .background {
                ZStack {
                    NoirwaveVisualEffectMaterial(
                        material: SidebarVisualStyle.panelMaterial,
                        blendingMode: .withinWindow
                    )
                    .opacity(appearance.materialOpacity)

                    shape
                        .fill(Color(hex: GraphiteSurfaceStyle.centerFloorHex).opacity(appearance.dimOpacity))

                    shape
                        .fill(.white.opacity(0.006))

                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(appearance.innerHighlightOpacity),
                                    .white.opacity(appearance.diagonalHighlightOpacity),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    shape
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.070),
                                    .white.opacity(0.035),
                                    .white.opacity(0.018)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .leading) {
                shape
                    .stroke(.white.opacity(0.060), lineWidth: 1)
                    .blur(radius: 0.45)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: 1.5)
                    }
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                shape
                    .stroke(.white.opacity(0.065), lineWidth: 1)
                    .blur(radius: 0.45)
                    .mask(alignment: .top) {
                        Rectangle().frame(height: 18)
                    }
                    .allowsHitTesting(false)
            }
            .shadow(
                color: .black.opacity(appearance.shadowOpacity),
                radius: appearance.shadowRadius,
                x: 0,
                y: appearance.shadowYOffset
            )
            .clipShape(shape)
            .contentShape(shape)
            .clipped()
    }

    @ViewBuilder
    func noirwavePanelGlass<S: InsettableShape>(
        in shape: S,
        material: NSVisualEffectView.Material = LiquidGlassPanelStyle.material,
        appearance: LiquidGlassPanelAppearance = LiquidGlassPanelStyle.appearance
    ) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                self
                    .glassEffect(
                        .regular
                            .tint(Color.white.opacity(MiniPlayerVisualStyle.materialTintOpacity))
                            .interactive(false),
                        in: shape
                    )
                    .overlay {
                        shape.strokeBorder(.white.opacity(LiquidGlassPanelStyle.borderOpacity), lineWidth: 1)
                    }
                    .overlay(alignment: .top) {
                        shape
                            .stroke(.white.opacity(LiquidGlassPanelStyle.topHighlightOpacity), lineWidth: 1)
                            .blur(radius: 0.5)
                            .mask(alignment: .top) {
                                Rectangle().frame(height: LiquidGlassPanelStyle.topHighlightHeight)
                            }
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        LiquidGlassPanelChrome(shape: shape, appearance: appearance)
                    }
                    .shadow(
                        color: NoirwaveTheme.primaryAccent.opacity(appearance.mintGlowOpacity),
                        radius: 24,
                        x: 0,
                        y: 0
                    )
                    .shadow(
                        color: .black.opacity(appearance.shadowOpacity),
                        radius: appearance.shadowRadius,
                        x: 0,
                        y: appearance.shadowYOffset
                    )
                    .clipShape(shape)
                    .contentShape(shape)
                    .clipped()
            }
        } else {
            self.noirwaveFallbackPanelGlass(in: shape, material: material, appearance: appearance)
        }
#else
        self.noirwaveFallbackPanelGlass(in: shape, material: material, appearance: appearance)
#endif
    }

    func noirwaveFallbackPanelGlass<S: InsettableShape>(
        in shape: S,
        material: NSVisualEffectView.Material,
        appearance: LiquidGlassPanelAppearance
    ) -> some View {
        self
            .background {
                LiquidGlassPanelBackground(shape: shape, material: material, appearance: appearance)
            }
            .overlay {
                shape.strokeBorder(.white.opacity(LiquidGlassPanelStyle.borderOpacity), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                shape
                    .stroke(.white.opacity(LiquidGlassPanelStyle.topHighlightOpacity), lineWidth: 1)
                    .blur(radius: 0.5)
                    .mask(alignment: .top) {
                        Rectangle().frame(height: LiquidGlassPanelStyle.topHighlightHeight)
                    }
                    .allowsHitTesting(false)
            }
            .shadow(
                color: NoirwaveTheme.primaryAccent.opacity(appearance.mintGlowOpacity),
                radius: 24,
                x: 0,
                y: 0
            )
            .shadow(
                color: .black.opacity(appearance.shadowOpacity),
                radius: appearance.shadowRadius,
                x: 0,
                y: appearance.shadowYOffset
            )
            .clipShape(shape)
            .contentShape(shape)
            .clipped()
    }

    func legacyGlassPlayer<S: InsettableShape>(in shape: S) -> some View {
        self
            .background {
                LegacyGlassPlayerBackground(shape: shape)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.16),
                            .white.opacity(0.075),
                            .white.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .overlay(alignment: .top) {
                shape
                    .stroke(.white.opacity(0.18), lineWidth: 1)
                    .blur(radius: 0.5)
                    .mask(alignment: .top) {
                        Rectangle().frame(height: 18)
                    }
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
            .clipShape(shape)
            .contentShape(shape)
            .clipped()
    }
}

private struct LiquidGlassPanelChrome<S: InsettableShape>: View {
    let shape: S
    let appearance: LiquidGlassPanelAppearance

    var body: some View {
        ZStack {
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.30),
                            .white.opacity(0.10),
                            .white.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(max(appearance.innerHighlightOpacity, 0.032)),
                            .white.opacity(appearance.diagonalHighlightOpacity),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

private struct LiquidGlassPanelBackground<S: Shape>: View {
    let shape: S
    let material: NSVisualEffectView.Material
    let appearance: LiquidGlassPanelAppearance

    var body: some View {
        ZStack {
            NoirwaveVisualEffectMaterial(material: material, blendingMode: .withinWindow)
                .clipShape(shape)
                .opacity(appearance.materialOpacity)

            if appearance.dimOpacity > 0 {
                shape
                    .fill(NoirwaveTheme.backgroundElevated.opacity(appearance.dimOpacity))
            }

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(appearance.innerHighlightOpacity),
                            NoirwaveTheme.text.opacity(appearance.diagonalHighlightOpacity),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(LiquidGlassPanelStyle.topHighlightOpacity),
                            .white.opacity(0.06),
                            NoirwaveTheme.text.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

private struct LegacyGlassPlayerBackground<S: Shape>: View {
    let shape: S

    var body: some View {
        NoirwaveVisualEffectMaterial(material: LiquidGlassPanelStyle.material, blendingMode: .withinWindow)
            .clipShape(shape)
            .allowsHitTesting(false)
    }
}

private struct NoirwaveVisualEffectMaterial: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }
}

private struct CurrentTrackWidgetOverlay: View {
    let track: Track
    @Binding var isPresented: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    close()
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ArtworkTile(track: track, size: 204, cornerRadius: 12, priority: .high)
                        .shadow(color: .black.opacity(0.20), radius: 18, x: 0, y: 10)

                    VStack(alignment: .leading, spacing: 10) {
                        InfoPill(symbol: "music.note", text: "Now Playing")

                        VStack(alignment: .leading, spacing: 6) {
                            Text(track.title)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)

                            Text(track.artist)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.68))
                                .lineLimit(1)

                            Text(track.album)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.46))
                                .lineLimit(1)
                        }

                        HStack(spacing: 8) {
                            InfoPill(symbol: "clock", text: track.durationLabel)
                            InfoPill(symbol: track.kind.systemImage, text: track.kind.rawValue)
                        }
                    }

                    Spacer(minLength: 0)

                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.08), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                    .accessibilityLabel("Close track details")
                }
            }
            .padding(18)
            .frame(width: 520, alignment: .leading)
            .noirwaveContentGlass(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                fillOpacity: 0.058,
                strokeOpacity: 0.12
            )
            .shadow(color: .black.opacity(0.24), radius: 20, x: 0, y: 14)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture {}
            .transition(.opacity)
        }
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onExitCommand {
            close()
        }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.10)) {
            isPresented = false
        }
    }
}

private struct MiniPlayerBar: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var isProgressExpanded: Bool
    @Binding var selectedPanel: NowPlayingPanelMode
    @Binding var isShowingNowPlaying: Bool
    @Binding var isShowingTrackWidget: Bool
    let onOpenCatalogTarget: (Track) -> Void

    private var displayTrack: Track? {
        store.currentTrack
            ?? store.visibleTracks.first(where: \.isPlayable)
            ?? store.featuredTracks.first(where: \.isPlayable)
    }

    private var playSymbol: String {
        switch store.playbackState {
        case .playing:
            "pause.fill"
        case .loading:
            "hourglass"
        case .idle, .paused, .failed:
            "play.fill"
        }
    }

    var body: some View {
        if let track = displayTrack {
            GeometryReader { proxy in
                let playerWidth = min(max(proxy.size.width - 40, 1), 740)
                let compact = playerWidth < 700
                let narrow = playerWidth < 600
                let tiny = playerWidth < 500
                let playerShape = RoundedRectangle(cornerRadius: 30, style: .continuous)
                let horizontalPadding: CGFloat = narrow ? 12 : 18
                let spacing: CGFloat = tiny ? 4 : (narrow ? 6 : 7)
                let progressWidth = min(
                    max(playerWidth - horizontalPadding * 2 - 120, 180),
                    MiniPlayerVisualStyle.progressMaxWidth
                )
                let trackWidth: CGFloat = {
                    if tiny { return 116 }
                    if narrow { return 150 }
                    if compact { return 186 }
                    return 228
                }()
                let controls = HStack(spacing: spacing) {
                    MiniPlayerTrackSummary(
                        track: track,
                        isShowingNowPlaying: $isShowingNowPlaying,
                        isShowingTrackWidget: $isShowingTrackWidget,
                        artworkSize: narrow ? 36 : 40,
                        onOpenCatalogTarget: onOpenCatalogTarget
                    )
                    .frame(width: trackWidth, alignment: .leading)
                    .layoutPriority(1)

                    PlaybackControlsCompact(
                        track: track,
                        playSymbol: playSymbol,
                        showModes: !tiny,
                        showLike: !tiny,
                        compact: compact
                    )
                    .fixedSize()
                    .layoutPriority(4)

                    MiniPlayerUtilityControls(
                        selectedPanel: $selectedPanel,
                        isShowingNowPlaying: $isShowingNowPlaying,
                        showLyrics: !narrow,
                        showQueue: !tiny,
                        showSliders: !compact,
                        showVolumeSlider: false,
                        compact: compact
                    )
                    .fixedSize()
                    .layoutPriority(3)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(width: playerWidth, height: 58)
                .opacity(isProgressExpanded ? 0.12 : 1)
                .offset(y: isProgressExpanded ? 8 : 0)
                .allowsHitTesting(!isProgressExpanded)

                let content = ZStack(alignment: .top) {
                    controls

                    MiniPlayerInlineProgressStrip(track: track, isExpanded: $isProgressExpanded)
                        .padding(.top, MiniPlayerVisualStyle.progressTopPadding)
                        .frame(
                            width: progressWidth,
                            height: isProgressExpanded
                                ? MiniPlayerVisualStyle.progressExpandedHeight
                                : MiniPlayerVisualStyle.progressCompactHeight,
                            alignment: .top
                        )
                        .zIndex(2)
                }
                .frame(width: playerWidth, height: 58)
                .animation(.easeOut(duration: 0.14), value: isProgressExpanded)

                #if compiler(>=6.2)
                if #available(macOS 26.0, *) {
                    GlassEffectContainer(spacing: 12) {
                        content
                            .glassEffect(
                                .regular
                                    .tint(Color.white.opacity(MiniPlayerVisualStyle.materialTintOpacity))
                                    .interactive(false),
                                in: playerShape
                            )
                            .overlay {
                                playerShape
                                    .fill(.black.opacity(0.13))
                                    .allowsHitTesting(false)
                            }
                            .overlay {
                                playerShape
                                    .fill(.white.opacity(0.008))
                                    .allowsHitTesting(false)
                            }
                            .overlay(alignment: .top) {
                                playerShape
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                                    .blur(radius: 0.5)
                                    .mask(alignment: .top) {
                                        Rectangle().frame(height: 18)
                                    }
                                    .allowsHitTesting(false)
                            }
                            .overlay {
                                playerShape.strokeBorder(.white.opacity(0.10), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 11)
                            .clipShape(playerShape)
                            .contentShape(playerShape)
                            .clipped()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    content
                        .legacyGlassPlayer(in: playerShape)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                #else
                content
                    .legacyGlassPlayer(in: playerShape)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                #endif
            }
            .frame(height: 58)
        }
    }
}

private struct MiniPlayerTrackSummary: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var hoveredTarget: MiniPlayerNavigationTarget?
    let track: Track
    @Binding var isShowingNowPlaying: Bool
    @Binding var isShowingTrackWidget: Bool
    let artworkSize: CGFloat
    let onOpenCatalogTarget: (Track) -> Void

    var body: some View {
        HStack(spacing: 9) {
            Button {
                isShowingTrackWidget = true
            } label: {
                    ArtworkTile(track: track, size: artworkSize, cornerRadius: 9, priority: .high)
            }
            .buttonStyle(.plain)
            .help("Track details")
            .onHover { hoveredTarget = $0 ? .album : nil }
            .scaleEffect(hoveredTarget == .album ? 1.035 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    openAlbum()
                } label: {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(hoveredTarget == .title ? .white : .white.opacity(0.94))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("Open album")
                .onHover { hoveredTarget = $0 ? .title : nil }

                Button {
                    openArtist()
                } label: {
                    Text(track.artist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(hoveredTarget == .artist ? .white.opacity(0.78) : .white.opacity(0.58))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("Open artist")
                .onHover { hoveredTarget = $0 ? .artist : nil }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomLeading) {
                Capsule()
                    .fill(.white.opacity(0.28))
                    .frame(width: hoveredTarget == .title || hoveredTarget == .artist ? 34 : 0, height: 1)
                    .offset(y: 2)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .clipped()
        .animation(.snappy(duration: 0.14), value: hoveredTarget)
    }

    private func openArtist() {
        guard let target = MiniPlayerCatalogTarget.artist(from: track) else { return }
        onOpenCatalogTarget(target)
    }

    private func openAlbum() {
        guard let target = MiniPlayerCatalogTarget.album(from: track) else { return }
        onOpenCatalogTarget(target)
    }
}

private enum MiniPlayerNavigationTarget {
    case title
    case artist
    case album
}

private enum MiniPlayerCatalogTarget {
    static func artist(from track: Track) -> Track? {
        guard let artistID = deezerID(from: track.artistCatalogID, kind: .artist, track: track) else {
            NoirwaveDiagnostics.log("Mini player artist navigation missing artistId for '\(track.artist)' from track '\(track.title)'")
            return nil
        }

        return Track(
            id: "deemix-artist.\(artistID)",
            title: track.artist,
            artist: track.artist,
            album: "Artist",
            duration: 0,
            palette: track.palette,
            catalogID: track.artistCatalogID,
            previewURL: nil,
            kind: .artist,
            artworkURL: track.artworkURL
        )
    }

    static func album(from track: Track) -> Track? {
        guard let albumID = deezerID(from: track.albumCatalogID, kind: .album, track: track) else {
            NoirwaveDiagnostics.log("Mini player album navigation missing albumId for '\(track.album)' from track '\(track.title)'")
            return nil
        }

        return Track(
            id: "deemix-album.\(albumID)",
            title: track.album,
            artist: track.artist,
            album: "Album",
            duration: 0,
            palette: track.palette,
            catalogID: track.albumCatalogID,
            previewURL: nil,
            kind: .album,
            artworkURL: track.artworkURL
        )
    }

    private static func deezerID(from catalogID: String?, kind: TrackKind, track: Track) -> String? {
        guard let catalogID = catalogID?.nonEmpty,
              let url = URL(string: catalogID)
        else {
            return nil
        }

        let pathID = url.pathComponents.last ?? ""
        guard pathID.range(of: #"^\d+$"#, options: .regularExpression) != nil else {
            NoirwaveDiagnostics.log("Mini player \(kind.rawValue.lowercased()) navigation has non-numeric Deezer URL '\(catalogID)' for track '\(track.title)'")
            return nil
        }

        return pathID
    }
}

private struct MiniPlayerUtilityControls: View {
    @Binding var selectedPanel: NowPlayingPanelMode
    @Binding var isShowingNowPlaying: Bool
    let showLyrics: Bool
    let showQueue: Bool
    let showSliders: Bool
    let showVolumeSlider: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 5 : 8) {
            if showLyrics {
                Button {
                    toggle(.lyrics)
                } label: {
                    PlayerPanelButtonLabel(
                        symbol: "text.quote",
                        active: isShowingNowPlaying && selectedPanel == .lyrics
                    )
                }
                .buttonStyle(.plain)
                .help("Lyrics")
            }

            if showQueue {
                Button {
                    toggle(.queue)
                } label: {
                    PlayerPanelButtonLabel(
                        symbol: "text.line.last.and.arrowtriangle.forward",
                        active: isShowingNowPlaying && selectedPanel == .queue
                    )
                }
                .buttonStyle(.plain)
                .help("Queue")
            }

            if showSliders {
                Button {
                    toggle(.sound)
                } label: {
                    PlayerPanelButtonLabel(
                        symbol: "slider.horizontal.3",
                        active: isShowingNowPlaying && selectedPanel == .sound
                    )
                }
                .buttonStyle(.plain)
                .help("Audio controls")
            }

            VolumeControl(showSlider: showVolumeSlider)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        .clipped()
    }

    private func toggle(_ panel: NowPlayingPanelMode) {
        if isShowingNowPlaying && selectedPanel == panel {
            isShowingNowPlaying = false
        } else {
            selectedPanel = panel
            isShowingNowPlaying = true
        }
    }
}

private struct PlayerPanelButtonLabel: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovered = false
    let symbol: String
    let active: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(
                active
                    ? NoirwaveTheme.primaryAccent
                    : (
                        isHovered
                            ? .white.opacity(MiniPlayerVisualStyle.inactiveControlHoverOpacity)
                            : .white.opacity(MiniPlayerVisualStyle.inactiveControlOpacity)
                    )
            )
            .frame(width: 32, height: 32)
            .background(
                active
                    ? NoirwaveTheme.primaryAccent.opacity(MiniPlayerVisualStyle.activeControlFillOpacity)
                    : .white.opacity(isHovered ? MiniPlayerVisualStyle.inactiveFillHoverOpacity : MiniPlayerVisualStyle.inactiveFillOpacity),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        active
                            ? NoirwaveTheme.primaryAccent.opacity(MiniPlayerVisualStyle.activeControlStrokeOpacity)
                            : .white.opacity(isHovered ? MiniPlayerVisualStyle.inactiveControlHoverStrokeOpacity : MiniPlayerVisualStyle.inactiveControlStrokeOpacity),
                        lineWidth: 1
                    )
            )
            .onHover { isHovered = $0 }
            .animation(.snappy(duration: 0.12), value: isHovered)
    }
}

private struct FavoriteButton: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovered = false
    let track: Track
    let size: CGFloat

    private var isLiked: Bool {
        store.isLiked(track)
    }

    var body: some View {
        Button {
            store.toggleLike(track)
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: size > 32 ? 15 : 12, weight: .bold))
                .frame(width: size, height: size)
                .background(
                    isLiked
                        ? NoirwaveTheme.primaryAccent.opacity(0.14)
                        : .white.opacity(isHovered ? MiniPlayerVisualStyle.inactiveFillHoverOpacity : MiniPlayerVisualStyle.inactiveFillOpacity),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(
                            isLiked
                                ? NoirwaveTheme.primaryAccent.opacity(MiniPlayerVisualStyle.activeControlStrokeOpacity)
                                : .white.opacity(isHovered ? MiniPlayerVisualStyle.inactiveControlHoverStrokeOpacity : MiniPlayerVisualStyle.inactiveControlStrokeOpacity),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            isLiked
                ? NoirwaveTheme.primaryAccent
                : (
                    isHovered
                        ? .white.opacity(MiniPlayerVisualStyle.inactiveControlHoverOpacity)
                        : .white.opacity(MiniPlayerVisualStyle.inactiveControlOpacity)
                )
        )
        .help(isLiked ? "Remove from favorites" : "Add to favorites")
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.12), value: isHovered)
    }
}

private struct SavedCollectionButton: View {
    @EnvironmentObject private var store: PlayerStore
    let item: Track
    let size: CGFloat

    private var isSaved: Bool {
        store.isSavedCollection(item)
    }

    var body: some View {
        if !item.isPlayable {
            Button {
                store.toggleSavedCollection(item)
            } label: {
                Image(systemName: isSaved ? "checkmark" : "plus")
                    .font(.system(size: size > 36 ? 14 : 12, weight: .bold))
                    .frame(width: size, height: size)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSaved ? .black : .white.opacity(0.76))
            .background(
                isSaved ? NoirwaveTheme.primaryAccent : .white.opacity(0.065),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSaved ? NoirwaveTheme.primaryAccent.opacity(0.38) : .white.opacity(0.1), lineWidth: 1)
            )
            .help(isSaved ? "Remove from Library" : "Save to Library")
        }
    }
}

private struct VolumeControl: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHoveringMute = false
    @State private var isExpanded = false
    let showSlider: Bool

    var body: some View {
        HStack(spacing: isSliderVisible ? 7 : 0) {
            Button {
                if showSlider {
                    store.toggleMute()
                } else {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: VolumeIcon.symbol(for: store.volume))
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(
                        .white.opacity(isHoveringMute || isExpanded ? MiniPlayerVisualStyle.inactiveFillHoverOpacity : MiniPlayerVisualStyle.inactiveFillOpacity),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                .white.opacity(isHoveringMute || isExpanded ? MiniPlayerVisualStyle.inactiveControlHoverStrokeOpacity : MiniPlayerVisualStyle.inactiveControlStrokeOpacity),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                store.volume <= 0
                    ? NoirwaveTheme.primaryAccent.opacity(0.72)
                    : isHoveringMute
                    ? .white.opacity(MiniPlayerVisualStyle.inactiveControlHoverOpacity)
                    : .white.opacity(MiniPlayerVisualStyle.inactiveControlOpacity)
            )
            .help(showSlider ? "Mute" : "Volume")
            .onHover { isHoveringMute = $0 }
            .popover(isPresented: $isExpanded, arrowEdge: .top) {
                VolumeSliderPopover()
                    .environmentObject(store)
            }

            if isSliderVisible {
                Slider(
                    value: Binding(
                        get: { store.volume },
                        set: { store.setVolume($0) }
                    ),
                    in: 0...1
                )
                .tint(NoirwaveTheme.primaryAccent)
                .frame(width: 76)
            }
        }
        .help("Volume")
        .animation(.snappy(duration: 0.12), value: isHoveringMute)
        .animation(.snappy(duration: 0.12), value: isExpanded)
    }

    private var isSliderVisible: Bool {
        showSlider
    }
}

private struct VolumeSliderPopover: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    store.toggleMute()
                } label: {
                    Image(systemName: VolumeIcon.symbol(for: store.volume))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(NoirwaveTheme.primaryAccent)
                .help(store.volume > 0 ? "Mute" : "Unmute")

                Slider(
                    value: Binding(
                        get: { store.volume },
                        set: { store.setVolume($0) }
                    ),
                    in: 0...1
                )
                .tint(NoirwaveTheme.primaryAccent)
                .frame(width: 132)
            }
        }
        .padding(12)
        .background(.regularMaterial)
    }
}

private struct PlaybackControlsCompact: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track
    let playSymbol: String
    let showModes: Bool
    let showLike: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            if showModes {
                PlayerModeButton(
                    symbol: "shuffle",
                    active: store.isShuffled,
                    helpText: store.isShuffled ? "Shuffle on" : "Shuffle"
                ) {
                    store.toggleShuffle()
                }
            }

            PlayerIconButton(symbol: "backward.fill", size: compact ? 32 : 34, primary: false) {
                store.previous()
            }
            .help("Previous")

            PlayerIconButton(symbol: playSymbol, size: MiniPlayerVisualStyle.primaryControlHitSize, primary: true) {
                if store.currentTrack == nil {
                    store.play(track)
                } else {
                    store.togglePlayPause()
                }
            }
            .help("Play/Pause")

            PlayerIconButton(symbol: "forward.fill", size: compact ? 32 : 34, primary: false) {
                store.next()
            }
            .help("Next")

            if showModes {
                PlayerModeButton(
                    symbol: store.repeatMode.systemImage,
                    active: store.repeatMode != .off,
                    helpText: "Repeat \(store.repeatMode.rawValue)"
                ) {
                    store.cycleRepeatMode()
                }
            }

            if showLike {
                FavoriteButton(track: track, size: compact ? 30 : 32)
            }
        }
    }
}

private struct PlayerModeButton: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovered = false
    let symbol: String
    let active: Bool
    let helpText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        active
                            ? NoirwaveTheme.primaryAccent
                            : (
                                isHovered
                                    ? .white.opacity(MiniPlayerVisualStyle.inactiveControlHoverOpacity)
                                    : .white.opacity(MiniPlayerVisualStyle.inactiveControlOpacity)
                            )
                    )
                    .frame(width: 30, height: 30)
                    .background(
                        active
                            ? NoirwaveTheme.primaryAccent.opacity(MiniPlayerVisualStyle.activeControlFillOpacity)
                            : .white.opacity(isHovered ? MiniPlayerVisualStyle.inactiveFillHoverOpacity : MiniPlayerVisualStyle.inactiveFillOpacity),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                active
                                    ? NoirwaveTheme.primaryAccent.opacity(MiniPlayerVisualStyle.activeControlStrokeOpacity)
                                    : .white.opacity(isHovered ? MiniPlayerVisualStyle.inactiveControlHoverStrokeOpacity : MiniPlayerVisualStyle.inactiveControlStrokeOpacity),
                                lineWidth: 1
                            )
                    )
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.12), value: isHovered)
    }
}

private struct PlayerIconButton: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovered = false
    let symbol: String
    let size: CGFloat
    let primary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: primary ? MiniPlayerVisualStyle.primaryIconSize : 13, weight: .bold))
                .foregroundStyle(
                    primary
                        ? .black
                        : (
                            isHovered
                                ? .white.opacity(MiniPlayerVisualStyle.inactiveControlHoverOpacity)
                                : .white.opacity(MiniPlayerVisualStyle.inactiveControlOpacity)
                        )
                )
                .frame(width: primary ? MiniPlayerVisualStyle.primaryControlVisualSize : size, height: primary ? MiniPlayerVisualStyle.primaryControlVisualSize : size)
                .background(
                    primary
                        ? NoirwaveTheme.primaryAccent
                        : .white.opacity(isHovered ? MiniPlayerVisualStyle.inactiveFillHoverOpacity : MiniPlayerVisualStyle.inactiveFillOpacity),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(
                            primary
                                ? .white.opacity(MiniPlayerVisualStyle.primaryControlStrokeOpacity)
                                : .white.opacity(isHovered ? MiniPlayerVisualStyle.inactiveControlHoverStrokeOpacity : MiniPlayerVisualStyle.inactiveControlStrokeOpacity),
                            lineWidth: 1
                        )
                )
                .frame(width: primary ? MiniPlayerVisualStyle.primaryControlHitSize : size, height: primary ? MiniPlayerVisualStyle.primaryControlHitSize : size)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.12), value: isHovered)
        .shadow(
            color: primary ? NoirwaveTheme.primaryAccent.opacity(MiniPlayerVisualStyle.primaryControlShadowOpacity) : .clear,
            radius: primary ? 12 : 0,
            x: 0,
            y: 0
        )
    }
}

private struct MiniPlayerInlineProgressStrip: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovering = false
    @State private var isScrubbing = false
    @State private var scrubFraction: Double?
    @State private var hoverActivationTask: Task<Void, Never>?
    let track: Track
    @Binding var isExpanded: Bool

    private var progressFraction: Double {
        guard track.duration > 0 else { return 0 }
        return min(max(store.progress / track.duration, 0), 1)
    }

    private var displayedProgressFraction: Double {
        scrubFraction ?? progressFraction
    }

    private var isActive: Bool {
        isHovering || isScrubbing
    }

    private var elapsedLabel: String {
        store.progress.playbackLabel
    }

    private var remainingLabel: String {
        "-\(max(track.duration - store.progress, 0).playbackLabel)"
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let active = self.isActive
            let inset: CGFloat = 0
            let scrubberWidth = max(width - inset * 2, 1)
            let progressWidth = scrubberWidth * CGFloat(displayedProgressFraction)
            let progressX = inset + progressWidth
            let lineHeight = active ? MiniPlayerVisualStyle.progressHoverHeight : MiniPlayerVisualStyle.progressHeight
            let thumbSize = active ? MiniPlayerVisualStyle.progressHoverThumbSize : MiniPlayerVisualStyle.progressThumbSize
            let timeOpacity = active ? 1.0 : 0.0

            VStack(spacing: active ? 7 : 0) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(active ? MiniPlayerVisualStyle.progressHoverTrackOpacity : MiniPlayerVisualStyle.progressTrackOpacity))
                        .frame(width: scrubberWidth, height: lineHeight)
                        .offset(x: inset)

                    Capsule()
                        .fill(NoirwaveTheme.primaryAccent.opacity(MiniPlayerVisualStyle.progressAccentOpacity))
                        .frame(width: max(progressWidth, active && displayedProgressFraction > 0 ? lineHeight : 0), height: lineHeight)
                        .offset(x: inset)
                        .shadow(color: NoirwaveTheme.primaryAccent.opacity(active ? 0.08 : 0), radius: active ? 3 : 0, x: 0, y: 0)

                    Circle()
                        .fill(NoirwaveTheme.primaryAccent)
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: progressX - thumbSize / 2)
                        .opacity(active ? 0.98 : 0)
                        .shadow(color: NoirwaveTheme.primaryAccent.opacity(active ? 0.18 : 0), radius: 4, x: 0, y: 0)
                }
                .frame(width: width, height: max(lineHeight, thumbSize))

                HStack {
                    Text(elapsedLabel)
                        .frame(width: MiniPlayerVisualStyle.progressTimeWidth, alignment: .leading)
                    Spacer(minLength: 0)
                    Text(remainingLabel)
                        .frame(width: MiniPlayerVisualStyle.progressTimeWidth, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .monospacedDigit()
                .opacity(timeOpacity)
                .frame(height: active ? 14 : 0)
                .allowsHitTesting(false)

                Spacer(minLength: 0)
            }
            .padding(.top, active ? 2 : 0)
            .frame(width: width, height: proxy.size.height, alignment: .top)
            .background(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(active ? 0.020 : 0.0),
                        Color.white.opacity(active ? 0.012 : 0.0),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(
                    height: active
                        ? MiniPlayerVisualStyle.progressExpandedHeight
                        : MiniPlayerVisualStyle.progressCompactHeight
                )
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        let fraction = min(max((value.location.x - inset) / scrubberWidth, 0), 1)
                        scrubFraction = fraction
                        store.seek(toFraction: fraction)
                    }
                    .onEnded { _ in
                        scrubFraction = nil
                        isScrubbing = false
                    }
            )
            .onHover { hovering in
                updateHoverIntent(hovering)
            }
            .onChange(of: isScrubbing) { _, scrubbing in
                isExpanded = scrubbing || isHovering
            }
            .onDisappear {
                hoverActivationTask?.cancel()
            }
            .animation(.easeOut(duration: 0.10), value: active)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(
            height: isExpanded
                ? MiniPlayerVisualStyle.progressExpandedHeight
                : MiniPlayerVisualStyle.progressCompactHeight,
            alignment: .top
        )
        .accessibilityLabel("Playback progress")
        .accessibilityValue("\(Int(displayedProgressFraction * 100)) percent")
    }

    private func updateHoverIntent(_ hovering: Bool) {
        hoverActivationTask?.cancel()

        if hovering {
            hoverActivationTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isHovering = true
                    isExpanded = true
                }
            }
        } else {
            isHovering = false
            isExpanded = isScrubbing
        }
    }
}

private struct SoundSettingsPanel: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var selectedQuality = "Optimal"

    private let qualities = [
        ("Excellent", "Lossless and high-resolution formats"),
        ("Optimal", "Balanced sound for most devices"),
        ("Economy", "Stable playback on slow internet")
    ]
    private let bandLabels = ["60", "170", "310", "600", "1k", "3k", "6k", "12k", "14k", "16k"]
    private let presets = EqualizerPreset.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(qualities, id: \.0) { quality in
                    Button {
                        selectedQuality = quality.0
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(quality.0)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(quality.1)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.48))
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            if selectedQuality == quality.0 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(NoirwaveTheme.primaryAccent)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().overlay(.white.opacity(0.12))

            HStack {
                Text("Equalizer")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.equalizerSettings.isEnabled },
                        set: { store.setEqualizerEnabled($0) }
                    )
                )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(NoirwaveTheme.primaryAccent)
            }

            HStack(alignment: .bottom, spacing: 9) {
                ForEach(EqualizerSettings.bandFrequencies.indices, id: \.self) { index in
                    VStack(spacing: 10) {
                        EqualizerBandControl(
                            value: Binding(
                                get: { store.equalizerSettings.normalizedBandGains[index] },
                                set: { store.setEqualizerBand(at: index, gain: $0) }
                            ),
                            label: bandLabels[index],
                            isEnabled: store.equalizerSettings.isEnabled
                        )
                        .frame(width: 28, height: 112)

                        Text(bandLabels[index])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.46))
                            .lineLimit(1)
                            .frame(width: 30, height: 12)
                    }
                    .frame(width: 24, height: 136, alignment: .bottom)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(height: 140)
            .frame(maxWidth: .infinity, alignment: .center)
            .noirwaveContentGlass(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                fillOpacity: NowPlayingPanelVisualStyle.innerCardFillOpacity,
                strokeOpacity: NowPlayingPanelVisualStyle.innerCardStrokeOpacity
            )

            Picker(
                "Preset",
                selection: Binding(
                    get: { store.equalizerSettings.preset },
                    set: { store.setEqualizerPreset($0) }
                )
            ) {
                ForEach(presets) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Divider().overlay(.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Crossfade")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Text(store.crossfadeDuration == 0 ? "Off" : "\(String(format: "%.1f", store.crossfadeDuration))s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.52))
                }

                Slider(
                    value: Binding(
                        get: { store.crossfadeDuration },
                        set: { store.setCrossfadeDuration($0) }
                    ),
                    in: 0...8,
                    step: 0.5
                )
                .tint(NoirwaveTheme.primaryAccent)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct EqualizerBandControl: View {
    @Binding var value: Double
    let label: String
    let isEnabled: Bool

    private let range = -12.0...12.0
    private let thumbSize: CGFloat = 24

    private var fraction: CGFloat {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return CGFloat((clamped - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        GeometryReader { proxy in
            let usableHeight = max(proxy.size.height - thumbSize, 1)
            let thumbY = (1 - fraction) * usableHeight
            let thumbCenterY = thumbY + thumbSize / 2

            ZStack(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(isEnabled ? 0.16 : 0.08))
                    .frame(width: 6)

                Capsule()
                    .fill(NoirwaveTheme.primaryAccent.opacity(isEnabled ? 1 : 0.32))
                    .frame(width: 6, height: max(proxy.size.height - thumbCenterY, 0))
                    .offset(y: thumbCenterY)

                Circle()
                    .fill(.white.opacity(isEnabled ? 0.92 : 0.36))
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(isEnabled ? 0.26 : 0), radius: 6, x: 0, y: 3)
                    .offset(y: thumbY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { updateValue(from: $0.location.y, height: proxy.size.height) }
            )
        }
        .allowsHitTesting(isEnabled)
        .accessibilityElement()
        .accessibilityLabel("\(label) Hz")
        .accessibilityValue("\(Int(value.rounded())) decibels")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + 1, range.upperBound)
            case .decrement:
                value = max(value - 1, range.lowerBound)
            @unknown default:
                break
            }
        }
    }

    private func updateValue(from yLocation: CGFloat, height: CGFloat) {
        let usableHeight = max(height - thumbSize, 1)
        let clampedY = min(max(yLocation - thumbSize / 2, 0), usableHeight)
        let nextFraction = 1 - Double(clampedY / usableHeight)
        value = range.lowerBound + nextFraction * (range.upperBound - range.lowerBound)
    }
}

private struct NowPlayingPanel: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedPanel: NowPlayingPanelMode
    @Binding var isShowingNowPlaying: Bool

    var body: some View {
        if let track = store.currentTrack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    NowPlayingPanelTabs(selectedPanel: $selectedPanel)

                    Button {
                        isShowingNowPlaying = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.075), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.82))
                    .help("Close")
                    .accessibilityLabel("Close now playing panel")
                }

                ZStack(alignment: .topLeading) {
                    switch selectedPanel {
                    case .lyrics:
                        LyricsReaderContentView(track: track, isExpanded: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    case .queue:
                        QueuePanelView()
                            .frame(maxHeight: .infinity, alignment: .top)
                    case .sound:
                        SoundSettingsPanel()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(16)
            .foregroundStyle(.white)
            .noirwavePanelGlass(
                in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                material: NowPlayingPanelVisualStyle.panelMaterial,
                appearance: NowPlayingPanelVisualStyle.panelAppearance
            )
        }
    }
}

private struct PlaybackControlsView: View {
    @EnvironmentObject private var store: PlayerStore

    private var playSymbol: String {
        switch store.playbackState {
        case .playing:
            "pause.fill"
        case .loading:
            "hourglass"
        case .idle, .paused, .failed:
            "play.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            PlayerModeButton(
                symbol: "shuffle",
                active: store.isShuffled,
                helpText: store.isShuffled ? "Shuffle on" : "Shuffle"
            ) {
                store.toggleShuffle()
            }

            PlayerIconButton(symbol: "backward.fill", size: 40, primary: false) {
                store.previous()
            }
            .help("Previous")

            PlayerIconButton(symbol: playSymbol, size: 56, primary: true) {
                store.togglePlayPause()
            }
            .help("Play/Pause")

            PlayerIconButton(symbol: "forward.fill", size: 40, primary: false) {
                store.next()
            }
            .help("Next")

            PlayerModeButton(
                symbol: store.repeatMode.systemImage,
                active: store.repeatMode != .off,
                helpText: "Repeat \(store.repeatMode.rawValue)"
            ) {
                store.cycleRepeatMode()
            }
        }
    }
}

private struct NowPlayingPanelTabs: View {
    @Binding var selectedPanel: NowPlayingPanelMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NowPlayingPanelMode.allCases) { panel in
                NowPlayingPanelTabButton(
                    panel: panel,
                    isSelected: selectedPanel == panel
                ) {
                    selectedPanel = panel
                }
            }
        }
        .padding(4)
        .noirwaveContentGlass(
            in: RoundedRectangle(cornerRadius: 13, style: .continuous),
            fillOpacity: NowPlayingPanelVisualStyle.innerCardFillOpacity,
            strokeOpacity: NowPlayingPanelVisualStyle.innerCardStrokeOpacity
        )
        .accessibilityElement(children: .contain)
    }
}

private struct NowPlayingPanelTabButton: View {
    @State private var isHovered = false
    let panel: NowPlayingPanelMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: panel.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(panel.rawValue)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(
                isSelected
                    ? NoirwaveTheme.primaryAccent.opacity(0.95)
                    : .white.opacity(isHovered ? 0.78 : 0.52)
            )
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(
                isSelected
                    ? NoirwaveTheme.primaryAccent.opacity(NowPlayingPanelVisualStyle.selectedFillOpacity)
                    : .white.opacity(isHovered ? NowPlayingPanelVisualStyle.hoverFillOpacity : 0),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected
                            ? NoirwaveTheme.primaryAccent.opacity(NowPlayingPanelVisualStyle.selectedStrokeOpacity)
                            : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help(panel.rawValue)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.14), value: isHovered)
        .animation(.snappy(duration: 0.18), value: isSelected)
    }
}

private struct LyricsReaderContentView: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track
    let isExpanded: Bool

    private var activeLineIndex: Int? {
        guard case .loaded(let lyrics) = store.lyricsState else { return nil }
        return lyrics.activeLineIndex(at: store.progress + 0.12)
    }

    @ViewBuilder
    private var content: some View {
        switch store.lyricsState {
        case .idle, .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading lyrics")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let lyrics):
            if lyrics.hasSynchronizedLines {
                synchronizedLyrics(lyrics)
            } else {
                plainLyrics(lyrics)
            }
        case .unavailable(let message), .failed(let message):
            VStack(spacing: 10) {
                Image(systemName: "text.quote")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var body: some View {
        content
    }

    private func synchronizedLyrics(_ lyrics: TrackLyrics) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: isExpanded) {
                VStack(alignment: .leading, spacing: isExpanded ? 18 : 12) {
                    ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { index, line in
                        LyricsLineView(
                            text: line.text,
                            isActive: index == activeLineIndex,
                            accent: NoirwaveTheme.primaryAccent,
                            isExpanded: isExpanded,
                            timestamp: line.startTime
                        ) {
                            store.seek(to: line.startTime)
                        }
                        .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, isExpanded ? 18 : 6)
                .padding(.trailing, isExpanded ? 18 : 0)
            }
            .onAppear {
                guard let activeLineIndex else { return }
                proxy.scrollTo(activeLineIndex, anchor: .center)
            }
            .onChange(of: activeLineIndex) { _, index in
                guard let index else { return }
                withAnimation(.easeOut(duration: 0.10)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func plainLyrics(_ lyrics: TrackLyrics) -> some View {
        ScrollView(showsIndicators: isExpanded) {
            VStack(alignment: .leading, spacing: isExpanded ? 16 : 10) {
                Label("Unsynced", systemImage: "text.alignleft")
                    .font(.system(size: isExpanded ? 12 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .labelStyle(.titleAndIcon)

                Text(lyrics.text)
                    .font(.system(size: isExpanded ? 19 : 14, weight: .semibold, design: .rounded))
                    .lineSpacing(isExpanded ? 11 : 7)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.vertical, isExpanded ? 18 : 6)
            .padding(.trailing, isExpanded ? 18 : 0)
        }
    }
}

private struct LyricsLineView: View {
    let text: String
    let isActive: Bool
    let accent: Color
    let isExpanded: Bool
    let timestamp: TimeInterval
    let onSeek: () -> Void

    var body: some View {
        Button(action: onSeek) {
            Text(text)
                .font(.system(
                    size: isExpanded ? (isActive ? 25 : 18) : (isActive ? 17 : 13),
                    weight: isActive ? .bold : .semibold,
                    design: .rounded
                ))
                .lineSpacing(isExpanded ? 8 : 4)
                .foregroundStyle(isActive ? accent : .white.opacity(0.48))
                .scaleEffect(isActive ? 1.01 : 1, anchor: .leading)
                .animation(.snappy(duration: 0.16), value: isActive)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Seek to lyric: \(text)")
        .accessibilityValue(timestamp.playbackLabel)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QueuePanelView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var queueQuery = ""

    private var filteredQueue: [Track] {
        QueueSearchFilter.filteredTracks(store.queue, query: queueQuery)
    }

    private var countLabel: String {
        if queueQuery.trimmed.isEmpty {
            return "\(store.queue.count)"
        }

        return "\(filteredQueue.count)/\(store.queue.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up Next")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(countLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                if !store.queue.isEmpty {
                    Button {
                        store.clearQueue()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.44))
                    .help("Clear queue")
                }
            }

            if !store.queue.isEmpty {
                QueueSearchField(query: $queueQuery)
            }

            if store.queue.isEmpty {
                QueuePanelStateView(title: "Queue is empty", symbol: "text.line.last.and.arrowtriangle.forward")
                    .frame(maxHeight: .infinity)
            } else if filteredQueue.isEmpty {
                QueuePanelStateView(title: "No queued tracks found", symbol: "magnifyingglass")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(filteredQueue) { track in
                            QueueRowView(
                                track: track,
                                canMoveUp: canMoveUp(track),
                                canMoveDown: canMoveDown(track),
                                moveUp: { moveUp(track) },
                                moveDown: { moveDown(track) }
                            )
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.top, 2)
    }

    private func canMoveUp(_ track: Track) -> Bool {
        guard let index = store.queue.firstIndex(of: track) else { return false }
        return index > store.queue.startIndex
    }

    private func canMoveDown(_ track: Track) -> Bool {
        guard let index = store.queue.firstIndex(of: track) else { return false }
        return index < store.queue.index(before: store.queue.endIndex)
    }

    private func moveUp(_ track: Track) {
        guard let index = store.queue.firstIndex(of: track),
              index > store.queue.startIndex
        else { return }

        store.moveQueueItem(track, before: store.queue[store.queue.index(before: index)])
    }

    private func moveDown(_ track: Track) {
        guard let index = store.queue.firstIndex(of: track),
              index < store.queue.index(before: store.queue.endIndex)
        else { return }

        let targetIndex = store.queue.index(index, offsetBy: 2, limitedBy: store.queue.endIndex)
        if let targetIndex, targetIndex < store.queue.endIndex {
            store.moveQueueItem(track, before: store.queue[targetIndex])
        } else {
            store.moveQueueItem(track, before: nil)
        }
    }
}

private struct QueueSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.48))

            TextField("Search queue", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))

            if !query.trimmed.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.52))
                .help("Clear queue search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(.white.opacity(0.052), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.075), lineWidth: 1)
        )
    }
}

private struct QueuePanelStateView: View {
    let title: String
    let symbol: String

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct QueueRowView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isHovering = false
    let track: Track
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            ArtworkTile(track: track, size: 30, cornerRadius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }
            Spacer()

            HStack(spacing: 4) {
                QueueActionButton(
                    symbol: "chevron.up",
                    helpText: "Move up",
                    isEnabled: canMoveUp,
                    action: moveUp
                )

                QueueActionButton(
                    symbol: "chevron.down",
                    helpText: "Move down",
                    isEnabled: canMoveDown,
                    action: moveDown
                )

                QueueActionButton(
                    symbol: "arrow.up.to.line",
                    helpText: "Play next",
                    isEnabled: true
                ) {
                    store.playNext(track)
                }
            }
            .opacity(isHovering ? 1 : 0.32)

            Button {
                store.removeFromQueue(track)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.42))
            .help("Remove")
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(.white.opacity(isHovering ? 0.075 : 0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
    }
}

private struct QueueActionButton: View {
    let symbol: String
    let helpText: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(isEnabled ? 0.64 : 0.24))
        .disabled(!isEnabled)
        .help(helpText)
    }
}

private struct ProgressStack: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track
    var compactGlass = false

    private var progressFraction: Double {
        guard track.duration > 0 else { return 0 }
        return min(max(store.progress / track.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 7) {
            Slider(
                value: Binding(
                    get: { progressFraction },
                    set: { store.seek(toFraction: $0) }
                ),
                in: 0...1
            )
            .tint(NoirwaveTheme.primaryAccent)
            .controlSize(compactGlass ? .small : .regular)
            .padding(.horizontal, compactGlass ? 2 : 0)

            HStack {
                Text(store.progress.playbackLabel)
                Spacer()
                Text(track.durationLabel)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.47))
        }
        .padding(.top, compactGlass ? 1 : 0)
    }
}

private enum YandexImportDestination: String, CaseIterable, Identifiable {
    case likedSongs = "Liked Songs"
    case playlist = "Yandex Music Likes"

    var id: String { rawValue }
}

private struct ProfileSettingsView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Streaming, imports, local cache, and AI")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                HStack(spacing: 8) {
                    ProviderStatusView()
                    Text(store.providerStatus.canPlayCatalogContent ? "Stream source online" : "Stream source needs setup")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.64))
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .noirwaveLiquidGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 14) {
                DeezerSessionSettingsPanel()
                    .frame(maxWidth: .infinity, alignment: .top)
                ArtworkCacheSettingsPanel()
                    .frame(maxWidth: .infinity, alignment: .top)
            }

            YandexImportSettingsPanel()

            MCPSettingsPanel()

            ImportHistoryPanel()
        }
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let content: Content

    init(title: String, subtitle: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(NoirwaveTheme.primaryAccent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(16)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct DeezerSessionSettingsPanel: View {
    @EnvironmentObject private var store: PlayerStore
    @FocusState private var isTokenFocused: Bool
    @State private var sessionToken = ""

    private var canSubmit: Bool {
        DeemixAPISessionSecret.normalizedARL(sessionToken) != nil
            && !store.isConfiguringBackendSession
    }

    var body: some View {
        SettingsPanel(title: "Stream Source", subtitle: "Deezer ARL session", symbol: "key.fill") {
            ProviderStatusCard()

            SecureField("Paste Deezer ARL", text: $sessionToken)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .focused($isTokenFocused)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(isTokenFocused ? 0.28 : 0.1), lineWidth: 1)
                )
                .onSubmit(submit)

            HStack(spacing: 9) {
                Button(action: submit) {
                    HStack(spacing: 8) {
                        if store.isConfiguringBackendSession {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.68)
                                .frame(width: 15, height: 15)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 15, height: 15)
                        }

                        Text(store.isConfiguringBackendSession ? "Connecting" : "Connect ARL")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        NoirwaveTheme.primaryAccent.opacity(canSubmit ? 1 : 0.5),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .help("Connect ARL")

                Button {
                    store.connectProvider()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 104)
                        .frame(height: 38)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Refresh stream source")
            }

            if let errorMessage = store.errorMessage?.nonEmpty {
                InlineSettingsMessage(symbol: "exclamationmark.triangle.fill", text: errorMessage)
            }
        }
    }

    private func submit() {
        guard DeemixAPISessionSecret.normalizedARL(sessionToken) != nil else {
            return
        }

        let token = sessionToken
        sessionToken = ""
        isTokenFocused = false
        store.configureBackendSession(token)
    }
}

private struct ArtworkCacheSettingsPanel: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var cacheMessage = "Memory and disk cache are active."

    var body: some View {
        SettingsPanel(title: "Artwork Cache", subtitle: "Covers and shelf prefetch", symbol: "photo.stack") {
            HStack(spacing: 10) {
                MetricTile(title: "Visible", value: "\(store.visibleTracks.count)", symbol: "rectangle.grid.1x2")
                MetricTile(title: "Queue", value: "\(store.queue.count)", symbol: "text.line.last.and.arrowtriangle.forward")
            }

            HStack(spacing: 9) {
                Button {
                    ArtworkImagePipeline.shared.clearCache()
                    cacheMessage = "Artwork cache cleared."
                } label: {
                    Label("Clear Cache", systemImage: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    let tracks = artworkTracksForRebuild
                    ArtworkImagePipeline.shared.rebuildCache(for: tracks, targetPixelSize: 360)
                    cacheMessage = "Rebuilding artwork cache for \(tracks.count) covers."
                } label: {
                    Label("Rebuild", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(NoirwaveTheme.primaryAccent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            InlineSettingsMessage(symbol: "checkmark.circle.fill", text: cacheMessage)
        }
    }

    private var artworkTracksForRebuild: [Track] {
        var tracks = [Track]()
        if let currentTrack = store.currentTrack {
            tracks.append(currentTrack)
        }
        tracks.append(contentsOf: store.visibleTracks)
        tracks.append(contentsOf: store.queue)
        tracks.append(contentsOf: store.featuredTracks)
        tracks.append(contentsOf: store.likedTracks(limit: Int.max))
        tracks.append(contentsOf: store.localPlaylists.flatMap { $0.orderedTracks(preferredTracks: []) })
        return tracks
    }
}

private struct MCPSettingsPanel: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var copyMessage: String?

    private let toolColumns = [
        GridItem(.adaptive(minimum: 178), spacing: 7, alignment: .leading)
    ]

    var body: some View {
        SettingsPanel(title: "AI / MCP", subtitle: "Local agent bridge", symbol: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                MCPStatusHeader(status: store.mcpServerStatus) {
                    store.refreshMCPStatus()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Command")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                        Spacer()
                        Button {
                            copyConnectionCommand()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(height: 28)
                                .padding(.horizontal, 9)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Copy MCP command")
                    }

                    Text(MCPLibraryBridge.connectionCommand)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        )

                    if let copyMessage {
                        InlineSettingsMessage(symbol: "checkmark.circle.fill", text: copyMessage)
                    }
                }

                MCPPermissionsGrid()

                VStack(alignment: .leading, spacing: 8) {
                    MCPSubsectionTitle(title: "Resources", value: "\(MCPLibraryBridge.resourceURIs.count)")
                    LazyVGrid(columns: toolColumns, alignment: .leading, spacing: 7) {
                        ForEach(MCPLibraryBridge.resourceURIs, id: \.self) { uri in
                            MCPChip(text: uri, symbol: "doc.text")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    MCPSubsectionTitle(title: "Tools", value: "\(MCPLibraryBridge.toolNames.count)")
                    LazyVGrid(columns: toolColumns, alignment: .leading, spacing: 7) {
                        ForEach(MCPLibraryBridge.toolNames, id: \.self) { tool in
                            MCPChip(text: tool, symbol: "wrench.and.screwdriver")
                        }
                    }
                }

                MCPActivityLogView()
            }
        }
    }

    private func copyConnectionCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(MCPLibraryBridge.connectionCommand, forType: .string)
        copyMessage = "MCP command copied."
    }
}

private struct MCPStatusHeader: View {
    let status: MCPServerStatus
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.isRunning ? NoirwaveTheme.primaryAccent.opacity(0.22) : .white.opacity(0.06))
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(status.isRunning ? NoirwaveTheme.primaryAccent : .white.opacity(0.36))
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(status.displayState)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(status.isRunning ? NoirwaveTheme.primaryAccent : .white.opacity(0.62))
                Text(statusSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Refresh MCP status")
        }
        .padding(10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusSubtitle: String {
        if status.isRunning {
            return [status.transport ?? "stdio", status.pid.map { "pid \($0)" }]
                .compactMap(\.self)
                .joined(separator: " · ")
        }

        if let updatedDate = status.updatedDate {
            return "last seen \(updatedDate.formatted(date: .omitted, time: .standard))"
        }

        return "stdio server not connected"
    }
}

private struct MCPPermissionsGrid: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MCPSubsectionTitle(title: "Permissions", value: enabledCountLabel)

            VStack(spacing: 7) {
                MCPPermissionToggle(
                    title: "read library",
                    symbol: "books.vertical",
                    isOn: Binding(
                        get: { store.mcpPermissions.readLibrary },
                        set: { newValue in store.updateMCPPermissions { $0.readLibrary = newValue } }
                    )
                )
                MCPPermissionToggle(
                    title: "edit playlists",
                    symbol: "music.note.list",
                    isOn: Binding(
                        get: { store.mcpPermissions.editPlaylists },
                        set: { newValue in store.updateMCPPermissions { $0.editPlaylists = newValue } }
                    )
                )
                MCPPermissionToggle(
                    title: "edit metadata",
                    symbol: "tag",
                    isOn: Binding(
                        get: { store.mcpPermissions.editMetadata },
                        set: { newValue in store.updateMCPPermissions { $0.editMetadata = newValue } }
                    )
                )
                MCPPermissionToggle(
                    title: "delete playlists",
                    symbol: "trash",
                    isOn: Binding(
                        get: { store.mcpPermissions.deletePlaylists },
                        set: { newValue in store.updateMCPPermissions { $0.deletePlaylists = newValue } }
                    )
                )
                MCPPermissionToggle(
                    title: "playback control",
                    symbol: "playpause",
                    isOn: Binding(
                        get: { store.mcpPermissions.playbackControl },
                        set: { newValue in store.updateMCPPermissions { $0.playbackControl = newValue } }
                    )
                )
            }
        }
    }

    private var enabledCountLabel: String {
        let values = [
            store.mcpPermissions.readLibrary,
            store.mcpPermissions.editPlaylists,
            store.mcpPermissions.editMetadata,
            store.mcpPermissions.deletePlaylists,
            store.mcpPermissions.playbackControl
        ]
        return "\(values.filter { $0 }.count)/\(values.count)"
    }
}

private struct MCPPermissionToggle: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? NoirwaveTheme.primaryAccent : .white.opacity(0.48))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.76))
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MCPSubsectionTitle: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(NoirwaveTheme.primaryAccent.opacity(0.82))
        }
    }
}

private struct MCPChip: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NoirwaveTheme.primaryAccent.opacity(0.8))
            Text(text)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct MCPActivityLogView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MCPSubsectionTitle(title: "Activity Log", value: "\(store.mcpActivityLog.count)")
                Button {
                    store.refreshMCPActivityLog()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .frame(width: 24, height: 24)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Refresh activity log")
            }

            if store.mcpActivityLog.isEmpty {
                InlineSettingsMessage(symbol: "tray", text: "No MCP activity yet.")
            } else {
                VStack(spacing: 7) {
                    ForEach(Array(store.mcpActivityLog.prefix(8))) { entry in
                        MCPActivityRow(entry: entry)
                    }
                }
            }
        }
    }
}

private struct MCPActivityRow: View {
    let entry: MCPActivityEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NoirwaveTheme.primaryAccent.opacity(0.82))
                .frame(width: 22, height: 22)
                .background(NoirwaveTheme.primaryAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                Text("\(entry.actor) · \(entry.action)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Spacer()

            Text(timeLabel)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var timeLabel: String {
        guard let date = ISO8601DateFormatter.noirwaveMCP.date(from: entry.timestamp) else {
            return "--:--"
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct YandexImportSettingsPanel: View {
    @EnvironmentObject private var store: PlayerStore
    @FocusState private var isTokenFocused: Bool
    @State private var token = ""
    @State private var shouldSaveToken = false
    @State private var rows: [YandexImportPreviewRow] = []
    @State private var isLoading = false
    @State private var progressText = "Ready"
    @State private var resultText: String?
    @State private var errorText: String?
    @State private var isFileImporterPresented = false
    @State private var destination: YandexImportDestination = .likedSongs

    private let client = YandexMusicImportClient()
    private let tokenVault = YandexMusicTokenVault.app

    private var matchedCount: Int {
        rows.filter { $0.status == .matched }.count
    }

    private var ambiguousCount: Int {
        rows.filter { $0.status == .ambiguous }.count
    }

    private var notFoundCount: Int {
        rows.filter { $0.status == .notFound }.count
    }

    private var importableRows: [YandexImportPreviewRow] {
        rows.filter { $0.importableTrack != nil }
    }

    var body: some View {
        SettingsPanel(title: "Yandex Music Import", subtitle: "Liked tracks transfer", symbol: "square.and.arrow.down") {
            VStack(alignment: .leading, spacing: 10) {
                SecureField("Paste Yandex OAuth token", text: $token)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .focused($isTokenFocused)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(isTokenFocused ? 0.28 : 0.1), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Toggle("Save token in Keychain", isOn: $shouldSaveToken)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))

                    Spacer()

                    Button("Load Saved") {
                        loadSavedToken()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NoirwaveTheme.primaryAccent)

                    Button("Forget") {
                        clearSavedToken()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.54))
                }
            }

            HStack(spacing: 9) {
                Button {
                    Task { await buildPreviewFromToken() }
                } label: {
                    Label(isLoading ? "Matching" : "Preview Token Import", systemImage: isLoading ? "hourglass" : "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            NoirwaveTheme.primaryAccent.opacity(canPreviewToken ? 1 : 0.5),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canPreviewToken)

                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("Choose Export", systemImage: "doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 138)
                        .frame(height: 38)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Picker("Destination", selection: $destination) {
                ForEach(YandexImportDestination.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .disabled(rows.isEmpty || isLoading)

            ImportPreviewSummary(
                matched: matchedCount,
                ambiguous: ambiguousCount,
                notFound: notFoundCount,
                progressText: progressText
            )

            if !rows.isEmpty {
                YandexImportPreviewList(rows: $rows)
                    .frame(maxHeight: 260)

                Button {
                    importPreviewRows()
                } label: {
                    Label("Import \(importableRows.count)", systemImage: "square.and.arrow.down.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            NoirwaveTheme.primaryAccent.opacity(importableRows.isEmpty ? 0.5 : 1),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(importableRows.isEmpty)
            }

            if let resultText {
                InlineSettingsMessage(symbol: "checkmark.circle.fill", text: resultText)
            }

            if let errorText {
                InlineSettingsMessage(symbol: "exclamationmark.triangle.fill", text: errorText)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.json, .commaSeparatedText, .plainText, .text]
        ) { result in
            handleImportFile(result)
        }
    }

    private var canPreviewToken: Bool {
        YandexMusicTokenVault.normalizedToken(token) != nil && !isLoading
    }

    private func loadSavedToken() {
        do {
            token = try tokenVault.savedToken() ?? ""
            errorText = token.isEmpty ? "No saved Yandex token found." : nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func clearSavedToken() {
        do {
            try tokenVault.deleteSavedToken()
            if shouldSaveToken {
                shouldSaveToken = false
            }
            resultText = "Saved Yandex token removed from Keychain."
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func buildPreviewFromToken() async {
        guard let normalizedToken = YandexMusicTokenVault.normalizedToken(token) else { return }
        if shouldSaveToken {
            do {
                try tokenVault.saveToken(normalizedToken)
            } catch {
                errorText = error.localizedDescription
                return
            }
        }
        token = shouldSaveToken ? token : ""
        isTokenFocused = false
        await buildPreview(token: normalizedToken, exportText: nil)
    }

    private func buildPreview(token: String?, exportText: String?) async {
        isLoading = true
        rows = []
        resultText = nil
        errorText = nil
        progressText = "Loading Yandex likes"
        defer { isLoading = false }

        do {
            let items = try await client.likedTracks(token: token, exportText: exportText)
            guard !items.isEmpty else {
                progressText = "No liked tracks found"
                return
            }

            for (index, item) in items.enumerated() {
                progressText = "Matching \(index + 1)/\(items.count)"
                let candidates = (try? await store.provider.search(item.searchQuery, scope: .catalog)) ?? []
                rows.append(YandexImportMatcher.previewRow(for: item, candidates: candidates))
            }

            progressText = "Preview ready"
        } catch {
            rows = []
            progressText = "Import failed"
            errorText = error.localizedDescription
        }
    }

    private func handleImportFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let text = try String(contentsOf: url, encoding: .utf8)
            Task {
                await buildPreview(token: nil, exportText: text)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func importPreviewRows() {
        let tracks = importableRows.compactMap(\.importableTrack)
        let imported: Int
        let destinationLabel: String

        switch destination {
        case .likedSongs:
            imported = store.addLikedTracks(tracks)
            destinationLabel = "Liked Songs"
        case .playlist:
            let result = store.addTracksToPlaylist(named: "Yandex Music Likes", tracks: tracks)
            imported = result.imported
            destinationLabel = result.playlist.title
        }

        let skipped = max(tracks.count - imported, 0)
        store.recordImport(
            source: "Yandex Music",
            imported: imported,
            skipped: skipped,
            notFound: notFoundCount,
            destination: destinationLabel
        )
        resultText = "\(imported) imported, \(skipped) skipped, \(notFoundCount) not found."
    }
}

private struct ImportPreviewSummary: View {
    let matched: Int
    let ambiguous: Int
    let notFound: Int
    let progressText: String

    var body: some View {
        HStack(spacing: 10) {
            ImportMetric(label: "Matched", value: matched, color: NoirwaveTheme.primaryAccent)
            ImportMetric(label: "Ambiguous", value: ambiguous, color: .orange)
            ImportMetric(label: "Not Found", value: notFound, color: .white.opacity(0.5))
            Spacer()
            Text(progressText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)
        }
    }
}

private struct ImportMetric: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("\(value)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct YandexImportPreviewList: View {
    @Binding var rows: [YandexImportPreviewRow]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 7) {
                ForEach($rows) { $row in
                    YandexImportPreviewRowView(row: $row)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
    }
}

private struct YandexImportPreviewRowView: View {
    @Binding var row: YandexImportPreviewRow

    private var statusColor: Color {
        switch row.status {
        case .matched:
            NoirwaveTheme.primaryAccent
        case .ambiguous:
            .orange
        case .notFound:
            .white.opacity(0.44)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.source.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(row.source.artist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            if row.status == .ambiguous {
                Menu {
                    ForEach(row.candidates) { candidate in
                        Button {
                            row.selectedTrack = candidate
                        } label: {
                            Text("\(candidate.artist) - \(candidate.title)")
                        }
                    }
                } label: {
                    Text(row.selectedTrack.map { "\($0.artist) - \($0.title)" } ?? "Choose")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .frame(maxWidth: 240, alignment: .trailing)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            } else {
                Text(row.selectedTrack.map { "\($0.artist) - \($0.title)" } ?? row.status.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(row.status == .notFound ? .white.opacity(0.42) : .white.opacity(0.72))
                    .lineLimit(1)
                    .frame(maxWidth: 240, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ImportHistoryPanel: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        SettingsPanel(title: "Import History", subtitle: "Recent local snapshots", symbol: "clock.arrow.circlepath") {
            if store.importHistory.isEmpty {
                InlineSettingsMessage(symbol: "tray", text: "No imports yet.")
            } else {
                VStack(spacing: 7) {
                    ForEach(store.importHistory) { record in
                        HStack(spacing: 10) {
                            Text(record.source)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(record.destination)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.48))
                                .lineLimit(1)

                            Spacer()

                            Text("\(record.imported) imported")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(NoirwaveTheme.primaryAccent)

                            Text(record.importedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct InlineSettingsMessage: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
        }
        .foregroundStyle(.white.opacity(0.72))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ProviderStatusCard: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProviderStatusView()
                Spacer()
                Text(store.providerStatus.canPlayCatalogContent ? "Connected" : "Offline")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(store.providerStatus.canPlayCatalogContent ? NoirwaveTheme.primaryAccent : .white.opacity(0.45))
            }

            if let message = store.providerStatus.message?.nonEmpty {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ProviderStatusView: View {
    @EnvironmentObject private var store: PlayerStore

    private var label: String {
        switch store.providerStatus.authorization {
        case .authorized:
            if store.needsBackendSession {
                return "Needs session"
            }
            return store.providerStatus.canPlayCatalogContent ? "Connected" : "Needs setup"
        case .notDetermined:
            return "Not connected"
        case .denied:
            return "Access denied"
        case .restricted:
            return "Restricted"
        case .unsupported:
            return "Backend offline"
        }
    }

    private var statusColor: Color {
        if store.needsBackendSession {
            return .orange
        }

        return store.providerStatus.authorization == .authorized ? NoirwaveTheme.primaryAccent : .white.opacity(0.35)
    }

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .help(label)
    }
}

private struct MusicConnectPanel: View {
    @EnvironmentObject private var store: PlayerStore

    private var title: String {
        switch store.providerStatus.authorization {
        case .authorized:
            "No tracks loaded"
        case .denied:
            "\(store.provider.sourceName) access denied"
        case .restricted:
            "\(store.provider.sourceName) is restricted"
        case .notDetermined, .unsupported:
            "Connect \(store.provider.sourceName)"
        }
    }

    private var actionTitle: String {
        store.providerStatus.canPlayCatalogContent ? "Refresh Source" : "Connect Source"
    }

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            Button {
                store.connectProvider()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: store.providerStatus.canPlayCatalogContent ? "arrow.clockwise" : "network")
                    Text(actionTitle)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((NoirwaveTheme.primaryAccent), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(actionTitle)
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct PlaybackErrorBanner: View {
    let message: String

    var body: some View {
        let bannerShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .noirwaveContentGlass(
            in: bannerShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct CatalogLoadingView: View {
    let title: String
    let subtitle: String

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.82)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct CatalogLoadingSkeletonView: View {
    let title: String
    let subtitle: String
    let showsHero: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CatalogLoadingView(title: title, subtitle: subtitle)

            if showsHero {
                CatalogHeroSkeleton()
            }

            CatalogShelfSkeleton()
            CatalogTrackListSkeleton()
        }
    }
}

private struct CatalogHeroSkeleton: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack {
                Spacer()
                LoadingSkeletonBlock(width: 220, height: 220, cornerRadius: 18)
                    .rotationEffect(.degrees(-4))
                    .padding(.trailing, 58)
                    .padding(.vertical, 34)
            }

            LinearGradient(
                colors: [
                    .white.opacity(0.02),
                    NoirwaveTheme.primaryAccent.opacity(0.08),
                    Color(hex: GraphiteSurfaceStyle.centerBaseHex).opacity(0.46)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            VStack(alignment: .leading, spacing: 14) {
                LoadingSkeletonBlock(width: 260, height: 46, cornerRadius: 10)
                LoadingSkeletonBlock(width: 160, height: 18, cornerRadius: 6)
                HStack(spacing: 10) {
                    LoadingSkeletonBlock(width: 150, height: 46, cornerRadius: 12)
                    LoadingSkeletonBlock(width: 46, height: 46, cornerRadius: 12)
                }
            }
            .padding(30)
        }
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

private struct CatalogShelfSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LoadingSkeletonBlock(width: 190, height: 22, cornerRadius: 7)

            HStack(alignment: .top, spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        LoadingSkeletonBlock(width: 166, height: 166, cornerRadius: 10)
                        LoadingSkeletonBlock(width: 132, height: 14, cornerRadius: 5)
                        LoadingSkeletonBlock(width: 96, height: 12, cornerRadius: 5)
                    }
                    .frame(width: 166, alignment: .leading)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CatalogTrackListSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LoadingSkeletonBlock(width: 160, height: 22, cornerRadius: 7)

            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 12) {
                        LoadingSkeletonBlock(width: 36, height: 36, cornerRadius: 7)
                        VStack(alignment: .leading, spacing: 6) {
                            LoadingSkeletonBlock(width: 220, height: 13, cornerRadius: 5)
                            LoadingSkeletonBlock(width: 140, height: 11, cornerRadius: 5)
                        }
                        Spacer()
                        LoadingSkeletonBlock(width: 48, height: 12, cornerRadius: 5)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 52)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LoadingSkeletonBlock: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.07),
                        .white.opacity(0.12),
                        .white.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.05), lineWidth: 1)
            )
    }
}

private struct EmptySearchView: View {
    var isSearching = false

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        VStack(spacing: 10) {
            if isSearching {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.82)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
            }

            Text(isSearching ? "Searching catalog" : "No matches found")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .noirwaveContentGlass(
            in: panelShape,
            fillOpacity: GraphiteSurfaceStyle.contentStrongFillOpacity,
            strokeOpacity: GraphiteSurfaceStyle.contentStrongStrokeOpacity
        )
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
            Spacer()
        }
    }
}

private struct CollectionActionCluster: View {
    @EnvironmentObject private var store: PlayerStore
    let tracks: [Track]
    let accent: Color
    let primaryLabel: String

    private var playableTracks: [Track] {
        tracks.filter(\.isPlayable)
    }

    var body: some View {
        if !playableTracks.isEmpty {
            HStack(spacing: 8) {
                Button {
                    store.playAll(playableTracks)
                } label: {
                    Label(primaryLabel, systemImage: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(primaryLabel)

                Button {
                    store.shufflePlay(playableTracks)
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help("Shuffle play")

                Button {
                    store.playNext(playableTracks)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help("Play next")

                Button {
                    store.enqueue(playableTracks)
                } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help("Add all to queue")

                AddTracksToPlaylistMenu(
                    tracks: playableTracks,
                    excludingPlaylistID: nil,
                    help: "Add visible tracks to playlist",
                    size: 34
                )

                Spacer(minLength: 0)
            }
        }
    }
}

private struct InfoPill: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.78))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        )
    }
}

private struct MediaKindBadge: View {
    let kind: TrackKind

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: 10, weight: .bold))
            .frame(width: 20, height: 20)
        .foregroundStyle(.white.opacity(0.72))
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .help(kind.rawValue)
    }
}

private struct ArtworkTile: View {
    let track: Track
    let size: CGFloat
    let cornerRadius: CGFloat
    var priority: ArtworkRequestPriority = .visible
    @State private var image: NSImage?
    @State private var didFail = false
    @State private var loadedArtworkURL: URL?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            fallbackArtwork
                .opacity(image == nil ? 1 : 0)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .transition(.opacity.animation(.easeOut(duration: 0.14)))
            } else if artworkURL != nil && !didFail {
                ArtworkSkeletonHighlight()
            }

            LinearGradient(
                colors: [
                    .black.opacity(0),
                    .black.opacity(0.26)
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            shape
                .fill(.white.opacity(0.08))
                .blendMode(.screen)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .contentShape(shape)
        .overlay(
            shape.stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .task(id: artworkURL) {
            await loadArtwork()
        }
    }

    private var fallbackArtwork: some View {
        ZStack {
            Color(hex: ArtworkFallbackStyle.backgroundHex)

            Image(systemName: track.kind.systemImage)
                .font(.system(size: size * 0.22, weight: .semibold))
                .foregroundStyle(NoirwaveTheme.primaryAccent.opacity(ArtworkFallbackStyle.iconOpacity))
        }
    }

    private var artworkURL: URL? {
        ArtworkImagePipeline.artworkURL(for: track)
    }

    private var targetPixelSize: CGFloat {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return max(size * scale, 96)
    }

    private func loadArtwork() async {
        guard let artworkURL else {
            image = nil
            loadedArtworkURL = nil
            didFail = false
            return
        }

        if loadedArtworkURL == artworkURL, image != nil {
            return
        }

        didFail = false

        if let cachedImage = ArtworkImagePipeline.shared.cachedMemoryImage(
            for: artworkURL,
            targetPixelSize: targetPixelSize
        ) {
            image = cachedImage
            loadedArtworkURL = artworkURL
            return
        }

        image = nil

        guard let loadedImage = await ArtworkImagePipeline.shared.image(
            for: artworkURL,
            targetPixelSize: targetPixelSize,
            priority: priority
        ) else {
            didFail = true
            return
        }

        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.14)) {
            image = loadedImage
            loadedArtworkURL = artworkURL
        }
    }
}

private struct ArtworkSkeletonHighlight: View {
    var body: some View {
        LinearGradient(
            colors: [.white.opacity(0.08), .white.opacity(0.22), .white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}
