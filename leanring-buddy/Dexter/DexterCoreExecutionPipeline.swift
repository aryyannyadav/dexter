//
//  DexterCoreExecutionPipeline.swift
//  leanring-buddy
//
//  Shared execution phases for text and voice (single runtime — no voice-specific actions).
//

import Foundation

/// User input channel into the same Dexter core runtime.
enum DexterUserInputChannel: Equatable {
    case pushToTalkTranscript
    case typedText
}

typealias DexterVoiceUserMessageSource = DexterUserInputChannel

enum DexterCoreExecutionPipelinePhase: String, Equatable, CaseIterable {
    case pushToTalk = "PTT"
    case microphone = "MICROPHONE"
    case speechToText = "STT"
    case finalTranscript = "FINAL_TRANSCRIPT"
    case intent = "INTENT"
    case context = "CONTEXT"
    case plan = "PLAN"
    case permission = "PERMISSION"
    case toolGateway = "TOOL_GATEWAY"
    case observe = "OBSERVE"
    case verify = "VERIFY"
    case response = "RESPONSE"
    case textToSpeech = "TTS"
}

enum DexterCoreExecutionPipelineLog {
    static func log(phase: DexterCoreExecutionPipelinePhase, detail: String? = nil) {
        if let detail, !detail.isEmpty {
            print("[DEXTER][PIPELINE] \(phase.rawValue) \(detail)")
        } else {
            print("[DEXTER][PIPELINE] \(phase.rawValue)")
        }
    }
}
