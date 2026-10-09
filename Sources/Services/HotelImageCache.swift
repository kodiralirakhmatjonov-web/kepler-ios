import CryptoKit
import Foundation
import ImageIO
import SwiftUI
import UIKit

/// Hotel photography is cached by URL, independently of flight/hotel pricing.
/// Always decode thumbnails rather than full-resolution original photos: a single
/// hotel image may expand from a few MB on disk to tens of MB in process memory.
actor HotelImageCache {
    static let shared = HotelImageCache()

    private let memory: NSCache<NSURL, UIImage>
    private let fileManager: FileManager
    private let directory: URL
    private let maximumCompressedBytes = 16 * 1024 * 1024
    private let maximumPixelDimension = 1600

    private init() {
        // Build the cache and filesystem dependencies as locals first. Calling
        // actor-isolated properties from an actor's nonisolated initializer is
        // rejected in Swift 6 language mode.
        let fileManager = FileManager.default
        let memory = NSCache<NSURL, UIImage>()
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = caches.appendingPathComponent("iumrah-hotel-images-v1", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 24
        memory.totalCostLimit = 48 * 1024 * 1024
        self.fileManager = fileManager
        self.memory = memory
        self.directory = directory
    }

    func image(for url: URL) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let key = url as NSURL
        if let cached = memory.object(forKey: key) { return cached }

        let diskURL = fileURL(for: url)
        if let attributes = try? fileManager.attributesOfItem(atPath: diskURL.path),
           let size = attributes[.size] as? NSNumber,
           size.intValue > maximumCompressedBytes {
            try? fileManager.removeItem(at: diskURL)
        } else if let data = try? Data(contentsOf: diskURL),
                  let decoded = downsample(data) {
            store(decoded, for: key)
            return decoded
        }

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  data.count <= maximumCompressedBytes,
                  let decoded = downsample(data) else { return nil }

            // Preserve compressed data on disk, but never hold the full-sized
            // decoded bitmap in NSCache or SwiftUI views.
            try? data.write(to: diskURL, options: .atomic)
            store(decoded, for: key)
            return decoded
        } catch {
            return nil
        }
    }

    /// Only a few visible covers should be prefetched. Detail-gallery images
    /// remain on-demand; prefetching an entire global catalogue caused OOM risk.
    func prefetch(urls: [URL]) async {
        var seen = Set<URL>()
        let prioritized = urls.filter { seen.insert($0).inserted }.prefix(12)
        for url in prioritized {
            guard !Task.isCancelled else { return }
            _ = await image(for: url)
        }
    }

    private func downsample(_ data: Data) -> UIImage? {
        guard data.count <= maximumCompressedBytes,
              let source = CGImageSourceCreateWithData(data as CFData,
                   [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    private func store(_ image: UIImage, for key: NSURL) {
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        memory.setObject(image, forKey: key, cost: cost)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name).appendingPathExtension("img")
    }
}

struct HotelCachedImage: View {
    enum ContentMode { case fill, fit }

    let rawURL: String?
    var contentMode: ContentMode = .fill
    var placeholderSystemName: String = "building.2.fill"

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode == .fill ? .fill : .fit)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Color.iumrahRaisedBackground
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .overlay {
                            Image(systemName: placeholderSystemName)
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipped()
        .task(id: rawURL) {
            guard let url = AppConfig.absoluteURL(rawURL) else {
                image = nil
                return
            }
            image = nil
            let loaded = await HotelImageCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            image = loaded
        }
        .onDisappear { image = nil }
    }
}
