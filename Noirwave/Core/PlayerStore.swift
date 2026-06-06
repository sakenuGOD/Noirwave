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
    @Published private(set) var likedTrackOrder: [String] = []
    @Published private(set) var likedTrackSnapshots: [String: Track] = [:]
    @Published private(set) var savedCollectionIDs: Set<String> = []
    @Published private(set) var savedCollectionOrder: [String] = []
    @Published private(set) var savedCollectionSnapshots: [String: Track] = [:]
    @Published private(set) var localPlaylists: [LocalPlaylist] = []
    @Published private(set) var importHistory: [MusicImportHistoryRecord] = []
    @Published private(set) var listeningScores: [String: Int] = [:]
    @Published private(set) var mcpPermissions = MCPLibraryPermissions()
    @Published private(set) var mcpActivityLog: [MCPActivityEntry] = []
    @Published private(set) var mcpLastSyncedAt: Date?
    @Published private(set) var mcpServerStatus = MCPServerStatus.stopped

    @Published var searchQuery = ""
    @Published var selectedScope: SearchScope = .smart
    @Published var progress: TimeInterval = 0
    @Published var volume: Double = 0.78
    @Published var equalizerSettings: EqualizerSettings = .flat
    @Published var crossfadeDuration: TimeInterval = 4

    let provider: MusicProviding

    private static let volumeKey = "noirwave.volume"
    private static let equalizerEnabledKey = "noirwave.equalizer.enabled"
    private static let equalizerPresetKey = "noirwave.equalizer.preset"
    private static let equalizerBandsKey = "noirwave.equalizer.bands"
    private static let crossfadeDurationKey = "noirwave.crossfade.duration"
    private static let likedTrackIDsKey = "noirwave.likedTrackIDs"
    private static let likedTrackOrderKey = "noirwave.likedTrackOrder"
    private static let likedTrackSnapshotsKey = "noirwave.likedTrackSnapshots"
    private static let savedCollectionIDsKey = "noirwave.savedCollectionIDs"
    private static let savedCollectionOrderKey = "noirwave.savedCollectionOrder"
    private static let savedCollectionSnapshotsKey = "noirwave.savedCollectionSnapshots"
    private static let localPlaylistsKey = "noirwave.localPlaylists"
    private static let importHistoryKey = "noirwave.importHistory"
    private static let listeningScoresKey = "noirwave.listeningScores"
    private let playbackContextLimit = 16
    private let userDefaults: UserDefaults
    private var searchTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var catalogPrefetchTask: Task<Void, Never>?
    private var mcpBridgeTask: Task<Void, Never>?
    private var mcpLastSeenLibraryModificationDate: Date?
    private var isApplyingMCPSnapshot = false
    private var activePlaybackContext: [Track] = []
    private var lastAudibleVolume: Double = 0.78
    private var isAdvancingWithCrossfade = false
    private var searchResultsCache: [String: [Track]] = [:]
    private var lyricsCache: [String: TrackLyrics] = [:]
    private var catalogItemsCache: [String: CachedCatalogItems] = [:]
    private var activeCatalogCacheKey: String?
    private var catalogInFlightKey: String?
    private let catalogCacheTTL: TimeInterval = 60 * 60
    private let catalogCacheLimit = 160
    private let catalogPrefetchLimit = 4
    private let searchDebounceMilliseconds = 260

    init(provider: MusicProviding, userDefaults: UserDefaults = .standard) {
        self.provider = provider
        self.userDefaults = userDefaults
        likedTrackIDs = Set(userDefaults.stringArray(forKey: Self.likedTrackIDsKey) ?? [])
        likedTrackOrder = Self.normalizedLikedTrackOrder(
            userDefaults.stringArray(forKey: Self.likedTrackOrderKey) ?? [],
            likedIDs: likedTrackIDs
        )
        likedTrackSnapshots = Self.loadLikedTrackSnapshots(from: userDefaults, likedIDs: likedTrackIDs)
        savedCollectionIDs = Set(userDefaults.stringArray(forKey: Self.savedCollectionIDsKey) ?? [])
        savedCollectionOrder = Self.normalizedSavedCollectionOrder(
            userDefaults.stringArray(forKey: Self.savedCollectionOrderKey) ?? [],
            savedIDs: savedCollectionIDs
        )
        savedCollectionSnapshots = Self.loadSavedCollectionSnapshots(from: userDefaults, savedIDs: savedCollectionIDs)
        localPlaylists = Self.loadLocalPlaylists(from: userDefaults)
        importHistory = Self.loadImportHistory(from: userDefaults)
        mcpPermissions = MCPLibraryBridge.loadPermissions()
        mcpActivityLog = MCPLibraryBridge.loadActivityLog()
        mcpServerStatus = MCPLibraryBridge.loadServerStatus()
        if let storedVolume = userDefaults.object(forKey: Self.volumeKey) as? NSNumber {
            volume = min(max(storedVolume.doubleValue, 0), 1)
            lastAudibleVolume = volume > 0 ? volume : lastAudibleVolume
            provider.setVolume(volume)
        }
        if let storedPreset = userDefaults.string(forKey: Self.equalizerPresetKey),
           let preset = EqualizerPreset(rawValue: storedPreset) {
            equalizerSettings.preset = preset
            equalizerSettings.bandGains = preset.bandGains
        }
        if let storedBands = userDefaults.array(forKey: Self.equalizerBandsKey) as? [Double],
           !storedBands.isEmpty {
            equalizerSettings.bandGains = storedBands
        }
        equalizerSettings.isEnabled = userDefaults.object(forKey: Self.equalizerEnabledKey).map { _ in
            userDefaults.bool(forKey: Self.equalizerEnabledKey)
        } ?? equalizerSettings.isEnabled
        if let storedCrossfade = userDefaults.object(forKey: Self.crossfadeDurationKey) as? NSNumber {
            crossfadeDuration = Self.normalizedCrossfadeDuration(storedCrossfade.doubleValue)
        }
        provider.setEqualizer(equalizerSettings)
        provider.setCrossfadeDuration(crossfadeDuration)
        listeningScores = (userDefaults.dictionary(forKey: Self.listeningScoresKey) ?? [:]).reduce(into: [:]) { result, item in
            if let score = item.value as? Int {
                result[item.key] = score
            } else if let score = item.value as? NSNumber {
                result[item.key] = score.intValue
            }
        }
        startMCPBridge()
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
        mcpBridgeTask?.cancel()
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
        searchTask?.cancel()
        catalogContext = nil
        activeCatalogCacheKey = nil
        catalogInFlightKey = nil
        resultSubtitle = nil
        isSearching = false

        if searchQuery.trimmed.isEmpty {
            resultTitle = "Catalog Tracks"
            visibleTracks = featuredTracks
        } else {
            resultTitle = SearchScope.smart.resultsTitle
            scheduleSearch()
        }
    }

    func activate(_ item: Track) {
        activate(item, in: visibleTracks)
    }

    func activate(_ item: Track, in playbackContext: [Track]) {
        guard item.isPlayable else {
            drillIntoCatalog(from: item)
            return
        }

        if currentTrack?.id == item.id {
            togglePlayPause()
            return
        }

        let context = uniquePlayableTracks(in: playbackContext)
        activePlaybackContext = context.contains(item) ? context : [item] + context.filter { $0 != item }
        let playbackContext = playbackQueue(after: item, in: activePlaybackContext, limit: playbackContextLimit)
        queue = playbackContext
        prepare(Array(([item] + playbackContext).prefix(playbackContextLimit)))
        play(item)
    }

    func playAll(_ tracks: [Track]) {
        let playableTracks = uniquePlayableTracks(in: tracks)
        guard let firstTrack = playableTracks.first else { return }

        activePlaybackContext = playableTracks
        queue = Array(playableTracks.dropFirst())
        prepare(Array(playableTracks.prefix(playbackContextLimit)))
        play(firstTrack)
    }

    func shufflePlay(_ tracks: [Track]) {
        let playableTracks = uniquePlayableTracks(in: tracks).shuffled()
        guard let firstTrack = playableTracks.first else { return }

        activePlaybackContext = playableTracks
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
        isAdvancingWithCrossfade = false

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
        playbackTask?.cancel()
        isAdvancingWithCrossfade = false
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
            likedTrackOrder.removeAll { $0 == track.id }
            likedTrackSnapshots.removeValue(forKey: track.id)
        } else {
            likedTrackIDs.insert(track.id)
            likedTrackOrder.removeAll { $0 == track.id }
            likedTrackOrder.insert(track.id, at: likedTrackOrder.startIndex)
            likedTrackSnapshots[track.id] = track
        }

        persistLikedTracks()
    }

    @discardableResult
    func addLikedTracks(_ tracks: [Track]) -> Int {
        let playableTracks = uniquePlayableTracks(in: tracks)
        var imported = 0

        for track in playableTracks where !likedTrackIDs.contains(track.id) {
            likedTrackIDs.insert(track.id)
            likedTrackOrder.removeAll { $0 == track.id }
            likedTrackOrder.insert(track.id, at: likedTrackOrder.startIndex)
            likedTrackSnapshots[track.id] = track
            imported += 1
        }

        if imported > 0 {
            persistLikedTracks()
        }

        return imported
    }

    func likedTracks(limit: Int = 12) -> [Track] {
        let knownTracks = knownPlaybackTracks.filter { likedTrackIDs.contains($0.id) }
        var trackByID = likedTrackSnapshots.filter { likedTrackIDs.contains($0.key) }
        for track in knownTracks {
            trackByID[track.id] = track
        }
        var seenIDs: Set<String> = []
        var orderedTracks: [Track] = []

        for id in likedTrackOrder where likedTrackIDs.contains(id) {
            guard let track = trackByID[id],
                  seenIDs.insert(id).inserted
            else { continue }
            orderedTracks.append(track)
        }

        for track in knownTracks where seenIDs.insert(track.id).inserted {
            orderedTracks.append(track)
        }

        return Array(orderedTracks.prefix(limit))
    }

    func isSavedCollection(_ item: Track) -> Bool {
        savedCollectionIDs.contains(item.id)
    }

    func toggleSavedCollection(_ item: Track) {
        guard !item.isPlayable else { return }

        if savedCollectionIDs.contains(item.id) {
            savedCollectionIDs.remove(item.id)
            savedCollectionOrder.removeAll { $0 == item.id }
            savedCollectionSnapshots.removeValue(forKey: item.id)
        } else {
            savedCollectionIDs.insert(item.id)
            savedCollectionOrder.removeAll { $0 == item.id }
            savedCollectionOrder.insert(item.id, at: savedCollectionOrder.startIndex)
            savedCollectionSnapshots[item.id] = item
        }

        persistSavedCollections()
    }

    func savedCollections(limit: Int = 16) -> [Track] {
        let knownItems = knownCollectionItems.filter { savedCollectionIDs.contains($0.id) }
        var itemByID = savedCollectionSnapshots.filter { savedCollectionIDs.contains($0.key) }
        for item in knownItems {
            itemByID[item.id] = item
        }
        var seenIDs: Set<String> = []
        var orderedItems: [Track] = []

        for id in savedCollectionOrder where savedCollectionIDs.contains(id) {
            guard let item = itemByID[id],
                  seenIDs.insert(id).inserted
            else { continue }
            orderedItems.append(item)
        }

        for item in knownItems where seenIDs.insert(item.id).inserted {
            orderedItems.append(item)
        }

        return Array(orderedItems.prefix(limit))
    }

    @discardableResult
    func createPlaylist(title: String, tracks: [Track] = []) -> LocalPlaylist {
        let playableTracks = uniquePlayableTracks(in: tracks)
        let normalizedTitle = LocalPlaylist.normalizedTitle(title)

        if let existingIndex = localPlaylists.firstIndex(where: { $0.title == normalizedTitle }) {
            let originalPlaylist = localPlaylists[existingIndex]
            _ = localPlaylists[existingIndex].append(playableTracks)
            localPlaylists[existingIndex].normalize()
            if localPlaylists[existingIndex] != originalPlaylist {
                persistLocalPlaylists()
            }
            return localPlaylists[existingIndex]
        }

        let playlist = LocalPlaylist(title: normalizedTitle, tracks: playableTracks)
        localPlaylists.insert(playlist, at: localPlaylists.startIndex)
        persistLocalPlaylists()
        return playlist
    }

    @discardableResult
    func addTracksToPlaylist(named title: String, tracks: [Track]) -> (playlist: LocalPlaylist, imported: Int) {
        let playableTracks = uniquePlayableTracks(in: tracks)
        guard !playableTracks.isEmpty else {
            let playlist = localPlaylists.first { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }
                ?? createPlaylist(title: title)
            return (playlist, 0)
        }

        if let index = localPlaylists.firstIndex(where: { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }) {
            let originalCount = localPlaylists[index].trackCount
            _ = localPlaylists[index].append(playableTracks)
            let imported = localPlaylists[index].trackCount - originalCount
            if imported > 0 {
                persistLocalPlaylists()
            }
            return (localPlaylists[index], imported)
        }

        let playlist = createPlaylist(title: title, tracks: playableTracks)
        return (playlist, playlist.trackCount)
    }

    func recordImport(source: String, imported: Int, skipped: Int, notFound: Int, destination: String) {
        let record = MusicImportHistoryRecord(
            source: source,
            imported: imported,
            skipped: skipped,
            notFound: notFound,
            destination: destination
        )
        importHistory.insert(record, at: importHistory.startIndex)
        importHistory = Array(importHistory.prefix(10))
        persistImportHistory()
    }

    @discardableResult
    func createPlaylist(title: String, track: Track) -> LocalPlaylist {
        createPlaylist(title: title, tracks: [track])
    }

    func renamePlaylist(playlistID: String, title: String) {
        updatePlaylist(playlistID: playlistID) { playlist in
            _ = playlist.rename(to: title)
        }
    }

    func deletePlaylist(playlistID: String) {
        let originalCount = localPlaylists.count
        localPlaylists.removeAll { $0.id == playlistID }
        guard localPlaylists.count != originalCount else { return }

        persistLocalPlaylists()
    }

    func addToPlaylist(_ track: Track, playlistID: String) {
        addToPlaylist([track], playlistID: playlistID)
    }

    func addToPlaylist(_ tracks: [Track], playlistID: String) {
        let playableTracks = uniquePlayableTracks(in: tracks)
        guard !playableTracks.isEmpty else { return }

        updatePlaylist(playlistID: playlistID) { playlist in
            _ = playlist.append(playableTracks)
        }
    }

    func removeFromPlaylist(_ track: Track, playlistID: String) {
        updatePlaylist(playlistID: playlistID) { playlist in
            _ = playlist.remove(track)
        }
    }

    func playlistTracks(playlistID: String) -> [Track] {
        guard let playlist = localPlaylists.first(where: { $0.id == playlistID }) else { return [] }
        return playlist.orderedTracks(preferredTracks: knownPlaybackTracks)
    }

    func startWave() {
        let wave = smartWaveTracks(limit: playbackContextLimit)
        guard let firstTrack = wave.first else { return }

        activePlaybackContext = wave
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

        let excludedTrack = currentTrack ?? currentPlaybackContext.first
        queue = Array(shuffledPlaybackCandidates(excluding: excludedTrack).prefix(playbackContextLimit))
        preparePlaybackContext()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    func seek(to time: TimeInterval) {
        guard let duration = currentTrack?.duration else { return }
        playbackTask?.cancel()
        isAdvancingWithCrossfade = false
        progress = min(max(time, 0), duration)

        let targetTime = progress
        Task {
            await provider.seek(to: targetTime)
        }
    }

    func seek(toFraction fraction: Double) {
        guard let duration = currentTrack?.duration else { return }
        seek(to: min(max(fraction, 0), 1) * duration)
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        if volume > 0 {
            lastAudibleVolume = volume
        }
        userDefaults.set(volume, forKey: Self.volumeKey)
        provider.setVolume(volume)
    }

    func toggleMute() {
        if volume > 0 {
            setVolume(0)
        } else {
            setVolume(max(lastAudibleVolume, 0.1))
        }
    }

    func setEqualizerEnabled(_ isEnabled: Bool) {
        equalizerSettings.isEnabled = isEnabled
        persistEqualizerSettings()
        provider.setEqualizer(equalizerSettings)
    }

    func setEqualizerPreset(_ preset: EqualizerPreset) {
        equalizerSettings = EqualizerSettings.preset(preset, isEnabled: equalizerSettings.isEnabled)
        persistEqualizerSettings()
        provider.setEqualizer(equalizerSettings)
    }

    func setEqualizerBand(at index: Int, gain: Double) {
        guard EqualizerSettings.bandFrequencies.indices.contains(index) else { return }
        var gains = equalizerSettings.normalizedBandGains
        gains[index] = min(max(gain, -12), 12)
        equalizerSettings.bandGains = gains
        equalizerSettings.preset = .flat
        persistEqualizerSettings()
        provider.setEqualizer(equalizerSettings)
    }

    func setCrossfadeDuration(_ duration: TimeInterval) {
        crossfadeDuration = Self.normalizedCrossfadeDuration(duration)
        userDefaults.set(crossfadeDuration, forKey: Self.crossfadeDurationKey)
        provider.setCrossfadeDuration(crossfadeDuration)
    }

    func updateMCPPermissions(_ update: (inout MCPLibraryPermissions) -> Void) {
        var permissions = mcpPermissions
        update(&permissions)
        guard permissions != mcpPermissions else { return }
        mcpPermissions = permissions
        MCPLibraryBridge.savePermissions(permissions)
        exportMCPLibrarySnapshot()
    }

    func refreshMCPActivityLog() {
        mcpActivityLog = MCPLibraryBridge.loadActivityLog()
    }

    func refreshMCPStatus() {
        mcpServerStatus = MCPLibraryBridge.loadServerStatus()
        mcpActivityLog = MCPLibraryBridge.loadActivityLog()
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let term = searchQuery.trimmed
        let scope = SearchScope.smart

        guard !term.isEmpty else {
            applyEmptySearchState()
            return
        }

        if let cachedResults = searchResultsCache[searchCacheKey(term: term, scope: scope)] {
            applySearchResults(cachedResults, term: term, scope: scope)
            return
        }

        let optimisticResults = localSearchResults(term: term)
        if optimisticResults.isEmpty {
            resultTitle = scope.resultsTitle
            resultSubtitle = nil
            catalogContext = nil
            activeCatalogCacheKey = nil
            catalogInFlightKey = nil
            errorMessage = nil
        } else {
            applySearchResults(optimisticResults, term: term, scope: scope)
        }
        isSearching = false

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(self?.searchDebounceMilliseconds ?? 80))
            guard let self, !Task.isCancelled else { return }
            await runSearch(term: term, scope: scope)
        }
    }

    private func runSearch(term: String, scope: SearchScope) async {
        guard !term.isEmpty else {
            applyEmptySearchState()
            return
        }

        isSearching = true
        defer {
            if term == searchQuery.trimmed {
                isSearching = false
            }
        }

        do {
            let results = try await remoteSearchResults(term: term, scope: scope)
            guard !Task.isCancelled,
                  term == searchQuery.trimmed
            else { return }
            searchResultsCache[searchCacheKey(term: term, scope: scope)] = results
            applySearchResults(results, term: term, scope: scope)
        } catch {
            guard !Task.isCancelled,
                  term == searchQuery.trimmed
            else { return }
            resultTitle = scope.resultsTitle
            resultSubtitle = nil
            catalogContext = nil
            errorMessage = visibleTracks.isEmpty ? error.localizedDescription : nil
        }
    }

    private func remoteSearchResults(term: String, scope: SearchScope) async throws -> [Track] {
        let candidates = SearchQueryVariants.candidates(for: term)
        var lastError: Error?

        for (index, candidate) in candidates.enumerated() {
            do {
                let results = try await provider.search(candidate, scope: scope)
                if !results.isEmpty || index == candidates.count - 1 {
                    return results
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        return []
    }

    private func applyEmptySearchState() {
        catalogPrefetchTask?.cancel()
        isSearching = false
        errorMessage = nil
        resultTitle = "Catalog Tracks"
        resultSubtitle = nil
        catalogContext = nil
        activeCatalogCacheKey = nil
        catalogInFlightKey = nil
        visibleTracks = featuredTracks
        preparePlaybackContext()
    }

    private func applySearchResults(_ results: [Track], term: String, scope: SearchScope) {
        guard term == searchQuery.trimmed else { return }
        visibleTracks = results
        resultTitle = scope.resultsTitle
        resultSubtitle = nil
        catalogContext = nil
        activeCatalogCacheKey = nil
        catalogInFlightKey = nil
        errorMessage = nil
        isSearching = false
        preparePlaybackContext()
        prefetchCatalogDetails(from: results)
    }

    private func searchCacheKey(term: String, scope: SearchScope) -> String {
        "\(scope.rawValue)::\(term.searchNormalized)"
    }

    private func localSearchResults(term: String) -> [Track] {
        let normalizedTerm = term.searchNormalized
        guard !normalizedTerm.isEmpty else { return [] }

        let tokens = normalizedTerm.split(separator: " ").map(String.init)
        let candidates = uniqueSearchItems(in:
            visibleTracks
            + featuredTracks
            + Array(likedTrackSnapshots.values)
            + Array(savedCollectionSnapshots.values)
            + localPlaylists.flatMap { $0.orderedTracks(preferredTracks: Array(likedTrackSnapshots.values) + featuredTracks) }
        )

        return candidates
            .filter { item in
                SearchTextMatcher.matches(normalizedQuery: normalizedTerm, normalizedText: searchText(for: item))
            }
            .sorted { lhs, rhs in
                let lhsScore = localSearchScore(lhs, term: normalizedTerm, tokens: tokens)
                let rhsScore = localSearchScore(rhs, term: normalizedTerm, tokens: tokens)
                if lhsScore == rhsScore {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhsScore > rhsScore
            }
            .prefix(80)
            .map { $0 }
    }

    private func uniqueSearchItems(in items: [Track]) -> [Track] {
        var result: [Track] = []
        var seenIDs = Set<String>()
        for item in items where seenIDs.insert(item.id).inserted {
            result.append(item)
        }
        return result
    }

    private func searchText(for item: Track) -> String {
        [item.title, item.artist, item.album, item.detailLabel]
            .joined(separator: " ")
            .searchNormalized
    }

    private func localSearchScore(_ item: Track, term: String, tokens: [String]) -> Int {
        let title = item.title.searchNormalized
        let artist = item.artist.searchNormalized
        let album = item.album.searchNormalized
        let titleMatchScore = SearchTextMatcher.matchScore(normalizedQuery: term, normalizedText: title)
        let artistMatchScore = SearchTextMatcher.matchScore(normalizedQuery: term, normalizedText: artist)
        let albumMatchScore = SearchTextMatcher.matchScore(normalizedQuery: term, normalizedText: album)
        var score = 0

        if title == term { score += 120 }
        if artist == term { score += 110 }
        if album == term { score += 80 }
        if title.hasPrefix(term) { score += 60 }
        if artist.hasPrefix(term) { score += 55 }
        if title.contains(term) { score += 35 }
        if artist.contains(term) { score += 30 }
        if album.contains(term) { score += 20 }
        score += tokens.filter { title.contains($0) || artist.contains($0) || album.contains($0) }.count * 8
        score += titleMatchScore * 2
        score += artistMatchScore * 2
        score += albumMatchScore

        switch item.kind {
        case .artist:
            score += 10
        case .track:
            score += 6
        case .album:
            score += 4
        }

        return score
    }

    private func drillIntoCatalog(from item: Track) {
        let cacheKeys = catalogItemsCacheKeys(for: item)
        let primaryCacheKey = cacheKeys[0]
        let cached = cachedCatalogItems(for: item)
        let cachedItems = cached?.entry.items
        let hasFreshCache = cached.map { isFreshCatalogCache($0.entry) } ?? false
        let isSameInFlightRequest = catalogInFlightKey.map { cacheKeys.contains($0) } ?? false

        if !isSameInFlightRequest {
            searchTask?.cancel()
            catalogInFlightKey = nil
        }

        selectedScope = .catalog
        let optimisticItems = cachedItems ?? optimisticCatalogItems(for: item, in: visibleTracks)
        resultTitle = item.title
        resultSubtitle = item.detailLabel
        catalogContext = item
        activeCatalogCacheKey = primaryCacheKey
        errorMessage = nil
        visibleTracks = optimisticItems
        isSearching = !hasFreshCache
        preparePlaybackContext()

        guard !hasFreshCache else { return }
        guard !isSameInFlightRequest else { return }

        catalogInFlightKey = primaryCacheKey
        searchTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if catalogInFlightKey == primaryCacheKey {
                    catalogInFlightKey = nil
                }
                if activeCatalogCacheKey == primaryCacheKey {
                    isSearching = false
                }
            }

            do {
                let items = try await provider.catalogItems(for: item)
                guard !Task.isCancelled,
                      activeCatalogCacheKey == primaryCacheKey
                else { return }
                let resolvedItems = items.isEmpty ? optimisticItems : items
                cacheCatalogItems(resolvedItems, for: item)
                if let catalogContext {
                    cacheCatalogItems(resolvedItems, for: catalogContext)
                }
                visibleTracks = resolvedItems
                resultTitle = item.title
                resultSubtitle = item.detailLabel
                errorMessage = items.isEmpty && optimisticItems.isEmpty ? "\(provider.sourceName) returned no catalog items." : nil
                preparePlaybackContext()
            } catch {
                guard !Task.isCancelled,
                      activeCatalogCacheKey == primaryCacheKey
                else { return }
                visibleTracks = optimisticItems
                resultTitle = item.title
                resultSubtitle = item.detailLabel
                errorMessage = optimisticItems.isEmpty ? error.localizedDescription : nil
            }
        }
    }

    private func catalogItemsCacheKeys(for item: Track) -> [String] {
        var keys: [String] = []

        func append(_ key: String?) {
            guard let key, !key.isEmpty, !keys.contains(key) else { return }
            keys.append(key)
        }

        switch item.kind {
        case .track:
            append("track:\(item.catalogID?.nonEmpty ?? item.id)")
        case .artist:
            append("artist:\(item.title.searchNormalized)")
        case .album:
            append("album:\(item.title.searchNormalized):\(item.artist.searchNormalized)")
        }

        if let catalogID = item.catalogID?.nonEmpty {
            append("\(item.kind.rawValue.lowercased()):catalog:\(catalogID)")
        }
        append("\(item.kind.rawValue.lowercased()):id:\(item.id)")
        return keys
    }

    private func cachedCatalogItems(for item: Track) -> (key: String, entry: CachedCatalogItems)? {
        for key in catalogItemsCacheKeys(for: item) {
            if let entry = catalogItemsCache[key] {
                return (key, entry)
            }
        }

        return nil
    }

    private func isFreshCatalogCache(_ cached: CachedCatalogItems) -> Bool {
        Date().timeIntervalSince(cached.createdAt) <= catalogCacheTTL
    }

    private func cacheCatalogItems(_ items: [Track], for item: Track) {
        let entry = CachedCatalogItems(items: items, createdAt: Date())
        for key in catalogItemsCacheKeys(for: item) {
            catalogItemsCache[key] = entry
        }

        guard catalogItemsCache.count > catalogCacheLimit else { return }
        let keysToRemove = catalogItemsCache
            .sorted { $0.value.createdAt < $1.value.createdAt }
            .prefix(catalogItemsCache.count - catalogCacheLimit)
            .map(\.key)
        for key in keysToRemove {
            catalogItemsCache.removeValue(forKey: key)
        }
    }

    private func prefetchCatalogDetails(from items: [Track]) {
        catalogPrefetchTask?.cancel()

        let targets = uniqueCollectionItems(in: items)
            .filter { item in
                guard item.kind == .artist || item.kind == .album else { return false }
                if cachedCatalogItems(for: item) != nil { return false }
                if let catalogInFlightKey {
                    return !catalogItemsCacheKeys(for: item).contains(catalogInFlightKey)
                }
                return true
            }
            .prefix(catalogPrefetchLimit)

        guard !targets.isEmpty else { return }

        catalogPrefetchTask = Task { [weak self] in
            guard let self else { return }

            for target in targets {
                guard !Task.isCancelled else { return }
                if cachedCatalogItems(for: target) != nil { continue }

                do {
                    let items = try await provider.catalogItems(for: target)
                    guard !Task.isCancelled else { return }
                    cacheCatalogItems(items, for: target)
                } catch {
                    continue
                }
            }
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
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }

                if let providerProgress = provider.currentPlaybackTime() {
                    updateProgress(to: providerProgress)
                } else {
                    advanceProgress(by: 0.1)
                }
            }
        }
    }

    private func applyFeaturedTracks(_ tracks: [Track]) {
        featuredTracks = tracks
        visibleTracks = searchQuery.trimmed.isEmpty ? tracks : visibleTracks
        activePlaybackContext = []
        if searchQuery.trimmed.isEmpty {
            resultTitle = "Catalog Tracks"
            resultSubtitle = nil
            catalogContext = nil
        }
        preparePlaybackContext()
    }

    private func loadLyrics(for track: Track) {
        lyricsTask?.cancel()

        guard track.isPlayable else {
            lyricsState = .idle
            return
        }

        if let cachedLyrics = lyricsCache[track.id] {
            applyLyrics(cachedLyrics)
            return
        }

        lyricsState = .loading
        lyricsTask = Task { [weak self] in
            guard let self else { return }

            do {
                let lyrics = try await provider.lyrics(for: track)
                guard !Task.isCancelled, currentTrack == track else { return }
                lyricsCache[track.id] = lyrics
                applyLyrics(lyrics)
            } catch {
                guard !Task.isCancelled, currentTrack == track else { return }
                lyricsState = .failed(error.localizedDescription)
            }
        }
    }

    private func applyLyrics(_ lyrics: TrackLyrics) {
        lyricsState = lyrics.isAvailable
            ? .loaded(lyrics)
            : .unavailable("No lyrics available for this track.")
    }

    private func advanceProgress(by delta: TimeInterval) {
        guard playbackState == .playing, let currentTrack else { return }

        progress += delta
        if maybeStartCrossfade(for: currentTrack) {
            return
        }
        if progress >= currentTrack.duration {
            progress = currentTrack.duration
            next()
        }
    }

    private func updateProgress(to playbackTime: TimeInterval) {
        guard playbackState == .playing, let currentTrack else { return }

        progress = min(max(playbackTime, 0), currentTrack.duration)
        if maybeStartCrossfade(for: currentTrack) {
            return
        }
        if progress >= currentTrack.duration {
            next()
        }
    }

    private func maybeStartCrossfade(for track: Track) -> Bool {
        guard !isAdvancingWithCrossfade,
              crossfadeDuration > 0,
              track.duration > crossfadeDuration + 1,
              progress >= track.duration - crossfadeDuration,
              let nextTrack = crossfadeCandidate()
        else {
            return false
        }

        startCrossfade(to: nextTrack)
        return true
    }

    private func crossfadeCandidate() -> Track? {
        guard repeatMode != .one else { return nil }

        if let nextTrack = queue.first {
            return nextTrack
        }

        if isShuffled {
            return shuffledPlaybackCandidates(excluding: currentTrack).first
        }

        let context = currentPlaybackContext
        guard let currentTrack,
              let index = context.firstIndex(of: currentTrack),
              !context.isEmpty
        else {
            return repeatMode == .all ? context.first(where: \.isPlayable) : nil
        }

        let isLastTrack = context.index(after: index) == context.endIndex
        guard !isLastTrack || repeatMode == .all else { return nil }
        let nextIndex = isLastTrack ? context.startIndex : context.index(after: index)
        return context[nextIndex]
    }

    private func startCrossfade(to nextTrack: Track) {
        playbackTask?.cancel()
        isAdvancingWithCrossfade = true

        if queue.first == nextTrack {
            queue.removeFirst()
        } else {
            queue.removeAll { $0 == nextTrack }
        }

        currentTrack = nextTrack
        progress = 0
        playbackState = .playing
        errorMessage = nil
        loadLyrics(for: nextTrack)
        prepare(Array(([nextTrack] + queue).prefix(playbackContextLimit)))

        playbackTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await provider.crossfade(to: nextTrack, duration: crossfadeDuration)
                guard !Task.isCancelled else { return }
                recordListening(nextTrack)
                playbackState = .playing
                isAdvancingWithCrossfade = false
                refillQueue(after: nextTrack)
                preparePlaybackContext()
            } catch is CancellationError {
                isAdvancingWithCrossfade = false
            } catch {
                guard !Task.isCancelled else { return }
                isAdvancingWithCrossfade = false
                handlePlaybackFailure(error)
            }
        }
    }

    private func refillQueue(after track: Track) {
        guard queue.count < playbackContextLimit else { return }

        var queuedIDs = Set(queue.map(\.id))
        queuedIDs.insert(track.id)
        if let currentTrack {
            queuedIDs.insert(currentTrack.id)
        }

        if !activePlaybackContext.isEmpty,
           activePlaybackContext.contains(track) {
            let candidates = playbackQueue(after: track, in: activePlaybackContext, limit: playbackContextLimit)
            for candidate in candidates where queue.count < playbackContextLimit {
                guard candidate != currentTrack,
                      !queue.contains(candidate),
                      !queuedIDs.contains(candidate.id)
                else { continue }

                queue.append(candidate)
                queuedIDs.insert(candidate.id)
            }

            preparePlaybackContext()
            return
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

    private func persistEqualizerSettings() {
        userDefaults.set(equalizerSettings.isEnabled, forKey: Self.equalizerEnabledKey)
        userDefaults.set(equalizerSettings.preset.rawValue, forKey: Self.equalizerPresetKey)
        userDefaults.set(equalizerSettings.normalizedBandGains, forKey: Self.equalizerBandsKey)
    }

    private static func normalizedCrossfadeDuration(_ duration: TimeInterval) -> TimeInterval {
        min(max(duration, 0), 8)
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
        append(activePlaybackContext)
        append(visibleTracks)
        append(featuredTracks)

        return result
    }

    private var currentPlaybackContext: [Track] {
        if !activePlaybackContext.isEmpty {
            return activePlaybackContext
        }

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
        tracks.append(contentsOf: localPlaylists.flatMap { $0.orderedTracks(preferredTracks: []) })
        return uniquePlayableTracks(in: tracks)
    }

    private var knownCollectionItems: [Track] {
        var items: [Track] = []
        if let catalogContext {
            items.append(catalogContext)
        }
        items.append(contentsOf: visibleTracks)
        items.append(contentsOf: featuredTracks)
        return uniqueCollectionItems(in: items)
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

    private func uniqueCollectionItems(in items: [Track]) -> [Track] {
        var result: [Track] = []
        var seenIDs = Set<String>()

        for item in items {
            guard !item.isPlayable,
                  seenIDs.insert(item.id).inserted
            else { continue }
            result.append(item)
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

    private func startMCPBridge() {
        MCPLibraryBridge.ensureFiles(permissions: mcpPermissions)
        exportMCPLibrarySnapshot()

        mcpBridgeTask?.cancel()
        mcpBridgeTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.importExternalMCPSnapshotIfNeeded()
                self?.mcpPermissions = MCPLibraryBridge.loadPermissions()
                self?.mcpActivityLog = MCPLibraryBridge.loadActivityLog()
                self?.mcpServerStatus = MCPLibraryBridge.loadServerStatus()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var mcpKnownTracks: [Track] {
        uniquePlayableTracks(
            in: knownPlaybackTracks
                + Array(likedTrackSnapshots.values)
                + Array(savedCollectionSnapshots.values)
                + localPlaylists.flatMap { $0.orderedTracks(preferredTracks: knownPlaybackTracks) }
        )
    }

    private func exportMCPLibrarySnapshot() {
        guard !isApplyingMCPSnapshot else { return }
        let snapshot = MCPLibraryBridge.snapshot(
            tracks: mcpKnownTracks,
            likedIDs: likedTrackIDs,
            savedIDs: savedCollectionIDs,
            playlists: localPlaylists,
            permissions: mcpPermissions
        )
        MCPLibraryBridge.saveSnapshot(snapshot)
        mcpLastSyncedAt = Date()
        mcpLastSeenLibraryModificationDate = Self.fileModificationDate(MCPLibraryBridge.libraryURL)
    }

    private func importExternalMCPSnapshotIfNeeded() {
        guard let modificationDate = Self.fileModificationDate(MCPLibraryBridge.libraryURL),
              modificationDate != mcpLastSeenLibraryModificationDate,
              let snapshot = MCPLibraryBridge.loadSnapshot()
        else { return }

        mcpLastSeenLibraryModificationDate = modificationDate

        let importedPlaylists = Self.normalizedLocalPlaylists(MCPLibraryBridge.playlists(from: snapshot))
        if importedPlaylists != localPlaylists {
            isApplyingMCPSnapshot = true
            localPlaylists = importedPlaylists
            Self.persistLocalPlaylists(localPlaylists, to: userDefaults)
            isApplyingMCPSnapshot = false
        }

        if snapshot.permissions != mcpPermissions {
            mcpPermissions = snapshot.permissions
            MCPLibraryBridge.savePermissions(snapshot.permissions)
        }

        mcpLastSyncedAt = Date()
    }

    private static func fileModificationDate(_ url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private func recordListening(_ track: Track) {
        listeningScores[track.id, default: 0] += 1
        persistListeningScores()
    }

    private func persistLikedTracks() {
        userDefaults.set(Array(likedTrackIDs).sorted(), forKey: Self.likedTrackIDsKey)
        likedTrackOrder = Self.normalizedLikedTrackOrder(likedTrackOrder, likedIDs: likedTrackIDs)
        userDefaults.set(likedTrackOrder, forKey: Self.likedTrackOrderKey)
        likedTrackSnapshots = likedTrackSnapshots.filter { likedTrackIDs.contains($0.key) }
        Self.persistLikedTrackSnapshots(likedTrackSnapshots, to: userDefaults)
        exportMCPLibrarySnapshot()
    }

    private func persistSavedCollections() {
        userDefaults.set(Array(savedCollectionIDs).sorted(), forKey: Self.savedCollectionIDsKey)
        savedCollectionOrder = Self.normalizedSavedCollectionOrder(savedCollectionOrder, savedIDs: savedCollectionIDs)
        userDefaults.set(savedCollectionOrder, forKey: Self.savedCollectionOrderKey)
        savedCollectionSnapshots = savedCollectionSnapshots.filter { savedCollectionIDs.contains($0.key) }
        Self.persistSavedCollectionSnapshots(savedCollectionSnapshots, to: userDefaults)
        exportMCPLibrarySnapshot()
    }

    private func updatePlaylist(playlistID: String, _ update: (inout LocalPlaylist) -> Void) {
        guard let index = localPlaylists.firstIndex(where: { $0.id == playlistID }) else { return }

        let originalPlaylist = localPlaylists[index]
        update(&localPlaylists[index])
        localPlaylists[index].normalize()

        guard localPlaylists[index] != originalPlaylist else { return }
        persistLocalPlaylists()
    }

    private func persistLocalPlaylists() {
        localPlaylists = Self.normalizedLocalPlaylists(localPlaylists)
        Self.persistLocalPlaylists(localPlaylists, to: userDefaults)
        exportMCPLibrarySnapshot()
    }

    private func persistImportHistory() {
        guard let data = try? JSONEncoder().encode(importHistory) else { return }
        userDefaults.set(data, forKey: Self.importHistoryKey)
    }

    private static func normalizedLikedTrackOrder(_ order: [String], likedIDs: Set<String>) -> [String] {
        var seenIDs: Set<String> = []
        var normalizedOrder = order.filter { id in
            likedIDs.contains(id) && seenIDs.insert(id).inserted
        }

        let missingIDs = likedIDs.subtracting(normalizedOrder)
        normalizedOrder.append(contentsOf: missingIDs.sorted())
        return normalizedOrder
    }

    private static func normalizedSavedCollectionOrder(_ order: [String], savedIDs: Set<String>) -> [String] {
        var seenIDs: Set<String> = []
        var normalizedOrder = order.filter { id in
            savedIDs.contains(id) && seenIDs.insert(id).inserted
        }

        let missingIDs = savedIDs.subtracting(normalizedOrder)
        normalizedOrder.append(contentsOf: missingIDs.sorted())
        return normalizedOrder
    }

    private static func loadLikedTrackSnapshots(from userDefaults: UserDefaults, likedIDs: Set<String>) -> [String: Track] {
        guard let data = userDefaults.data(forKey: Self.likedTrackSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([String: Track].self, from: data)
        else { return [:] }

        return snapshots.filter { likedIDs.contains($0.key) }
    }

    private static func persistLikedTrackSnapshots(_ snapshots: [String: Track], to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        userDefaults.set(data, forKey: Self.likedTrackSnapshotsKey)
    }

    private static func loadSavedCollectionSnapshots(from userDefaults: UserDefaults, savedIDs: Set<String>) -> [String: Track] {
        guard let data = userDefaults.data(forKey: Self.savedCollectionSnapshotsKey),
              let snapshots = try? JSONDecoder().decode([String: Track].self, from: data)
        else { return [:] }

        return snapshots.filter { savedIDs.contains($0.key) }
    }

    private static func persistSavedCollectionSnapshots(_ snapshots: [String: Track], to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        userDefaults.set(data, forKey: Self.savedCollectionSnapshotsKey)
    }

    private static func loadLocalPlaylists(from userDefaults: UserDefaults) -> [LocalPlaylist] {
        guard let data = userDefaults.data(forKey: Self.localPlaylistsKey),
              let playlists = try? JSONDecoder().decode([LocalPlaylist].self, from: data)
        else { return [] }

        return normalizedLocalPlaylists(playlists)
    }

    private static func normalizedLocalPlaylists(_ playlists: [LocalPlaylist]) -> [LocalPlaylist] {
        var seenIDs: Set<String> = []
        var titleIndex: [String: Int] = [:]
        var normalizedPlaylists: [LocalPlaylist] = []

        for playlist in playlists {
            guard seenIDs.insert(playlist.id).inserted else { continue }

            var normalizedPlaylist = playlist
            normalizedPlaylist.normalize()

            let titleKey = normalizedPlaylist.title.searchNormalized
            if let existingIndex = titleIndex[titleKey] {
                var existingPlaylist = normalizedPlaylists[existingIndex]
                let mergedUpdatedAt = max(existingPlaylist.updatedAt, normalizedPlaylist.updatedAt)
                _ = existingPlaylist.append(
                    normalizedPlaylist.orderedTracks(preferredTracks: []),
                    updatedAt: mergedUpdatedAt
                )
                normalizedPlaylists[existingIndex] = existingPlaylist
            } else {
                titleIndex[titleKey] = normalizedPlaylists.count
                normalizedPlaylists.append(normalizedPlaylist)
            }
        }

        return normalizedPlaylists
    }

    private static func persistLocalPlaylists(_ playlists: [LocalPlaylist], to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        userDefaults.set(data, forKey: Self.localPlaylistsKey)
    }

    private static func loadImportHistory(from userDefaults: UserDefaults) -> [MusicImportHistoryRecord] {
        guard let data = userDefaults.data(forKey: Self.importHistoryKey),
              let records = try? JSONDecoder().decode([MusicImportHistoryRecord].self, from: data)
        else { return [] }

        return Array(records.prefix(10))
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

private struct CachedCatalogItems {
    let items: [Track]
    let createdAt: Date
}
