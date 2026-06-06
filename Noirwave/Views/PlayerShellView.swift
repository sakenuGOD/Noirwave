import SwiftUI

private enum ShellDestination: String, CaseIterable, Identifiable {
    case listenNow = "Listen Now"
    case search = "Search"
    case library = "Library"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .listenNow:
            "play.circle.fill"
        case .search:
            "magnifyingglass"
        case .library:
            "rectangle.stack.fill"
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
        }
    }
}

private enum NowPlayingPanelMode: String, CaseIterable, Identifiable {
    case lyrics = "Lyrics"
    case queue = "Queue"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .lyrics:
            "text.quote"
        case .queue:
            "text.line.last.and.arrowtriangle.forward"
        }
    }
}

private typealias PlaylistCreationRequest = @MainActor @Sendable (Track) -> Void

private struct PlaylistCreationRequestKey: EnvironmentKey {
    static let defaultValue: PlaylistCreationRequest = { _ in }
}

private extension EnvironmentValues {
    var requestPlaylistCreationFromTrack: PlaylistCreationRequest {
        get { self[PlaylistCreationRequestKey.self] }
        set { self[PlaylistCreationRequestKey.self] = newValue }
    }
}

struct PlayerShellView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var selectedDestination: ShellDestination = .listenNow
    @State private var selectedLocalPlaylistID: String?
    @State private var isShowingNowPlaying = false
    @State private var nowPlayingPanelMode: NowPlayingPanelMode = .lyrics
    @State private var playlistEditor: PlaylistEditor?

    private var palette: TrackPalette {
        store.currentTrack?.palette ?? .fallback
    }

    var body: some View {
        ZStack {
            DynamicStudioBackground(palette: palette)

                HStack(spacing: 0) {
                    SidebarView(
                        selection: $selectedDestination,
                        selectedLocalPlaylistID: $selectedLocalPlaylistID
                    )
                    .frame(width: 284)

                Rectangle()
                    .fill(.white.opacity(0.055))
                    .frame(width: 1)

                VStack(spacing: 0) {
                    TopBarView(selection: $selectedDestination)
                        .padding(.horizontal, 30)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    ContentDeckView(
                        selection: selectedDestination,
                        selectedLocalPlaylistID: $selectedLocalPlaylistID
                    )
                    .environment(\.requestPlaylistCreationFromTrack) { track in
                        playlistEditor = PlaylistEditor(
                            playlistID: nil,
                            title: LocalPlaylist.fallbackTitle,
                            tracks: [track]
                        )
                    }

                    MiniPlayerBar(
                        selectedPanel: $nowPlayingPanelMode,
                        isShowingNowPlaying: $isShowingNowPlaying
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $isShowingNowPlaying) {
            NowPlayingPanel(selectedPanel: $nowPlayingPanelMode)
                .environmentObject(store)
                .frame(minWidth: 900, idealWidth: 980, minHeight: 680, idealHeight: 760)
                .background(.regularMaterial)
        }
        .sheet(item: $playlistEditor) { editor in
            PlaylistTitleSheet(title: editor.title, primaryLabel: "Create") { title in
                let playlist = store.createPlaylist(title: title, tracks: editor.tracks)
                selectedDestination = .library
                selectedLocalPlaylistID = playlist.id
                store.leaveCatalogContext()
                playlistEditor = nil
            } onCancel: {
                playlistEditor = nil
            }
        }
    }
}

private struct DynamicStudioBackground: View {
    let palette: TrackPalette

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: "#050505"))

            LinearGradient(
                colors: [
                    palette.accent.opacity(0.12),
                    .clear,
                    Color(hex: "#050505")
                ],
                startPoint: .topTrailing,
                endPoint: .center
            )

            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.04)).frame(height: 1)
                Spacer()
                Rectangle().fill(Color(hex: "#050505").opacity(0.92)).frame(height: 112)
            }
        }
        .ignoresSafeArea()
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: ShellDestination
    @Binding var selectedLocalPlaylistID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((store.currentTrack?.palette.accent ?? Color(hex: "#FF4F72")).opacity(0.95))
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Noirwave")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("music")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(ShellDestination.allCases) { destination in
                    SidebarItem(
                        title: destination.rawValue,
                        symbol: destination.symbol,
                        active: selection == destination
                    ) {
                        selection = destination
                        selectedLocalPlaylistID = nil
                        store.leaveCatalogContext()
                    }
                }
            }

            Spacer(minLength: 12)

            SidebarPlaylistPreview(
                selection: $selection,
                selectedLocalPlaylistID: $selectedLocalPlaylistID
            )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .foregroundStyle(.white)
        .background(Color(hex: "#070707"))
    }
}

private struct SidebarItem: View {
    @EnvironmentObject private var store: PlayerStore
    let title: String
    let symbol: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 14, weight: active ? .semibold : .medium))

                Spacer()
            }
            .foregroundStyle(active ? .black : .white.opacity(0.82))
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(
                active
                    ? (store.currentTrack?.palette.accent ?? Color(hex: "#FF4F72"))
                    : .white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct SidebarLibraryCollection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tracks: [Track]
    let localPlaylistID: String?

    init(
        id: String,
        title: String,
        subtitle: String,
        symbol: String,
        tracks: [Track],
        localPlaylistID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tracks = tracks
        self.localPlaylistID = localPlaylistID
    }

    var artworkTracks: [Track] {
        Array(tracks.prefix(4))
    }
}

private struct SidebarPlaylistPreview: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: ShellDestination
    @Binding var selectedLocalPlaylistID: String?

    private var collections: [SidebarLibraryCollection] {
        let savedTracks = store.likedTracks(limit: 120).filter(\.isPlayable)
        let localCollections = store.localPlaylists.prefix(3).map { playlist in
            let tracks = store.playlistTracks(playlistID: playlist.id)
            return SidebarLibraryCollection(
                id: "playlist.\(playlist.id)",
                title: playlist.title,
                subtitle: "\(playlist.trackCount) track\(playlist.trackCount == 1 ? "" : "s")",
                symbol: "music.note.list",
                tracks: tracks,
                localPlaylistID: playlist.id
            )
        }

        if savedTracks.isEmpty {
            let discoveryTracks = Array(store.featuredTracks.filter(\.isPlayable).prefix(18))
            guard !discoveryTracks.isEmpty || !localCollections.isEmpty else { return [] }
            let discoveryCollections = discoveryTracks.isEmpty ? [] : [
                SidebarLibraryCollection(
                    id: "discovery.mix",
                    title: "Noirwave Mix",
                    subtitle: "\(discoveryTracks.count) tracks",
                    symbol: "waveform",
                    tracks: discoveryTracks
                )
            ]
            return Array((localCollections + discoveryCollections).prefix(3))
        }

        var output: [SidebarLibraryCollection] = localCollections + [
            SidebarLibraryCollection(
                id: "liked.songs",
                title: "Liked Songs",
                subtitle: "\(savedTracks.count) saved",
                symbol: "heart.fill",
                tracks: savedTracks
            )
        ]

        if let album = topAlbumCollection(from: savedTracks) {
            output.append(album)
        }

        if let artist = topArtistCollection(from: savedTracks) {
            output.append(artist)
        }

        return Array(output.prefix(3))
    }

    private var accent: Color {
        store.currentTrack?.palette.accent ?? collections.first?.tracks.first?.palette.accent ?? .white
    }

    private func topAlbumCollection(from tracks: [Track]) -> SidebarLibraryCollection? {
        var order: [String] = []
        var grouped: [String: [Track]] = [:]

        for track in tracks {
            guard let album = track.album.nonEmpty else { continue }
            let key = "\(album.searchNormalized).\(track.artist.searchNormalized)"
            guard !key.isEmpty else { continue }
            if grouped[key] == nil {
                order.append(key)
                grouped[key] = []
            }
            grouped[key]?.append(track)
        }

        guard let key = order.max(by: { (grouped[$0]?.count ?? 0) < (grouped[$1]?.count ?? 0) }),
              let tracks = grouped[key],
              let first = tracks.first
        else { return nil }

        return SidebarLibraryCollection(
            id: "album.\(key)",
            title: first.album,
            subtitle: "\(tracks.count) saved · \(first.artist)",
            symbol: "square.stack.fill",
            tracks: tracks
        )
    }

    private func topArtistCollection(from tracks: [Track]) -> SidebarLibraryCollection? {
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

        guard let key = order.max(by: { (grouped[$0]?.count ?? 0) < (grouped[$1]?.count ?? 0) }),
              let tracks = grouped[key],
              let first = tracks.first
        else { return nil }

        return SidebarLibraryCollection(
            id: "artist.\(key)",
            title: first.artist,
            subtitle: "\(tracks.count) saved tracks",
            symbol: "music.mic",
            tracks: tracks
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Playlists")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(collections.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(.horizontal, 8)

            if collections.isEmpty {
                SidebarCollectionEmptyRow(accent: accent)
            } else {
                VStack(spacing: 6) {
                    ForEach(collections) { collection in
                        let isSelected = collection.localPlaylistID != nil
                            && selection == .library
                            && selectedLocalPlaylistID == collection.localPlaylistID
                        SidebarPlaylistRow(collection: collection, isSelected: isSelected) {
                            if let playlistID = collection.localPlaylistID {
                                selectedLocalPlaylistID = playlistID
                                selection = .library
                                store.leaveCatalogContext()
                            } else {
                                store.playAll(collection.tracks)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SidebarPlaylistRow: View {
    @EnvironmentObject private var store: PlayerStore
    let collection: SidebarLibraryCollection
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        store.currentTrack?.palette.accent ?? collection.tracks.first?.palette.accent ?? .white
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                LibraryMosaicArtwork(tracks: collection.artworkTracks, size: 38, accent: accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.84))
                        .lineLimit(1)
                    Text(collection.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? .black.opacity(0.6) : .white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: collection.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? .black.opacity(0.82) : accent.opacity(0.86))
                    .frame(width: 22, height: 22)
                    .background(
                        isSelected ? .black.opacity(0.14) : .white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
            }
            .padding(.horizontal, 8)
            .frame(height: 46)
            .background(
                isSelected ? accent.opacity(0.92) : .white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(collection.title)
    }
}

private struct SidebarCollectionEmptyRow: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(accent.opacity(0.2))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.54))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("No saved collections")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                Text("Library")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 46)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct TopBarView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selection: ShellDestination
    @State private var isShowingSessionSettings = false

    var body: some View {
        HStack(spacing: 12) {
            if store.catalogContext != nil {
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

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.52))
                TextField(
                    "Search music",
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
                .font(.system(size: 15))

                if store.isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.11), lineWidth: 1)
            )
            .frame(maxWidth: 680)

            TopBarSourceControls(isShowingSessionSettings: $isShowingSessionSettings)

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $isShowingSessionSettings) {
            SessionSettingsSheet()
                .environmentObject(store)
        }
    }
}

private struct TopBarSourceControls: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var isShowingSessionSettings: Bool

    private var statusText: String {
        store.providerStatus.canPlayCatalogContent ? "Online" : "Offline"
    }

    var body: some View {
        HStack(spacing: 7) {
            Button {
                isShowingSessionSettings = true
            } label: {
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
            .help("Configure Deezer ARL")

            Button {
                store.connectProvider()
            } label: {
                Image(systemName: store.providerStatus.canPlayCatalogContent ? "arrow.clockwise" : "network")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
            .help("Connect or refresh stream source")

            HStack(spacing: 6) {
                Circle()
                    .fill(store.providerStatus.canPlayCatalogContent ? .green : .orange.opacity(0.86))
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.64))
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct ContentDeckView: View {
    @EnvironmentObject private var store: PlayerStore
    let selection: ShellDestination
    @Binding var selectedLocalPlaylistID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if store.needsBackendSession,
                   let errorMessage = store.errorMessage?.nonEmpty {
                    PlaybackErrorBanner(message: errorMessage)
                }

                if let context = store.catalogContext {
                    CatalogDetailContent(context: context)
                } else if !store.searchQuery.trimmed.isEmpty {
                    SearchResultsView(items: store.visibleTracks, isLoading: store.isSearching)
                } else {
                    switch selection {
                    case .listenNow:
                        ListenNowView()
                    case .search:
                        SearchLandingView()
                    case .library:
                        LibraryView(selectedPlaylistID: $selectedLocalPlaylistID)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
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
        if store.featuredTracks.isEmpty && !store.isLoadingFeaturedTracks {
            MusicConnectPanel()
        } else {
            VStack(alignment: .leading, spacing: 24) {
                WaveLaunchHero(tracks: tracks)

                if store.isLoadingFeaturedTracks && tracks.isEmpty {
                    CatalogLoadingView(title: "Loading catalog", subtitle: store.provider.sourceName)
                }

                let likedTracks = store.likedTracks(limit: 12)
                if !likedTracks.isEmpty {
                    FeaturedTrackShelf(title: "Любимое", tracks: likedTracks)
                }

                FeaturedTrackShelf(title: "Рекомендации", tracks: Array(tracks.prefix(10)))
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
                        .shadow(color: track.palette.accent.opacity(0.32), radius: 38, x: 0, y: 22)
                        .padding(.trailing, 58)
                        .padding(.vertical, 34)
                }

                LinearGradient(
                    colors: [
                        Color(hex: "#171717").opacity(0.2),
                        track.palette.base.opacity(0.72),
                        .black.opacity(0.9)
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
                                .background(track.palette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        .foregroundStyle(store.isLiked(track) ? track.palette.accent : .white.opacity(0.82))
                        .help(store.isLiked(track) ? "Unlike" : "Like")
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
        }
    }
}

private struct SearchLandingView: View {
    @EnvironmentObject private var store: PlayerStore

    private var tracks: [Track] {
        store.featuredTracks.filter(\.isPlayable)
    }

    var body: some View {
        if store.featuredTracks.isEmpty && !store.isLoadingFeaturedTracks {
            MusicConnectPanel()
        } else {
            VStack(alignment: .leading, spacing: 24) {
                SearchPromptStage()
                CollectionActionCluster(
                    tracks: tracks,
                    accent: store.currentTrack?.palette.accent ?? .white,
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
            Text("Поиск")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Введи артиста, альбом или трек сверху.")
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

    private var artists: [Track] {
        items.filter { $0.kind == .artist }
    }

    private var albums: [Track] {
        items.filter { $0.kind == .album }
    }

    private var tracks: [Track] {
        items.filter(\.isPlayable)
    }

    var body: some View {
        if items.isEmpty && isLoading {
            CatalogLoadingView(title: "Searching", subtitle: "Deezer catalog")
        } else if items.isEmpty {
            EmptySearchView()
        } else {
            VStack(alignment: .leading, spacing: 24) {
                if let best = items.first {
                    BestMatchCard(item: best)
                }

                EntityShelf(title: "Исполнители", items: artists, cardSize: 164, roundArtists: true)
                EntityShelf(title: "Релизы", items: albums, cardSize: 190, roundArtists: false)
                CollectionActionCluster(
                    tracks: tracks,
                    accent: store.currentTrack?.palette.accent ?? .white,
                    primaryLabel: "Play"
                )
                TrackListSection(title: "Треки", subtitle: "\(tracks.count)", tracks: tracks, numbered: false)
            }
        }
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

private struct LibraryView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedPlaylistID: String?
    @State private var libraryQuery = ""
    @State private var librarySortMode: LibrarySortMode = .recentlyAdded
    @State private var playlistEditor: PlaylistEditor?

    private var likedTracks: [Track] {
        store.likedTracks(limit: Int.max)
    }

    private var localPlaylists: [LocalPlaylist] {
        store.localPlaylists
    }

    private var selectedPlaylist: LocalPlaylist? {
        guard let selectedPlaylistID else { return nil }
        return localPlaylists.first { $0.id == selectedPlaylistID }
    }

    private var savedCollections: [Track] {
        store.savedCollections(limit: 16)
    }

    private var filteredTracks: [Track] {
        LibraryTrackOrganizer.tracks(likedTracks, query: libraryQuery, sortMode: librarySortMode)
    }

    private var filteredLocalPlaylists: [LocalPlaylist] {
        filteredPlaylists(localPlaylists, query: libraryQuery)
    }

    private var filteredSavedCollections: [Track] {
        LibrarySearchFilter.filteredTracks(savedCollections, query: libraryQuery)
    }

    private var albums: [Track] {
        DerivedLibraryEntities.albums(from: filteredTracks)
    }

    private var artists: [Track] {
        DerivedLibraryEntities.artists(from: filteredTracks)
    }

    var body: some View {
        if let selectedPlaylist {
            LocalPlaylistDetailView(
                playlist: selectedPlaylist,
                tracks: store.playlistTracks(playlistID: selectedPlaylist.id),
                onBack: {
                    selectedPlaylistID = nil
                },
                onRename: {
                    playlistEditor = PlaylistEditor(playlistID: selectedPlaylist.id, title: selectedPlaylist.title)
                },
                onDelete: {
                    store.deletePlaylist(playlistID: selectedPlaylist.id)
                    selectedPlaylistID = nil
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
                    selectedPlaylistID = playlist.id
                    playlistEditor = nil
                } onCancel: {
                    playlistEditor = nil
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 24) {
                LibraryHeaderView(
                    query: $libraryQuery,
                    sortMode: $librarySortMode,
                    totalCount: likedTracks.count + savedCollections.count + localPlaylists.count,
                    filteredCount: filteredTracks.count + filteredSavedCollections.count + filteredLocalPlaylists.count
                ) {
                    playlistEditor = PlaylistEditor(playlistID: nil, title: LocalPlaylist.fallbackTitle)
                }

                LibraryStatsView(playlists: localPlaylists.count, artists: artists, albums: albums, tracks: filteredTracks)
                LibraryCollectionsShelf(
                    localPlaylists: filteredLocalPlaylists,
                    tracks: filteredTracks,
                    savedCollections: filteredSavedCollections,
                    albums: albums,
                    artists: artists
                ) { playlistID in
                    selectedPlaylistID = playlistID
                }

                if filteredTracks.isEmpty && filteredSavedCollections.isEmpty && filteredLocalPlaylists.isEmpty {
                    EmptyLibrarySearchPanel(query: libraryQuery)
                } else if !filteredTracks.isEmpty {
                    CollectionActionCluster(
                        tracks: filteredTracks,
                        accent: store.currentTrack?.palette.accent ?? .white,
                        primaryLabel: "Play Favorites"
                    )
                    TrackListSection(title: "Любимые треки", subtitle: "\(filteredTracks.count)", tracks: filteredTracks, numbered: true)
                }
            }
            .sheet(item: $playlistEditor) { editor in
                PlaylistTitleSheet(title: editor.title, primaryLabel: "Create") { title in
                    let playlist = store.createPlaylist(title: title)
                    selectedPlaylistID = playlist.id
                    playlistEditor = nil
                } onCancel: {
                    playlistEditor = nil
                }
            }
        }
    }

    private func filteredPlaylists(_ playlists: [LocalPlaylist], query: String) -> [LocalPlaylist] {
        let term = query.searchNormalized
        guard !term.isEmpty else { return playlists }

        let tokens = term.split(separator: " ").map(String.init)
        return playlists.filter { playlist in
            let tracks = store.playlistTracks(playlistID: playlist.id)
            let searchableText = ([playlist.title] + tracks.flatMap { [$0.title, $0.artist, $0.album] })
                .joined(separator: " ")
                .searchNormalized

            return searchableText.contains(term)
                || tokens.allSatisfy { searchableText.contains($0) }
        }
    }
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
                    .background(Color(hex: "#FF4F72"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .background(Color(hex: "#101010"))
    }
}

private struct LocalPlaylistDetailView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var playlistQuery = ""
    @State private var isConfirmingDelete = false
    let playlist: LocalPlaylist
    let tracks: [Track]
    let onBack: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    private var accent: Color {
        tracks.first?.palette.accent ?? store.currentTrack?.palette.accent ?? Color(hex: "#FF4F72")
    }

    private var trackCountLabel: String {
        "\(playlist.trackCount) track\(playlist.trackCount == 1 ? "" : "s")"
    }

    private var filteredTracks: [Track] {
        PlaylistTrackFilter.filteredTracks(tracks, query: playlistQuery)
    }

    private var isFiltering: Bool {
        !playlistQuery.trimmed.isEmpty
    }

    private var actionTracks: [Track] {
        isFiltering ? filteredTracks : tracks
    }

    private var visibleTrackCountLabel: String {
        isFiltering ? "\(filteredTracks.count) of \(tracks.count)" : trackCountLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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
                    InfoPill(symbol: "music.note.list", text: "Playlist")

                    Text(playlist.title)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.58)

                    HStack(spacing: 8) {
                        InfoPill(symbol: "music.note", text: trackCountLabel)
                        InfoPill(symbol: "clock.arrow.circlepath", text: "Local")
                    }

                    LocalPlaylistActionBar(
                        tracks: actionTracks,
                        accent: accent,
                        isFiltered: isFiltering,
                        onRename: onRename,
                        onDelete: {
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

                    if isFiltering {
                        InfoPill(symbol: "line.3.horizontal.decrease.circle", text: visibleTrackCountLabel)
                    }

                    Spacer(minLength: 0)
                }

                if filteredTracks.isEmpty {
                    EmptyPlaylistSearchPanel(accent: accent)
                } else {
                    TrackListSection(
                        title: "Треки",
                        subtitle: visibleTrackCountLabel,
                        tracks: filteredTracks,
                        numbered: true,
                        playlistID: playlist.id
                    )
                }
            }
        }
        .confirmationDialog("Delete playlist?", isPresented: $isConfirmingDelete) {
            Button("Delete Playlist", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct EmptyPlaylistSearchPanel: View {
    let accent: Color

    var body: some View {
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
        .background(Color(hex: "#101010"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LocalPlaylistActionBar: View {
    @EnvironmentObject private var store: PlayerStore
    let tracks: [Track]
    let accent: Color
    let isFiltered: Bool
    let onRename: () -> Void
    let onDelete: () -> Void

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
            }

            Menu {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete Playlist", systemImage: "trash")
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

private struct EmptyPlaylistTracksPanel: View {
    let accent: Color

    var body: some View {
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
        .background(Color(hex: "#101010"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LibraryHeaderView: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var query: String
    @Binding var sortMode: LibrarySortMode
    let totalCount: Int
    let filteredCount: Int
    let onCreatePlaylist: () -> Void

    private var countLabel: String {
        if query.trimmed.isEmpty {
            return "\(totalCount) items · \(sortMode.title)"
        }

        return "\(filteredCount) found · \(sortMode.title)"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Библиотека")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(countLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer(minLength: 0)

            LocalLibrarySearchField(query: $query)
                .frame(maxWidth: 360)

            LibraryCreatePlaylistMenu(onCreatePlaylist: onCreatePlaylist)
            LibrarySortMenu(selection: $sortMode)
        }
        .padding(.top, 18)
    }
}

private struct LibraryCreatePlaylistMenu: View {
    @EnvironmentObject private var store: PlayerStore
    let onCreatePlaylist: () -> Void

    private var accent: Color {
        store.currentTrack?.palette.accent ?? Color(hex: "#FF4F72")
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
                .frame(width: 40, height: 40)
                .background(accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        store.currentTrack?.palette.accent ?? .white
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
            .frame(height: 40)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Sort library")
    }
}

private struct LocalLibrarySearchField: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var query: String
    let placeholder: String
    let clearHelp: String

    init(
        query: Binding<String>,
        placeholder: String = "Search library",
        clearHelp: String = "Clear library search"
    ) {
        _query = query
        self.placeholder = placeholder
        self.clearHelp = clearHelp
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))

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
        .frame(height: 40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((store.currentTrack?.palette.accent ?? .white).opacity(0.18), lineWidth: 1)
        )
    }
}

private struct LibraryCollectionsShelf: View {
    @EnvironmentObject private var store: PlayerStore
    let localPlaylists: [LocalPlaylist]
    let tracks: [Track]
    let savedCollections: [Track]
    let albums: [Track]
    let artists: [Track]
    let onSelectPlaylist: (String) -> Void

    private var collectionCount: Int {
        min(localPlaylists.count, 10) + min(savedCollections.count, 10) + (tracks.isEmpty ? 0 : 1) + min(albums.count, 8) + min(artists.count, 6)
    }

    var body: some View {
        if !tracks.isEmpty || !savedCollections.isEmpty || !localPlaylists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Плейлисты и коллекции", subtitle: "\(collectionCount)")

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(localPlaylists.prefix(10)) { playlist in
                            let playlistTracks = store.playlistTracks(playlistID: playlist.id)
                            let accent = playlistTracks.first?.palette.accent ?? store.currentTrack?.palette.accent ?? .white
                            LibraryCollectionCard(
                                title: playlist.title,
                                subtitle: "\(playlist.trackCount) track\(playlist.trackCount == 1 ? "" : "s")",
                                symbol: "music.note.list",
                                artworkTracks: Array(playlistTracks.prefix(4)),
                                accent: accent
                            ) {
                                onSelectPlaylist(playlist.id)
                            }
                        }

                        if !tracks.isEmpty {
                            LibraryCollectionCard(
                                title: "Любимые треки",
                                subtitle: "\(tracks.count) tracks",
                                symbol: "heart.fill",
                                artworkTracks: Array(tracks.prefix(4)),
                                accent: store.currentTrack?.palette.accent ?? tracks.first?.palette.accent ?? .white
                            ) {
                                store.playAll(tracks)
                            }
                        }

                        ForEach(savedCollections.prefix(10)) { collection in
                            let collectionTracks = savedCollectionTracks(for: collection)
                            LibraryCollectionCard(
                                title: collection.title,
                                subtitle: savedCollectionSubtitle(for: collection, matchingTracks: collectionTracks),
                                symbol: collection.kind == .artist ? "music.mic" : "square.stack.fill",
                                artworkTracks: collectionTracks,
                                accent: collection.palette.accent
                            ) {
                                store.activate(collection)
                            }
                        }

                        ForEach(albums.prefix(8)) { album in
                            let albumTracks = tracks.filter {
                                $0.album.searchNormalized == album.title.searchNormalized
                                    && $0.artist.searchNormalized == album.artist.searchNormalized
                            }
                            LibraryCollectionCard(
                                title: album.title,
                                subtitle: "\(albumTracks.count) tracks",
                                symbol: "square.stack.fill",
                                artworkTracks: albumTracks,
                                accent: album.palette.accent
                            ) {
                                store.playAll(albumTracks)
                            }
                        }

                        ForEach(artists.prefix(6)) { artist in
                            let artistTracks = tracks.filter {
                                $0.artist.searchNormalized == artist.title.searchNormalized
                            }
                            LibraryCollectionCard(
                                title: artist.title,
                                subtitle: "\(artistTracks.count) tracks",
                                symbol: "music.mic",
                                artworkTracks: artistTracks,
                                accent: artist.palette.accent
                            ) {
                                store.playAll(artistTracks)
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
                    LibraryMosaicArtwork(tracks: artworkTracks, size: 156, accent: accent)

                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(accent, in: Circle())
                        .padding(8)
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
            .frame(width: 156, alignment: .leading)
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
                    .fill(accent.opacity(0.22))
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
        .background(Color(hex: "#101010"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
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
        HStack(spacing: 12) {
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
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct NowPlayingHero: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        if let track = store.currentTrack {
            HStack(alignment: .center, spacing: 22) {
                ArtworkTile(track: track, size: 210, cornerRadius: 14)
                    .shadow(color: track.palette.accent.opacity(0.26), radius: 26, x: 0, y: 18)

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
                            .background(track.palette.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
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
                    .background(item.palette.accent, in: Circle())
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(item.palette.accent.opacity(0.22), lineWidth: 1)
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
                        ForEach(tracks.prefix(10)) { track in
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
                            .background(track.palette.accent, in: Circle())
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
                        ForEach(items.prefix(16)) { item in
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
                    ForEach(items.prefix(24)) { item in
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
                            .background(.black.opacity(0.36), in: Circle())
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

                VStack(spacing: 7) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(track: track, index: numbered ? index + 1 : nil, playlistID: playlistID)
                    }
                }
            }
        }
    }
}

private struct TrackRowView: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track
    let index: Int?
    let playlistID: String?

    init(track: Track, index: Int?, playlistID: String? = nil) {
        self.track = track
        self.index = index
        self.playlistID = playlistID
    }

    private var isCurrent: Bool {
        track.isPlayable && store.currentTrack == track
    }

    private var rowBackground: AnyShapeStyle {
        isCurrent
            ? AnyShapeStyle(track.palette.accent.opacity(0.16))
            : AnyShapeStyle(.ultraThinMaterial)
    }

    var body: some View {
        HStack(spacing: 12) {
            if let index {
                Text("\(index)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(width: 24, alignment: .trailing)
            }

            Button {
                store.activate(track)
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
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isCurrent ? track.palette.accent.opacity(0.38) : .white.opacity(0.07), lineWidth: 1)
        )
        .contextMenu {
            Button {
                store.activate(track)
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
        store.localPlaylists.filter { $0.id != excludingPlaylistID }
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

    var body: some View {
        let groups = releaseGroups

        VStack(alignment: .leading, spacing: 24) {
            ArtistHeroView(
                artist: artist,
                tracks: tracks,
                releases: releases,
                studioAlbums: groups.studioAlbums,
                isLoading: isLoading
            )

            if tracks.isEmpty && releases.isEmpty && isLoading {
                CatalogLoadingView(title: "Loading artist", subtitle: "Fetching releases and popular tracks")
            } else if tracks.isEmpty && releases.isEmpty {
                EmptySearchView()
            } else {
                EntityShelf(title: "Studio Albums", items: groups.studioAlbums, cardSize: 214, roundArtists: false)
                EntityShelf(title: "Reissues & Live", items: groups.otherReleases, cardSize: 178, roundArtists: false)
                TrackListSection(title: "Popular Tracks", subtitle: "\(tracks.count) tracks", tracks: tracks, numbered: true)
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
        HStack(alignment: .center, spacing: 22) {
            ArtworkTile(track: artist, size: 158, cornerRadius: 79)
                .shadow(color: artist.palette.accent.opacity(0.26), radius: 26, x: 0, y: 18)

            VStack(alignment: .leading, spacing: 14) {
                MediaKindBadge(kind: artist.kind)

                Text(artist.title)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                HStack(spacing: 8) {
                    InfoPill(symbol: "person.2.fill", text: listenersLabel)
                    InfoPill(symbol: "square.stack.fill", text: albumLabel)
                    InfoPill(symbol: "music.note.list", text: "\(tracks.count) tracks")
                }

                if let latestRelease {
                    Text("Latest: \(latestRelease.title)\(latestRelease.releaseDate?.releaseYear.map { " · \($0)" } ?? "")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                CollectionActionCluster(
                    tracks: tracks,
                    accent: artist.palette.accent,
                    primaryLabel: "Play Artist"
                )

                SavedCollectionButton(item: artist, size: 38)
            }
            .frame(maxWidth: 360, alignment: .trailing)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
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
                CatalogLoadingView(title: "Loading album", subtitle: "Fetching the full tracklist")
            } else if tracks.isEmpty {
                EmptySearchView()
            } else {
                TrackListSection(title: "Tracks", subtitle: trackSubtitle, tracks: tracks, numbered: true)
            }
        }
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
        if isLoading && tracks.isEmpty {
            return "Loading tracks"
        }
        let expected = album.trackCount ?? tracks.count
        return "\(expected) track\(expected == 1 ? "" : "s")"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            ArtworkTile(track: album, size: 190, cornerRadius: 14)
                .shadow(color: album.palette.accent.opacity(0.26), radius: 26, x: 0, y: 18)

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
                    accent: album.palette.accent,
                    primaryLabel: "Play Album"
                )

                SavedCollectionButton(item: album, size: 38)
            }
            .frame(maxWidth: 360, alignment: .trailing)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct MiniPlayerBar: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedPanel: NowPlayingPanelMode
    @Binding var isShowingNowPlaying: Bool

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
        if let track = store.currentTrack {
            VStack(spacing: 10) {
                ProgressStack(track: track)

                HStack(spacing: 14) {
                    Button {
                        isShowingNowPlaying = true
                    } label: {
                        HStack(spacing: 10) {
                            ArtworkTile(track: track, size: 52, cornerRadius: 9)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.52))
                                .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 260, alignment: .leading)
                    .help("Now playing")

                    FavoriteButton(track: track, size: 34)

                    Spacer()

                    PlaybackControlsCompact(playSymbol: playSymbol)

                    Spacer()

                    HStack(spacing: 10) {
                        Button {
                            selectedPanel = .lyrics
                            isShowingNowPlaying = true
                        } label: {
                            PlayerPanelButtonLabel(
                                symbol: "text.quote",
                                active: isShowingNowPlaying && selectedPanel == .lyrics
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Lyrics")

                        Button {
                            selectedPanel = .queue
                            isShowingNowPlaying = true
                        } label: {
                            PlayerPanelButtonLabel(
                                symbol: "text.line.last.and.arrowtriangle.forward",
                                active: isShowingNowPlaying && selectedPanel == .queue
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Queue")

                        VolumeControl()
                    }
                    .frame(width: 300, alignment: .trailing)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

private struct PlayerPanelButtonLabel: View {
    @EnvironmentObject private var store: PlayerStore
    let symbol: String
    let active: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(active ? .black : .white.opacity(0.74))
            .frame(width: 32, height: 32)
            .background(
                active
                    ? (store.currentTrack?.palette.accent ?? .white)
                    : .white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
    }
}

private struct FavoriteButton: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track
    let size: CGFloat

    var body: some View {
        Button {
            store.toggleLike(track)
        } label: {
            Image(systemName: store.isLiked(track) ? "heart.fill" : "heart")
                .font(.system(size: size > 32 ? 15 : 12, weight: .bold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.isLiked(track) ? track.palette.accent : .white.opacity(0.62))
        .help(store.isLiked(track) ? "Remove from favorites" : "Add to favorites")
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
                isSaved ? item.palette.accent : Color(hex: "#1C1C1E"),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSaved ? item.palette.accent.opacity(0.38) : .white.opacity(0.1), lineWidth: 1)
            )
            .help(isSaved ? "Remove from Library" : "Save to Library")
        }
    }
}

private struct VolumeControl: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        HStack(spacing: 7) {
            Button {
                store.toggleMute()
            } label: {
                Image(systemName: store.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.58))
            .help(store.volume == 0 ? "Unmute" : "Mute")

            Slider(
                value: Binding(
                    get: { store.volume },
                    set: { store.setVolume($0) }
                ),
                in: 0...1
            )
            .tint(store.currentTrack?.palette.accent ?? .white)
            .frame(width: 104)
        }
        .help("Volume")
    }
}

private struct PlaybackControlsCompact: View {
    @EnvironmentObject private var store: PlayerStore
    let playSymbol: String

    var body: some View {
        HStack(spacing: 12) {
            PlayerModeButton(
                symbol: "shuffle",
                active: store.isShuffled,
                helpText: store.isShuffled ? "Shuffle on" : "Shuffle"
            ) {
                store.toggleShuffle()
            }

            PlayerIconButton(symbol: "backward.fill", size: 34, primary: false) {
                store.previous()
            }
            .help("Previous")

            PlayerIconButton(symbol: playSymbol, size: 44, primary: true) {
                store.togglePlayPause()
            }
            .help("Play/Pause")

            PlayerIconButton(symbol: "forward.fill", size: 34, primary: false) {
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

private struct PlayerModeButton: View {
    @EnvironmentObject private var store: PlayerStore
    let symbol: String
    let active: Bool
    let helpText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(active ? .black : .white.opacity(0.58))
                .frame(width: 30, height: 30)
                .background(
                    active
                        ? (store.currentTrack?.palette.accent ?? .white)
                        : .white.opacity(0.07),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

private struct PlayerIconButton: View {
    @EnvironmentObject private var store: PlayerStore
    let symbol: String
    let size: CGFloat
    let primary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: primary ? 18 : 13, weight: .bold))
                .foregroundStyle(primary ? .black : .white.opacity(0.82))
                .frame(width: size, height: size)
                .background(
                    primary
                        ? (store.currentTrack?.palette.accent ?? .white)
                        : .white.opacity(0.1),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct NowPlayingPanel: View {
    @EnvironmentObject private var store: PlayerStore
    @Binding var selectedPanel: NowPlayingPanelMode

    var body: some View {
        if let track = store.currentTrack {
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 18) {
                    ArtworkTile(track: track, size: 360, cornerRadius: 20)
                        .shadow(color: track.palette.accent.opacity(0.3), radius: 34, x: 0, y: 22)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(track.title)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)

                            Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)
                        }

                        Spacer()
                        FavoriteButton(track: track, size: 42)
                    }

                    ProgressStack(track: track)
                    PlaybackControlsView()

                    Spacer(minLength: 0)
                }
                .frame(width: 390)

                VStack(alignment: .leading, spacing: 16) {
                    NowPlayingPanelPicker(selectedPanel: $selectedPanel)

                    switch selectedPanel {
                    case .lyrics:
                        LyricsReaderContentView(track: track, isExpanded: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    case .queue:
                        QueuePanelView()
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(26)
            .foregroundStyle(.white)
            .background {
                ZStack {
                    track.palette.base.opacity(0.5)
                    LinearGradient(
                        colors: [track.palette.accent.opacity(0.18), .black.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Rectangle().fill(.regularMaterial)
                }
                .ignoresSafeArea()
            }
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

private struct NowPlayingPanelPicker: View {
    @Binding var selectedPanel: NowPlayingPanelMode

    var body: some View {
        Picker("Now playing panel", selection: $selectedPanel) {
            ForEach(NowPlayingPanelMode.allCases) { panel in
                Label(panel.rawValue, systemImage: panel.symbol)
                    .tag(panel)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
    }
}

private struct LyricsReaderContentView: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track
    let isExpanded: Bool

    private var activeLineIndex: Int? {
        guard case .loaded(let lyrics) = store.lyricsState else { return nil }
        return lyrics.activeLineIndex(at: store.progress)
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
                            accent: track.palette.accent,
                            isExpanded: isExpanded
                        )
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
                withAnimation(.snappy(duration: 0.22)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func plainLyrics(_ lyrics: TrackLyrics) -> some View {
        ScrollView(showsIndicators: isExpanded) {
            Text(lyrics.text)
                .font(.system(size: isExpanded ? 19 : 14, weight: .semibold, design: .rounded))
                .lineSpacing(isExpanded ? 11 : 7)
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
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

    var body: some View {
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
            .textSelection(.enabled)
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
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
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
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct QueuePanelStateView: View {
    let title: String
    let symbol: String

    var body: some View {
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
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private var progressFraction: Double {
        guard track.duration > 0 else { return 0 }
        return min(max(store.progress / track.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 7) {
            Slider(
                value: Binding(
                    get: { progressFraction },
                    set: { store.seek(to: $0) }
                ),
                in: 0...1
            )
            .tint(track.palette.accent)

            HStack {
                Text(store.progress.playbackLabel)
                Spacer()
                Text(track.durationLabel)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.47))
        }
    }
}

private struct SessionSettingsSheet: View {
    @EnvironmentObject private var store: PlayerStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTokenFocused: Bool
    @State private var sessionToken = ""

    private var canSubmit: Bool {
        DeemixAPISessionSecret.normalizedARL(sessionToken) != nil
            && !store.isConfiguringBackendSession
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((store.currentTrack?.palette.accent ?? .white).opacity(0.92))
                    Image(systemName: "key.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Stream Session")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("Deezer ARL")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
                .help("Close")
            }

            ProviderStatusCard()

            VStack(alignment: .leading, spacing: 9) {
                Text("Session Token")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.74))

                SecureField("Paste ARL", text: $sessionToken)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .focused($isTokenFocused)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(isTokenFocused ? 0.28 : 0.1), lineWidth: 1)
                    )
                    .onSubmit(submit)
            }

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
                        (store.currentTrack?.palette.accent ?? .white).opacity(canSubmit ? 1 : 0.5),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .help("Connect ARL")

                Button {
                    store.connectProvider()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Use Saved ARL")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 132)
                    .frame(height: 38)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Use saved local ARL")
            }

            if let errorMessage = store.errorMessage?.nonEmpty {
                HStack(spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                }
                .foregroundStyle(.white.opacity(0.72))
                .padding(10)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .frame(width: 440)
        .foregroundStyle(.white)
        .background(.regularMaterial)
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

private struct ProviderStatusCard: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProviderStatusView()
                Spacer()
                Text(store.providerStatus.canPlayCatalogContent ? "Connected" : "Offline")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(store.providerStatus.canPlayCatalogContent ? .green : .white.opacity(0.45))
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

        return store.providerStatus.authorization == .authorized ? .green : .white.opacity(0.35)
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
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))

            Button {
                store.connectProvider()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: store.providerStatus.canPlayCatalogContent ? "arrow.clockwise" : "network")
                    Text(actionTitle)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background((store.currentTrack?.palette.accent ?? .white), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(actionTitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 58)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PlaybackErrorBanner: View {
    let message: String

    var body: some View {
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct CatalogLoadingView: View {
    let title: String
    let subtitle: String

    var body: some View {
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
            Text("No matches found")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    var body: some View {
        ZStack {
            fallbackArtwork

            if let artworkURL {
                AsyncImage(url: artworkURL, transaction: Transaction(animation: .easeInOut(duration: 0.18))) { phase in
                    switch phase {
                    case .empty:
                        fallbackArtwork
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackArtwork
                    @unknown default:
                        fallbackArtwork
                    }
                }
            }

            LinearGradient(
                colors: [
                    .black.opacity(0),
                    .black.opacity(0.26)
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [
                    track.palette.accent.opacity(0.86),
                    track.palette.mid,
                    track.palette.base
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            AngularGradient(
                colors: [
                    .white.opacity(0.24),
                    .clear,
                    track.palette.accent.opacity(0.36),
                    .clear,
                    .white.opacity(0.18)
                ],
                center: .center
            )
            .blendMode(.screen)

            Image(systemName: track.kind.systemImage)
                .font(.system(size: size * 0.24, weight: .semibold))
                .foregroundStyle(track.palette.ink.opacity(0.82))

            VStack(spacing: max(size * 0.05, 3)) {
                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.055 : 0.025))
                        .frame(height: max(size * 0.008, 1))
                }
            }
            .padding(size * 0.12)
        }
    }

    private var artworkURL: URL? {
        guard let value = track.artworkURL?.nonEmpty else { return nil }
        return URL(string: value)
    }
}
