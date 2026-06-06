import AppKit
import SwiftUI

private enum NoirwaveTheme {
    static let accent = Color(hex: "#5EE0C2")
    static let background = Color(hex: "#0A1211")
    static let panel = Color(hex: "#111B1A")
    static let panelRaised = Color(hex: "#182322")
    static let stroke = Color.white.opacity(0.1)
    static let secondaryText = Color.white.opacity(0.58)
}

private struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillOpacity: Double
    let strokeOpacity: Double
    let tintOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(NoirwaveTheme.panel.opacity(fillOpacity))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.16),
                                .white.opacity(0.035),
                                NoirwaveTheme.accent.opacity(tintOpacity),
                                .black.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(strokeOpacity + 0.08),
                                NoirwaveTheme.accent.opacity(strokeOpacity),
                                .white.opacity(strokeOpacity * 0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

private struct AccentGlassButtonStyle: ButtonStyle {
    enum ShapeKind {
        case rounded(CGFloat)
        case circle
    }

    let isActive: Bool
    let isPrimary: Bool
    let shape: ShapeKind

    init(isActive: Bool = false, isPrimary: Bool = false, shape: ShapeKind) {
        self.isActive = isActive
        self.isPrimary = isPrimary
        self.shape = shape
    }

    func makeBody(configuration: Configuration) -> some View {
        let isHighlighted = isPrimary || isActive
        let fillColor = isHighlighted ? NoirwaveTheme.accent : .white.opacity(configuration.isPressed ? 0.16 : 0.08)
        let strokeColor = isHighlighted ? .white.opacity(0.28) : NoirwaveTheme.stroke

        configuration.label
            .foregroundStyle(isHighlighted ? .black : .white.opacity(0.74))
            .background {
                fillShape(fillColor)
                fillShape(.white.opacity(configuration.isPressed ? 0.1 : 0.045))
                    .blendMode(.screen)
                highlightShape()
            }
            .overlay {
                strokeShape(strokeColor)
            }
            .shadow(
                color: (isHighlighted ? NoirwaveTheme.accent.opacity(0.28) : .black.opacity(0.14)),
                radius: isHighlighted ? 16 : 10,
                x: 0,
                y: isHighlighted ? 8 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }

    @ViewBuilder
    private func fillShape(_ color: Color) -> some View {
        switch shape {
        case .rounded(let radius):
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color)
        case .circle:
            Circle()
                .fill(color)
        }
    }

    @ViewBuilder
    private func strokeShape(_ color: Color) -> some View {
        switch shape {
        case .rounded(let radius):
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(color, lineWidth: 1)
        case .circle:
            Circle()
                .stroke(color, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func highlightShape() -> some View {
        switch shape {
        case .rounded(let radius):
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear, NoirwaveTheme.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
        case .circle:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear, NoirwaveTheme.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
        }
    }
}

private extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 8,
        fillOpacity: Double = 0.34,
        strokeOpacity: Double = 0.11,
        tintOpacity: Double = 0.055
    ) -> some View {
        modifier(
            LiquidGlassModifier(
                cornerRadius: cornerRadius,
                fillOpacity: fillOpacity,
                strokeOpacity: strokeOpacity,
                tintOpacity: tintOpacity
            )
        )
    }
}

struct PlayerShellView: View {
    @EnvironmentObject private var store: PlayerStore

    private var palette: TrackPalette {
        store.currentTrack?.palette ?? .fallback
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DynamicStudioBackground(palette: palette)

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        SidebarView()
                            .frame(width: 258)
                            .zIndex(2)

                        Rectangle()
                            .fill(NoirwaveTheme.stroke)
                            .frame(width: 1)

                        ContentDeckView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if let mode = store.utilityPanelMode {
                            Rectangle()
                                .fill(NoirwaveTheme.stroke)
                                .frame(width: 1)

                            UtilityDrawerView(mode: mode)
                                .frame(width: min(max(geometry.size.width * 0.27, 360), 440))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    BottomMiniPlayerView()
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                }
            }
            .animation(.snappy(duration: 0.24), value: store.utilityPanelMode?.rawValue)
        }
    }
}

private struct DynamicStudioBackground: View {
    let palette: TrackPalette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#0A1211"),
                    Color(hex: "#111B1A"),
                    Color(hex: "#07100F")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    NoirwaveTheme.accent.opacity(0.18),
                    .clear,
                    palette.mid.opacity(0.16)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    .white.opacity(0.08),
                    .clear,
                    .black.opacity(0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(.black.opacity(0.08))

            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                Spacer()
                Rectangle().fill(.black.opacity(0.1)).frame(height: 110)
            }
        }
        .ignoresSafeArea()
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var store: PlayerStore
    @State private var isShowingSessionSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(NoirwaveTheme.accent)
                    Text("nw")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                }
                .frame(width: 34, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Noirwave")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(store.provider.sourceName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                }
            }
            .padding(.top, 22)

            SidebarSearchField()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(PlayerSection.allCases.filter { $0 != .favourites }) { section in
                    SidebarItem(
                        title: section.rawValue,
                        symbol: section.systemImage,
                        active: store.selectedSection == section
                    ) {
                        store.selectSection(section)
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                ProviderStatusView()
                Button {
                    store.connectProvider()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(store.providerStatus.canPlayCatalogContent ? "Refresh" : "Connect")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .liquidGlass(fillOpacity: 0.18, strokeOpacity: 0.08, tintOpacity: 0.035)
                }
                .buttonStyle(.plain)
                .help("Connect or refresh source")
            }

            VStack(spacing: 8) {
                Button {
                    isShowingSessionSettings = true
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .liquidGlass(fillOpacity: 0.2, strokeOpacity: 0.08, tintOpacity: 0.04)
                }
                .buttonStyle(.plain)
                .help("Open playback and source settings")
            }
        }
        .sheet(isPresented: $isShowingSessionSettings) {
            SessionSettingsSheet()
                .environmentObject(store)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .foregroundStyle(.white)
        .liquidGlass(cornerRadius: 0, fillOpacity: 0.5, strokeOpacity: 0.05, tintOpacity: 0.05)
    }
}

private struct SidebarItem: View {
    let title: String
    let symbol: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 18)
                Text(title)
                Spacer()
            }
            .font(.system(size: 13, weight: active ? .semibold : .regular))
            .foregroundStyle(active ? NoirwaveTheme.accent : .white.opacity(0.62))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .liquidGlass(
                fillOpacity: active ? 0.22 : 0.08,
                strokeOpacity: active ? 0.17 : 0.04,
                tintOpacity: active ? 0.075 : 0.016
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(active ? NoirwaveTheme.accent.opacity(0.3) : .white.opacity(0.035), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarSearchField: View {
    @EnvironmentObject private var store: PlayerStore
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            TextField(
                "Search",
                text: Binding(
                    get: { store.searchQuery },
                    set: { store.updateSearchQuery($0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .focused($isFocused)

            if !store.searchQuery.trimmed.isEmpty {
                Button {
                    store.updateSearchQuery("")
                    isFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.46))
                .frame(width: 22, height: 22)
                .liquidGlass(cornerRadius: 999, fillOpacity: 0.1, strokeOpacity: 0.04, tintOpacity: 0.018)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .liquidGlass(
            fillOpacity: isFocused ? 0.24 : 0.16,
            strokeOpacity: isFocused ? 0.22 : 0.08,
            tintOpacity: isFocused ? 0.08 : 0.025
        )
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
                        .fill(NoirwaveTheme.accent)
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Playback Source")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("Local mode by default")
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
                }
                .buttonStyle(AccentGlassButtonStyle(shape: .circle))
                .help("Close")
            }

            ProviderStatusCard()

            Text("Noirwave starts in local free mode and does not read Keychain ARL automatically. Deezer ARL is optional and only used when you paste it here.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 9) {
                Text("Optional Deezer ARL")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.74))

                SecureField("Paste ARL", text: $sessionToken)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .focused($isTokenFocused)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .liquidGlass(
                        fillOpacity: isTokenFocused ? 0.28 : 0.18,
                        strokeOpacity: isTokenFocused ? 0.2 : 0.08,
                        tintOpacity: isTokenFocused ? 0.08 : 0.035
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

                        Text(store.isConfiguringBackendSession ? "Connecting" : "Connect Deezer")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(AccentGlassButtonStyle(isPrimary: canSubmit, shape: .rounded(8)))
                .disabled(!canSubmit)
                .help("Connect ARL")

                Button {
                    store.connectProvider()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Local Mode")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 132)
                    .frame(height: 38)
                    .liquidGlass(fillOpacity: 0.18, strokeOpacity: 0.08, tintOpacity: 0.035)
                }
                .buttonStyle(.plain)
                .help("Refresh local source")
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
                .liquidGlass(fillOpacity: 0.18, strokeOpacity: 0.08, tintOpacity: 0.035)
            }
        }
        .padding(20)
        .frame(width: 440)
        .foregroundStyle(.white)
        .background {
            NoirwaveTheme.panel.opacity(0.84)
            Rectangle().fill(.regularMaterial)
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

private struct ProviderStatusCard: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProviderStatusView()
                Spacer()
                Text(store.providerStatus.canPlayCatalogContent ? "Catalog OK" : "Offline")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(store.providerStatus.canPlayCatalogContent ? NoirwaveTheme.accent : .white.opacity(0.45))
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
        .liquidGlass(fillOpacity: 0.18, strokeOpacity: 0.08, tintOpacity: 0.04)
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
            return "Backend offline"
        }
    }

    private var statusColor: Color {
        if store.needsBackendSession {
            return .orange
        }

        return store.providerStatus.authorization == .authorized ? NoirwaveTheme.accent : .white.opacity(0.35)
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

private struct ContentDeckView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let errorMessage = store.errorMessage {
                    PlaybackErrorBanner(message: errorMessage)
                }

                if !store.searchQuery.trimmed.isEmpty || store.isSearching {
                    SearchSectionView()
                } else {
                    switch store.selectedSection {
                    case .studio:
                        StudioSectionView()
                    case .wave:
                        WaveSectionView()
                    case .library:
                        LibrarySectionView()
                    case .favourites:
                        FavouritesSectionView()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct StudioSectionView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeaderView(
                title: "Studio",
                subtitle: "Fresh catalog picks and current source tracks",
                isLoading: store.isLoadingFeaturedTracks
            )

            FeaturedStripView()

            if store.visibleTracks.isEmpty,
               store.searchQuery.trimmed.isEmpty,
               !store.isLoadingFeaturedTracks {
                MusicConnectPanel()
            } else {
                TrackSectionView(title: "Catalog Tracks", subtitle: nil, tracks: store.visibleTracks)
            }
        }
    }
}

private struct SearchSectionView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: store.resultTitle,
                subtitle: "Tracks, artists, albums",
                isLoading: store.isSearching
            )

            SearchChipRowView()

            TrackSectionView(
                title: store.resultTitle,
                subtitle: store.resultSubtitle,
                tracks: store.visibleTracks
            )
        }
    }
}

private struct WaveSectionView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                SectionHeaderView(
                    title: "Wave",
                    subtitle: "Radio-style recommendations from the current track",
                    isLoading: store.isLoadingWave
                )

                Spacer()

                Button {
                    store.refreshWave()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(AccentGlassButtonStyle(shape: .rounded(8)))
                .help("Refresh Wave")
            }

            TrackSectionView(
                title: "Recommended Next",
                subtitle: store.currentTrack.map { "Seed: \($0.artist) - \($0.title)" },
                tracks: store.waveTracks
            )
        }
        .onAppear {
            if store.waveTracks.isEmpty {
                store.refreshWave()
            }
        }
    }
}

private struct LibrarySectionView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Library",
                subtitle: "Favourites and saved source views live here",
                isLoading: false
            )

            HStack(spacing: 10) {
                LibraryTileView(
                    title: "Favourites",
                    subtitle: "\(store.favouriteTracks.count) liked tracks",
                    symbol: "heart.fill",
                    accent: NoirwaveTheme.accent
                ) {
                    store.selectSection(.favourites)
                }

                LibraryTileView(
                    title: "Recent Source",
                    subtitle: "\(store.featuredTracks.count) catalog tracks",
                    symbol: "clock.arrow.circlepath",
                    accent: NoirwaveTheme.accent.opacity(0.82)
                ) {
                    store.selectSection(.studio)
                }
            }

            TrackSectionView(title: "Recently Loaded", subtitle: nil, tracks: store.featuredTracks)
        }
    }
}

private struct FavouritesSectionView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Favourites",
                subtitle: "Liked tracks saved on this Mac",
                isLoading: false
            )

            TrackSectionView(title: "Liked Tracks", subtitle: nil, tracks: store.favouriteTracks)
        }
    }
}

private struct SectionHeaderView: View {
    let title: String
    let subtitle: String?
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                }
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(0.72)
                    .padding(.top, 6)
            }
        }
    }
}

private struct SearchChipRowView: View {
    @EnvironmentObject private var store: PlayerStore

    private let scopes: [SearchScope] = [.smart, .catalog, .library, .albums]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(scopes) { scope in
                let isActive = store.selectedSearchScope == scope
                Button {
                    store.selectSearchScope(scope)
                } label: {
                    Label(scope.rawValue, systemImage: scope.systemImage)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                }
                .buttonStyle(AccentGlassButtonStyle(isActive: isActive, shape: .rounded(999)))
                .help("Search \(scope.rawValue.lowercased())")
            }
        }
    }
}

private struct TrackSectionView: View {
    let title: String
    let subtitle: String?
    let tracks: [Track]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            TrackListView(tracks: tracks)
        }
    }
}

private struct LibraryTileView: View {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.36))
            }
            .padding(12)
            .liquidGlass(fillOpacity: 0.18, strokeOpacity: 0.08, tintOpacity: 0.04)
        }
        .buttonStyle(.plain)
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
                .frame(height: 34)
                .padding(.horizontal, 14)
            }
            .buttonStyle(AccentGlassButtonStyle(isPrimary: true, shape: .rounded(8)))
            .help(actionTitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .liquidGlass(fillOpacity: 0.2, strokeOpacity: 0.09, tintOpacity: 0.045)
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
                .background(NoirwaveTheme.accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .liquidGlass(fillOpacity: 0.2, strokeOpacity: 0.1, tintOpacity: 0.05)
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
            .padding(10)
            .frame(width: 152, alignment: .leading)
            .liquidGlass(fillOpacity: 0.13, strokeOpacity: 0.055, tintOpacity: 0.024)
        }
        .buttonStyle(.plain)
        .help("Play \(track.title)")
    }
}

private struct TrackListView: View {
    @EnvironmentObject private var store: PlayerStore
    let tracks: [Track]
    @State private var isShowingAllCollections = false

    private var playableTracks: [Track] {
        tracks.filter(\.isPlayable)
    }

    private var collectionTracks: [Track] {
        tracks.filter { !$0.isPlayable }
    }

    private var visibleCollections: [Track] {
        isShowingAllCollections ? collectionTracks : Array(collectionTracks.prefix(5))
    }

    var body: some View {
        if tracks.isEmpty {
            EmptySearchView()
        } else {
            VStack(spacing: 7) {
                ForEach(playableTracks) { track in
                    TrackRowView(track: track)
                }

                ForEach(visibleCollections) { track in
                    TrackRowView(track: track)
                }

                if collectionTracks.count > 5 {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            isShowingAllCollections.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isShowingAllCollections ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                            Text(isShowingAllCollections ? "Show Less" : "Show \(collectionTracks.count - 5) More")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                    }
                    .buttonStyle(AccentGlassButtonStyle(isPrimary: true, shape: .rounded(8)))
                    .help(isShowingAllCollections ? "Collapse list" : "Expand list")
                }
            }
        }
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
            ? AnyShapeStyle(NoirwaveTheme.accent.opacity(0.13))
            : AnyShapeStyle(NoirwaveTheme.panelRaised.opacity(0.12))
    }

    private var artworkCornerRadius: CGFloat {
        track.kind == .artist ? 22 : 8
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.activate(track)
            } label: {
                ZStack {
                    ArtworkTile(track: track, size: 44, cornerRadius: artworkCornerRadius)
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
                    store.toggleFavourite(track)
                } label: {
                    Image(systemName: store.isFavourite(track) ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(AccentGlassButtonStyle(isActive: store.isFavourite(track), shape: .rounded(7)))
                .help(store.isFavourite(track) ? "Remove from favourites" : "Add to favourites")

                Button {
                    store.enqueue(track)
                } label: {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(AccentGlassButtonStyle(shape: .rounded(7)))
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
        .liquidGlass(
            fillOpacity: isCurrent ? 0.24 : 0.12,
            strokeOpacity: isCurrent ? 0.14 : 0.06,
            tintOpacity: isCurrent ? 0.08 : 0.02
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isCurrent ? NoirwaveTheme.accent.opacity(0.38) : .white.opacity(0.07), lineWidth: 1)
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
        .liquidGlass(cornerRadius: 999, fillOpacity: 0.1, strokeOpacity: 0.035, tintOpacity: 0.014)
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
        .liquidGlass(fillOpacity: 0.18, strokeOpacity: 0.08, tintOpacity: 0.035)
    }
}

private struct NowPlayingActionRow: View {
    @EnvironmentObject private var store: PlayerStore
    let track: Track

    var body: some View {
        HStack(spacing: 10) {
            PanelActionButton(
                symbol: store.isFavourite(track) ? "heart.fill" : "heart",
                active: store.isFavourite(track),
                help: store.isFavourite(track) ? "Remove from favourites" : "Add to favourites"
            ) {
                store.toggleFavourite(track)
            }

            PanelActionButton(
                symbol: UtilityPanelMode.lyrics.systemImage,
                active: store.utilityPanelMode == .lyrics,
                help: "Show lyrics"
            ) {
                store.toggleUtilityPanel(.lyrics)
            }

            PanelActionButton(
                symbol: UtilityPanelMode.queue.systemImage,
                active: store.utilityPanelMode == .queue,
                help: "Show queue"
            ) {
                store.toggleUtilityPanel(.queue)
            }

            PanelActionButton(symbol: "dot.radiowaves.left.and.right", active: false, help: "Refresh Wave") {
                store.selectSection(.wave)
                store.refreshWave()
            }
        }
    }
}

private struct BottomMiniPlayerView: View {
    @EnvironmentObject private var store: PlayerStore

    private var track: Track? {
        store.currentTrack
    }

    var body: some View {
        HStack(spacing: 18) {
            if let track {
                HStack(spacing: 12) {
                    ArtworkTile(track: track, size: 52, cornerRadius: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text("\(track.artist) · \(track.album)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.54))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
                .frame(width: 300, alignment: .leading)

                Spacer(minLength: 10)

                VStack(spacing: 8) {
                    PlaybackControlsView()
                    ProgressStack(track: track)
                        .frame(maxWidth: 460)
                }
                .frame(maxWidth: 520)

                Spacer(minLength: 10)

                HStack(spacing: 10) {
                    NowPlayingActionRow(track: track)

                    HStack(spacing: 7) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.54))
                        Slider(value: $store.volume, in: 0...1)
                            .tint(NoirwaveTheme.accent)
                            .frame(width: 90)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .liquidGlass(cornerRadius: 8, fillOpacity: 0.12, strokeOpacity: 0.055, tintOpacity: 0.024)
                }
                .frame(width: 326, alignment: .trailing)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(NoirwaveTheme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Noirwave")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(store.providerStatus.canPlayCatalogContent ? "Ready" : "Connect source")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.54))
                    }

                    Spacer()

                    Button {
                        store.connectProvider()
                    } label: {
                        Image(systemName: store.providerStatus.canPlayCatalogContent ? "arrow.clockwise" : "network")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 38, height: 34)
                    }
                    .buttonStyle(AccentGlassButtonStyle(isPrimary: true, shape: .rounded(8)))
                    .help(store.providerStatus.canPlayCatalogContent ? "Refresh source" : "Connect source")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .foregroundStyle(.white)
        .liquidGlass(cornerRadius: 18, fillOpacity: 0.38, strokeOpacity: 0.16, tintOpacity: 0.085)
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
                .blendMode(.screen)
        }
    }
}

private struct PanelActionButton: View {
    @EnvironmentObject private var store: PlayerStore
    let symbol: String
    let active: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 42, height: 34)
        }
        .buttonStyle(AccentGlassButtonStyle(isActive: active, shape: .rounded(8)))
        .help(help)
    }
}

private struct UtilityDrawerView: View {
    @EnvironmentObject private var store: PlayerStore
    let mode: UtilityPanelMode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label(mode.rawValue, systemImage: mode.systemImage)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    store.closeUtilityPanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(AccentGlassButtonStyle(shape: .circle))
                .help("Close")
            }

            Rectangle()
                .fill(.white.opacity(0.09))
                .frame(height: 1)

            switch mode {
            case .lyrics:
                if let track = store.currentTrack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        LyricsReaderContentView(track: track, isExpanded: true)
                    }
                } else {
                    EmptyPanelMessage(symbol: "text.quote", title: "No active lyrics")
                }
            case .queue:
                QueuePanelView()
            }
        }
        .padding(18)
        .foregroundStyle(.white)
        .frame(maxHeight: .infinity, alignment: .top)
        .liquidGlass(fillOpacity: 0.3, strokeOpacity: 0.12, tintOpacity: 0.065)
        .shadow(color: .black.opacity(0.24), radius: 28, x: -10, y: 16)
    }
}

private struct EmptyPanelMessage: View {
    let symbol: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        Button {
                            store.seek(toTime: line.startTime)
                        } label: {
                            LyricsLineView(
                                text: line.text,
                                isActive: index == activeLineIndex,
                                accent: NoirwaveTheme.accent,
                                isExpanded: isExpanded
                            )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .help("Seek to \(line.startTime.playbackLabel)")
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
            .tint(NoirwaveTheme.accent)

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
        }
        .buttonStyle(AccentGlassButtonStyle(isPrimary: isPrimary, shape: .circle))
    }
}

private struct QueuePanelView: View {
    @EnvironmentObject private var store: PlayerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up Next")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(store.queue.count)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                if !store.queue.isEmpty {
                    Button {
                        store.clearQueue()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(AccentGlassButtonStyle(shape: .rounded(7)))
                    .help("Clear queue")
                }
            }

            if store.queue.isEmpty {
                EmptyPanelMessage(symbol: "text.line.first.and.arrowtriangle.forward", title: "Queue is empty")
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.queue) { track in
                            QueueRowView(track: track)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
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
                store.play(track)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(AccentGlassButtonStyle(shape: .rounded(6)))
            .help("Play now")

            Button {
                store.removeFromQueue(track)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(AccentGlassButtonStyle(shape: .rounded(6)))
            .help("Remove")
        }
        .padding(8)
        .liquidGlass(fillOpacity: 0.13, strokeOpacity: 0.055, tintOpacity: 0.025)
    }
}

@MainActor
private final class ArtworkImageCache {
    static let shared = ArtworkImageCache()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 240
    }

    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

private struct CachedArtworkImage: View {
    let url: URL?

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.16)))
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            await loadArtwork()
        }
    }

    @MainActor
    private func loadArtwork() async {
        guard let url else {
            image = nil
            return
        }

        if let cachedImage = ArtworkImageCache.shared.image(for: url) {
            image = cachedImage
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 12

            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                image = nil
                return
            }

            guard let loadedImage = NSImage(data: data) else {
                image = nil
                return
            }

            ArtworkImageCache.shared.store(loadedImage, for: url)
            image = loadedImage
        } catch {
            guard !Task.isCancelled else { return }
            image = nil
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
                CachedArtworkImage(url: artworkURL)
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
                    NoirwaveTheme.accent.opacity(0.76),
                    track.palette.mid,
                    track.palette.base
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    .white.opacity(0.18),
                    .clear,
                    .black.opacity(0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.overlay)

            AngularGradient(
                colors: [
                    .white.opacity(0.24),
                    .clear,
                    NoirwaveTheme.accent.opacity(0.36),
                    .clear,
                    .white.opacity(0.18)
                ],
                center: .center
            )
            .blendMode(.screen)

            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: max(size * 0.012, 1), style: .continuous)
                    .fill(.white.opacity(index.isMultiple(of: 2) ? 0.075 : 0.035))
                    .frame(width: stripeWidth(index), height: max(size * 0.011, 1))
                    .rotationEffect(.degrees(-8))
                    .offset(x: stripeOffset(index), y: stripeVerticalOffset(index))
            }

            Circle()
                .stroke(.white.opacity(0.08), lineWidth: max(size * 0.012, 1))
                .frame(width: size * 0.82, height: size * 0.82)
                .offset(x: size * 0.18, y: -size * 0.18)
                .blendMode(.screen)

            Text(artworkInitials)
                .font(.system(size: min(size * 0.24, 48), weight: .black, design: .rounded))
                .foregroundStyle(track.palette.ink.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .shadow(color: .black.opacity(0.26), radius: 10, x: 0, y: 6)

            if size >= 90 {
                VStack(alignment: .leading, spacing: 2) {
                    Spacer()
                    Text(artworkTitle)
                        .font(.system(size: min(size * 0.09, 15), weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: min(size * 0.065, 11), weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(max(size * 0.08, 8))
            }
        }
    }

    private var artworkURL: URL? {
        guard let value = track.artworkURL?.nonEmpty else { return nil }
        return URL(string: value)
    }

    private var artworkTitle: String {
        if track.kind == .artist {
            return track.title
        }

        return track.album.nonEmpty ?? track.title
    }

    private var artworkInitials: String {
        let source = artworkTitle == "Unknown Album" ? track.title : artworkTitle
        let words = source
            .split { !$0.isLetter && !$0.isNumber }
            .prefix(2)
            .compactMap { $0.first }

        let initials = String(words).uppercased()
        return initials.nonEmpty ?? "NW"
    }

    private func stripeWidth(_ index: Int) -> CGFloat {
        size * (0.46 + (CGFloat((index * 17) % 27) / 100))
    }

    private func stripeOffset(_ index: Int) -> CGFloat {
        size * (-0.08 + CGFloat((index * 13) % 20) / 100)
    }

    private func stripeVerticalOffset(_ index: Int) -> CGFloat {
        size * (-0.28 + CGFloat(index) * 0.105)
    }
}
