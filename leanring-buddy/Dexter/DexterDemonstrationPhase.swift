//
//  DexterDemonstrationPhase.swift
//  leanring-buddy
//

import Combine
import Foundation

/// Hackathon-visible Dexter lifecycle (driven by real capture, model, and action pipeline events).
enum DexterDemonstrationPhase: String, Equatable, CaseIterable {
    case idle
    case seeing = "SEEING"
    case thinking = "THINKING"
    case planning = "PLANNING"
    case waitingForApproval = "WAITING FOR APPROVAL"
    case acting = "ACTING"
    case verifying = "VERIFYING"
    case done = "DONE"
}

@MainActor
final class DexterDemonstrationPhaseStore: ObservableObject {
    @Published private(set) var currentPhase: DexterDemonstrationPhase = .idle
    @Published private(set) var statusDetail: String = ""

    func transition(to phase: DexterDemonstrationPhase, detail: String = "") {
        currentPhase = phase
        statusDetail = detail
    }

    func reset() {
        currentPhase = .idle
        statusDetail = ""
    }
}
