//
//  DexterUserFacingErrorMessage.swift
//  leanring-buddy
//

import Foundation

enum DexterUserFacingErrorMessage {
    static func forCompanionModelError(_ error: Error) -> String {
        if error is CancellationError {
            return ""
        }

        if let urlError = error as? URLError {
            return forNetworkError(urlError)
        }

        let localizedDescription = error.localizedDescription.lowercased()
        if localizedDescription.contains("credit")
            || localizedDescription.contains("billing")
            || localizedDescription.contains("402") {
            return "I'm out of API credits or billing isn't configured. Check your Cloudflare Worker and API keys, then try again."
        }

        let nsError = error as NSError
        if nsError.domain == "ClaudeAPI" {
            if (500...599).contains(nsError.code) {
                return "Dexter couldn't reach the AI service right now. Check your network and worker URL, then try again."
            }
            if nsError.code == 401 || nsError.code == 403 {
                return "Dexter couldn't authenticate with the AI service. Check your worker configuration and try again."
            }
            return "Dexter couldn't get a response from the AI service. \(trimmedAPIErrorBody(from: nsError.localizedDescription))"
        }

        return "Dexter couldn't finish that request. \(error.localizedDescription)"
    }

    static func forTextToSpeechError(_ error: Error) -> String {
        if error is CancellationError {
            return ""
        }
        if let urlError = error as? URLError {
            return "Spoken responses are unavailable right now (\(forNetworkError(urlError))). You can still read Dexter's reply in the panel."
        }
        return "Spoken responses failed. You can still read Dexter's reply in the panel."
    }

    static func forActionRuntimeError(_ error: Error, runtimeName: String) -> String {
        if error is CancellationError {
            return "Dexter stopped that action."
        }
        if let runtimeError = error as? AgentRuntimeError {
            switch runtimeError {
            case .notConfigured:
                return "Dexter's action runtime isn't configured."
            case .unavailable:
                return "Dexter couldn't run that action because the agent runtime is unavailable. For Safari, Dexter uses the Mac runtime first; install OpenClaw only if you need the legacy fallback."
            case .unsupportedAction(let message):
                return message
            case .executionFailed(let message):
                return message
            }
        }
        if let timeout = error as? DexterAgentRuntimeExecutionGuard.TimeoutError {
            return "Dexter stopped waiting after \(Int(timeout.timeoutSeconds)) seconds. The action may still be running — check the app, then try again."
        }
        return "Dexter couldn't complete that action via \(runtimeName): \(error.localizedDescription)"
    }

    static func forMicrophoneUnavailable() -> String {
        "Microphone permission is required for push-to-talk. Enable it in System Settings, then try again."
    }

    static func forScreenRecordingUnavailable() -> String {
        "Screen Recording permission is off, so Dexter can't capture your screen. Enable it in System Settings for visual answers."
    }

    static func forAccessibilityUnavailable(actionDescription: String) -> String {
        "Accessibility permission is required before Dexter can \(actionDescription). Enable it in System Settings."
    }

    private static func forNetworkError(_ urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "You're offline or the network dropped. Check your connection and try again."
        case .timedOut:
            return "The network request timed out. Try again in a moment."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Dexter couldn't reach the server. Check your worker URL and network."
        default:
            return urlError.localizedDescription
        }
    }

    private static func trimmedAPIErrorBody(from description: String) -> String {
        let maxLength = 160
        if description.count <= maxLength {
            return description
        }
        return String(description.prefix(maxLength)) + "…"
    }
}
