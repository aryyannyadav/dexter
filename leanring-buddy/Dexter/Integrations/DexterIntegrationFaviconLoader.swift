//
//  DexterIntegrationFaviconLoader.swift
//  leanring-buddy
//

import AppKit
import Foundation

/// Loads and caches small website favicons for integration list rows (settings only).
actor DexterIntegrationFaviconLoader {
    static let shared = DexterIntegrationFaviconLoader()

    private var memoryCache: [String: NSImage] = [:]

    func faviconImage(forWebsiteHost websiteHost: String) async -> NSImage? {
        let normalizedHost = websiteHost.lowercased()
        if let cached = memoryCache[normalizedHost] {
            return cached
        }

        if let duckDuckGoImage = await fetchImage(
            urlString: "https://icons.duckduckgo.com/ip3/\(normalizedHost).ico"
        ) {
            memoryCache[normalizedHost] = duckDuckGoImage
            return duckDuckGoImage
        }

        if let googleImage = await fetchImage(
            urlString: "https://www.google.com/s2/favicons?domain=\(normalizedHost)&sz=64"
        ) {
            memoryCache[normalizedHost] = googleImage
            return googleImage
        }

        return nil
    }

    private func fetchImage(urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            guard let image = NSImage(data: data), image.size.width > 1, image.size.height > 1 else {
                return nil
            }
            return image
        } catch {
            return nil
        }
    }
}
