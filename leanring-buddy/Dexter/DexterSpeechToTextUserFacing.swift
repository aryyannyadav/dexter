//
//  DexterSpeechToTextUserFacing.swift
//  leanring-buddy
//

import Foundation

struct DexterSpeechToTextProviderUnavailableError: LocalizedError {
    let providerDisplayName: String
    let developerDetail: String

    var errorDescription: String? {
        DexterSpeechToTextUserFacing.presentationForUnavailableProvider(
            providerDisplayName: providerDisplayName,
            developerDetail: developerDetail
        ).detail
    }
}

struct DexterVoiceInputErrorPresentation: Equatable {
    let headline: String
    let detail: String
    let opensVoiceSettingsOnAction: Bool

    static let openVoiceSettingsButtonTitle = "Open Voice Settings"
}

enum DexterSpeechToTextUserFacing {
    static func presentation(for error: Error) -> DexterVoiceInputErrorPresentation {
        if error is DexterSpeechToTextTimeoutError {
            return DexterVoiceInputErrorPresentation(
                headline: "Voice input timed out",
                detail: "Dexter did not receive a final transcript. Try holding push-to-talk a little longer.",
                opensVoiceSettingsOnAction: false
            )
        }

        if let appleSpeechError = error as? AppleSpeechTranscriptionProviderError {
            return presentationForAppleSpeech(message: appleSpeechError.message)
        }

        if let assemblyAIError = error as? AssemblyAIStreamingTranscriptionProviderError {
            return presentationForDeveloperFacingProviderMessage(assemblyAIError.message)
        }

        if let unavailableError = error as? DexterSpeechToTextProviderUnavailableError {
            return presentationForUnavailableProvider(
                providerDisplayName: unavailableError.providerDisplayName,
                developerDetail: unavailableError.developerDetail
            )
        }

        return DexterVoiceInputErrorPresentation(
            headline: "Voice input unavailable",
            detail: "Something went wrong while transcribing speech. Try again.",
            opensVoiceSettingsOnAction: false
        )
    }

    static func presentationForEmptyTranscript(providerDisplayName: String) -> DexterVoiceInputErrorPresentation {
        DexterVoiceInputErrorPresentation(
            headline: "No speech detected",
            detail: "Hold push-to-talk a bit longer and speak clearly, then try again.",
            opensVoiceSettingsOnAction: false
        )
    }

    static func presentationForUnavailableProvider(
        providerDisplayName: String,
        developerDetail: String?
    ) -> DexterVoiceInputErrorPresentation {
        DexterDiagnosticLog.stt("STT unavailable presentation: \(developerDetail ?? providerDisplayName)")

        if providerDisplayName == "Apple Speech" {
            return DexterVoiceInputErrorPresentation(
                headline: "Voice input unavailable",
                detail: "Apple Speech is not available on this Mac. Check Speech Recognition permission in System Settings.",
                opensVoiceSettingsOnAction: true
            )
        }

        return DexterVoiceInputErrorPresentation(
            headline: "Voice input unavailable",
            detail: "Speech recognition isn't configured yet. You can use Apple Speech on this Mac or set up cloud transcription in Voice settings.",
            opensVoiceSettingsOnAction: true
        )
    }

    static func presentationRemappingLegacyUserString(_ legacyMessage: String) -> DexterVoiceInputErrorPresentation {
        let lowered = legacyMessage.lowercased()
        if lowered.contains("dexterworkerbaseurl")
            || lowered.contains("info.plist")
            || lowered.contains("secrets.xcconfig") {
            return DexterVoiceInputErrorPresentation(
                headline: "Voice input unavailable",
                detail: "Speech recognition isn't configured yet. Dexter will use Apple Speech when cloud transcription isn't set up.",
                opensVoiceSettingsOnAction: true
            )
        }

        if lowered.contains("didn't catch") || lowered.contains("did not catch") {
            return presentationForEmptyTranscript(providerDisplayName: "")
        }

        return DexterVoiceInputErrorPresentation(
            headline: "Voice input unavailable",
            detail: legacyMessage,
            opensVoiceSettingsOnAction: false
        )
    }

    private static func presentationForAppleSpeech(message: String) -> DexterVoiceInputErrorPresentation {
        let lowered = message.lowercased()
        if lowered.contains("permission") || lowered.contains("not authorized") {
            return DexterVoiceInputErrorPresentation(
                headline: "Voice input unavailable",
                detail: "Allow Speech Recognition for Dexter in System Settings, then try again.",
                opensVoiceSettingsOnAction: true
            )
        }

        return DexterVoiceInputErrorPresentation(
            headline: "Voice input unavailable",
            detail: message,
            opensVoiceSettingsOnAction: true
        )
    }

    private static func presentationForDeveloperFacingProviderMessage(_ message: String) -> DexterVoiceInputErrorPresentation {
        DexterDiagnosticLog.stt("remapped developer STT message for UI: \(DexterObservabilityRedaction.redact(message))")
        return DexterVoiceInputErrorPresentation(
            headline: "Voice input unavailable",
            detail: "Cloud speech recognition could not start. Dexter can use Apple Speech when it is enabled on this Mac.",
            opensVoiceSettingsOnAction: true
        )
    }
}
