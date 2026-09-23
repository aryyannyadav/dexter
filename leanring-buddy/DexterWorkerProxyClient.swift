//
//  DexterWorkerProxyClient.swift
//  leanring-buddy
//
//  Centralizes Cloudflare Worker base URL and optional client authentication.
//  Anthropic/ElevenLabs/AssemblyAI API keys must stay on the worker — never in the app binary.
//

import Foundation

enum DexterWorkerProxyClient {
    private static let defaultWorkerBaseURL = "https://your-worker-name.your-subdomain.workers.dev"

    static var workerBaseURL: String {
        let configuredBaseURL = AppBundleConfiguration.stringValue(forKey: "DexterWorkerBaseURL")
        let trimmed = configuredBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return defaultWorkerBaseURL
    }

    static func url(path: String) -> URL {
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: workerBaseURL + normalizedPath)!
    }

    /// Optional shared proxy key (not an upstream API secret). Set `DEXTER_PROXY_CLIENT_KEY` on the worker and the matching value in Info.plist at build time.
    static func applyAuthenticationHeaders(to request: inout URLRequest) {
        guard let clientKey = AppBundleConfiguration.stringValue(forKey: "DexterProxyClientKey")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !clientKey.isEmpty else {
            return
        }
        request.setValue(clientKey, forHTTPHeaderField: "X-Dexter-Proxy-Key")
    }
}
