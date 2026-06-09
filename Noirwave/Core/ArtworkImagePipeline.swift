import AppKit
import CryptoKit
import Foundation
import ImageIO
import SwiftUI

enum ArtworkRequestPriority: Int, Comparable, Sendable {
    case low = 0
    case visible = 1
    case high = 2

    static func < (lhs: ArtworkRequestPriority, rhs: ArtworkRequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var taskPriority: TaskPriority {
        switch self {
        case .high:
            .userInitiated
        case .visible:
            .utility
        case .low:
            .background
        }
    }

    var label: String {
        switch self {
        case .high:
            "high"
        case .visible:
            "visible"
        case .low:
            "low"
        }
    }
}

@MainActor
final class ArtworkImagePipeline {
    static let shared = ArtworkImagePipeline()

    private struct ArtworkLoadTicket: Sendable {
        let id = UUID()
        let url: URL
        let task: Task<Data?, Never>
    }

    private struct ArtworkInFlightLoad {
        let task: Task<Data?, Never>
        var consumers: Set<UUID>
        let priority: ArtworkRequestPriority
    }

    private struct ArtworkPrefetchTask {
        let id: UUID
        let task: Task<Void, Never>
        let priority: ArtworkRequestPriority
    }

    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let urlSession: URLSession
    private let networkLimiter = ArtworkPipelineLimiter(maxConcurrentOperations: 6)
    private let decodeLimiter = ArtworkPipelineLimiter(maxConcurrentOperations: 4)
    private var inFlightLoads: [URL: ArtworkInFlightLoad] = [:]
    private var prefetchTasks: [URL: ArtworkPrefetchTask] = [:]
    private var failedURLs: [URL: Date] = [:]

    private let failedURLRetryInterval: TimeInterval = 45

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Noirwave", isDirectory: true)
            .appendingPathComponent("ArtworkCache", isDirectory: true)

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 18 * 1024 * 1024,
            diskCapacity: 260 * 1024 * 1024,
            diskPath: "NoirwaveArtworkURLCache"
        )
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.timeoutIntervalForRequest = 14
        configuration.timeoutIntervalForResource = 28

        urlSession = URLSession(configuration: configuration)
        memoryCache.countLimit = 420
        memoryCache.totalCostLimit = 96 * 1024 * 1024
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func cachedMemoryImage(for url: URL, targetPixelSize: CGFloat) -> NSImage? {
        let pixelSize = normalizedPixelSize(targetPixelSize)
        let key = memoryKey(for: url, pixelSize: pixelSize)
        guard let image = memoryCache.object(forKey: key) else {
            return nil
        }

        Self.debugLog("Artwork cache hit memory: \(stableCacheKey(for: url))")
        return image
    }

    func image(
        for url: URL,
        targetPixelSize: CGFloat = 320,
        priority: ArtworkRequestPriority = .visible
    ) async -> NSImage? {
        let pixelSize = normalizedPixelSize(targetPixelSize)
        let memoryKey = memoryKey(for: url, pixelSize: pixelSize)
        let cacheKey = stableCacheKey(for: url)

        if isRecentlyFailed(url) {
            Self.debugLog("Artwork retry cooldown: \(cacheKey)")
            return nil
        }

        if let image = memoryCache.object(forKey: memoryKey) {
            Self.debugLog("Artwork cache hit memory: \(cacheKey)")
            return image
        }

        if let data = await diskData(for: url),
           let image = await decodeImage(from: data, targetPixelSize: pixelSize, priority: priority) {
            Self.debugLog("Artwork cache hit disk: \(cacheKey)")
            cache(image, forKey: memoryKey, cost: data.count)
            return image
        }

        if let data = cachedURLCacheData(for: url),
           let image = await decodeImage(from: data, targetPixelSize: pixelSize, priority: priority) {
            Self.debugLog("Artwork cache hit URLCache: \(cacheKey)")
            cache(image, forKey: memoryKey, cost: data.count)
            return image
        }

        Self.debugLog("Artwork cache miss \(priority.label): \(cacheKey)")
        let ticket = retainLoad(for: url, priority: priority)
        let data = await withTaskCancellationHandler {
            await ticket.task.value
        } onCancel: {
            Task { @MainActor in
                ArtworkImagePipeline.shared.releaseLoad(ticket, cancelled: true)
            }
        }
        releaseLoad(ticket, cancelled: false)

        guard !Task.isCancelled,
              let data,
              let image = await decodeImage(from: data, targetPixelSize: pixelSize, priority: priority)
        else {
            failedURLs[url] = Date()
            Self.debugLog("Artwork failed: \(cacheKey)")
            return nil
        }

        failedURLs.removeValue(forKey: url)
        cache(image, forKey: memoryKey, cost: data.count)
        return image
    }

    func prefetch(
        _ tracks: [Track],
        limit: Int? = nil,
        targetPixelSize: CGFloat = 360,
        priority: ArtworkRequestPriority = .low
    ) {
        let uniqueURLs = uniqueArtworkURLs(from: tracks)
        let requestedLimit = limit.map { max($0, 0) } ?? uniqueURLs.count
        let urls = Array(uniqueURLs.prefix(requestedLimit))
        cancelPrefetches(excluding: Set(urls), priority: priority)

        for url in urls {
            let pixelSize = normalizedPixelSize(targetPixelSize)
            if memoryCache.object(forKey: memoryKey(for: url, pixelSize: pixelSize)) != nil
                || inFlightLoads[url] != nil
                || shouldKeepExistingPrefetch(for: url, priority: priority) {
                continue
            }

            let prefetchID = UUID()
            let task = Task(priority: priority.taskPriority) { @MainActor in
                guard !Task.isCancelled else { return }
                _ = await image(for: url, targetPixelSize: targetPixelSize, priority: priority)
                if prefetchTasks[url]?.id == prefetchID {
                    prefetchTasks[url] = nil
                }
            }
            prefetchTasks[url] = ArtworkPrefetchTask(id: prefetchID, task: task, priority: priority)
        }
    }

    func clearCache() {
        cancelAllPrefetches()
        inFlightLoads.values.forEach { $0.task.cancel() }
        inFlightLoads.removeAll()
        failedURLs.removeAll()
        memoryCache.removeAllObjects()
        urlSession.configuration.urlCache?.removeAllCachedResponses()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func rebuildCache(for tracks: [Track], limit: Int? = nil, targetPixelSize: CGFloat = 360) {
        clearCache()
        prefetch(tracks, limit: limit, targetPixelSize: targetPixelSize, priority: .visible)
    }

    static func artworkURL(for track: Track) -> URL? {
        guard let value = track.artworkURL?.nonEmpty,
              let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased())
        else {
            return nil
        }

        return url
    }

    private func uniqueArtworkURLs(from tracks: [Track]) -> [URL] {
        var seen = Set<String>()
        return tracks.compactMap(Self.artworkURL).filter { url in
            seen.insert(stableCacheKey(for: url)).inserted
        }
    }

    private func retainLoad(for url: URL, priority: ArtworkRequestPriority) -> ArtworkLoadTicket {
        if var load = inFlightLoads[url] {
            let ticket = ArtworkLoadTicket(url: url, task: load.task)
            load.consumers.insert(ticket.id)
            inFlightLoads[url] = load
            if priority > load.priority {
                Self.debugLog("Artwork joined lower-priority in-flight load: \(stableCacheKey(for: url))")
            }
            return ticket
        }

        let task = startLoad(for: url, priority: priority)
        let ticket = ArtworkLoadTicket(url: url, task: task)
        inFlightLoads[url] = ArtworkInFlightLoad(task: task, consumers: [ticket.id], priority: priority)
        return ticket
    }

    private func releaseLoad(_ ticket: ArtworkLoadTicket, cancelled: Bool) {
        guard var load = inFlightLoads[ticket.url] else { return }
        load.consumers.remove(ticket.id)
        guard load.consumers.isEmpty else {
            inFlightLoads[ticket.url] = load
            return
        }

        if cancelled {
            load.task.cancel()
            Self.debugLog("Artwork cancelled offscreen request: \(stableCacheKey(for: ticket.url))")
        }
        inFlightLoads[ticket.url] = nil
    }

    private func startLoad(for url: URL, priority: ArtworkRequestPriority) -> Task<Data?, Never> {
        let destination = diskURL(for: url)
        let cacheDirectory = cacheDirectory
        let urlSession = urlSession
        let networkLimiter = networkLimiter
        let cacheKey = stableCacheKey(for: url)

        return Task.detached(priority: priority.taskPriority) { () async -> Data? in
            await networkLimiter.acquire(priority: priority)
            if Task.isCancelled {
                await networkLimiter.release()
                return nil
            }

            let loadedData: Data?
            do {
                Self.debugLog("Artwork network load \(priority.label): \(cacheKey)")
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 14

                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      !data.isEmpty
                else {
                    Self.debugLog("Artwork failed: \(cacheKey)")
                    await networkLimiter.release()
                    return nil
                }

                Self.debugLog("Artwork network response: \(cacheKey) \(Self.httpCacheSummary(httpResponse))")
                try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                try? data.write(to: destination, options: .atomic)
                loadedData = data
            } catch {
                Self.debugLog("Artwork failed: \(cacheKey)")
                loadedData = nil
            }

            await networkLimiter.release()
            return loadedData
        }
    }

    private func cachedURLCacheData(for url: URL) -> Data? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        return urlSession.configuration.urlCache?.cachedResponse(for: request)?.data
    }

    private func diskData(for url: URL) async -> Data? {
        let fileURL = diskURL(for: url)
        return await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]), !data.isEmpty else {
                return nil
            }

            return data
        }.value
    }

    private func decodeImage(
        from data: Data,
        targetPixelSize: Int,
        priority: ArtworkRequestPriority
    ) async -> NSImage? {
        await decodeLimiter.acquire(priority: priority)
        let image = await Task.detached(priority: priority.taskPriority) {
            Self.downsampledImage(from: data, maxPixelSize: targetPixelSize)
        }.value
        await decodeLimiter.release()
        return image
    }

    private func isRecentlyFailed(_ url: URL) -> Bool {
        guard let failedAt = failedURLs[url] else {
            return false
        }

        if Date().timeIntervalSince(failedAt) < failedURLRetryInterval {
            return true
        }

        failedURLs.removeValue(forKey: url)
        return false
    }

    private func cache(_ image: NSImage, forKey key: NSString, cost: Int? = nil) {
        let imageCost = cost ?? Int(max(image.size.width * image.size.height * 4, 1))
        memoryCache.setObject(image, forKey: key, cost: imageCost)
    }

    private func normalizedPixelSize(_ targetPixelSize: CGFloat) -> Int {
        let requested = max(Int(targetPixelSize.rounded(.up)), 80)
        let buckets = [96, 160, 240, 320, 480, 640]
        return buckets.first { $0 >= requested } ?? min(requested, 720)
    }

    private func memoryKey(for url: URL, pixelSize: Int) -> NSString {
        "\(stableCacheKey(for: url))#\(pixelSize)" as NSString
    }

    private func diskURL(for url: URL) -> URL {
        let key = SHA256.hash(data: Data(stableCacheKey(for: url).utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return cacheDirectory.appendingPathComponent(key).appendingPathExtension("img")
    }

    private func stableCacheKey(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        if let queryItems = components.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems.sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return (lhs.value ?? "") < (rhs.value ?? "")
                }
                return lhs.name < rhs.name
            }
        }
        return components.string ?? url.absoluteString
    }

    private func shouldKeepExistingPrefetch(for url: URL, priority: ArtworkRequestPriority) -> Bool {
        guard let existing = prefetchTasks[url] else { return false }
        if priority > existing.priority {
            existing.task.cancel()
            prefetchTasks[url] = nil
            Self.debugLog("Artwork upgraded prefetch priority: \(stableCacheKey(for: url))")
            return false
        }
        return true
    }

    private func cancelPrefetches(excluding activeURLs: Set<URL>, priority: ArtworkRequestPriority) {
        let urlsToCancel = prefetchTasks.compactMap { url, entry in
            entry.priority == priority && !activeURLs.contains(url) ? url : nil
        }
        for url in urlsToCancel {
            prefetchTasks.removeValue(forKey: url)?.task.cancel()
            Self.debugLog("Artwork cancelled offscreen prefetch: \(stableCacheKey(for: url))")
        }
    }

    private func cancelAllPrefetches() {
        for entry in prefetchTasks.values {
            entry.task.cancel()
        }
        prefetchTasks.removeAll()
    }

    private nonisolated static func httpCacheSummary(_ response: HTTPURLResponse) -> String {
        let etag = response.value(forHTTPHeaderField: "ETag")?.nonEmpty.map { "etag=\($0)" }
        let lastModified = response.value(forHTTPHeaderField: "Last-Modified")?.nonEmpty.map { "lastModified=\($0)" }
        let cacheControl = response.value(forHTTPHeaderField: "Cache-Control")?.nonEmpty.map { "cacheControl=\($0)" }
        return [etag, lastModified, cacheControl].compactMap(\.self).joined(separator: " ")
    }

    private nonisolated static func downsampledImage(from data: Data, maxPixelSize: Int) -> NSImage? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return NSImage(data: data)
        }

        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1)
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return NSImage(data: data)
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    private nonisolated static func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[Noirwave] \(message())")
        #endif
    }
}

private actor ArtworkPipelineLimiter {
    private let maxConcurrentOperations: Int
    private var activeOperations = 0
    private var waiters: [(priority: ArtworkRequestPriority, continuation: CheckedContinuation<Void, Never>)] = []

    init(maxConcurrentOperations: Int) {
        self.maxConcurrentOperations = max(maxConcurrentOperations, 1)
    }

    func acquire(priority: ArtworkRequestPriority) async {
        if activeOperations < maxConcurrentOperations {
            activeOperations += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append((priority, continuation))
        }
    }

    func release() {
        if let index = waiters.indices.max(by: { waiters[$0].priority < waiters[$1].priority }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume()
        } else {
            activeOperations = max(activeOperations - 1, 0)
        }
    }
}
