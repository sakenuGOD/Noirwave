import XCTest
@testable import Noirwave

final class DeemixAPITrackMapperTests: XCTestCase {
    func testMapsDeemixSearchTrackIntoFullDownloadTrack() throws {
        let payload = DeemixAPITrackPayload(
            id: 313_555_6,
            readable: true,
            title: "Around the World",
            titleShort: nil,
            titleVersion: nil,
            link: "https://www.deezer.com/track/3135556",
            duration: 429,
            rank: nil,
            explicitLyrics: false,
            preview: "https://cdns-preview.dzcdn.net/stream/c-test-preview.mp3",
            artist: DeemixAPIArtistPayload(id: 27, name: "Daft Punk", link: nil, picture: nil, pictureSmall: nil, pictureMedium: nil),
            album: DeemixAPIAlbumPayload(
                id: 302_127,
                title: "Homework",
                link: nil,
                cover: "https://e-cdns-images.dzcdn.net/images/cover/homework/500x500-000000-80-0-0.jpg",
                coverSmall: nil,
                coverMedium: "https://e-cdns-images.dzcdn.net/images/cover/homework/250x250-000000-80-0-0.jpg",
                artist: nil
            )
        )

        let track = try DeemixAPITrackMapper.map(payload, fallbackIndex: 0)

        XCTAssertEqual(track.title, "Around the World")
        XCTAssertEqual(track.artist, "Daft Punk")
        XCTAssertEqual(track.album, "Homework")
        XCTAssertEqual(track.duration, 429)
        XCTAssertEqual(track.catalogID, "https://www.deezer.com/track/3135556")
        XCTAssertEqual(track.previewURL, "https://cdns-preview.dzcdn.net/stream/c-test-preview.mp3")
        XCTAssertEqual(track.kind, .track)
        XCTAssertEqual(track.artworkURL, "https://e-cdns-images.dzcdn.net/images/cover/homework/250x250-000000-80-0-0.jpg")
        XCTAssertEqual(track.artistCatalogID, "https://www.deezer.com/artist/27")
        XCTAssertEqual(track.albumCatalogID, "https://www.deezer.com/album/302127")
    }

    func testRejectsTrackWithoutDownloadURL() {
        let payload = DeemixAPITrackPayload(
            id: 1,
            readable: true,
            title: "No Preview",
            titleShort: nil,
            titleVersion: nil,
            link: nil,
            duration: 180,
            rank: nil,
            explicitLyrics: false,
            preview: "https://cdns-preview.dzcdn.net/stream/c-test-preview.mp3",
            artist: nil,
            album: nil
        )

        XCTAssertThrowsError(try DeemixAPITrackMapper.map(payload, fallbackIndex: 0))
    }

    func testResolvesDownloadedFilePathFromQueueItem() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("Daft Punk - Around the World.mp3")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("audio".utf8))

        let item = DeemixAPIQueueItem(
            uuid: "track_3135556_1",
            status: "completed",
            size: 1,
            downloaded: 1,
            failed: 0,
            progress: 100,
            files: [
                DeemixAPIQueueFile(path: fileURL.path, filename: "Daft Punk - Around the World.mp3")
            ],
            extrasPath: tempDirectory.path,
            errors: []
        )

        XCTAssertEqual(DeemixAPIDownloadedFileResolver.fileURL(from: item), fileURL)
    }

    func testResolvesDownloadedFileFromExtrasPathAndFilename() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("Nirvana - Come As You Are.mp3")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("audio".utf8))

        let item = DeemixAPIQueueItem(
            uuid: "track_13791932_1",
            status: "completed",
            size: 1,
            downloaded: 1,
            failed: 0,
            progress: 100,
            files: [
                DeemixAPIQueueFile(path: nil, filename: "Nirvana - Come As You Are.mp3")
            ],
            extrasPath: tempDirectory.path,
            errors: []
        )

        XCTAssertEqual(DeemixAPIDownloadedFileResolver.fileURL(from: item), fileURL)
    }

    func testMapsNotLoggedInQueueFailureToBackendSessionMessage() {
        let response = DeemixAPIAddToQueueResponse(
            result: false,
            errid: "NotLoggedIn",
            data: nil
        )

        XCTAssertEqual(
            DeemixAPIPlaybackFailureMapper.error(from: response).localizedDescription,
            "Backend session inactive."
        )
    }

    func testDoesNotUsePreviewFallbackWhenBackendSessionIsInactive() {
        let error = MusicProviderError.providerNotReady("Backend session inactive.")

        XCTAssertFalse(DeemixAPIPlaybackURLResolver.shouldUsePreviewFallback(after: error))
    }

    func testUsesPreviewFallbackWhenPreferredBitrateIsUnavailable() {
        let error = MusicProviderError.providerNotReady("The current Deezer session cannot stream 320 kbps.")

        XCTAssertTrue(DeemixAPIPlaybackURLResolver.shouldUsePreviewFallback(after: error))
    }

    func testUsesPreviewFallbackWhenBackendNetworkTimesOut() {
        let error = MusicProviderError.providerNotReady("Deezer network request timed out. Try again in a moment.")

        XCTAssertTrue(DeemixAPIPlaybackURLResolver.shouldUsePreviewFallback(after: error))
    }

    func testRequestsHighQualityFullTrackBeforeFreeFallbackBitrate() {
        XCTAssertEqual(DeemixAPIBitrate.fullTrackPlaybackPreferences, [3])
        XCTAssertEqual(DeemixAPIBitrate.displayLabel(for: 3), "320 kbps")
        XCTAssertEqual(DeemixAPIBitrate.displayLabel(for: 1), "128 kbps")
    }

    @MainActor
    func testBootstrapPreparesVisiblePlaybackContextForFastSkipping() async throws {
        let tracks = (1...12).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        try await Task.sleep(for: .milliseconds(80))

        let preparedIDs = Array(provider.preparedBatches.flatMap { $0 }.prefix(11))
        let expectedIDs = tracks.prefix(11).map(\.id)
        XCTAssertEqual(preparedIDs, expectedIDs)
    }

    @MainActor
    func testBootstrapDoesNotSelectFeaturedTrackAsCurrentPlayback() async throws {
        let tracks = (1...3).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        await store.bootstrap()

        XCTAssertNil(store.currentTrack)
        XCTAssertTrue(store.queue.isEmpty)
        XCTAssertEqual(store.playbackState, .idle)
        XCTAssertEqual(store.visibleTracks, tracks)
    }

    @MainActor
    func testSearchDebouncesRemoteRequestAndKeepsTypingLocal() async throws {
        let provider = SearchCacheRecordingProvider(
            featured: [Self.makePlaybackTrack(1, title: "Ambient Seed")],
            resultsByQuery: [
                "ambient": [Self.makePlaybackTrack(2, title: "Ambient Result")]
            ],
            searchDelay: .milliseconds(120)
        )
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.updateSearchQuery("ambient")

        try await Task.sleep(for: .milliseconds(10))

        XCTAssertEqual(store.searchQuery, "ambient")
        XCTAssertFalse(store.isSearching)
        XCTAssertTrue(provider.recordedQueries.isEmpty)
        XCTAssertEqual(store.visibleTracks.map(\.title), ["Ambient Seed"])

        try await Task.sleep(for: .milliseconds(180))

        XCTAssertTrue(provider.recordedQueries.isEmpty)
        XCTAssertEqual(store.visibleTracks.map(\.title), ["Ambient Seed"])
        XCTAssertFalse(store.isSearching)

        try await Task.sleep(for: .milliseconds(110))

        XCTAssertEqual(provider.recordedQueries.map(\.query), ["ambient"])
        XCTAssertEqual(store.visibleTracks.map(\.title), ["Ambient Seed"])
        XCTAssertTrue(store.isSearching)

        try await Task.sleep(for: .milliseconds(160))

        XCTAssertEqual(provider.recordedQueries.map(\.query), ["ambient"])
        XCTAssertEqual(store.visibleTracks.map(\.title), ["Ambient Result"])
    }

    @MainActor
    func testSearchRetriesKeyboardLayoutVariantWhenOriginalReturnsEmpty() async throws {
        let result = Self.makePlaybackTrack(2, title: "Especially for You", artist: "Manchild")
        let provider = SearchCacheRecordingProvider(
            featured: [],
            resultsByQuery: ["manchild": [result]],
            searchDelay: .milliseconds(20)
        )
        let store = PlayerStore(provider: provider)

        store.updateSearchQuery("ьanchild")
        try await Task.sleep(for: .milliseconds(360))

        XCTAssertEqual(provider.recordedQueries.map(\.query), ["ьanchild", "manchild"])
        XCTAssertEqual(store.visibleTracks, [result])
        XCTAssertFalse(store.isSearching)
    }

    @MainActor
    func testSearchUsesCachedResultsWithoutRepeatingRemoteQuery() async throws {
        let cachedResult = Self.makePlaybackTrack(2, title: "Cached Search Result")
        let provider = SearchCacheRecordingProvider(
            featured: [Self.makePlaybackTrack(1, title: "Seed")],
            resultsByQuery: ["cache": [cachedResult]],
            searchDelay: .milliseconds(20)
        )
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.updateSearchQuery("cache")
        try await Task.sleep(for: .milliseconds(420))
        XCTAssertEqual(store.visibleTracks, [cachedResult])
        XCTAssertEqual(provider.recordedQueries.map(\.query), ["cache"])

        store.updateSearchQuery("")
        try await Task.sleep(for: .milliseconds(40))
        store.updateSearchQuery("cache")
        try await Task.sleep(for: .milliseconds(420))

        XCTAssertEqual(store.visibleTracks, [cachedResult])
        XCTAssertEqual(provider.recordedQueries.map(\.query), ["cache"])
    }

    @MainActor
    func testSlowNetworkSearchKeepsShellPlaybackAndPreviousResultsUsable() async throws {
        let seed = Self.makePlaybackTrack(1, title: "Slow Seed")
        let playingTrack = Self.makePlaybackTrack(2, title: "Playing Track")
        let delayedResult = Self.makePlaybackTrack(3, title: "Delayed Result")
        let provider = SearchCacheRecordingProvider(
            featured: [seed],
            resultsByQuery: ["slow": [delayedResult]],
            searchDelay: .milliseconds(3_500)
        )
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.play(playingTrack)
        try await Task.sleep(for: .milliseconds(80))

        store.updateSearchQuery("slow")
        try await Task.sleep(for: .milliseconds(360))

        XCTAssertEqual(store.searchQuery, "slow")
        XCTAssertTrue(store.isSearching)
        XCTAssertEqual(store.visibleTracks, [seed])
        XCTAssertEqual(store.currentTrack, playingTrack)
        XCTAssertEqual(store.playbackState, .playing)

        store.togglePlayPause()
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(store.playbackState, .paused)
        XCTAssertEqual(store.visibleTracks, [seed])
        XCTAssertEqual(provider.recordedQueries.map(\.query), ["slow"])
        XCTAssertEqual(provider.playedIDs, [playingTrack.id])

        try await Task.sleep(for: .milliseconds(4_000))

        XCTAssertFalse(store.isSearching)
        XCTAssertEqual(store.visibleTracks, [delayedResult])
        XCTAssertEqual(store.currentTrack, playingTrack)
    }

    @MainActor
    func testActivatingCurrentSearchTrackTogglesPlaybackInsteadOfRestarting() async throws {
        let result = Self.makePlaybackTrack(7, title: "Search Playback")
        let provider = SearchCacheRecordingProvider(
            featured: [],
            resultsByQuery: ["play": [result]],
            searchDelay: .milliseconds(10)
        )
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.updateSearchQuery("play")
        try await Task.sleep(for: .milliseconds(380))

        store.activate(result, in: store.visibleTracks)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.currentTrack, result)
        XCTAssertEqual(store.playbackState, .playing)
        XCTAssertEqual(provider.playedIDs, [result.id])

        store.activate(result, in: store.visibleTracks)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.currentTrack, result)
        XCTAssertEqual(store.playbackState, .paused)
        XCTAssertEqual(provider.playedIDs, [result.id])
    }

    @MainActor
    func testActivatingSearchResultUsesVisibleResultsForPlaybackContext() async throws {
        let results = [
            Self.makePlaybackTrack(10, title: "Search One"),
            Self.makePlaybackTrack(11, title: "Search Two"),
            Self.makePlaybackTrack(12, title: "Search Three")
        ]
        let provider = SearchCacheRecordingProvider(
            featured: [],
            resultsByQuery: ["queue": results],
            searchDelay: .milliseconds(10)
        )
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.updateSearchQuery("queue")
        try await Task.sleep(for: .milliseconds(380))

        store.activate(results[1], in: store.visibleTracks)
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(store.currentTrack, results[1])
        XCTAssertEqual(store.playbackState, .playing)
        XCTAssertEqual(store.queue, [results[2]])
        XCTAssertEqual(provider.playedIDs, [results[1].id])
    }

    @MainActor
    func testLyricsSeekUpdatesProgressAndForwardsToProvider() async throws {
        let track = Self.makePlaybackTrack(3)
        let provider = SearchCacheRecordingProvider(featured: [track], resultsByQuery: [:], searchDelay: .milliseconds(10))
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.play(track)
        try await Task.sleep(for: .milliseconds(80))

        store.seek(to: 42)
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(store.progress, 42, accuracy: 0.25)
        XCTAssertEqual(provider.seekTimes, [42])
    }

    @MainActor
    func testProgressSliderSeekUsesFractionOfCurrentTrackDuration() async throws {
        let track = Self.makePlaybackTrack(4)
        let provider = SearchCacheRecordingProvider(featured: [track], resultsByQuery: [:], searchDelay: .milliseconds(10))
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.play(track)
        try await Task.sleep(for: .milliseconds(80))

        store.seek(toFraction: 0.25)
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(store.progress, 45, accuracy: 0.25)
        XCTAssertEqual(provider.seekTimes, [45])
    }

    @MainActor
    func testLyricsCacheReusesLoadedLyricsForRepeatedPlayback() async throws {
        let track = Self.makePlaybackTrack(41, title: "Cached Lyrics")
        let otherTrack = Self.makePlaybackTrack(42, title: "Other Track")
        let lyrics = TrackLyrics(
            text: "cached line",
            lines: [],
            copyright: nil,
            writers: nil
        )
        let provider = LyricsCacheRecordingProvider(lyricsByTrackID: [track.id: lyrics])
        let store = PlayerStore(provider: provider)

        store.play(track)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(store.lyricsState, .loaded(lyrics))
        XCTAssertEqual(provider.lyricsRequests, [track.id])

        store.play(otherTrack)
        store.play(track)
        XCTAssertEqual(store.lyricsState, .loaded(lyrics))

        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(provider.lyricsRequests.filter { $0 == track.id }.count, 1)
    }

    func testMiniPlayerVisualStyleKeepsGlassReadable() {
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.materialTintOpacity, 0.1)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.legacyDimOpacity, 0.1)
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.inactiveControlOpacity, 0.62)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.progressTrackOpacity, 0.18)
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.progressHeight, 0.75)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.progressHeight, 1.0)
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.progressHoverHeight, MiniPlayerVisualStyle.progressHeight * 4)
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.progressHitHeight, 24)
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.primaryControlStrokeOpacity, 0.30)
    }

    func testSidebarVisualStyleUsesControlledNativePalette() {
        XCTAssertGreaterThanOrEqual(SidebarVisualStyle.materialDimOpacity, LiquidGlassPanelStyle.dimOpacity)
        XCTAssertLessThanOrEqual(SidebarVisualStyle.activeAccentOpacity, 0.8)
        XCTAssertLessThanOrEqual(SidebarVisualStyle.activeAccentFillOpacity, 0.05)
        XCTAssertGreaterThanOrEqual(SidebarVisualStyle.inactiveTextOpacity, 0.7)
        XCTAssertGreaterThanOrEqual(SidebarVisualStyle.inactiveIconOpacity, 0.62)
        XCTAssertLessThanOrEqual(SidebarVisualStyle.searchRestFillOpacity, 0.065)
        XCTAssertLessThanOrEqual(SidebarVisualStyle.activeStrokeOpacity, 0.12)
    }

    func testSidePanelsShareMiniPlayerLiquidGlassLanguage() {
        XCTAssertEqual(SidebarVisualStyle.panelMaterial, .sidebar)
        XCTAssertEqual(NowPlayingPanelVisualStyle.panelMaterial, LiquidGlassPanelStyle.material)
        XCTAssertGreaterThanOrEqual(LiquidGlassPanelStyle.dimOpacity, MiniPlayerVisualStyle.legacyDimOpacity + 0.015)
        XCTAssertLessThanOrEqual(LiquidGlassPanelStyle.dimOpacity, 0.03)
        XCTAssertLessThanOrEqual(LiquidGlassPanelStyle.materialOpacity, 0.82)
        XCTAssertGreaterThanOrEqual(LiquidGlassPanelStyle.materialOpacity, 0.70)
        XCTAssertEqual(LiquidGlassPanelStyle.borderOpacity, 0.18, accuracy: 0.001)
        XCTAssertEqual(LiquidGlassPanelStyle.topHighlightOpacity, 0.24, accuracy: 0.001)
        XCTAssertLessThanOrEqual(LiquidGlassPanelStyle.innerHighlightOpacity, 0.055)
        XCTAssertLessThanOrEqual(LiquidGlassPanelStyle.diagonalHighlightOpacity, 0.018)
        XCTAssertEqual(LiquidGlassPanelStyle.mintGlowOpacity, 0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(SidebarVisualStyle.activeAccentFillOpacity, 0.05)
        XCTAssertLessThanOrEqual(NowPlayingPanelVisualStyle.innerCardFillOpacity, 0.08)
    }

    func testSidebarUsesNativeMaterialWithoutHeavyBlackFill() {
        XCTAssertGreaterThan(SidebarVisualStyle.panelAppearance.materialOpacity, LiquidGlassPanelStyle.appearance.materialOpacity)
        XCTAssertGreaterThan(SidebarVisualStyle.panelAppearance.dimOpacity, LiquidGlassPanelStyle.appearance.dimOpacity)
        XCTAssertGreaterThanOrEqual(SidebarVisualStyle.panelAppearance.materialOpacity, 0.80)
        XCTAssertLessThanOrEqual(SidebarVisualStyle.panelAppearance.dimOpacity, 0.025)

        XCTAssertGreaterThan(NowPlayingPanelVisualStyle.panelAppearance.materialOpacity, LiquidGlassPanelStyle.appearance.materialOpacity)
        XCTAssertGreaterThan(NowPlayingPanelVisualStyle.panelAppearance.dimOpacity, LiquidGlassPanelStyle.appearance.dimOpacity)
        XCTAssertGreaterThanOrEqual(NowPlayingPanelVisualStyle.panelAppearance.materialOpacity, 0.76)
        XCTAssertLessThanOrEqual(NowPlayingPanelVisualStyle.panelAppearance.dimOpacity, 0.03)
        XCTAssertGreaterThanOrEqual(NowPlayingPanelVisualStyle.panelAppearance.shadowOpacity, SidebarVisualStyle.panelAppearance.shadowOpacity)
    }

    func testSidebarPlaylistPreviewBuilderUsesOnlyRealLocalPlaylists() {
        let localPlaylist = LocalPlaylist(
            id: "dream-pop",
            title: "Dream Pop",
            tracks: [Self.makeLibraryTrack(1, title: "Cherry-Coloured Funk", artist: "Cocteau Twins", album: "Heaven or Las Vegas")]
        )

        let items = SidebarPlaylistPreviewBuilder.visibleItems(
            localPlaylists: [localPlaylist],
            isExpanded: false,
            tracksForPlaylist: { $0.orderedTracks(preferredTracks: []) }
        )

        XCTAssertEqual(items.map(\.id), ["playlist.dream-pop"])
        XCTAssertEqual(items.first?.title, "Dream Pop")
        XCTAssertEqual(items.first?.subtitle, "1 track")
        XCTAssertEqual(items.first?.symbol, "music.note.list")
        XCTAssertEqual(items.first?.selection, .localPlaylist("dream-pop"))
        XCTAssertFalse(items.map(\.id).contains("liked.songs"))
        XCTAssertFalse(items.map(\.id).contains("discovery.mix"))
        XCTAssertTrue(items.allSatisfy { !$0.id.hasPrefix("album.") && !$0.id.hasPrefix("artist.") })

        let emptyItems = SidebarPlaylistPreviewBuilder.visibleItems(
            localPlaylists: [],
            isExpanded: false,
            tracksForPlaylist: { _ in [] }
        )
        XCTAssertTrue(emptyItems.isEmpty)
    }

    @MainActor
    func testCancelledSearchDoesNotSurfaceProviderError() async throws {
        let provider = CancelledSearchProvider()
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.updateSearchQuery("first")
        try await Task.sleep(for: .milliseconds(360))
        store.updateSearchQuery("second")
        try await Task.sleep(for: .milliseconds(700))

        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.visibleTracks.map(\.title), ["Track 1"])
    }

    @MainActor
    func testCatalogDrillKeepsSearchTextAndDoesNotRunSmartSearch() async throws {
        let detailTrack = Self.makePlaybackTrack(1)
        let provider = CatalogDrillRecordingProvider(detailItems: [detailTrack])
        let store = PlayerStore(provider: provider)
        let artist = Track(
            id: "deemix-artist.415",
            title: "Nirvana",
            artist: "Nirvana",
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/415",
            previewURL: nil,
            kind: .artist,
            fanCount: 10_001_682,
            albumCount: 25
        )

        store.updateSearchQuery("nirvana")
        store.activate(artist)

        XCTAssertEqual(store.searchQuery, "nirvana")
        XCTAssertEqual(store.catalogContext, artist)
        XCTAssertTrue(store.visibleTracks.allSatisfy { $0.artist.searchNormalized == "nirvana" })
        XCTAssertTrue(store.isSearching)

        try await Task.sleep(for: .milliseconds(240))

        XCTAssertEqual(provider.searchCalls, 0)
        XCTAssertEqual(provider.catalogItemsCalls, 1)
        XCTAssertEqual(store.catalogContext, artist)
        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)
    }

    @MainActor
    func testAlbumSearchResultOpensAlbumDetailThroughSharedCatalogNavigation() async throws {
        let detailTrack = Self.makePlaybackTrack(2, title: "Lithium", artist: "Nirvana", album: "Nevermind")
        let provider = CatalogDrillRecordingProvider(detailItems: [detailTrack])
        let store = PlayerStore(provider: provider)
        let album = Self.makeAlbum(
            id: "1262014",
            title: "Nevermind",
            trackCount: 13,
            releaseDate: "1991-09-26",
            recordType: "album"
        )

        store.updateSearchQuery("nevermind")
        store.activate(album)

        XCTAssertEqual(store.searchQuery, "nevermind")
        XCTAssertEqual(store.catalogContext, album)
        XCTAssertTrue(store.visibleTracks.isEmpty)
        XCTAssertTrue(store.isSearching)

        try await Task.sleep(for: .milliseconds(240))

        XCTAssertEqual(provider.searchCalls, 0)
        XCTAssertEqual(provider.catalogItemsCalls, 1)
        XCTAssertEqual(store.catalogContext, album)
        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)
    }

    @MainActor
    func testCatalogDetailCacheReusesLoadedItemsWithoutProviderRoundTrip() async throws {
        let artist = Self.makeArtist(id: "415", title: "Nirvana", albumCount: 25)
        let detailTrack = Self.makePlaybackTrack(2, title: "Lithium", artist: "Nirvana", album: "Nevermind")
        let provider = CatalogDrillRecordingProvider(featuredItems: [artist], detailItems: [detailTrack])
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.activate(artist)
        try await Task.sleep(for: .milliseconds(180))

        XCTAssertEqual(provider.catalogItemsCalls, 1)
        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)

        store.leaveCatalogContext()
        store.activate(artist)

        XCTAssertEqual(store.catalogContext, artist)
        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)

        try await Task.sleep(for: .milliseconds(180))
        XCTAssertEqual(provider.catalogItemsCalls, 1)
    }

    @MainActor
    func testAlbumDrillDoesNotStartDuplicateFetchWhileTracklistIsLoading() async throws {
        let album = Self.makeAlbum(id: "1262014", title: "Nevermind", trackCount: 13, releaseDate: "1991-09-26", recordType: "album")
        let detailTrack = Self.makePlaybackTrack(2, title: "Lithium", artist: "Nirvana", album: "Nevermind")
        let provider = CatalogDrillRecordingProvider(detailItems: [detailTrack])
        let store = PlayerStore(provider: provider)

        store.activate(album)
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(provider.catalogItemsCalls, 1)

        store.activate(album)
        try await Task.sleep(for: .milliseconds(240))

        XCTAssertEqual(provider.catalogItemsCalls, 1)
        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)
    }

    @MainActor
    func testAlbumDrillReusesCachedTracklistForEquivalentDerivedAlbum() async throws {
        let album = Self.makeAlbum(id: "1262014", title: "Nevermind", trackCount: 13, releaseDate: "1991-09-26", recordType: "album")
        let derivedAlbum = Track(
            id: "derived-album.nevermind.nirvana",
            title: "Nevermind",
            artist: "Nirvana",
            album: "Album",
            duration: 0,
            palette: .fallback,
            catalogID: nil,
            previewURL: nil,
            kind: .album,
            trackCount: 13,
            releaseDate: "1991-09-26",
            recordType: "album"
        )
        let detailTrack = Self.makePlaybackTrack(2, title: "Lithium", artist: "Nirvana", album: "Nevermind")
        let provider = CatalogDrillRecordingProvider(detailItems: [detailTrack])
        let store = PlayerStore(provider: provider)

        store.activate(album)
        try await Task.sleep(for: .milliseconds(240))

        XCTAssertEqual(provider.catalogItemsCalls, 1)

        store.leaveCatalogContext()
        store.activate(derivedAlbum)

        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)

        try await Task.sleep(for: .milliseconds(180))

        XCTAssertEqual(provider.catalogItemsCalls, 1)
    }

    @MainActor
    func testSearchPrefetchesCatalogDetailSoOpeningAlbumIsInstant() async throws {
        let detailTrack = Self.makePlaybackTrack(2, title: "Lithium", artist: "Nirvana", album: "Nevermind")
        let album = Self.makeAlbum(id: "1262014", title: "Nevermind", trackCount: 13, releaseDate: "1991-09-26", recordType: "album")
        let provider = CatalogDrillRecordingProvider(detailItems: [detailTrack], searchItems: [album])
        let store = PlayerStore(provider: provider)

        store.updateSearchQuery("nevermind")
        try await Task.sleep(for: .milliseconds(420))

        XCTAssertEqual(store.visibleTracks, [album])
        XCTAssertEqual(provider.catalogItemsCalls, 1)

        store.activate(album)

        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)
        XCTAssertEqual(provider.catalogItemsCalls, 1)
    }

    @MainActor
    func testCatalogDrillShowsOptimisticArtistTracksWhileDetailLoads() async throws {
        let artist = Track(
            id: "deemix-artist.415",
            title: "Nirvana",
            artist: "Nirvana",
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/415",
            previewURL: nil,
            kind: .artist,
            fanCount: 10_001_682,
            albumCount: 25
        )
        let searchTrack = Track(
            id: "deemix-api.13791932",
            title: "Come As You Are",
            artist: "Nirvana",
            album: "Nevermind",
            duration: 218,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/13791932",
            previewURL: nil
        )
        let detailTrack = Track(
            id: "deemix-api.14861373",
            title: "Smells Like Teen Spirit",
            artist: "Nirvana",
            album: "Nevermind",
            duration: 301,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/14861373",
            previewURL: nil
        )
        let provider = CatalogDrillRecordingProvider(
            detailItems: [detailTrack],
            searchItems: [artist, searchTrack]
        )
        let store = PlayerStore(provider: provider)

        store.updateSearchQuery("nirvana")
        try await Task.sleep(for: .milliseconds(420))
        XCTAssertEqual(store.visibleTracks, [artist, searchTrack])

        store.activate(artist)

        XCTAssertEqual(store.searchQuery, "nirvana")
        XCTAssertEqual(store.catalogContext, artist)
        if store.visibleTracks == [detailTrack] {
            XCTAssertFalse(store.isSearching)
        } else {
            XCTAssertEqual(store.visibleTracks, [searchTrack])
            XCTAssertTrue(store.isSearching)
        }

        try await Task.sleep(for: .milliseconds(240))

        XCTAssertEqual(provider.searchCalls, 1)
        XCTAssertEqual(provider.catalogItemsCalls, 1)
        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)
    }

    @MainActor
    func testQueryUpdateAfterCatalogDrillReturnsToFreshSearchResults() async throws {
        let artist = Self.makeArtist(id: "415", title: "Nirvana", albumCount: 25)
        let staleDetailTrack = Self.makePlaybackTrack(13, title: "Stale Detail", artist: "Nirvana")
        let freshSearchTrack = Self.makePlaybackTrack(14, title: "Where Is My Mind?", artist: "Pixies")
        let provider = CatalogDrillRecordingProvider(
            detailItems: [staleDetailTrack],
            searchItems: [freshSearchTrack]
        )
        let store = PlayerStore(provider: provider)

        store.updateSearchQuery("nirvana")
        store.activate(artist)
        XCTAssertEqual(store.catalogContext, artist)

        store.updateSearchQuery("pixies")
        try await Task.sleep(for: .milliseconds(420))

        XCTAssertEqual(store.searchQuery, "pixies")
        XCTAssertNil(store.catalogContext)
        XCTAssertEqual(store.visibleTracks, [freshSearchTrack])
        XCTAssertFalse(store.isSearching)
        XCTAssertEqual(provider.catalogItemsCalls, 1)
        XCTAssertEqual(provider.searchCalls, 1)
    }


    func testDecodesBackendPlaybackFallbackResponse() throws {
        let data = Data("""
        {
          "result": true,
          "format": "MP3_128",
          "bitrate": 1,
          "streamURL": "http://127.0.0.1:6605/api/stream/13791932?format=MP3_128"
        }
        """.utf8)

        let response = try JSONDecoder().decode(DeemixAPIPlaybackResponse.self, from: data)

        XCTAssertTrue(response.result)
        XCTAssertEqual(response.format, "MP3_128")
        XCTAssertEqual(response.bitrate, 1)
        XCTAssertEqual(response.streamURL, "http://127.0.0.1:6605/api/stream/13791932?format=MP3_128")
    }

    func testBuildsDirectBackendStreamURLWithoutPlaybackPreflight() throws {
        let track = Track(
            id: "deemix-api.13791932",
            title: "Come As You Are",
            artist: "Nirvana",
            album: "Nevermind",
            duration: 218,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/13791932",
            previewURL: nil
        )
        let baseURL = URL(string: "http://127.0.0.1:6605")!

        let streamURL = try DeemixAPIStreamURLResolver.streamURL(baseURL: baseURL, track: track)

        XCTAssertEqual(streamURL.absoluteString, "http://127.0.0.1:6605/api/stream/13791932")
    }

    func testSessionVaultPersistsARLInKeychain() throws {
        let vault = DeemixAPISessionVault(
            service: "com.fsociety.noirwave.tests.\(UUID().uuidString)",
            account: "deezer-arl"
        )
        defer { try? vault.deleteSavedARL() }

        let token = "abcdefghijklmnopqrstuvwxyz1234567890"

        XCTAssertNil(try vault.savedARL())
        try vault.saveARL(" \(token)\n")
        XCTAssertEqual(try vault.savedARL(), token)
    }

    func testMapsArtistSearchMetadataForNativeCards() {
        let payload = DeemixAPIArtistPayload(
            id: 415,
            name: "Nirvana",
            link: "https://www.deezer.com/artist/415",
            picture: nil,
            pictureSmall: nil,
            pictureMedium: "https://cdn-images.dzcdn.net/images/artist/nirvana/250x250-000000-80-0-0.jpg",
            pictureBig: "https://cdn-images.dzcdn.net/images/artist/nirvana/500x500-000000-80-0-0.jpg",
            pictureXL: "https://cdn-images.dzcdn.net/images/artist/nirvana/1000x1000-000000-80-0-0.jpg",
            albumCount: 25,
            fanCount: 9_999_080,
            tracklist: "https://api.deezer.com/artist/415/top?limit=1000"
        )

        let artist = DeemixAPITrackMapper.mapArtist(payload, fallbackIndex: 0)

        XCTAssertEqual(artist.title, "Nirvana")
        XCTAssertEqual(artist.detailLabel, "10M listeners · 25 albums")
        XCTAssertEqual(artist.artworkURL, "https://cdn-images.dzcdn.net/images/artist/nirvana/1000x1000-000000-80-0-0.jpg")
        XCTAssertEqual(artist.fanCount, 9_999_080)
        XCTAssertEqual(artist.albumCount, 25)
    }

    func testMapsAlbumSearchMetadataForNativeCards() {
        let payload = DeemixAPIAlbumPayload(
            id: 1_262_014,
            title: "Nevermind (Remastered)",
            link: "https://www.deezer.com/album/1262014",
            cover: nil,
            coverSmall: nil,
            coverMedium: "https://cdn-images.dzcdn.net/images/cover/nevermind/250x250-000000-80-0-0.jpg",
            coverBig: "https://cdn-images.dzcdn.net/images/cover/nevermind/500x500-000000-80-0-0.jpg",
            coverXL: "https://cdn-images.dzcdn.net/images/cover/nevermind/1000x1000-000000-80-0-0.jpg",
            artist: DeemixAPIArtistPayload(id: 415, name: "Nirvana", link: nil, picture: nil, pictureSmall: nil, pictureMedium: nil),
            trackCount: 13,
            fanCount: 368_509,
            releaseDate: "2011-09-27",
            recordType: "album",
            rank: 955_546,
            tracklist: "https://api.deezer.com/album/1262014/tracks"
        )

        let album = DeemixAPITrackMapper.mapAlbum(payload, fallbackIndex: 0)

        XCTAssertEqual(album.title, "Nevermind (Remastered)")
        XCTAssertEqual(album.detailLabel, "Nirvana · Album · 13 tracks · 2011")
        XCTAssertEqual(album.artworkURL, "https://cdn-images.dzcdn.net/images/cover/nevermind/1000x1000-000000-80-0-0.jpg")
        XCTAssertEqual(album.trackCount, 13)
        XCTAssertEqual(album.releaseDate, "2011-09-27")
    }

    func testArtistReleaseClassifierSeparatesStudioAlbumsFromReissuesAndLiveAlbums() {
        let live = Self.makeAlbum(
            id: "live",
            title: "In Utero 30th Live",
            trackCount: 4,
            releaseDate: "2023-10-27",
            recordType: "live"
        )
        let inUtero = Self.makeAlbum(
            id: "in-utero",
            title: "In Utero",
            trackCount: 12,
            releaseDate: "1993-09-21",
            recordType: "studio"
        )
        let deluxe = Self.makeAlbum(
            id: "deluxe",
            title: "Nevermind (Deluxe Edition)",
            trackCount: 42,
            releaseDate: "2011-09-27",
            recordType: "reissue"
        )
        let nevermind = Self.makeAlbum(
            id: "nevermind",
            title: "Nevermind",
            trackCount: 13,
            releaseDate: "1991-09-24",
            recordType: "studio"
        )

        let groups = ArtistReleaseClassifier.groups(from: [live, inUtero, deluxe, nevermind])

        XCTAssertEqual(groups.studioAlbums.map(\.title), ["In Utero", "Nevermind"])
        XCTAssertEqual(groups.otherReleases.map(\.title), ["In Utero 30th Live", "Nevermind (Deluxe Edition)"])
    }

    func testDisplayRecordTypesExposeReleaseRole() {
        XCTAssertEqual("studio".displayRecordType, "Studio Album")
        XCTAssertEqual("live".displayRecordType, "Live Album")
        XCTAssertEqual("reissue".displayRecordType, "Reissue")
    }

    func testSortsTracksByPopularityRankDescending() throws {
        let low = DeemixAPITrackPayload(
            id: 1,
            readable: true,
            title: "Less Played",
            titleShort: nil,
            titleVersion: nil,
            link: "https://www.deezer.com/track/1",
            duration: 180,
            rank: 1_000,
            explicitLyrics: false,
            preview: nil,
            artist: DeemixAPIArtistPayload(id: 415, name: "Nirvana", link: nil, picture: nil, pictureSmall: nil, pictureMedium: nil),
            album: nil
        )
        let high = DeemixAPITrackPayload(
            id: 2,
            readable: true,
            title: "Popular",
            titleShort: nil,
            titleVersion: nil,
            link: "https://www.deezer.com/track/2",
            duration: 180,
            rank: 950_000,
            explicitLyrics: false,
            preview: nil,
            artist: DeemixAPIArtistPayload(id: 415, name: "Nirvana", link: nil, picture: nil, pictureSmall: nil, pictureMedium: nil),
            album: nil
        )

        let tracks = try [low, high].enumerated().map { index, payload in
            try DeemixAPITrackMapper.map(payload, fallbackIndex: index)
        }

        XCTAssertEqual(DeemixAPITrackSorter.sortedByPopularity(tracks).map(\.title), ["Popular", "Less Played"])
    }

    func testArtistCatalogComposerDoesNotTruncatePopularTracks() {
        let popularTracks = (1...18).map { index in
            Self.makePlaybackTrack(index, title: "Popular \(index)", artist: "Nirvana", album: "Nevermind", rank: 1_000_000 - index)
        }
        let album = Self.makeAlbum(
            id: "album",
            title: "Nevermind",
            trackCount: 13,
            releaseDate: "1991-09-24",
            recordType: "studio"
        )

        let items = DeemixAPIArtistCatalogComposer.items(popularTracks: popularTracks, albums: [album])

        XCTAssertEqual(items.prefix(18).map(\.title), popularTracks.map(\.title))
        XCTAssertEqual(items.last?.title, "Nevermind")
    }

    func testRejectsInvalidPreviewFallbackURL() {
        let track = Track(
            id: "deemix-api.3135556",
            title: "Around the World",
            artist: "Daft Punk",
            album: "Homework",
            duration: 429,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/3135556",
            previewURL: "not a url"
        )

        XCTAssertNil(DeemixAPIPlaybackURLResolver.previewURL(for: track))
    }

    func testSearchScopeLabelsAreClearMediaTypes() {
        XCTAssertEqual(SearchScope.smart.rawValue, "Smart")
        XCTAssertEqual(SearchScope.catalog.rawValue, "Tracks")
        XCTAssertEqual(SearchScope.library.rawValue, "Artists")
        XCTAssertEqual(SearchScope.albums.rawValue, "Albums")
    }

    func testCatalogRequestWindowsAreExpandedPastPreviewLimits() {
        XCTAssertGreaterThanOrEqual(DeemixAPICatalogRequestLimits.searchWindow, 180)
        XCTAssertGreaterThanOrEqual(DeemixAPICatalogRequestLimits.artistTrackWindow, 500)
    }

    func testArtistPopularTracksSubtitleDescribesDeezerTopWindow() {
        XCTAssertEqual(ArtistPopularTracksCopy.subtitle(count: 0), "No Deezer top tracks loaded")
        XCTAssertEqual(ArtistPopularTracksCopy.subtitle(count: 1), "1 Deezer top track")
        XCTAssertEqual(ArtistPopularTracksCopy.subtitle(count: 100), "100 Deezer top tracks")
    }

    func testArtistHeaderLayoutKeepsFirstViewportDense() {
        XCTAssertLessThanOrEqual(ArtistHeaderLayoutMetrics.heroMinHeight, 280)
        XCTAssertLessThanOrEqual(ArtistHeaderLayoutMetrics.foregroundArtworkSize, 156)
        XCTAssertLessThanOrEqual(ArtistHeaderLayoutMetrics.titleFontSize, 48)
        XCTAssertLessThanOrEqual(
            ArtistHeaderLayoutMetrics.aboveFoldStackHeight,
            ArtistHeaderLayoutMetrics.availableDesktopContentHeight
        )
    }

    func testArtistPopularTracksPresentationDefaultsToTopFiveAndCanExpand() {
        let tracks = (1...12).map { index in
            Self.makePlaybackTrack(index, title: "Popular \(index)")
        }

        XCTAssertEqual(
            ArtistPopularTracksPresentation.visibleTracks(from: tracks, isExpanded: false).map(\.title),
            ["Popular 1", "Popular 2", "Popular 3", "Popular 4", "Popular 5"]
        )
        XCTAssertEqual(
            ArtistPopularTracksPresentation.visibleTracks(from: tracks, isExpanded: true).map(\.title),
            tracks.map(\.title)
        )
        XCTAssertTrue(ArtistPopularTracksPresentation.showsToggle(totalCount: tracks.count))
        XCTAssertFalse(ArtistPopularTracksPresentation.showsToggle(totalCount: 5))
        XCTAssertEqual(ArtistPopularTracksPresentation.toggleTitle(totalCount: tracks.count, isExpanded: false), "Show more")
        XCTAssertEqual(ArtistPopularTracksPresentation.toggleTitle(totalCount: tracks.count, isExpanded: true), "Show less")
    }

    func testSearchPresentationKeepsArtistResultsLightweight() {
        let artist = Self.makeArtist(id: "artist", title: "Арсений Креститель", albumCount: 4)
        let album = Self.makeAlbum(id: "album", title: "Hidden release", trackCount: 9, releaseDate: "2024-01-01", recordType: "studio")
        let track = Self.makePlaybackTrack(44, title: "Fast result", artist: "Арсений Креститель")

        let presentation = SearchResultsPresentation(items: [artist, album, track])

        XCTAssertEqual(presentation.bestMatch, artist)
        XCTAssertEqual(presentation.artists, [artist])
        XCTAssertTrue(presentation.albums.isEmpty)
        XCTAssertEqual(presentation.tracks, [track])
    }

    func testSearchPresentationDerivesArtistCandidateFromTrackMetadata() {
        let track = Track(
            id: "deemix-api.2",
            title: "About A Girl",
            artist: "Nirvana",
            album: "Bleach",
            duration: 166,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/2",
            previewURL: nil,
            artistCatalogID: "https://www.deezer.com/artist/415",
            albumCatalogID: "https://www.deezer.com/album/1",
            kind: .track,
            artworkURL: "https://cdn.example.test/bleach.jpg",
            rank: 200_000
        )

        let presentation = SearchResultsPresentation(items: [track], query: "nirvana")

        XCTAssertEqual(presentation.bestMatch?.kind, .artist)
        XCTAssertEqual(presentation.bestMatch?.title, "Nirvana")
        XCTAssertEqual(presentation.bestMatch?.catalogID, "https://www.deezer.com/artist/415")
        XCTAssertEqual(presentation.artists.map(\.title), ["Nirvana"])
        XCTAssertEqual(presentation.tracks, [track])
    }

    func testMiniPlayerVisualStyleUsesInsetMintProgressAndSmallerPrimaryControl() {
        XCTAssertEqual(NoirwaveTheme.primaryAccentHex, "#78DCD0")
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.progressHorizontalInset, 8)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.progressHeight, 1.0)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.progressThumbSize, 4.0)
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.progressHoverThumbSize, MiniPlayerVisualStyle.progressThumbSize * 2)
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.progressTimeWidth, 40)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.progressMaxWidth, 560)
        XCTAssertEqual(MiniPlayerVisualStyle.progressTopPadding, 0)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.progressCompactHeight, 10)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.progressExpandedHeight, 46)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.primaryControlVisualSize, 38)
        XCTAssertLessThanOrEqual(MiniPlayerVisualStyle.primaryIconSize, 15)
        XCTAssertGreaterThanOrEqual(MiniPlayerVisualStyle.primaryControlHitSize, 44)
    }

    func testArtworkFallbackStyleUsesNeutralNonGeneratedPlaceholder() {
        XCTAssertEqual(ArtworkFallbackStyle.backgroundHex, NoirwaveTheme.backgroundHex)
        XCTAssertFalse(ArtworkFallbackStyle.usesGeneratedArtwork)
    }

    func testSearchResultsStayScopedToCatalogDestination() {
        XCTAssertTrue(ContentDeckRouting.showsSearchResults(
            selectionIsCatalog: true,
            hasCatalogContext: false,
            searchQuery: "nirvana"
        ))
        XCTAssertFalse(ContentDeckRouting.showsSearchResults(
            selectionIsCatalog: false,
            hasCatalogContext: false,
            searchQuery: "nirvana"
        ))
        XCTAssertFalse(ContentDeckRouting.showsSearchResults(
            selectionIsCatalog: true,
            hasCatalogContext: true,
            searchQuery: "nirvana"
        ))
        XCTAssertFalse(ContentDeckRouting.showsSearchResults(
            selectionIsCatalog: true,
            hasCatalogContext: false,
            searchQuery: "   "
        ))
    }

    func testCatalogDetailStaysScopedToCatalogDestination() {
        XCTAssertTrue(ContentDeckRouting.showsCatalogDetail(
            selectionIsCatalog: true,
            hasCatalogContext: true
        ))
        XCTAssertFalse(ContentDeckRouting.showsCatalogDetail(
            selectionIsCatalog: false,
            hasCatalogContext: true
        ))
        XCTAssertFalse(ContentDeckRouting.showsCatalogDetail(
            selectionIsCatalog: true,
            hasCatalogContext: false
        ))
    }

    @MainActor
    func testLeavingCatalogDetailWithEmptyQueryCancelsLateDetailResponse() async throws {
        let featured = Self.makePlaybackTrack(1, title: "Featured Track")
        let detailTrack = Self.makePlaybackTrack(2, title: "Late Detail")
        let provider = CatalogDrillRecordingProvider(
            featuredItems: [featured],
            detailItems: [detailTrack]
        )
        let store = PlayerStore(provider: provider)
        let album = Self.makeAlbum(
            id: "1262014",
            title: "Nevermind",
            trackCount: 13,
            releaseDate: "1991-09-26",
            recordType: "album"
        )

        await store.bootstrap()
        store.activate(album)
        XCTAssertEqual(store.catalogContext, album)
        XCTAssertTrue(store.isSearching)

        store.leaveCatalogContext()
        try await Task.sleep(for: .milliseconds(180))

        XCTAssertNil(store.catalogContext)
        XCTAssertEqual(store.visibleTracks, [featured])
        XCTAssertFalse(store.isSearching)
    }

    func testAlbumDetailLabelKeepsSinglesAndEPsDistinct() {
        let single = Track(
            id: "deemix-album.1",
            title: "Single Release",
            artist: "Nirvana",
            album: "Album",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/album/1",
            previewURL: nil,
            kind: .album,
            trackCount: 1,
            releaseDate: "1991-01-01",
            recordType: "single"
        )
        let ep = Track(
            id: "deemix-album.2",
            title: "EP Release",
            artist: "Nirvana",
            album: "Album",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/album/2",
            previewURL: nil,
            kind: .album,
            trackCount: 4,
            releaseDate: "1992-01-01",
            recordType: "ep"
        )

        XCTAssertEqual(single.detailLabel, "Nirvana · Single · 1 track · 1991")
        XCTAssertEqual(ep.detailLabel, "Nirvana · EP · 4 tracks · 1992")
    }

    func testSmartSearchDeduplicatesExactArtistsAndFiltersWeakContainsMatches() {
        let canonical = Track(
            id: "deemix-artist.415",
            title: "Nirvana",
            artist: "Nirvana",
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/415",
            previewURL: nil,
            kind: .artist,
            fanCount: 10_000_000,
            albumCount: 26
        )
        let duplicate = Track(
            id: "deemix-artist.999",
            title: "Nirvana",
            artist: "Nirvana",
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/999",
            previewURL: nil,
            kind: .artist,
            fanCount: 10,
            albumCount: 2
        )
        let weakContainsMatch = Track(
            id: "deemix-artist.777",
            title: "Approaching Nirvana",
            artist: "Approaching Nirvana",
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/777",
            previewURL: nil,
            kind: .artist,
            fanCount: 9_900,
            albumCount: 100
        )
        let weakPrefixVariant = Track(
            id: "deemix-artist.778",
            title: "Nirvana UK",
            artist: "Nirvana UK",
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/778",
            previewURL: nil,
            kind: .artist,
            fanCount: 133,
            albumCount: 5
        )

        let ranked = SmartSearchRanker.ranked(
            query: "nirvana",
            artists: [duplicate, weakContainsMatch, weakPrefixVariant, canonical],
            tracks: [],
            albums: []
        )

        XCTAssertEqual(ranked.map(\.id), ["deemix-artist.415"])
    }

    func testSmartSearchBoostsDominantArtistTracksOverTitleOnlyMatches() {
        let artist = Track(
            id: "deemix-artist.415",
            title: "Nirvana",
            artist: "Nirvana",
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/415",
            previewURL: nil,
            kind: .artist,
            fanCount: 10_000_000,
            albumCount: 26
        )
        let titleOnlyTrack = Track(
            id: "deemix-api.1",
            title: "Nirvana",
            artist: "Kerchak",
            album: "Nirvana",
            duration: 167,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/1",
            previewURL: nil,
            rank: 950_000
        )
        let dominantArtistTrack = Track(
            id: "deemix-api.2",
            title: "About A Girl",
            artist: "Nirvana",
            album: "Nirvana",
            duration: 166,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/2",
            previewURL: nil,
            rank: 200_000
        )

        let ranked = SmartSearchRanker.ranked(
            query: "nirvana",
            artists: [artist],
            tracks: [titleOnlyTrack, dominantArtistTrack],
            albums: []
        )

        XCTAssertEqual(ranked.map(\.id), ["deemix-artist.415", "deemix-api.2", "deemix-api.1"])
    }

    func testSmartSearchInfersDominantArtistFromTrackArtistsWhenArtistScopeIsEmpty() {
        let titleOnlyTrack = Track(
            id: "deemix-api.1",
            title: "Nirvana",
            artist: "Kerchak",
            album: "Confiance",
            duration: 167,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/1",
            previewURL: nil,
            rank: 950_000
        )
        let dominantArtistTrack = Track(
            id: "deemix-api.2",
            title: "About A Girl",
            artist: "Nirvana",
            album: "Bleach",
            duration: 166,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/2",
            previewURL: nil,
            rank: 200_000
        )

        let ranked = SmartSearchRanker.ranked(
            query: "nirvana",
            artists: [],
            tracks: [titleOnlyTrack, dominantArtistTrack],
            albums: []
        )

        XCTAssertEqual(ranked.map(\.id), ["deemix-api.2", "deemix-api.1"])
    }

    func testCatalogSearchComposesArtistsAndTitleMatchedTracks() {
        let artist = Track(
            id: "deemix-artist.100",
            title: "Арсений Креститель",
            artist: "Арсений Креститель",
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/100",
            previewURL: nil,
            kind: .artist,
            fanCount: 25_000,
            albumCount: 4
        )
        let titleMatch = Track(
            id: "track.title",
            title: "Арсений Креститель",
            artist: "Other Artist",
            album: "Singles",
            duration: 180,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/1",
            previewURL: nil,
            rank: 10
        )
        let artistMatch = Track(
            id: "track.artist",
            title: "Город",
            artist: "Арсений Креститель",
            album: "Album",
            duration: 180,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/2",
            previewURL: nil,
            rank: 950_000
        )
        let looseMatch = Track(
            id: "track.loose",
            title: "Popular But Loose",
            artist: "Someone Else",
            album: "Album",
            duration: 180,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/3",
            previewURL: nil,
            rank: 990_000
        )

        let results = CatalogSearchResultComposer.catalogResults(
            term: "арсений креститель",
            tracks: [looseMatch, artistMatch, titleMatch],
            artists: [artist]
        )

        XCTAssertEqual(results.map(\.id), ["deemix-artist.100", "track.title", "track.artist", "track.loose"])
        XCTAssertEqual(results.first?.detailLabel, "25K listeners · 4 albums")
    }

    func testNormalizesBackendSessionTokenBeforeLogin() {
        XCTAssertEqual(
            DeemixAPISessionSecret.normalizedARL("  \(String(repeating: "a", count: 192))\n"),
            String(repeating: "a", count: 192)
        )
    }

    func testRejectsEmptyOrClearlyInvalidBackendSessionToken() {
        XCTAssertNil(DeemixAPISessionSecret.normalizedARL(""))
        XCTAssertNil(DeemixAPISessionSecret.normalizedARL("      "))
        XCTAssertNil(DeemixAPISessionSecret.normalizedARL("short"))
    }

    func testSavedBackendSessionIsReportedReadyBeforeLazyLogin() {
        XCTAssertEqual(
            DeemixAPISessionState.playbackMessage(autologin: true, savedARL: String(repeating: "a", count: 192)),
            "playback session ready"
        )
    }

    func testMissingBackendSessionIsReportedInactive() {
        XCTAssertEqual(
            DeemixAPISessionState.playbackMessage(autologin: true, savedARL: nil),
            "playback session inactive"
        )
    }

    func testTrackLyricsSelectsActiveSynchronizedLine() {
        let lyrics = TrackLyrics(
            text: "first line\nsecond line",
            lines: [
                TrackLyricsLine(milliseconds: 1_000, duration: 900, text: "first line"),
                TrackLyricsLine(milliseconds: 2_500, duration: 1_100, text: "second line")
            ],
            copyright: nil,
            writers: nil
        )

        XCTAssertEqual(lyrics.activeLineIndex(at: 0.8), 0)
        XCTAssertEqual(lyrics.activeLineIndex(at: 2.7), 1)
        XCTAssertEqual(lyrics.activeLineIndex(at: 9), 1)
    }

    func testDecodesBackendLyricsResponse() throws {
        let data = Data("""
        {
          "result": true,
          "id": "13791932",
          "available": true,
          "hasSynced": true,
          "text": "first line\\nsecond line",
          "lines": [
            { "milliseconds": 1000, "duration": 900, "text": "first line" },
            { "milliseconds": 2500, "duration": 1100, "text": "second line" }
          ],
          "copyright": "provider copyright",
          "writers": "writer one"
        }
        """.utf8)

        let response = try JSONDecoder().decode(DeemixAPILyricsResponse.self, from: data)
        let lyrics = response.trackLyrics

        XCTAssertTrue(response.available)
        XCTAssertEqual(lyrics.lines.count, 2)
        XCTAssertEqual(lyrics.lines[1].milliseconds, 2_500)
        XCTAssertEqual(lyrics.writers, "writer one")
    }

    @MainActor
    func testSearchAlwaysUsesSmartScope() async throws {
        let provider = ScopeRecordingProvider(results: [Self.makePlaybackTrack(1)])
        let store = PlayerStore(provider: provider)

        store.setScope(.library)
        store.updateSearchQuery("nirvana")

        try await Task.sleep(for: .milliseconds(360))

        XCTAssertEqual(provider.recordedScopes, [.smart])
        XCTAssertEqual(store.resultTitle, SearchScope.smart.resultsTitle)
    }

    func testLibrarySearchFilterMatchesTitleArtistAndAlbum() {
        let apple = Self.makeLibraryTrack(1, title: "Everything In Its Right Place", artist: "Radiohead", album: "Kid A")
        let spotify = Self.makeLibraryTrack(2, title: "Cherry-Coloured Funk", artist: "Cocteau Twins", album: "Heaven or Las Vegas")
        let noir = Self.makeLibraryTrack(3, title: "Digital Bath", artist: "Deftones", album: "White Pony")

        XCTAssertEqual(
            LibrarySearchFilter.filteredTracks([apple, spotify, noir], query: "kid").map(\.id),
            [apple.id]
        )
        XCTAssertEqual(
            LibrarySearchFilter.filteredTracks([apple, spotify, noir], query: "cocteau").map(\.id),
            [spotify.id]
        )
        XCTAssertEqual(
            LibrarySearchFilter.filteredTracks([apple, spotify, noir], query: "digital").map(\.id),
            [noir.id]
        )
    }

    func testFavoriteTracksOrganizerComposesLibraryAndLocalSearch() {
        let slowdive = Self.makeLibraryTrack(1, title: "Alison", artist: "Slowdive", album: "Souvlaki")
        let slowdiveSecond = Self.makeLibraryTrack(2, title: "When the Sun Hits", artist: "Slowdive", album: "Souvlaki")
        let radiohead = Self.makeLibraryTrack(3, title: "Everything In Its Right Place", artist: "Radiohead", album: "Kid A")
        let aphex = Self.makeLibraryTrack(4, title: "Xtal", artist: "Aphex Twin", album: "Selected Ambient Works 85-92")
        let tracks = [slowdiveSecond, radiohead, aphex, slowdive]

        XCTAssertEqual(
            FavoriteTracksOrganizer.tracks(tracks, libraryQuery: "slowdive", localQuery: "souvlaki", sortMode: .recentlyAdded).map(\.id),
            [slowdiveSecond.id, slowdive.id]
        )
        XCTAssertEqual(
            FavoriteTracksOrganizer.tracks(tracks, libraryQuery: "", localQuery: "kid", sortMode: .title).map(\.id),
            [radiohead.id]
        )
        XCTAssertEqual(
            FavoriteTracksOrganizer.tracks(tracks, libraryQuery: "slowdive", localQuery: "alison", sortMode: .recentlyAdded).map(\.id),
            [slowdive.id]
        )
    }

    func testLibrarySectionExpansionLimitsCollapsedItemsToSix() {
        let items = Array(1...9)

        XCTAssertEqual(LibrarySectionExpansion.visibleItems(items, isExpanded: false), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(LibrarySectionExpansion.visibleItems(items, isExpanded: true), items)
        XCTAssertTrue(LibrarySectionExpansion.showsToggle(totalCount: 7))
        XCTAssertFalse(LibrarySectionExpansion.showsToggle(totalCount: 6))
    }

    func testPlaylistTrackFilterKeepsPlaylistOrderAndMatchesTrackMetadata() {
        let tracks = [
            Self.makeLibraryTrack(1, title: "Only Shallow", artist: "My Bloody Valentine", album: "Loveless"),
            Self.makeLibraryTrack(2, title: "Alison", artist: "Slowdive", album: "Souvlaki"),
            Self.makeLibraryTrack(3, title: "Cherry-Coloured Funk", artist: "Cocteau Twins", album: "Heaven or Las Vegas"),
            Self.makeLibraryTrack(4, title: "When the Sun Hits", artist: "Slowdive", album: "Souvlaki")
        ]

        XCTAssertEqual(
            PlaylistTrackFilter.filteredTracks(tracks, query: "").map(\.id),
            tracks.map(\.id)
        )
        XCTAssertEqual(
            PlaylistTrackFilter.filteredTracks(tracks, query: "slowdive souvlaki").map(\.id),
            [tracks[1].id, tracks[3].id]
        )
        XCTAssertEqual(
            PlaylistTrackFilter.filteredTracks(tracks, query: "cherry").map(\.id),
            [tracks[2].id]
        )
    }

    func testPlaylistTrackOrganizerComposesSearchWithPlaylistSortModes() {
        let tracks = [
            Self.makeLibraryTrack(1, title: "When the Sun Hits", artist: "Slowdive", album: "Souvlaki", duration: 285, trackPosition: 8),
            Self.makeLibraryTrack(2, title: "Alison", artist: "Slowdive", album: "Souvlaki", duration: 171, trackPosition: 2),
            Self.makeLibraryTrack(3, title: "Joga", artist: "Bjork", album: "Homogenic", duration: 301),
            Self.makeLibraryTrack(4, title: "Xtal", artist: "Aphex Twin", album: "Selected Ambient Works 85-92", duration: 293)
        ]

        XCTAssertEqual(
            PlaylistTrackOrganizer.tracks(tracks, query: "slowdive", sortMode: .playlistOrder).map(\.id),
            [tracks[0].id, tracks[1].id]
        )
        XCTAssertEqual(
            PlaylistTrackOrganizer.tracks(tracks, query: "", sortMode: .title).map(\.id),
            [tracks[1].id, tracks[2].id, tracks[0].id, tracks[3].id]
        )
        XCTAssertEqual(
            PlaylistTrackOrganizer.tracks(tracks, query: "", sortMode: .artist).map(\.id),
            [tracks[3].id, tracks[2].id, tracks[1].id, tracks[0].id]
        )
        XCTAssertEqual(
            PlaylistTrackOrganizer.tracks(tracks, query: "", sortMode: .album).map(\.id),
            [tracks[2].id, tracks[3].id, tracks[1].id, tracks[0].id]
        )
        XCTAssertEqual(
            PlaylistTrackOrganizer.tracks(tracks, query: "", sortMode: .duration).map(\.id),
            [tracks[1].id, tracks[0].id, tracks[3].id, tracks[2].id]
        )
    }

    func testNoirwavePrimaryAccentUsesMintCyan() {
        XCTAssertEqual(NoirwaveTheme.primaryAccentHex, "#78DCD0")
        XCTAssertEqual(NoirwaveTheme.backgroundHex, "#141414")
        XCTAssertEqual(NoirwaveTheme.backgroundElevatedHex, "#1A1A17")
        XCTAssertEqual(TrackPalette.fallback.accentHex, NoirwaveTheme.primaryAccentHex)
    }

    func testSearchMatcherToleratesSmallTyposAndKeyboardLayoutMisses() {
        XCTAssertTrue(SearchTextMatcher.matches(query: "mancild", text: "Manchild"))
        XCTAssertTrue(SearchTextMatcher.matches(query: "ьanchild", text: "Manchild"))
        XCTAssertEqual(SearchQueryVariants.candidates(for: "ьanchild"), ["ьanchild", "manchild"])
    }

    func testLibraryDefaultSortDoesNotExposeRecentlyAddedBlockLabel() {
        XCTAssertEqual(LibrarySortMode.recentlyAdded.title, "Saved Order")
    }

    func testLibrarySurfaceLayoutPlacesPlaylistsAtBottom() {
        XCTAssertEqual(
            LibrarySurfaceLayout.sections(hasTracks: true, hasSavedCollections: true, hasLocalPlaylists: true),
            [.favoriteTracks, .playlists, .collections]
        )
        XCTAssertEqual(
            LibrarySurfaceLayout.sections(hasTracks: false, hasSavedCollections: true, hasLocalPlaylists: true),
            [.playlists, .collections]
        )
        XCTAssertEqual(
            LibrarySurfaceLayout.sections(hasTracks: true, hasSavedCollections: false, hasLocalPlaylists: false),
            [.favoriteTracks, .playlists]
        )
        XCTAssertEqual(
            LibrarySurfaceLayout.sections(hasTracks: false, hasSavedCollections: false, hasLocalPlaylists: true),
            [.playlists]
        )
    }

    func testLibraryPlaylistShelfBuilderKeepsLikedSongsOutOfPlaylistShelf() {
        let likedTracks = [
            Self.makeLibraryTrack(1, title: "Alison", artist: "Slowdive", album: "Souvlaki"),
            Self.makeLibraryTrack(2, title: "Xtal", artist: "Aphex Twin", album: "Selected Ambient Works 85-92")
        ]
        let localPlaylist = LocalPlaylist(
            id: "road-trip",
            title: "Road Trip",
            tracks: [Self.makeLibraryTrack(3, title: "Joga", artist: "Bjork", album: "Homogenic")]
        )

        let items = LibraryPlaylistShelfBuilder.items(
            likedTracks: likedTracks,
            localPlaylists: [localPlaylist],
            query: ""
        )

        XCTAssertEqual(items.map(\.id), ["playlist.road-trip"])
        XCTAssertEqual(items.first?.title, "Road Trip")
        XCTAssertEqual(items.first?.subtitle, "1 track")
        XCTAssertEqual(items.first?.selection, .localPlaylist("road-trip"))
    }

    func testLibraryPlaylistShelfBuilderFiltersOnlyRealLocalPlaylists() {
        let likedTracks = [
            Self.makeLibraryTrack(1, title: "Digital Bath", artist: "Deftones", album: "White Pony"),
            Self.makeLibraryTrack(2, title: "Only Shallow", artist: "My Bloody Valentine", album: "Loveless")
        ]
        let localPlaylist = LocalPlaylist(
            id: "dream-pop",
            title: "Dream Pop",
            tracks: [Self.makeLibraryTrack(3, title: "Cherry-Coloured Funk", artist: "Cocteau Twins", album: "Heaven or Las Vegas")]
        )

        XCTAssertEqual(
            LibraryPlaylistShelfBuilder.items(likedTracks: likedTracks, localPlaylists: [localPlaylist], query: "liked").map(\.selection),
            []
        )
        XCTAssertEqual(
            LibraryPlaylistShelfBuilder.items(likedTracks: likedTracks, localPlaylists: [localPlaylist], query: "white pony").map(\.selection),
            []
        )
        XCTAssertEqual(
            LibraryPlaylistShelfBuilder.items(likedTracks: likedTracks, localPlaylists: [localPlaylist], query: "cocteau").map(\.selection),
            [.localPlaylist("dream-pop")]
        )
    }

    func testLibraryTrackOrganizerSortsByTitleArtistAlbumAndDuration() {
        let slowdive = Self.makeLibraryTrack(1, title: "Alison", artist: "Slowdive", album: "Souvlaki", duration: 171)
        let aphex = Self.makeLibraryTrack(2, title: "Xtal", artist: "Aphex Twin", album: "Selected Ambient Works 85-92", duration: 293)
        let bjork = Self.makeLibraryTrack(3, title: "Joga", artist: "Bjork", album: "Homogenic", duration: 301)
        let trackTen = Self.makeLibraryTrack(10, title: "Track Ten", artist: "Album Artist", album: "Numbered Album", trackPosition: 10)
        let trackTwo = Self.makeLibraryTrack(11, title: "Track Two", artist: "Album Artist", album: "Numbered Album", trackPosition: 2)

        XCTAssertEqual(
            LibraryTrackOrganizer.tracks([slowdive, aphex, bjork], query: "", sortMode: .title).map(\.id),
            [slowdive.id, bjork.id, aphex.id]
        )
        XCTAssertEqual(
            LibraryTrackOrganizer.tracks([slowdive, aphex, bjork], query: "", sortMode: .artist).map(\.id),
            [aphex.id, bjork.id, slowdive.id]
        )
        XCTAssertEqual(
            LibraryTrackOrganizer.tracks([slowdive, aphex, bjork], query: "", sortMode: .album).map(\.id),
            [bjork.id, aphex.id, slowdive.id]
        )
        XCTAssertEqual(
            LibraryTrackOrganizer.tracks([trackTen, trackTwo], query: "", sortMode: .album).map(\.id),
            [trackTwo.id, trackTen.id]
        )
        XCTAssertEqual(
            LibraryTrackOrganizer.tracks([slowdive, aphex, bjork], query: "", sortMode: .duration).map(\.id),
            [slowdive.id, aphex.id, bjork.id]
        )
    }

    func testLibraryTrackOrganizerPreservesRecentlyAddedOrderAndComposesWithQuery() {
        let radiohead = Self.makeLibraryTrack(1, title: "Everything In Its Right Place", artist: "Radiohead", album: "Kid A", duration: 251)
        let cocteau = Self.makeLibraryTrack(2, title: "Cherry-Coloured Funk", artist: "Cocteau Twins", album: "Heaven or Las Vegas", duration: 193)
        let deftones = Self.makeLibraryTrack(3, title: "Digital Bath", artist: "Deftones", album: "White Pony", duration: 255)

        XCTAssertEqual(
            LibraryTrackOrganizer.tracks([deftones, radiohead, cocteau], query: "", sortMode: .recentlyAdded).map(\.id),
            [deftones.id, radiohead.id, cocteau.id]
        )
        XCTAssertEqual(
            LibraryTrackOrganizer.tracks([deftones, radiohead, cocteau], query: "bath", sortMode: .artist).map(\.id),
            [deftones.id]
        )
    }

    @MainActor
    func testSavedCollectionsPersistNewestFirstAcrossStoreInstances() {
        let defaults = Self.makeIsolatedDefaults(name: "saved-collections-order")
        let album = Self.makeAlbum(id: "10", title: "Souvlaki", trackCount: 10, releaseDate: "1993-05-17", recordType: "album")
        let artist = Self.makeArtist(id: "20", title: "Slowdive", albumCount: 6)
        let store = PlayerStore(provider: PrewarmRecordingProvider(tracks: []), userDefaults: defaults)

        XCTAssertFalse(store.isSavedCollection(album))

        store.toggleSavedCollection(album)
        store.toggleSavedCollection(artist)

        XCTAssertTrue(store.isSavedCollection(album))
        XCTAssertTrue(store.isSavedCollection(artist))
        XCTAssertEqual(store.savedCollections().map(\.id), [artist.id, album.id])

        let restoredStore = PlayerStore(provider: PrewarmRecordingProvider(tracks: []), userDefaults: defaults)

        XCTAssertTrue(restoredStore.isSavedCollection(album))
        XCTAssertEqual(restoredStore.savedCollections().map(\.id), [artist.id, album.id])

        restoredStore.toggleSavedCollection(album)

        XCTAssertFalse(restoredStore.isSavedCollection(album))
        XCTAssertEqual(restoredStore.savedCollections().map(\.id), [artist.id])
    }

    @MainActor
    func testSavedCollectionsIgnorePlayableTracks() {
        let defaults = Self.makeIsolatedDefaults(name: "saved-collections-ignore-tracks")
        let track = Self.makeLibraryTrack(1, title: "Only Shallow", artist: "My Bloody Valentine", album: "Loveless")
        let store = PlayerStore(provider: PrewarmRecordingProvider(tracks: [track]), userDefaults: defaults)

        store.toggleSavedCollection(track)

        XCTAssertFalse(store.isSavedCollection(track))
        XCTAssertTrue(store.savedCollections().isEmpty)
    }

    @MainActor
    func testLocalPlaylistsPersistSnapshotsNewestFirstAndIgnoreDuplicateAdds() {
        let defaults = Self.makeIsolatedDefaults(name: "local-playlists-persist")
        let tracks = [
            Self.makeLibraryTrack(1, title: "Only Shallow", artist: "My Bloody Valentine", album: "Loveless"),
            Self.makeLibraryTrack(2, title: "Alison", artist: "Slowdive", album: "Souvlaki"),
            Self.makeLibraryTrack(3, title: "Cherry-Coloured Funk", artist: "Cocteau Twins", album: "Heaven or Las Vegas")
        ]
        let store = PlayerStore(provider: PrewarmRecordingProvider(tracks: tracks), userDefaults: defaults)

        let shoegaze = store.createPlaylist(title: "Shoegaze", tracks: [tracks[0]])
        let dreamPop = store.createPlaylist(title: "Dream Pop", tracks: [tracks[2]])

        store.addToPlaylist(tracks[1], playlistID: shoegaze.id)
        store.addToPlaylist(tracks[1], playlistID: shoegaze.id)

        XCTAssertEqual(store.localPlaylists.map(\.id), [dreamPop.id, shoegaze.id])
        XCTAssertEqual(store.playlistTracks(playlistID: shoegaze.id), [tracks[0], tracks[1]])

        let restoredStore = PlayerStore(provider: PrewarmRecordingProvider(tracks: []), userDefaults: defaults)

        XCTAssertEqual(restoredStore.localPlaylists.map(\.id), [dreamPop.id, shoegaze.id])
        XCTAssertEqual(restoredStore.playlistTracks(playlistID: shoegaze.id), [tracks[0], tracks[1]])
    }

    @MainActor
    func testBulkVisibleTracksAddToPlaylistKeepsVisibleOrderAndSkipsDuplicates() {
        let defaults = Self.makeIsolatedDefaults(name: "local-playlists-bulk-visible")
        let tracks = [
            Self.makeLibraryTrack(1, title: "Alison", artist: "Slowdive", album: "Souvlaki"),
            Self.makeLibraryTrack(2, title: "When the Sun Hits", artist: "Slowdive", album: "Souvlaki"),
            Self.makeLibraryTrack(3, title: "Joga", artist: "Bjork", album: "Homogenic"),
            Self.makeLibraryTrack(4, title: "Xtal", artist: "Aphex Twin", album: "Selected Ambient Works 85-92")
        ]
        let store = PlayerStore(provider: PrewarmRecordingProvider(tracks: tracks), userDefaults: defaults)
        let playlist = store.createPlaylist(title: "Night Drive", tracks: [tracks[2]])
        let visibleTracks = [tracks[1], tracks[2], tracks[0], tracks[1]]

        store.addToPlaylist(visibleTracks, playlistID: playlist.id)

        XCTAssertEqual(store.playlistTracks(playlistID: playlist.id), [tracks[2], tracks[1], tracks[0]])
    }

    func testPlaylistTargetMenuBuilderExcludesCurrentPlaylistAndKeepsLibraryOrder() {
        let shoegaze = LocalPlaylist(
            id: "shoegaze",
            title: "Shoegaze",
            tracks: [Self.makeLibraryTrack(1, title: "Alison", artist: "Slowdive", album: "Souvlaki")]
        )
        let favorites = LocalPlaylist(
            id: "favorites",
            title: "Favorites",
            tracks: [Self.makeLibraryTrack(2, title: "Joga", artist: "Bjork", album: "Homogenic")]
        )
        let archive = LocalPlaylist(
            id: "archive",
            title: "Archive",
            tracks: [Self.makeLibraryTrack(3, title: "Xtal", artist: "Aphex Twin", album: "Selected Ambient Works 85-92")]
        )

        XCTAssertEqual(
            PlaylistTargetMenuBuilder.targetPlaylists([favorites, shoegaze, archive], excludingPlaylistID: "shoegaze").map(\.id),
            ["favorites", "archive"]
        )
    }

    @MainActor
    func testLocalPlaylistsRenameRemoveAndDeleteWithoutTouchingLikedTracks() {
        let defaults = Self.makeIsolatedDefaults(name: "local-playlists-edit")
        let tracks = [
            Self.makeLibraryTrack(1, title: "Digital Bath", artist: "Deftones", album: "White Pony"),
            Self.makeLibraryTrack(2, title: "Joga", artist: "Bjork", album: "Homogenic")
        ]
        let store = PlayerStore(provider: PrewarmRecordingProvider(tracks: tracks), userDefaults: defaults)
        let playlist = store.createPlaylist(title: "Late Night", tracks: tracks)

        store.toggleLike(tracks[0])
        store.renamePlaylist(playlistID: playlist.id, title: "After Dark")
        store.removeFromPlaylist(tracks[0], playlistID: playlist.id)

        XCTAssertEqual(store.localPlaylists.first?.title, "After Dark")
        XCTAssertEqual(store.playlistTracks(playlistID: playlist.id), [tracks[1]])
        XCTAssertTrue(store.isLiked(tracks[0]))

        store.deletePlaylist(playlistID: playlist.id)

        XCTAssertTrue(store.localPlaylists.isEmpty)
        XCTAssertEqual(store.likedTracks(), [tracks[0]])
    }

    @MainActor
    func testCreatePlaylistWithSingleTrackUsesProvidedNameAndPersistsSnapshot() {
        let defaults = Self.makeIsolatedDefaults(name: "local-playlists-single-track")
        let track = Self.makeLibraryTrack(1, title: "Heaven or Las Vegas", artist: "Cocteau Twins", album: "Heaven or Las Vegas")
        let store = PlayerStore(provider: PrewarmRecordingProvider(tracks: [track]), userDefaults: defaults)

        let playlist = store.createPlaylist(title: "  New Light  ", track: track)

        XCTAssertEqual(playlist.title, "New Light")
        XCTAssertEqual(store.localPlaylists.map(\.id), [playlist.id])
        XCTAssertEqual(store.playlistTracks(playlistID: playlist.id), [track])

        let restoredStore = PlayerStore(provider: PrewarmRecordingProvider(tracks: []), userDefaults: defaults)

        XCTAssertEqual(restoredStore.playlistTracks(playlistID: playlist.id), [track])
    }

    @MainActor
    func testVolumeIsClampedAndForwardedToProvider() {
        let provider = PrewarmRecordingProvider(tracks: [])
        let store = PlayerStore(provider: provider)

        store.setVolume(1.4)
        XCTAssertEqual(store.volume, 1)
        XCTAssertEqual(provider.recordedVolume, 1)

        store.setVolume(-0.2)
        XCTAssertEqual(store.volume, 0)
        XCTAssertEqual(provider.recordedVolume, 0)
    }

    @MainActor
    func testMuteRestoresLastAudibleVolume() {
        let provider = PrewarmRecordingProvider(tracks: [])
        let store = PlayerStore(provider: provider)

        store.setVolume(0.42)
        store.toggleMute()
        XCTAssertEqual(store.volume, 0)
        XCTAssertEqual(provider.recordedVolume, 0)

        store.toggleMute()
        XCTAssertEqual(store.volume, 0.42)
        XCTAssertEqual(provider.recordedVolume, 0.42)
    }

    @MainActor
    func testVolumePersistsAcrossStoreInstancesAndIconTracksState() {
        let defaults = Self.makeIsolatedDefaults(name: "volume-persistence")
        let provider = PrewarmRecordingProvider(tracks: [])
        let store = PlayerStore(provider: provider, userDefaults: defaults)

        store.setVolume(0.31)

        let restoredStore = PlayerStore(provider: PrewarmRecordingProvider(tracks: []), userDefaults: defaults)

        XCTAssertEqual(restoredStore.volume, 0.31, accuracy: 0.001)
        XCTAssertEqual(VolumeIcon.symbol(for: 0), "speaker.slash.fill")
        XCTAssertEqual(VolumeIcon.symbol(for: 0.18), "speaker.wave.1.fill")
        XCTAssertEqual(VolumeIcon.symbol(for: 0.52), "speaker.wave.2.fill")
        XCTAssertEqual(VolumeIcon.symbol(for: 0.9), "speaker.wave.3.fill")
    }

    @MainActor
    func testEqualizerAndCrossfadeSettingsForwardToProvider() {
        let provider = PrewarmRecordingProvider(tracks: [])
        let store = PlayerStore(provider: provider)

        store.setEqualizerEnabled(true)
        store.setEqualizerPreset(.bassBoost)
        XCTAssertEqual(store.equalizerSettings.preset, .bassBoost)
        XCTAssertEqual(provider.recordedEqualizerSettings?.preset, .bassBoost)
        XCTAssertEqual(provider.recordedEqualizerSettings?.normalizedBandGains, EqualizerPreset.bassBoost.bandGains)

        store.setEqualizerBand(at: 0, gain: 8)
        XCTAssertEqual(store.equalizerSettings.normalizedBandGains[0], 8)
        XCTAssertEqual(provider.recordedEqualizerSettings?.normalizedBandGains[0], 8)

        store.setCrossfadeDuration(4.5)
        XCTAssertEqual(store.crossfadeDuration, 4.5, accuracy: 0.001)
        XCTAssertEqual(provider.recordedCrossfadeDuration ?? -1, 4.5, accuracy: 0.001)
    }

    @MainActor
    func testRepeatOneReplaysCurrentTrackOnNext() async throws {
        let tracks = (1...3).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        store.play(tracks[1])
        try await Task.sleep(for: .milliseconds(80))
        store.cycleRepeatMode()
        store.cycleRepeatMode()
        store.next()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(store.repeatMode, .one)
        XCTAssertEqual(Array(provider.playedIDs.suffix(2)), [tracks[1].id, tracks[1].id])
    }

    @MainActor
    func testShuffleQueueExcludesCurrentTrack() async throws {
        let tracks = (1...5).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.toggleShuffle()

        XCTAssertTrue(store.isShuffled)
        XCTAssertFalse(store.queue.contains(tracks[0]))
        XCTAssertEqual(Set(store.queue).count, store.queue.count)
    }

    @MainActor
    func testPlayAllQueuesRemainingTracks() async throws {
        let tracks = (1...4).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        store.playAll(tracks)
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(provider.playedIDs.last, tracks[0].id)
        XCTAssertEqual(store.queue, Array(tracks.dropFirst()))
    }

    @MainActor
    func testPlaylistPlaybackContextRepeatsWithinPlaylistOrder() async throws {
        let tracks = (1...4).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)
        let playlist = store.createPlaylist(title: "Night Drive", tracks: [tracks[1], tracks[2]])

        await store.bootstrap()
        store.cycleRepeatMode()
        store.playAll(store.playlistTracks(playlistID: playlist.id))
        try await Task.sleep(for: .milliseconds(80))
        store.next()
        try await Task.sleep(for: .milliseconds(80))
        store.next()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(store.repeatMode, .all)
        XCTAssertEqual(Array(provider.playedIDs.suffix(3)), [tracks[1].id, tracks[2].id, tracks[1].id])
    }

    @MainActor
    func testPlaylistPreviousUsesPlaylistOrderInsteadOfVisibleCatalog() async throws {
        let tracks = (1...4).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)
        let playlist = store.createPlaylist(title: "Sequenced", tracks: [tracks[1], tracks[2]])

        await store.bootstrap()
        store.cycleRepeatMode()
        store.playAll(store.playlistTracks(playlistID: playlist.id))
        try await Task.sleep(for: .milliseconds(80))
        store.previous()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(Array(provider.playedIDs.suffix(2)), [tracks[1].id, tracks[2].id])
    }

    @MainActor
    func testActivatingVisibleListTrackQueuesVisibleListOrder() async throws {
        let tracks = (1...4).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)
        let visiblePlaylistOrder = [tracks[0], tracks[2], tracks[1], tracks[3]]

        await store.bootstrap()
        store.activate(tracks[2], in: visiblePlaylistOrder)
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(provider.playedIDs.last, tracks[2].id)
        XCTAssertEqual(store.queue, [tracks[1], tracks[3]])
    }

    @MainActor
    func testQueueAllDeduplicatesAndSkipsCurrentTrack() async throws {
        let tracks = (1...4).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        store.play(tracks[0])
        try await Task.sleep(for: .milliseconds(80))
        store.enqueue([tracks[0], tracks[1], tracks[1], tracks[2]])

        XCTAssertEqual(store.queue, [tracks[1], tracks[2]])
    }

    func testQueueSearchFilterMatchesTitleArtistAndAlbum() {
        let radiohead = Self.makeLibraryTrack(1, title: "Everything In Its Right Place", artist: "Radiohead", album: "Kid A")
        let cocteau = Self.makeLibraryTrack(2, title: "Cherry-Coloured Funk", artist: "Cocteau Twins", album: "Heaven or Las Vegas")
        let deftones = Self.makeLibraryTrack(3, title: "Digital Bath", artist: "Deftones", album: "White Pony")

        XCTAssertEqual(
            QueueSearchFilter.filteredTracks([radiohead, cocteau, deftones], query: "kid").map(\.id),
            [radiohead.id]
        )
        XCTAssertEqual(
            QueueSearchFilter.filteredTracks([radiohead, cocteau, deftones], query: "cocteau").map(\.id),
            [cocteau.id]
        )
        XCTAssertEqual(
            QueueSearchFilter.filteredTracks([radiohead, cocteau, deftones], query: "digital").map(\.id),
            [deftones.id]
        )
    }

    @MainActor
    func testMoveQueueItemReordersQueueWithoutDuplicatingTracks() async throws {
        let tracks = (1...5).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        store.play(tracks[0])
        try await Task.sleep(for: .milliseconds(80))
        store.enqueue([tracks[1], tracks[2], tracks[3], tracks[4]])

        store.moveQueueItem(tracks[3], before: tracks[1])
        XCTAssertEqual(store.queue, [tracks[3], tracks[1], tracks[2], tracks[4]])
        XCTAssertEqual(Set(store.queue).count, store.queue.count)

        store.moveQueueItem(tracks[1], before: nil)
        XCTAssertEqual(store.queue, [tracks[3], tracks[2], tracks[4], tracks[1]])
        XCTAssertEqual(Set(store.queue).count, store.queue.count)
    }

    @MainActor
    func testPlayNextMovesTrackToFrontWithoutDuplicatingQueue() async throws {
        let tracks = (1...4).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        store.play(tracks[0])
        try await Task.sleep(for: .milliseconds(80))
        store.enqueue([tracks[1], tracks[2]])
        store.playNext(tracks[3])
        store.playNext(tracks[1])

        XCTAssertEqual(store.queue, [tracks[1], tracks[3], tracks[2]])
    }

    @MainActor
    func testUnavailableTrackFailureDoesNotSurfaceGlobalError() async throws {
        let track = Self.makePlaybackTrack(1)
        let provider = PrewarmRecordingProvider(tracks: [track], playError: MusicProviderError.trackUnavailable)
        let store = PlayerStore(provider: provider, userDefaults: Self.makeIsolatedDefaults(name: "unavailable-track"))

        await store.bootstrap()
        store.play(track)
        try await Task.sleep(for: .milliseconds(80))

        if case .failed(let message) = store.playbackState {
            XCTAssertEqual(message, MusicProviderError.trackUnavailable.localizedDescription)
        } else {
            XCTFail("Expected playback to fail for unavailable tracks.")
        }
        XCTAssertNil(store.errorMessage)
    }

    @MainActor
    func testPreviousUsesVisibleSearchContext() async throws {
        let tracks = (1...4).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        store.updateSearchQuery("album context")
        try await Task.sleep(for: .milliseconds(260))
        store.activate(tracks[2])
        try await Task.sleep(for: .milliseconds(80))
        store.previous()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(Array(provider.playedIDs.suffix(2)), [tracks[2].id, tracks[1].id])
    }

    @MainActor
    func testLikedTracksPersistAcrossStoreInstances() async {
        let defaults = Self.makeIsolatedDefaults(name: "liked-persistence")
        let track = Self.makePlaybackTrack(1)
        let provider = PrewarmRecordingProvider(tracks: [track])
        let store = PlayerStore(provider: provider, userDefaults: defaults)

        store.toggleLike(track)

        let restoredStore = PlayerStore(provider: provider, userDefaults: defaults)
        await restoredStore.bootstrap()
        XCTAssertTrue(restoredStore.isLiked(track))
        XCTAssertEqual(restoredStore.likedTracks(), [track])
    }

    @MainActor
    func testLikedTracksRestoreSavedTrackSnapshotWithoutProviderCatalog() async {
        let defaults = Self.makeIsolatedDefaults(name: "liked-snapshot")
        let track = Self.makeLibraryTrack(1, title: "Saved Song", artist: "Saved Artist", album: "Saved Album")
        let store = PlayerStore(provider: PrewarmRecordingProvider(tracks: [track]), userDefaults: defaults)

        await store.bootstrap()
        store.toggleLike(track)

        let restoredStore = PlayerStore(provider: PrewarmRecordingProvider(tracks: []), userDefaults: defaults)
        await restoredStore.bootstrap()

        XCTAssertTrue(restoredStore.isLiked(track))
        XCTAssertEqual(restoredStore.likedTracks(), [track])
    }

    @MainActor
    func testLikedTracksReturnNewestFirstAcrossStoreInstances() async {
        let defaults = Self.makeIsolatedDefaults(name: "liked-order")
        let tracks = (1...3).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider, userDefaults: defaults)

        await store.bootstrap()
        store.toggleLike(tracks[0])
        store.toggleLike(tracks[1])
        store.toggleLike(tracks[2])

        XCTAssertEqual(store.likedTracks(limit: 3), [tracks[2], tracks[1], tracks[0]])

        store.toggleLike(tracks[1])
        XCTAssertEqual(store.likedTracks(limit: 3), [tracks[2], tracks[0]])

        let restoredStore = PlayerStore(provider: provider, userDefaults: defaults)
        await restoredStore.bootstrap()

        XCTAssertEqual(restoredStore.likedTracks(limit: 3), [tracks[2], tracks[0]])
    }

    @MainActor
    func testStartWavePrioritizesLikedTracksAndRelatedArtists() async throws {
        let liked = Self.makePlaybackTrack(1, artist: "Daft Punk", album: "Homework", rank: 10)
        let related = Self.makePlaybackTrack(2, artist: "Daft Punk", album: "Discovery", rank: 5)
        let popularUnrelated = Self.makePlaybackTrack(3, artist: "Nirvana", album: "Nevermind", rank: 900_000)
        let tracks = [popularUnrelated, related, liked]
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider, userDefaults: Self.makeIsolatedDefaults(name: "wave-liked"))

        await store.bootstrap()
        store.toggleLike(liked)
        store.startWave()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(provider.playedIDs.last, liked.id)
        XCTAssertEqual(store.queue.first, related)
    }

    @MainActor
    func testListeningHistoryInfluencesWaveQueue() async throws {
        let repeatedArtist = Self.makePlaybackTrack(1, artist: "Justice", album: "Cross", rank: 10)
        let sameArtist = Self.makePlaybackTrack(2, artist: "Justice", album: "Audio Video Disco", rank: 10)
        let unrelated = Self.makePlaybackTrack(3, artist: "Slowdive", album: "Souvlaki", rank: 900_000)
        let tracks = [unrelated, sameArtist, repeatedArtist]
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider, userDefaults: Self.makeIsolatedDefaults(name: "wave-history"))

        await store.bootstrap()
        store.play(repeatedArtist)
        try await Task.sleep(for: .milliseconds(80))
        store.clearQueue()
        store.startWave()
        try await Task.sleep(for: .milliseconds(80))

        XCTAssertEqual(provider.playedIDs.last, repeatedArtist.id)
        XCTAssertEqual(store.queue.first, sameArtist)
    }

    private static func makeIsolatedDefaults(name: String) -> UserDefaults {
        let suiteName = "NoirwaveTests.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    fileprivate static func makePlaybackTrack(
        _ index: Int,
        title: String? = nil,
        artist: String = "Artist",
        album: String = "Album",
        rank: Int? = nil
    ) -> Track {
        Track(
            id: "deemix-api.\(1000 + index)",
            title: title ?? "Track \(index)",
            artist: artist,
            album: album,
            duration: 180,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/\(1000 + index)",
            previewURL: nil,
            rank: rank
        )
    }

    private static func makeLibraryTrack(
        _ index: Int,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval = 180,
        trackPosition: Int? = nil
    ) -> Track {
        Track(
            id: "library-track.\(index)",
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/\(index)",
            previewURL: nil,
            rank: nil,
            trackPosition: trackPosition
        )
    }

    private static func makeAlbum(
        id: String,
        title: String,
        trackCount: Int,
        releaseDate: String,
        recordType: String
    ) -> Track {
        Track(
            id: "deemix-album.\(id)",
            title: title,
            artist: "Nirvana",
            album: "Album",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/album/\(id)",
            previewURL: nil,
            kind: .album,
            trackCount: trackCount,
            releaseDate: releaseDate,
            recordType: recordType
        )
    }

    private static func makeArtist(id: String, title: String, albumCount: Int) -> Track {
        Track(
            id: "deemix-artist.\(id)",
            title: title,
            artist: title,
            album: "Artist",
            duration: 0,
            palette: .fallback,
            catalogID: "https://www.deezer.com/artist/\(id)",
            previewURL: nil,
            kind: .artist,
            albumCount: albumCount
        )
    }
}

@MainActor
private final class PrewarmRecordingProvider: MusicProviding {
    let sourceName = "Prewarm Test"
    private let tracks: [Track]
    private let playError: Error?
    private(set) var preparedBatches: [[String]] = []
    private(set) var recordedVolume: Double?
    private(set) var recordedEqualizerSettings: EqualizerSettings?
    private(set) var recordedCrossfadeDuration: TimeInterval?
    private(set) var playedIDs: [String] = []
    private(set) var crossfadedIDs: [String] = []

    init(tracks: [Track], playError: Error? = nil) {
        self.tracks = tracks
        self.playError = playError
    }

    func featuredTracks() async throws -> [Track] {
        tracks
    }

    func search(_ query: String, scope: SearchScope) async throws -> [Track] {
        tracks
    }

    func catalogItems(for item: Track) async throws -> [Track] {
        tracks
    }

    func radioTracks(seed: Track?) async throws -> [Track] {
        tracks
    }

    func requestAuthorization() async throws -> ProviderStatus {
        ProviderStatus(authorization: .authorized, canPlayCatalogContent: true, message: nil)
    }

    func currentStatus() async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func configureBackendSession(arl: String) async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func lyrics(for track: Track) async throws -> TrackLyrics {
        TrackLyrics(text: "", lines: [], copyright: nil, writers: nil)
    }

    func prepare(_ tracks: [Track]) async {
        preparedBatches.append(tracks.map(\.id))
    }

    func play(_ track: Track) async throws {
        if let playError {
            throw playError
        }
        playedIDs.append(track.id)
    }

    func resume() async throws {}

    func pause() async {}

    func stop() async {}

    func seek(to time: TimeInterval) async {}

    func setVolume(_ volume: Double) {
        recordedVolume = volume
    }

    func setEqualizer(_ settings: EqualizerSettings) {
        recordedEqualizerSettings = settings
    }

    func setCrossfadeDuration(_ duration: TimeInterval) {
        recordedCrossfadeDuration = duration
    }

    func crossfade(to track: Track, duration: TimeInterval) async throws {
        crossfadedIDs.append(track.id)
    }

    func currentPlaybackTime() -> TimeInterval? {
        nil
    }
}

@MainActor
private final class LyricsCacheRecordingProvider: MusicProviding {
    let sourceName = "Lyrics Cache Test"
    let lyricsByTrackID: [String: TrackLyrics]
    private(set) var lyricsRequests: [String] = []

    init(lyricsByTrackID: [String: TrackLyrics]) {
        self.lyricsByTrackID = lyricsByTrackID
    }

    func featuredTracks() async throws -> [Track] {
        []
    }

    func search(_ query: String, scope: SearchScope) async throws -> [Track] {
        []
    }

    func catalogItems(for item: Track) async throws -> [Track] {
        []
    }

    func radioTracks(seed: Track?) async throws -> [Track] {
        []
    }

    func requestAuthorization() async throws -> ProviderStatus {
        ProviderStatus(authorization: .authorized, canPlayCatalogContent: true, message: nil)
    }

    func currentStatus() async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func configureBackendSession(arl: String) async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func lyrics(for track: Track) async throws -> TrackLyrics {
        lyricsRequests.append(track.id)
        try await Task.sleep(for: .milliseconds(40))
        return lyricsByTrackID[track.id] ?? TrackLyrics(text: "", lines: [], copyright: nil, writers: nil)
    }

    func prepare(_ tracks: [Track]) async {}

    func play(_ track: Track) async throws {}

    func resume() async throws {}

    func pause() async {}

    func stop() async {}

    func seek(to time: TimeInterval) async {}

    func setVolume(_ volume: Double) {}

    func currentPlaybackTime() -> TimeInterval? {
        nil
    }
}

@MainActor
private final class SearchCacheRecordingProvider: MusicProviding {
    struct QueryRecord {
        let query: String
        let scope: SearchScope
    }

    let sourceName = "Search Cache Test"
    private let featured: [Track]
    private let resultsByQuery: [String: [Track]]
    private let searchDelay: Duration
    private(set) var recordedQueries: [QueryRecord] = []
    private(set) var playedIDs: [String] = []
    private(set) var seekTimes: [TimeInterval] = []

    init(featured: [Track], resultsByQuery: [String: [Track]], searchDelay: Duration) {
        self.featured = featured
        self.resultsByQuery = resultsByQuery
        self.searchDelay = searchDelay
    }

    func featuredTracks() async throws -> [Track] {
        featured
    }

    func search(_ query: String, scope: SearchScope) async throws -> [Track] {
        recordedQueries.append(QueryRecord(query: query, scope: scope))
        try await Task.sleep(for: searchDelay)
        return resultsByQuery[query] ?? []
    }

    func catalogItems(for item: Track) async throws -> [Track] {
        []
    }

    func radioTracks(seed: Track?) async throws -> [Track] {
        featured
    }

    func requestAuthorization() async throws -> ProviderStatus {
        ProviderStatus(authorization: .authorized, canPlayCatalogContent: true, message: nil)
    }

    func currentStatus() async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func configureBackendSession(arl: String) async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func lyrics(for track: Track) async throws -> TrackLyrics {
        TrackLyrics(text: "", lines: [], copyright: nil, writers: nil)
    }

    func prepare(_ tracks: [Track]) async {}

    func play(_ track: Track) async throws {
        playedIDs.append(track.id)
    }

    func resume() async throws {}

    func pause() async {}

    func stop() async {}

    func seek(to time: TimeInterval) async {
        seekTimes.append(time)
    }

    func setVolume(_ volume: Double) {}

    func currentPlaybackTime() -> TimeInterval? {
        nil
    }
}

@MainActor
private final class CancelledSearchProvider: MusicProviding {
    let sourceName = "Cancelled Search Test"
    private var searchCount = 0

    func featuredTracks() async throws -> [Track] {
        []
    }

    func search(_ query: String, scope: SearchScope) async throws -> [Track] {
        searchCount += 1
        if searchCount == 1 {
            try await Task.sleep(for: .milliseconds(500))
            throw MusicProviderError.providerNotReady("catalog_cli exited with code 1")
        }

        return [DeemixAPITrackMapperTests.makePlaybackTrack(1)]
    }

    func catalogItems(for item: Track) async throws -> [Track] {
        []
    }

    func radioTracks(seed: Track?) async throws -> [Track] {
        []
    }

    func requestAuthorization() async throws -> ProviderStatus {
        ProviderStatus(authorization: .authorized, canPlayCatalogContent: true, message: nil)
    }

    func currentStatus() async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func configureBackendSession(arl: String) async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func lyrics(for track: Track) async throws -> TrackLyrics {
        TrackLyrics(text: "", lines: [], copyright: nil, writers: nil)
    }

    func prepare(_ tracks: [Track]) async {}

    func play(_ track: Track) async throws {}

    func resume() async throws {}

    func pause() async {}

    func stop() async {}

    func seek(to time: TimeInterval) async {}

    func setVolume(_ volume: Double) {}

    func currentPlaybackTime() -> TimeInterval? {
        nil
    }
}

@MainActor
private final class ScopeRecordingProvider: MusicProviding {
    let sourceName = "Scope Recording Test"
    private let results: [Track]
    private(set) var recordedScopes: [SearchScope] = []

    init(results: [Track]) {
        self.results = results
    }

    func featuredTracks() async throws -> [Track] {
        []
    }

    func search(_ query: String, scope: SearchScope) async throws -> [Track] {
        recordedScopes.append(scope)
        return results
    }

    func catalogItems(for item: Track) async throws -> [Track] {
        []
    }

    func radioTracks(seed: Track?) async throws -> [Track] {
        results
    }

    func requestAuthorization() async throws -> ProviderStatus {
        ProviderStatus(authorization: .authorized, canPlayCatalogContent: true, message: nil)
    }

    func currentStatus() async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func configureBackendSession(arl: String) async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func lyrics(for track: Track) async throws -> TrackLyrics {
        TrackLyrics(text: "", lines: [], copyright: nil, writers: nil)
    }

    func prepare(_ tracks: [Track]) async {}

    func play(_ track: Track) async throws {}

    func resume() async throws {}

    func pause() async {}

    func stop() async {}

    func seek(to time: TimeInterval) async {}

    func setVolume(_ volume: Double) {}

    func currentPlaybackTime() -> TimeInterval? {
        nil
    }
}

@MainActor
private final class CatalogDrillRecordingProvider: MusicProviding {
    let sourceName = "Catalog Drill Test"
    private let featuredItems: [Track]
    private let detailItems: [Track]
    private let searchItems: [Track]
    private(set) var searchCalls = 0
    private(set) var catalogItemsCalls = 0

    init(featuredItems: [Track] = [], detailItems: [Track], searchItems: [Track] = []) {
        self.featuredItems = featuredItems
        self.detailItems = detailItems
        self.searchItems = searchItems
    }

    func featuredTracks() async throws -> [Track] {
        featuredItems
    }

    func search(_ query: String, scope: SearchScope) async throws -> [Track] {
        searchCalls += 1
        return searchItems
    }

    func catalogItems(for item: Track) async throws -> [Track] {
        catalogItemsCalls += 1
        try await Task.sleep(for: .milliseconds(120))
        return detailItems
    }

    func radioTracks(seed: Track?) async throws -> [Track] {
        detailItems
    }

    func requestAuthorization() async throws -> ProviderStatus {
        ProviderStatus(authorization: .authorized, canPlayCatalogContent: true, message: nil)
    }

    func currentStatus() async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func configureBackendSession(arl: String) async throws -> ProviderStatus {
        try await requestAuthorization()
    }

    func lyrics(for track: Track) async throws -> TrackLyrics {
        TrackLyrics(text: "", lines: [], copyright: nil, writers: nil)
    }

    func prepare(_ tracks: [Track]) async {}

    func play(_ track: Track) async throws {}

    func resume() async throws {}

    func pause() async {}

    func stop() async {}

    func seek(to time: TimeInterval) async {}

    func setVolume(_ volume: Double) {}

    func currentPlaybackTime() -> TimeInterval? {
        nil
    }
}
