import Foundation

enum MusicProviderFactory {
    @MainActor
    static func makeDefaultProvider() -> MusicProviding {
        let environment = ProcessInfo.processInfo.environment
        if environment["NOIRWAVE_USE_DEEZER_BACKEND"] == "1"
            || environment["NOIRWAVE_DEEZER_ARL"]?.isEmpty == false {
            return DeemixAPIProvider()
        }

        return MockMusicProvider()
    }
}
