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

    func testDoesNotUsePreviewFallbackWhenPreferredBitrateIsUnavailable() {
        let error = MusicProviderError.providerNotReady("The current Deezer session cannot stream 320 kbps.")

        XCTAssertFalse(DeemixAPIPlaybackURLResolver.shouldUsePreviewFallback(after: error))
    }

    func testRequestsHighQualityFullTrackBeforeFreeFallbackBitrate() {
        XCTAssertEqual(DeemixAPIBitrate.fullTrackPlaybackPreferences, [3, 1])
        XCTAssertEqual(DeemixAPIBitrate.displayLabel(for: 3), "320 kbps")
        XCTAssertEqual(DeemixAPIBitrate.displayLabel(for: 1), "128 kbps")
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
        XCTAssertEqual(SearchScope.catalog.rawValue, "Tracks")
        XCTAssertEqual(SearchScope.library.rawValue, "Artists")
        XCTAssertEqual(SearchScope.playlists.rawValue, "Albums")
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
}
