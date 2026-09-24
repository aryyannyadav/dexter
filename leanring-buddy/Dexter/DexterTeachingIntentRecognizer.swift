//
//  DexterTeachingIntentRecognizer.swift
//  leanring-buddy
//

import Foundation

enum DexterTeachingIntentRecognizer {
    static func recognizeResponseMode(forUserMessage userMessage: String) -> DexterResponseMode {
        let structuredIntent = DexterIntentRouter.recognize(userMessage: userMessage, context: nil)
        return DexterIntentResponseModeMapper.responseMode(for: structuredIntent)
    }
}
