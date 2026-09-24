//
//  DexterIntentComplexityClassifier.swift
//  leanring-buddy
//

import Foundation

enum DexterIntentComplexityClassifier {
    static func classify(intent: DexterStructuredIntent) -> DexterIntentComplexity {
        switch intent.kind {
        case .fix, .automate, .plan, .run:
            return .complex
        case .edit, .create:
            return intent.confidence >= 0.85 ? .complex : .simple
        case .open, .close, .focus, .remember, .forget, .remind, .companion, .ask,
             .explain, .teach, .search, .summarize, .compare, .find:
            return .simple
        }
    }
}
