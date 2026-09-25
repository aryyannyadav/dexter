//
//  DexterVoiceInteractionState.swift
//  leanring-buddy
//

import Foundation

/// User-visible Dexter Voice lifecycle (push-to-talk, model, TTS).
enum DexterVoiceInteractionState: Equatable {
    case idle
    case listening
    /// Push-to-talk released; waiting for the STT provider to return a final transcript.
    case transcribing
    case thinking
    case speaking
    case error
}
