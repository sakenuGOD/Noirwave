import Foundation

enum MusicProviderFactory {
    @MainActor
    static func makeDefaultProvider() -> MusicProviding {
        DeemixAPIProvider()
    }
}
