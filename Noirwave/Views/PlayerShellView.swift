import SwiftUI

struct PlayerShellView: View {
    @EnvironmentObject private var store: PlayerStore

    private var palette: TrackPalette {
        store.currentTrack?.palette ?? .fallback
    }

    var body: some View {
        ZStack {
            DynamicStudioBackground(palette: palette)

            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: 232)

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 1)

                VStack(spacing: 0) {
                    TopBarView()
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                        .padding(.bottom, 14)

                    ContentDeckView()
                }

                NowPlayingPanel()
                    .frame(width: 362)
                    .padding(.trailing, 16)
                    .padding(.vertical, 16)
            }
        }
    }
}

private struct DynamicStudioBackground: View {
    let palette: TrackPalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    palette.base,
                    palette.mid.opacity(0.78),
                    Color(hex: "#08090B")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    palette.accent.opacity(0.42),
                    .clear,
                    palette.mid.opacity(0.35)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .blendMode(.screen)

            Rectangle()
                .fill(.black.opacity(0.28))

            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.07)).frame(height: 1)
                Spacer()
                Rectangle().fill(.black.opacity(0.35)).frame(height: 96)
            }
        }
        .ignoresSafeArea()
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isShowingSessionSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((store.currentTrack?.palette.accent ?? .white).opacity(0.92))
                    Image(systemName: "waveform")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Noirwave")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text(store.provider.sourceName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                }
            }
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 8) {
                SidebarItem(title: "Studio", symbol: "music.quarternote.3", active: true)
                SidebarItem(title: "Queue", symbol: "text.line.first.and.arrowtriangle.forward", active: false)
                SidebarItem(title: "Search", symbol: "square.stack.3d.up", active: false)
            }

            Spacer()

            ProviderStatusView()

            VStack(spacing: 8) {
                Button {
                    isShowingSessionSettings = true
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "key.viewfinder")
                        Text("Stream Session")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Configure Deezer ARL")

                Button {
                    store.connectProvider()
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: store.providerStatus.canPlayCatalogContent ? "arrow.clockwise" : "network")
                        Text(store.providerStatus.canPlayCatalogContent ? "Refresh Source" : "Connect Source")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Connect or refresh the local stream source")
            }
        }
        .sheet(isPresented: $isShowingSessionSettings) {
            SessionSettingsSheet()
                .environmentObject(store)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .foregroundStyle(.white)
        .background(.regularMaterial)
    }
}

private struct SidebarItem: View {
    let title: String
    let symbol: String
    let active: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
            Text(title)
            Spacer()
        }
        .font(.system(size: 13, weight: active ? .semibold : .regular))
        .foregroundStyle(active ? .white : .white.opacity(0.58))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(active ? .white.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                Text(store.providerStatus.canPlayCatalogContent ? "Catalog OK" : "Offline")
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
            return store.providerStatus.canPlayCatalogContent ? "Ready" : "Needs setup"
        case .notDetermined:
            return "Not connected"
        case .denied:
            return "Access denied"
        case .restricted:
            return "Restricted"
        case .unsupported:
            return "Unsupported"
        }
    }

    private var statusColor: Color {
        if store.needsBackendSession {
            return .orange
        }

        return store.providerStatus.authorization == .authorized ? .green : .white.opacity(0.35)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.64))
        }
    }
}

private struct TopBarView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.52))
                TextField(
                    "Search tracks, artists, albums",
                    text: Binding(
                        get: { store.searchQuery },
                        set: { store.updateSearchQuery($0) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 15))
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.11), lineWidth: 1)
            )

            Picker(
                "",
                selection: Binding(
                    get: { store.selectedScope },
                    set: { store.setScope($0) }
                )
            ) {
                ForEach(SearchScope.allCases) { scope in
                    Label(scope.rawValue, systemImage: scope.systemImage)
                        .tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 310)
        }
    }
}

private struct ContentDeckView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                FeaturedStripView()

                if let errorMessage = store.errorMessage {
                    PlaybackErrorBanner(message: errorMessage)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.resultTitle)
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                            if let subtitle = store.resultSubtitle {
                                Text(subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.52))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if store.isSearching || store.isLoadingFeaturedTracks {
                            ProgressView()
                                .scaleEffect(0.72)
                        }
                    }

                    if store.visibleTracks.isEmpty,
                       store.searchQuery.trimmed.isEmpty,
                       !store.isLoadingFeaturedTracks {
                        MusicConnectPanel()
                    } else {
                        TrackListView(tracks: store.visibleTracks)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
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
        .padding(.vertical, 48)
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

private struct FeaturedStripView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(store.featuredTracks.prefix(5)) { track in
                    FeaturedTrackCard(track: track)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FeaturedTrackCard: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track

    var body: some View {
        Button {
            store.activate(track)
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                ArtworkTile(track: track, size: 132, cornerRadius: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                }
            }
            .frame(width: 132, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help("Play \(track.title)")
    }
}

private struct TrackListView: View {
    @EnvironmentObject private var store: PlayerStore
    let tracks: [Track]

    private var playableTracks: [Track] {
        tracks.filter(\.isPlayable)
    }

    private var mediaItems: [Track] {
        tracks.filter { !$0.isPlayable }
    }

    var body: some View {
        if tracks.isEmpty {
            EmptySearchView()
        } else if playableTracks.isEmpty {
            MediaCardGridView(items: mediaItems)
        } else if mediaItems.isEmpty {
            VStack(spacing: 7) {
                ForEach(playableTracks) { track in
                    TrackRowView(track: track)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ResultSection(title: "Popular Tracks") {
                    VStack(spacing: 7) {
                        ForEach(playableTracks) { track in
                            TrackRowView(track: track)
                        }
                    }
                }

                ResultSection(title: "Albums") {
                    MediaCardGridView(items: mediaItems)
                }
            }
        }
    }
}

private struct ResultSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.68))
            content
        }
    }
}

private struct MediaCardGridView: View {
    let items: [Track]

    private let columns = [
        GridItem(.adaptive(minimum: 142, maximum: 176), spacing: 12, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(items) { item in
                MediaCardView(item: item)
            }
        }
    }
}

private struct MediaCardView: View {
    @EnvironmentObject private var store: PlayerStore
    let item: Track

    private var cornerRadius: CGFloat {
        item.kind == .artist ? 72 : 8
    }

    var body: some View {
        Button {
            store.activate(item)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                ArtworkTile(track: item, size: 142, cornerRadius: cornerRadius)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        MediaKindBadge(kind: item.kind)
                        Spacer(minLength: 0)
                    }

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.detailLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Open \(item.title)")
    }
}

private struct TrackRowView: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track

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
            Button {
                store.activate(track)
            } label: {
                ZStack {
                    ArtworkTile(track: track, size: 44, cornerRadius: 8)
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
            .help(track.isPlayable ? "Play \(track.title)" : "Show tracks for \(track.title)")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    MediaKindBadge(kind: track.kind)
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(track.detailLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            if track.isPlayable {
                Text(track.durationLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
                    .frame(width: 42, alignment: .trailing)

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
    }
}

private struct MediaKindBadge: View {
    let kind: TrackKind

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 8, weight: .bold))
            Text(kind.rawValue)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.white.opacity(0.72))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
            Text("No tracks found")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct NowPlayingPanel: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var selectedPanel: NowPlayingPanelMode = .lyrics

    private var track: Track? {
        store.currentTrack
    }

    var body: some View {
        VStack(spacing: 18) {
            if let track {
                ArtworkTile(track: track, size: 300, cornerRadius: 18)
                    .shadow(color: track.palette.accent.opacity(0.28), radius: 24, x: 0, y: 18)

                VStack(spacing: 5) {
                    Text(track.title)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("\(track.artist) · \(track.album)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                }

                ProgressStack(track: track)
                PlaybackStatusLine()
                PlaybackControlsView()
                NowPlayingPanelPicker(selectedPanel: $selectedPanel)

                switch selectedPanel {
                case .lyrics:
                    LyricsPanelView(track: track)
                case .queue:
                    QueuePanelView()
                }
            }
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
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

private struct PlaybackStatusLine: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        if case .failed(let message) = store.playbackState {
            HStack(spacing: 6) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 11, weight: .semibold))
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

private struct LyricsPanelView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isShowingExpandedLyrics = false
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Lyrics", systemImage: "text.quote")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()

                Button {
                    isShowingExpandedLyrics = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 28, height: 24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .help("Expand lyrics")
            }

            LyricsReaderContentView(track: track, isExpanded: false)
        }
        .padding(12)
        .frame(minHeight: 220, maxHeight: 310)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
        .sheet(isPresented: $isShowingExpandedLyrics) {
            ExpandedLyricsSheet(track: track)
                .environmentObject(store)
        }
    }
}

private struct ExpandedLyricsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " • "))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .help("Close")
            }

            LyricsReaderContentView(track: track, isExpanded: true)
        }
        .padding(22)
        .frame(minWidth: 560, idealWidth: 660, minHeight: 640, idealHeight: 760)
        .background {
            ZStack {
                track.palette.base.opacity(0.56)
                track.palette.mid.opacity(0.32)
                Rectangle().fill(.regularMaterial)
            }
            .ignoresSafeArea()
        }
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

private struct ProgressStack: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track

    private var progressFraction: Double {
        guard track.duration > 0 else { return 0 }
        return min(max(store.progress / track.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
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
        HStack(spacing: 16) {
            IconControlButton(symbol: "backward.fill", size: 42, isPrimary: false) {
                store.previous()
            }
            .help("Previous")

            IconControlButton(symbol: playSymbol, size: 56, isPrimary: true) {
                store.togglePlayPause()
            }
            .help("Play/Pause")

            IconControlButton(symbol: "forward.fill", size: 42, isPrimary: false) {
                store.next()
            }
            .help("Next")
        }
    }
}

private struct IconControlButton: View {
    @EnvironmentObject private var store: PlayerStore
    let symbol: String
    let size: CGFloat
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: isPrimary ? 20 : 15, weight: .bold))
                .frame(width: size, height: size)
                .foregroundStyle(isPrimary ? .black : .white.opacity(0.82))
                .background(
                    isPrimary
                        ? (store.currentTrack?.palette.accent ?? .white)
                        : .white.opacity(0.1),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct QueuePanelView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Up Next")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(store.queue.count)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            VStack(spacing: 6) {
                ForEach(store.queue.prefix(5)) { track in
                    QueueRowView(track: track)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct QueueRowView: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track

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
