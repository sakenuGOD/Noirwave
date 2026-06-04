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

    @Published var searchQuery = ""
    @Published var selectedScope: SearchScope = .catalog
    @Published var progress: TimeInterval = 0
    @Published var volume: Double = 0.78

    let provider: MusicProviding

    private let playbackContextLimit = 16
    private var searchTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?

    init(provider: MusicProviding) {
        self.provider = provider
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
        searchQuery = query
        scheduleSearch()
    }

    func setScope(_ scope: SearchScope) {
        selectedScope = scope
        scheduleSearch()
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
        case .paused, .idle, .failed(_):
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
        if !queue.isEmpty {
            let nextTrack = queue.removeFirst()
            prepare(Array(([nextTrack] + queue).prefix(playbackContextLimit)))
            play(nextTrack)
            refillQueue(after: nextTrack)
            return
        }

        guard let currentTrack,
              let index = featuredTracks.firstIndex(of: currentTrack),
              !featuredTracks.isEmpty
        else { return }

        let nextIndex = featuredTracks.index(after: index) % featuredTracks.count
        let nextTrack = featuredTracks[nextIndex]
        prepare([nextTrack] + playbackQueue(after: nextTrack, in: featuredTracks, limit: playbackContextLimit - 1))
        play(nextTrack)
    }

    func previous() {
        guard progress < 4,
              let currentTrack,
              let index = featuredTracks.firstIndex(of: currentTrack),
              !featuredTracks.isEmpty
        else {
            progress = 0
            return
        }

        let previousIndex = index == featuredTracks.startIndex ? featuredTracks.count - 1 : index - 1
        let previousTrack = featuredTracks[previousIndex]
        prepare([previousTrack] + playbackQueue(after: previousTrack, in: featuredTracks, limit: playbackContextLimit - 1))
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

    func removeFromQueue(_ track: Track) {
        queue.removeAll { $0 == track }
        preparePlaybackContext()
    }

    func seek(to fraction: Double) {
        guard let duration = currentTrack?.duration else { return }
        progress = min(max(fraction, 0), 1) * duration

        let targetTime = progress
        Task {
            await provider.seek(to: targetTime)
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
        let scope = selectedScope

        guard !term.isEmpty else {
            isSearching = false
            errorMessage = nil
            resultTitle = "Catalog Tracks"
            resultSubtitle = nil
            visibleTracks = featuredTracks
            preparePlaybackContext()
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await provider.search(term, scope: scope)
            guard !Task.isCancelled,
                  term == searchQuery.trimmed,
                  scope == selectedScope
            else { return }
            visibleTracks = results
            resultTitle = scope.resultsTitle
            resultSubtitle = nil
            errorMessage = nil
            preparePlaybackContext()
        } catch {
            guard !Task.isCancelled else { return }
            visibleTracks = []
            resultTitle = scope.resultsTitle
            resultSubtitle = nil
            errorMessage = error.localizedDescription
        }
    }

    private func drillIntoCatalog(from item: Track) {
        searchTask?.cancel()
        selectedScope = .catalog
        searchQuery = item.title
        resultTitle = item.title
        resultSubtitle = item.detailLabel
        visibleTracks = []
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

    private func handlePlaybackFailure(_ error: Error) {
        let message = error.localizedDescription
        playbackState = .failed(message)

        if message.localizedCaseInsensitiveContains("backend session") {
            providerStatus.message = message
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

        let context = visibleTracks.contains(track) ? visibleTracks : featuredTracks
        let candidates = playbackQueue(after: track, in: context, limit: playbackContextLimit)

        for candidate in candidates where queue.count < playbackContextLimit {
            guard candidate != currentTrack,
                  !queue.contains(candidate)
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
