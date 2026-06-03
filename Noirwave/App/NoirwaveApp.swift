import SwiftUI

@main
struct NoirwaveApp: App {
    @StateObject private var store = PlayerStore(provider: MusicProviderFactory.makeDefaultProvider())

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            PlayerShellView()
                .environmentObject(store)
                .frame(minWidth: 1120, minHeight: 720)
                .preferredColorScheme(.dark)
                .task {
                    if !isRunningTests {
                        await store.bootstrap()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    store.togglePlayPause()
                }
                .keyboardShortcut(" ", modifiers: [])

                Button("Next Track") {
                    store.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("Previous Track") {
                    store.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
            }
        }
    }
}
