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
        let expectedIDs = tracks.dropFirst().map(\.id)
        XCTAssertEqual(preparedIDs, expectedIDs)
    }

    @MainActor
    func testCancelledSearchDoesNotSurfaceProviderError() async throws {
        let provider = CancelledSearchProvider()
        let store = PlayerStore(provider: provider)

        await store.bootstrap()
        store.updateSearchQuery("first")
        try await Task.sleep(for: .milliseconds(240))
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
        XCTAssertTrue(store.visibleTracks.isEmpty)
        XCTAssertTrue(store.isSearching)

        try await Task.sleep(for: .milliseconds(240))

        XCTAssertEqual(provider.searchCalls, 0)
        XCTAssertEqual(provider.catalogItemsCalls, 1)
        XCTAssertEqual(store.catalogContext, artist)
        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)
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
        try await Task.sleep(for: .milliseconds(240))
        XCTAssertEqual(store.visibleTracks, [artist, searchTrack])

        store.activate(artist)

        XCTAssertEqual(store.searchQuery, "nirvana")
        XCTAssertEqual(store.catalogContext, artist)
        XCTAssertEqual(store.visibleTracks, [searchTrack])
        XCTAssertTrue(store.isSearching)

        try await Task.sleep(for: .milliseconds(240))

        XCTAssertEqual(provider.searchCalls, 1)
        XCTAssertEqual(provider.catalogItemsCalls, 1)
        XCTAssertEqual(store.visibleTracks, [detailTrack])
        XCTAssertFalse(store.isSearching)
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
            tracklist: "https://api.deezer.com/artist/415/top?limit=50"
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
        XCTAssertEqual(SearchScope.playlists.rawValue, "Albums")
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

        try await Task.sleep(for: .milliseconds(260))

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
    func testQueueAllDeduplicatesAndSkipsCurrentTrack() async throws {
        let tracks = (1...4).map { Self.makePlaybackTrack($0) }
        let provider = PrewarmRecordingProvider(tracks: tracks)
        let store = PlayerStore(provider: provider)

        store.play(tracks[0])
        try await Task.sleep(for: .milliseconds(80))
        store.enqueue([tracks[0], tracks[1], tracks[1], tracks[2]])

        XCTAssertEqual(store.queue, [tracks[1], tracks[2]])
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
        artist: String = "Artist",
        album: String = "Album",
        rank: Int? = nil
    ) -> Track {
        Track(
            id: "deemix-api.\(1000 + index)",
            title: "Track \(index)",
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
        album: String
    ) -> Track {
        Track(
            id: "library-track.\(index)",
            title: title,
            artist: artist,
            album: album,
            duration: 180,
            palette: .fallback,
            catalogID: "https://www.deezer.com/track/\(index)",
            previewURL: nil,
            rank: nil
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
}

@MainActor
    private final class PrewarmRecordingProvider: MusicProviding {
    let sourceName = "Prewarm Test"
    private let tracks: [Track]
    private let playError: Error?
    private(set) var preparedBatches: [[String]] = []
    private(set) var recordedVolume: Double?
    private(set) var playedIDs: [String] = []

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
    private let detailItems: [Track]
    private let searchItems: [Track]
    private(set) var searchCalls = 0
    private(set) var catalogItemsCalls = 0

    init(detailItems: [Track], searchItems: [Track] = []) {
        self.detailItems = detailItems
        self.searchItems = searchItems
    }

    func featuredTracks() async throws -> [Track] {
        []
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
