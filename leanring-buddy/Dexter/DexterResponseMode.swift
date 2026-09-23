//
//  DexterResponseMode.swift
//  leanring-buddy
//

import Foundation

/// How Dexter should shape a response for this turn (single orchestrator, not a separate chatbot).
enum DexterResponseMode: String, Equatable {
    case answer = "ANSWER"
    case explain = "EXPLAIN"
    case teach = "TEACH"
    case troubleshoot = "TROUBLESHOOT"
    case guide = "GUIDE"
    case act = "ACT"
}
