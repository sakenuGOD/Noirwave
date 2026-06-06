import Foundation

enum PlayerSection: String, CaseIterable, Identifiable {
    case studio = "Studio"
    case wave = "Wave"
    case library = "Library"
    case favourites = "Favourites"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .studio:
            "music.quarternote.3"
        case .wave:
            "dot.radiowaves.left.and.right"
        case .library:
            "rectangle.stack"
        case .favourites:
            "heart"
        }
    }
}

enum UtilityPanelMode: String, Identifiable {
    case lyrics = "Lyrics"
    case queue = "Queue"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .lyrics:
            "text.quote"
        case .queue:
            "text.line.last.and.arrowtriangle.forward"
        }
    }
}

@MainActor
final class PlayerStore: ObservableObject {
    @Published var selectedSection: PlayerSection = .studio
    @Published var utilityPanelMode: UtilityPanelMode?
    @Published private(set) var featuredTracks: [Track] = []
    @Published private(set) var visibleTracks: [Track] = []
    @Published private(set) var waveTracks: [Track] = []
    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentTrack: Track?
    @Published private(set) var playbackState: PlaybackState = .idle
    @Published private(set) var lyricsState: LyricsState = .idle
    @Published private(set) var providerStatus = ProviderStatus.disconnected
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingFeaturedTracks = false
    @Published private(set) var isLoadingWave = false
    @Published private(set) var isConfiguringBackendSession = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var resultTitle = "Catalog Tracks"
    @Published private(set) var resultSubtitle: String?
    @Published private(set) var favouriteTrackIDs: Set<String> = []

    @Published var searchQuery = ""
    @Published var selectedSearchScope: SearchScope = .smart
    @Published var progress: TimeInterval = 0
    @Published var volume: Double = 0.78

    let provider: MusicProviding

    private var searchTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var waveTask: Task<Void, Never>?
    private var playbackContext: [Track] = []
    private var recentlyPlayedIDs: [String] = []
    private let favouritesStorageKey = "Noirwave.favouriteTrackIDs"

    init(provider: MusicProviding) {
        self.provider = provider
        if let savedIDs = UserDefaults.standard.array(forKey: favouritesStorageKey) as? [String] {
            favouriteTrackIDs = Set(savedIDs)
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
        waveTask?.cancel()
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
        if query.trimmed.isEmpty {
            visibleTracks = featuredTracks
            resultTitle = "Catalog Tracks"
            resultSubtitle = nil
        }
        scheduleSearch()
    }

    func selectSection(_ section: PlayerSection) {
        selectedSection = section

        if !searchQuery.trimmed.isEmpty {
            searchQuery = ""
            searchTask?.cancel()
            isSearching = false
        }

        if section == .wave, waveTracks.isEmpty {
            refreshWave()
        }
    }

    func toggleUtilityPanel(_ mode: UtilityPanelMode) {
        utilityPanelMode = utilityPanelMode == mode ? nil : mode
    }

    func closeUtilityPanel() {
        utilityPanelMode = nil
    }

    func selectSearchScope(_ scope: SearchScope) {
        selectedSearchScope = scope
        guard !searchQuery.trimmed.isEmpty else { return }
        scheduleSearch(delay: .milliseconds(60))
    }

    func activate(_ item: Track) {
        guard item.isPlayable else {
            drillIntoCatalog(from: item)
            return
        }

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

        seedPlaybackContext(for: track)

        playbackTask?.cancel()
        progressTask?.cancel()

        currentTrack = track
        rememberPlayed(track)
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
            play(nextTrack)
            refillQueue(after: nextTrack)
            return
        }

        guard let currentTrack else { return }

        if let nextTrack = nextContextTrack(after: currentTrack) {
            play(nextTrack)
            refillQueue(after: nextTrack)
        } else {
            refreshWave()
        }
    }

    func previous() {
        guard progress < 4,
              let currentTrack,
              let index = playbackContext.firstIndex(of: currentTrack),
              !playbackContext.isEmpty
        else {
            progress = 0
            return
        }

        let previousIndex = index == playbackContext.startIndex ? playbackContext.count - 1 : index - 1
        play(playbackContext[previousIndex])
    }

    func enqueue(_ track: Track) {
        guard track.isPlayable,
              !queue.contains(track),
              track != currentTrack
        else { return }
        queue.append(track)
    }

    func removeFromQueue(_ track: Track) {
        queue.removeAll { $0 == track }
    }

    func clearQueue() {
        queue.removeAll()
    }

    func seek(to fraction: Double) {
        guard let duration = currentTrack?.duration else { return }
        progress = min(max(fraction, 0), 1) * duration

        let targetTime = progress
        Task {
            await provider.seek(to: targetTime)
        }
    }

    func seek(toTime time: TimeInterval) {
        guard let currentTrack else { return }
        progress = min(max(time, 0), currentTrack.duration)

        let targetTime = progress
        Task {
            await provider.seek(to: targetTime)
        }
    }

    func toggleFavourite(_ track: Track) {
        guard track.isPlayable else { return }

        if favouriteTrackIDs.contains(track.id) {
            favouriteTrackIDs.remove(track.id)
        } else {
            favouriteTrackIDs.insert(track.id)
        }

        UserDefaults.standard.set(Array(favouriteTrackIDs).sorted(), forKey: favouritesStorageKey)
    }

    func isFavourite(_ track: Track) -> Bool {
        favouriteTrackIDs.contains(track.id)
    }

    var favouriteTracks: [Track] {
        let candidates = ([currentTrack].compactMap(\.self) + featuredTracks + visibleTracks + waveTracks + queue)
            .filter(\.isPlayable)
        var seenIDs = Set<String>()
        let uniqueTracks = candidates.filter { seenIDs.insert($0.id).inserted }
        return uniqueTracks.filter { favouriteTrackIDs.contains($0.id) }
    }

    func refreshWave() {
        waveTask?.cancel()
        isLoadingWave = true
        errorMessage = nil

        let seed = currentTrack ?? featuredTracks.first
        let excludedIDs = Set(([currentTrack].compactMap(\.self) + queue + Array(waveTracks.prefix(8))).map(\.id))

        waveTask = Task { [weak self] in
            guard let self else { return }

            do {
                let tracks = try await provider.radioTracks(seed: seed)
                    .filter(\.isPlayable)
                    .filter { !excludedIDs.contains($0.id) }
                guard !Task.isCancelled else { return }

                waveTracks = tracks.isEmpty
                    ? featuredTracks.filter { !excludedIDs.contains($0.id) }
                    : tracks
                refillQueueFromWave()
            } catch {
                guard !Task.isCancelled else { return }
                waveTracks = featuredTracks.filter { !excludedIDs.contains($0.id) }
                errorMessage = error.localizedDescription
            }

            isLoadingWave = false
        }
    }

    private func scheduleSearch(delay: Duration = .milliseconds(180)) {
        searchTask?.cancel()

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func runSearch() async {
        let term = searchQuery.trimmed

        guard !term.isEmpty else {
            isSearching = false
            errorMessage = nil
            resultTitle = "Catalog Tracks"
            resultSubtitle = nil
            visibleTracks = featuredTracks
            return
        }

        isSearching = true
        defer { isSearching = false }

        let scope = selectedSearchScope

        do {
            let results = try await provider.search(term, scope: scope)
            guard searchQuery.trimmed == term,
                  selectedSearchScope == scope
            else { return }
            visibleTracks = results
            resultTitle = scope.resultsTitle
            resultSubtitle = nil
            errorMessage = nil
        } catch {
            guard searchQuery.trimmed == term,
                  selectedSearchScope == scope
            else { return }
            visibleTracks = []
            resultTitle = scope.resultsTitle
            resultSubtitle = nil
            errorMessage = error.localizedDescription
        }
    }

    private func drillIntoCatalog(from item: Track) {
        searchTask?.cancel()
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
        playbackContext = tracks.filter(\.isPlayable)
        queue = Array(tracks.dropFirst().filter(\.isPlayable).prefix(5))
        progress = 0
        playbackState = .idle
        if let currentTrack {
            loadLyrics(for: currentTrack)
        } else {
            lyricsTask?.cancel()
            lyricsState = .idle
        }
    }

    private func refillQueueFromWave() {
        guard queue.count < 5 else { return }

        for track in waveTracks where track != currentTrack && !queue.contains(track) {
            queue.append(track)
            if queue.count >= 5 {
                return
            }
        }
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
        guard queue.count < 5 else { return }

        let excludedIDs = Set(([track, currentTrack].compactMap(\.self) + queue).map(\.id) + recentlyPlayedIDs)
        let candidates = playbackContext + waveTracks + featuredTracks

        for candidate in candidates where candidate.isPlayable && !excludedIDs.contains(candidate.id) {
            enqueue(candidate)
            if queue.count >= 5 {
                return
            }
        }

        if queue.count < 3 {
            refreshWave()
        }
    }

    private func seedPlaybackContext(for track: Track) {
        let source: [Track]
        switch selectedSection {
        case .wave:
            source = waveTracks
        case .favourites:
            source = favouriteTracks
        case .studio, .library:
            source = visibleTracks.isEmpty ? featuredTracks : visibleTracks
        }

        var seenIDs = Set<String>()
        let playable = source
            .filter(\.isPlayable)
            .filter { seenIDs.insert($0.id).inserted }

        if playable.contains(track) {
            playbackContext = playable
        } else if !playable.isEmpty {
            playbackContext = [track] + playable
        } else {
            playbackContext = [track]
        }
    }

    private func nextContextTrack(after track: Track) -> Track? {
        guard let index = playbackContext.firstIndex(of: track), !playbackContext.isEmpty else {
            return playbackContext.first { $0 != track }
        }

        let excludedIDs = Set(recentlyPlayedIDs.suffix(6))
        let wrapped = Array(playbackContext.dropFirst(index + 1)) + Array(playbackContext.prefix(index))
        return wrapped.first { $0 != track && !excludedIDs.contains($0.id) }
            ?? wrapped.first { $0 != track }
    }

    private func rememberPlayed(_ track: Track) {
        recentlyPlayedIDs.removeAll { $0 == track.id }
        recentlyPlayedIDs.append(track.id)
        if recentlyPlayedIDs.count > 16 {
            recentlyPlayedIDs.removeFirst(recentlyPlayedIDs.count - 16)
        }
    }

    private func messageNeedsBackendSession(_ message: String?) -> Bool {
        guard let message else { return false }
        return message.localizedCaseInsensitiveContains("session inactive")
            || message.localizedCaseInsensitiveContains("session activation failed")
            || message.localizedCaseInsensitiveContains("session expired")
            || message.localizedCaseInsensitiveContains("session token")
    }
}
