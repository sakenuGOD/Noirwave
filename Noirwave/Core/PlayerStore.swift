import Foundation

@MainActor
final class PlayerStore: ObservableObject {
    @Published private(set) var featuredTracks: [Track] = []
    @Published private(set) var visibleTracks: [Track] = []
    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentTrack: Track?
    @Published private(set) var playbackState: PlaybackState = .idle
    @Published private(set) var lyricsState: LyricsState = .idle
    @Published private(set) var providerStatus = ProviderStatus.disconnected
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingFeaturedTracks = false
    @Published private(set) var isConfiguringBackendSession = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var resultTitle = "Catalog Tracks"
    @Published private(set) var resultSubtitle: String?
    @Published private(set) var catalogContext: Track?
    @Published private(set) var isShuffled = false
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var likedTrackIDs: Set<String> = []
    @Published private(set) var listeningScores: [String: Int] = [:]

    @Published var searchQuery = ""
    @Published var selectedScope: SearchScope = .smart
    @Published var progress: TimeInterval = 0
    @Published var volume: Double = 0.78

    let provider: MusicProviding

    private static let likedTrackIDsKey = "noirwave.likedTrackIDs"
    private static let listeningScoresKey = "noirwave.listeningScores"
    private let playbackContextLimit = 16
    private let userDefaults: UserDefaults
    private var searchTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var lastAudibleVolume: Double = 0.78

    init(provider: MusicProviding, userDefaults: UserDefaults = .standard) {
        self.provider = provider
        self.userDefaults = userDefaults
        likedTrackIDs = Set(userDefaults.stringArray(forKey: Self.likedTrackIDsKey) ?? [])
        listeningScores = (userDefaults.dictionary(forKey: Self.listeningScoresKey) ?? [:]).reduce(into: [:]) { result, item in
            if let score = item.value as? Int {
                result[item.key] = score
            } else if let score = item.value as? NSNumber {
                result[item.key] = score.intValue
            }
        }
    }

    var needsBackendSession: Bool {
        messageNeedsBackendSession(providerStatus.message) || {
            if case .failed(let message) = playbackState {
                return messageNeedsBackendSession(message)
            }

            return false
        }()
    }

    deinit {
        searchTask?.cancel()
        playbackTask?.cancel()
        progressTask?.cancel()
        lyricsTask?.cancel()
        preparationTask?.cancel()
    }

    func bootstrap() async {
        do {
            providerStatus = try await provider.currentStatus()
        } catch {
            providerStatus = .disconnected
            errorMessage = error.localizedDescription
        }

        guard providerStatus.authorization == .authorized,
              providerStatus.canPlayCatalogContent
        else {
            applyFeaturedTracks([])
            return
        }

        await reloadFeaturedTracks()
    }

    func updateSearchQuery(_ query: String) {
        selectedScope = .smart
        searchQuery = query
        scheduleSearch()
    }

    func setScope(_ scope: SearchScope) {
        selectedScope = scope
        scheduleSearch()
    }

    func leaveCatalogContext() {
        guard catalogContext != nil else { return }
        catalogContext = nil
        resultSubtitle = nil

        if searchQuery.trimmed.isEmpty {
            resultTitle = "Catalog Tracks"
            visibleTracks = featuredTracks
        } else {
            resultTitle = SearchScope.smart.resultsTitle
            scheduleSearch()
        }
    }

    func activate(_ item: Track) {
        guard item.isPlayable else {
            drillIntoCatalog(from: item)
            return
        }

        let playbackContext = playbackQueue(after: item, in: visibleTracks, limit: playbackContextLimit)
        queue = playbackContext
        prepare(Array(([item] + playbackContext).prefix(playbackContextLimit)))
        play(item)
    }

    func playAll(_ tracks: [Track]) {
        let playableTracks = uniquePlayableTracks(in: tracks)
        guard let firstTrack = playableTracks.first else { return }

        queue = Array(playableTracks.dropFirst())
        prepare(Array(playableTracks.prefix(playbackContextLimit)))
        play(firstTrack)
    }

    func shufflePlay(_ tracks: [Track]) {
        let playableTracks = uniquePlayableTracks(in: tracks).shuffled()
        guard let firstTrack = playableTracks.first else { return }

        isShuffled = true
        queue = Array(playableTracks.dropFirst())
        prepare(Array(playableTracks.prefix(playbackContextLimit)))
        play(firstTrack)
    }

    func connectProvider() {
        Task {
            do {
                providerStatus = try await provider.requestAuthorization()
                if providerStatus.authorization == .authorized,
                   providerStatus.canPlayCatalogContent {
                    errorMessage = nil
                    await reloadFeaturedTracks()
                } else {
                    applyFeaturedTracks([])
                    errorMessage = providerStatus.message ?? "\(provider.sourceName) is not ready for playback."
                }
            } catch {
                providerStatus.authorization = .denied
                errorMessage = error.localizedDescription
            }
        }
    }

    func configureBackendSession(_ arl: String) {
        let sessionToken = arl

        Task { [weak self] in
            guard let self else { return }

            isConfiguringBackendSession = true
            defer { isConfiguringBackendSession = false }

            do {
                providerStatus = try await provider.configureBackendSession(arl: sessionToken)
                errorMessage = nil

                if case .failed(let message) = playbackState,
                   message.localizedCaseInsensitiveContains("session inactive") {
                    playbackState = .idle
                }

                if providerStatus.authorization == .authorized {
                    await reloadFeaturedTracks()
                }
            } catch {
                let message = error.localizedDescription
                providerStatus.message = message
                errorMessage = message
            }
        }
    }

    func play(_ track: Track) {
        guard track.isPlayable else {
            drillIntoCatalog(from: track)
            return
        }

        playbackTask?.cancel()
        progressTask?.cancel()

        currentTrack = track
        progress = 0
        playbackState = .loading
        errorMessage = nil
        loadLyrics(for: track)

        playbackTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await provider.play(track)
                guard !Task.isCancelled else { return }
                recordListening(track)
                playbackState = .playing
                startProgressTicker()
                preparePlaybackContext()
            } catch {
                guard !Task.isCancelled else { return }
                handlePlaybackFailure(error)
            }
        }
    }

    func togglePlayPause() {
        switch playbackState {
        case .playing:
            pause()
        case .failed(_):
            guard let currentTrack else { return }
            play(currentTrack)
        case .paused, .idle:
            guard let currentTrack else { return }
            if progress > 0 {
                resume()
            } else {
                play(currentTrack)
            }
        case .loading:
            break
        }
    }

    func pause() {
        progressTask?.cancel()
        playbackState = .paused

        Task {
            await provider.pause()
        }
    }

    func resume() {
        guard currentTrack != nil else { return }
        playbackState = .loading

        playbackTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await provider.resume()
                guard !Task.isCancelled else { return }
                playbackState = .playing
                startProgressTicker()
            } catch {
                handlePlaybackFailure(error)
            }
        }
    }

    func next() {
        if repeatMode == .one, let currentTrack {
            prepare([currentTrack])
            play(currentTrack)
            return
        }

        if !queue.isEmpty {
            let nextTrack = queue.removeFirst()
            prepare(Array(([nextTrack] + queue).prefix(playbackContextLimit)))
            play(nextTrack)
            refillQueue(after: nextTrack)
            return
        }

        if isShuffled,
           let nextTrack = shuffledPlaybackCandidates(excluding: currentTrack).first {
            queue = Array(shuffledPlaybackCandidates(excluding: nextTrack).prefix(playbackContextLimit))
            prepare(Array(([nextTrack] + queue).prefix(playbackContextLimit)))
            play(nextTrack)
            return
        }

        let context = currentPlaybackContext
        guard let currentTrack,
              let index = context.firstIndex(of: currentTrack),
              !context.isEmpty
        else {
            if repeatMode == .all,
               let nextTrack = context.first(where: \.isPlayable) {
                play(nextTrack)
            }
            return
        }

        let isLastTrack = context.index(after: index) == context.endIndex
        guard !isLastTrack || repeatMode == .all else {
            playbackState = .idle
            progress = 0
            return
        }

        let nextIndex = isLastTrack ? context.startIndex : context.index(after: index)
        let nextTrack = context[nextIndex]
        prepare([nextTrack] + playbackQueue(after: nextTrack, in: context, limit: playbackContextLimit - 1))
        play(nextTrack)
    }

    func previous() {
        guard progress < 4 else {
            progress = 0
            Task {
                await provider.seek(to: 0)
            }
            return
        }

        let context = currentPlaybackContext
        guard let currentTrack,
              let index = context.firstIndex(of: currentTrack),
              !context.isEmpty
        else {
            progress = 0
            Task {
                await provider.seek(to: 0)
            }
            return
        }

        let isFirstTrack = index == context.startIndex
        guard !isFirstTrack || repeatMode == .all else {
            progress = 0
            Task {
                await provider.seek(to: 0)
            }
            return
        }

        let previousIndex = isFirstTrack ? context.index(before: context.endIndex) : context.index(before: index)
        let previousTrack = context[previousIndex]
        prepare([previousTrack] + playbackQueue(after: previousTrack, in: context, limit: playbackContextLimit - 1))
        play(previousTrack)
    }

    func enqueue(_ track: Track) {
        guard track.isPlayable,
              !queue.contains(track),
              track != currentTrack
        else { return }
        queue.append(track)
        preparePlaybackContext()
    }

    func playNext(_ track: Track) {
        guard track.isPlayable,
              track != currentTrack
        else { return }

        queue.removeAll { $0 == track }
        queue.insert(track, at: queue.startIndex)
        preparePlaybackContext()
    }

    func enqueue(_ tracks: [Track]) {
        let playableTracks = uniquePlayableTracks(in: tracks)
        guard !playableTracks.isEmpty else { return }

        for track in playableTracks {
            guard track != currentTrack,
                  !queue.contains(track)
            else { continue }

            queue.append(track)
        }

        preparePlaybackContext()
    }

    func playNext(_ tracks: [Track]) {
        let playableTracks = uniquePlayableTracks(in: tracks)
            .filter { $0 != currentTrack }
        guard !playableTracks.isEmpty else { return }

        let nextIDs = Set(playableTracks.map(\.id))
        queue.removeAll { nextIDs.contains($0.id) }
        queue.insert(contentsOf: playableTracks, at: queue.startIndex)
        preparePlaybackContext()
    }

    func isLiked(_ track: Track) -> Bool {
        likedTrackIDs.contains(track.id)
    }

    func toggleLike(_ track: Track) {
        guard track.isPlayable else { return }

        if likedTrackIDs.contains(track.id) {
            likedTrackIDs.remove(track.id)
        } else {
            likedTrackIDs.insert(track.id)
        }

        persistLikedTracks()
    }

    func likedTracks(limit: Int = 12) -> [Track] {
        Array(
            knownPlaybackTracks
                .filter { likedTrackIDs.contains($0.id) }
                .prefix(limit)
        )
    }

    func startWave() {
        let wave = smartWaveTracks(limit: playbackContextLimit)
        guard let firstTrack = wave.first else { return }

        queue = Array(wave.dropFirst())
        prepare(Array(wave.prefix(playbackContextLimit)))
        play(firstTrack)
    }

    func removeFromQueue(_ track: Track) {
        queue.removeAll { $0 == track }
        preparePlaybackContext()
    }

    func moveQueueItem(_ track: Track, before target: Track?) {
        guard let currentIndex = queue.firstIndex(of: track) else { return }
        let movedTrack = queue.remove(at: currentIndex)

        if let target,
           let targetIndex = queue.firstIndex(of: target) {
            queue.insert(movedTrack, at: targetIndex)
        } else {
            queue.append(movedTrack)
        }

        preparePlaybackContext()
    }

    func clearQueue() {
        queue.removeAll()
        preparePlaybackContext()
    }

    func toggleShuffle() {
        isShuffled.toggle()
        guard isShuffled else {
            guard let currentTrack else { return }
            queue = playbackQueue(after: currentTrack, in: currentPlaybackContext, limit: playbackContextLimit)
            preparePlaybackContext()
            return
        }

        queue = Array(shuffledPlaybackCandidates(excluding: currentTrack).prefix(playbackContextLimit))
        preparePlaybackContext()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    func seek(to fraction: Double) {
        guard let duration = currentTrack?.duration else { return }
        progress = min(max(fraction, 0), 1) * duration

        let targetTime = progress
        Task {
            await provider.seek(to: targetTime)
        }
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        if volume > 0 {
            lastAudibleVolume = volume
        }
        provider.setVolume(volume)
    }

    func toggleMute() {
        if volume > 0 {
            setVolume(0)
        } else {
            setVolume(max(lastAudibleVolume, 0.1))
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self, !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func runSearch() async {
        let term = searchQuery.trimmed
        let scope = SearchScope.smart

        guard !term.isEmpty else {
            isSearching = false
            errorMessage = nil
            resultTitle = "Catalog Tracks"
            resultSubtitle = nil
            catalogContext = nil
            visibleTracks = featuredTracks
            preparePlaybackContext()
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await provider.search(term, scope: scope)
            guard !Task.isCancelled,
                  term == searchQuery.trimmed
            else { return }
            visibleTracks = results
            resultTitle = scope.resultsTitle
            resultSubtitle = nil
            catalogContext = nil
            errorMessage = nil
            preparePlaybackContext()
        } catch {
            guard !Task.isCancelled else { return }
            visibleTracks = []
            resultTitle = scope.resultsTitle
            resultSubtitle = nil
            catalogContext = nil
            errorMessage = error.localizedDescription
        }
    }

    private func drillIntoCatalog(from item: Track) {
        searchTask?.cancel()
        selectedScope = .catalog
        let optimisticItems = optimisticCatalogItems(for: item, in: visibleTracks)
        resultTitle = item.title
        resultSubtitle = item.detailLabel
        catalogContext = item
        visibleTracks = optimisticItems
        isSearching = true
        errorMessage = nil

        searchTask = Task { [weak self] in
            guard let self else { return }

            do {
                let items = try await provider.catalogItems(for: item)
                guard !Task.isCancelled else { return }
                visibleTracks = items
                resultTitle = item.title
                resultSubtitle = item.detailLabel
                errorMessage = items.isEmpty ? "\(provider.sourceName) returned no catalog items." : nil
            } catch {
                guard !Task.isCancelled else { return }
                visibleTracks = []
                resultTitle = item.title
                resultSubtitle = item.detailLabel
                errorMessage = error.localizedDescription
            }

            isSearching = false
        }
    }

    private func optimisticCatalogItems(for item: Track, in candidates: [Track]) -> [Track] {
        let itemTitle = item.title.searchNormalized
        let itemArtist = item.artist.searchNormalized

        switch item.kind {
        case .track:
            return [item]
        case .artist:
            return candidates.filter { candidate in
                guard candidate != item else { return false }
                return candidate.artist.searchNormalized == itemTitle
            }
        case .album:
            return candidates.filter { candidate in
                guard candidate.kind == .track else { return false }
                let sameAlbum = candidate.album.searchNormalized == itemTitle
                let sameArtist = itemArtist.isEmpty || itemArtist == "unknown artist" || candidate.artist.searchNormalized == itemArtist
                return sameAlbum && sameArtist
            }
        }
    }

    private func handlePlaybackFailure(_ error: Error) {
        let message = error.localizedDescription
        playbackState = .failed(message)

        if message.localizedCaseInsensitiveContains("backend session") {
            providerStatus.message = message
            errorMessage = nil
            return
        }

        if message.localizedCaseInsensitiveContains("not available from the current music provider")
            || message.localizedCaseInsensitiveContains("cannot stream") {
            errorMessage = nil
            return
        }

        errorMessage = message
    }

    private func reloadFeaturedTracks() async {
        isLoadingFeaturedTracks = true
        defer { isLoadingFeaturedTracks = false }

        do {
            let tracks = try await provider.featuredTracks()
            applyFeaturedTracks(tracks)
            errorMessage = tracks.isEmpty ? "\(provider.sourceName) returned no tracks." : nil
        } catch {
            applyFeaturedTracks([])
            errorMessage = error.localizedDescription
        }
    }

    private func startProgressTicker() {
        progressTask?.cancel()

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }

                if let providerProgress = provider.currentPlaybackTime() {
                    updateProgress(to: providerProgress)
                } else {
                    advanceProgress(by: 0.25)
                }
            }
        }
    }

    private func applyFeaturedTracks(_ tracks: [Track]) {
        featuredTracks = tracks
        visibleTracks = searchQuery.trimmed.isEmpty ? tracks : visibleTracks
        if searchQuery.trimmed.isEmpty {
            resultTitle = "Catalog Tracks"
            resultSubtitle = nil
            catalogContext = nil
        }
        currentTrack = tracks.first
        queue = tracks.first.map {
            playbackQueue(after: $0, in: tracks, limit: playbackContextLimit)
        } ?? []
        progress = 0
        playbackState = .idle
        if let currentTrack {
            loadLyrics(for: currentTrack)
        } else {
            lyricsTask?.cancel()
            lyricsState = .idle
        }
        preparePlaybackContext()
    }

    private func loadLyrics(for track: Track) {
        lyricsTask?.cancel()

        guard track.isPlayable else {
            lyricsState = .idle
            return
        }

        lyricsState = .loading
        lyricsTask = Task { [weak self] in
            guard let self else { return }

            do {
                let lyrics = try await provider.lyrics(for: track)
                guard !Task.isCancelled, currentTrack == track else { return }
                lyricsState = lyrics.isAvailable
                    ? .loaded(lyrics)
                    : .unavailable("No lyrics available for this track.")
            } catch {
                guard !Task.isCancelled, currentTrack == track else { return }
                lyricsState = .failed(error.localizedDescription)
            }
        }
    }

    private func advanceProgress(by delta: TimeInterval) {
        guard playbackState == .playing, let currentTrack else { return }

        progress += delta
        if progress >= currentTrack.duration {
            progress = currentTrack.duration
            next()
        }
    }

    private func updateProgress(to playbackTime: TimeInterval) {
        guard playbackState == .playing, let currentTrack else { return }

        progress = min(max(playbackTime, 0), currentTrack.duration)
        if progress >= currentTrack.duration {
            next()
        }
    }

    private func refillQueue(after track: Track) {
        guard queue.count < playbackContextLimit else { return }

        var queuedIDs = Set(queue.map(\.id))
        queuedIDs.insert(track.id)
        if let currentTrack {
            queuedIDs.insert(currentTrack.id)
        }

        let smartCandidates = smartWaveTracks(
            limit: playbackContextLimit,
            excludingIDs: queuedIDs
        )
        for candidate in smartCandidates where queue.count < playbackContextLimit {
            guard !queue.contains(candidate) else { continue }
            queue.append(candidate)
            queuedIDs.insert(candidate.id)
        }

        let context = visibleTracks.contains(track) ? visibleTracks : featuredTracks
        let candidates = playbackQueue(after: track, in: context, limit: playbackContextLimit)

        for candidate in candidates where queue.count < playbackContextLimit {
            guard candidate != currentTrack,
                  !queue.contains(candidate),
                  !queuedIDs.contains(candidate.id)
            else { continue }

            queue.append(candidate)
        }

        preparePlaybackContext()
    }

    private func preparePlaybackContext() {
        prepare(playbackPreparationCandidates(limit: playbackContextLimit))
    }

    private func prepare(_ candidates: [Track]) {
        preparationTask?.cancel()

        guard !candidates.isEmpty else { return }

        preparationTask = Task { [weak self, candidates] in
            guard let self else { return }
            await provider.prepare(candidates)
        }
    }

    private func playbackPreparationCandidates(limit: Int) -> [Track] {
        var result: [Track] = []
        var seenIDs = Set<String>()

        func append(_ tracks: [Track]) {
            for track in tracks {
                guard result.count < limit else { return }
                guard track.isPlayable,
                      track != currentTrack,
                      seenIDs.insert(track.id).inserted
                else { continue }

                result.append(track)
            }
        }

        append(queue)
        append(visibleTracks)
        append(featuredTracks)

        return result
    }

    private var currentPlaybackContext: [Track] {
        let playableVisibleTracks = visibleTracks.filter(\.isPlayable)
        return playableVisibleTracks.isEmpty ? featuredTracks.filter(\.isPlayable) : playableVisibleTracks
    }

    private var knownPlaybackTracks: [Track] {
        var tracks: [Track] = []
        if let currentTrack {
            tracks.append(currentTrack)
        }
        tracks.append(contentsOf: featuredTracks)
        tracks.append(contentsOf: visibleTracks)
        tracks.append(contentsOf: queue)
        return uniquePlayableTracks(in: tracks)
    }

    private func shuffledPlaybackCandidates(excluding excludedTrack: Track?) -> [Track] {
        currentPlaybackContext
            .filter { track in
                track.isPlayable && track != excludedTrack
            }
            .shuffled()
    }

    private func uniquePlayableTracks(in tracks: [Track]) -> [Track] {
        var result: [Track] = []
        var seenIDs = Set<String>()

        for track in tracks {
            guard track.isPlayable,
                  seenIDs.insert(track.id).inserted
            else { continue }

            result.append(track)
        }

        return result
    }

    private func smartWaveTracks(limit: Int, excludingIDs: Set<String> = []) -> [Track] {
        let tracks = knownPlaybackTracks.filter { !excludingIDs.contains($0.id) }
        guard !tracks.isEmpty else { return [] }

        let likedTracks = tracks.filter { likedTrackIDs.contains($0.id) }
        let likedArtists = Set(likedTracks.map { $0.artist.searchNormalized })
        let likedAlbums = Set(likedTracks.map { $0.album.searchNormalized })
        let listenedArtists = Set(
            tracks
                .filter { (listeningScores[$0.id] ?? 0) > 0 }
                .map { $0.artist.searchNormalized }
        )
        let listenedAlbums = Set(
            tracks
                .filter { (listeningScores[$0.id] ?? 0) > 0 }
                .map { $0.album.searchNormalized }
        )

        return Array(
            tracks
                .sorted { lhs, rhs in
                    let lhsScore = smartScore(
                        for: lhs,
                        likedArtists: likedArtists,
                        likedAlbums: likedAlbums,
                        listenedArtists: listenedArtists,
                        listenedAlbums: listenedAlbums
                    )
                    let rhsScore = smartScore(
                        for: rhs,
                        likedArtists: likedArtists,
                        likedAlbums: likedAlbums,
                        listenedArtists: listenedArtists,
                        listenedAlbums: listenedAlbums
                    )

                    if lhsScore != rhsScore {
                        return lhsScore > rhsScore
                    }

                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                .prefix(limit)
        )
    }

    private func smartScore(
        for track: Track,
        likedArtists: Set<String>,
        likedAlbums: Set<String>,
        listenedArtists: Set<String>,
        listenedAlbums: Set<String>
    ) -> Int {
        var score = 0

        if likedTrackIDs.contains(track.id) {
            score += 1_000
        }

        let artistKey = track.artist.searchNormalized
        let albumKey = track.album.searchNormalized

        if likedArtists.contains(artistKey) {
            score += 160
        }
        if likedAlbums.contains(albumKey) {
            score += 120
        }
        if listenedArtists.contains(artistKey) {
            score += 90
        }
        if listenedAlbums.contains(albumKey) {
            score += 70
        }

        score += min((listeningScores[track.id] ?? 0) * 45, 360)
        score += min((track.rank ?? 0) / 12_000, 80)

        return score
    }

    private func recordListening(_ track: Track) {
        listeningScores[track.id, default: 0] += 1
        persistListeningScores()
    }

    private func persistLikedTracks() {
        userDefaults.set(Array(likedTrackIDs).sorted(), forKey: Self.likedTrackIDsKey)
    }

    private func persistListeningScores() {
        userDefaults.set(listeningScores, forKey: Self.listeningScoresKey)
    }

    private func playbackQueue(after track: Track, in context: [Track], limit: Int) -> [Track] {
        guard let index = context.firstIndex(of: track) else { return [] }

        return Array(
            context
                .suffix(from: context.index(after: index))
                .filter(\.isPlayable)
                .prefix(limit)
        )
    }

    private func messageNeedsBackendSession(_ message: String?) -> Bool {
        guard let message else { return false }
        return message.localizedCaseInsensitiveContains("session inactive")
            || message.localizedCaseInsensitiveContains("session activation failed")
            || message.localizedCaseInsensitiveContains("session expired")
            || message.localizedCaseInsensitiveContains("session token")
    }
}
