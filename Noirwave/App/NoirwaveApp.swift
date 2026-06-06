import SwiftUI
import AppKit

@main
struct NoirwaveApp: App {
    @NSApplicationDelegateAdaptor(NoirwaveAppDelegate.self) private var appDelegate
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
                .background(WindowTransparencyConfigurator())
                .task {
                    if !isRunningTests {
                        await EmbeddedBackendProcess.shared.startIfNeeded()
                        await store.bootstrap()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .textEditing) {
                Button("Find in Catalog") {
                    NotificationCenter.default.post(name: .noirwaveFocusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
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

                Divider()

                Button(store.isShuffled ? "Shuffle: On" : "Shuffle: Off") {
                    store.toggleShuffle()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Repeat: \(store.repeatMode.rawValue)") {
                    store.cycleRepeatMode()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button(store.volume == 0 ? "Unmute" : "Mute") {
                    store.toggleMute()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Volume Up") {
                    store.setVolume(store.volume + 0.06)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])

                Button("Volume Down") {
                    store.setVolume(store.volume - 0.06)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command])
            }
        }
    }
}

final class NoirwaveAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        EmbeddedBackendProcess.shared.stop()
    }
}

private struct WindowTransparencyConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(from: view)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(from: view)
        }
    }

    private func configureWindow(from view: NSView) {
        guard let window = view.window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
}
