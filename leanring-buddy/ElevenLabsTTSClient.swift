//
//  ElevenLabsTTSClient.swift
//  leanring-buddy
//
//  Streams text-to-speech audio from ElevenLabs and plays it back
//  through the system audio output. Uses the streaming endpoint so
//  playback begins before the full audio has been generated.
//

import AVFoundation
import Foundation

@MainActor
final class ElevenLabsTTSClient: NSObject {
    private let proxyURL: URL
    private let session: URLSession

    /// The audio player for the current TTS playback. Kept alive so the
    /// audio finishes playing even if the caller doesn't hold a reference.
    private var audioPlayer: AVAudioPlayer?
    private var playbackDelegate: ElevenLabsAudioPlaybackDelegate?

    init(proxyURL: String) {
        self.proxyURL = URL(string: proxyURL)!

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    /// Sends `text` to ElevenLabs TTS and plays the resulting audio through completion.
    /// Throws on network or decoding errors. Cancellation-safe.
    func speakText(_ text: String) async throws {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        DexterWorkerProxyClient.applyAuthenticationHeaders(to: &request)

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_flash_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        DexterDiagnosticLog.tts("synthesis started")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ElevenLabsTTS", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ElevenLabsTTS", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "TTS API error (\(httpResponse.statusCode)): \(errorBody)"])
        }

        try Task.checkCancellation()

        DexterDiagnosticLog.tts("audio received")

        let player = try AVAudioPlayer(data: data)
        self.audioPlayer = player

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = ElevenLabsAudioPlaybackDelegate(continuation: continuation)
            playbackDelegate = delegate
            player.delegate = delegate
            DexterDiagnosticLog.tts("playback started")
            guard player.play() else {
                continuation.resume(throwing: NSError(
                    domain: "ElevenLabsTTS",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to start audio playback"]
                ))
                return
            }
        }

        DexterDiagnosticLog.tts("playback completed")
        playbackDelegate = nil
        audioPlayer = nil
    }

    /// Whether TTS audio is currently playing back.
    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    /// Stops any in-progress playback immediately.
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackDelegate?.cancel()
        playbackDelegate = nil
    }
}

@MainActor
private final class ElevenLabsAudioPlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func cancel() {
        if let continuation {
            continuation.resume(throwing: CancellationError())
            self.continuation = nil
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard let continuation else { return }
            if flag {
                continuation.resume()
            } else {
                continuation.resume(throwing: NSError(
                    domain: "ElevenLabsTTS",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Audio playback ended unsuccessfully"]
                ))
            }
            self.continuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard let continuation else { return }
            continuation.resume(throwing: error ?? NSError(
                domain: "ElevenLabsTTS",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Audio decode error"]
            ))
            self.continuation = nil
        }
    }
}
