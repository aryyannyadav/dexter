//
//  DexterVoiceInteractionState.swift
//  leanring-buddy
//

import Foundation

/// User-visible Dexter Voice lifecycle (push-to-talk, model, TTS).
enum DexterVoiceInteractionState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
}
