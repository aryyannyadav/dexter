//
//  DexterDemonstrationPhase.swift
//  leanring-buddy
//
//  Legacy orchestrator phase names map to `DexterRuntimeUIState` (see DexterRuntimeUIState.swift).
//

import Foundation

enum DexterDemonstrationPhase {
    static let idle = DexterRuntimeUIState.idle
    static let seeing = DexterRuntimeUIState.understanding
    static let thinking = DexterRuntimeUIState.thinking
    static let planning = DexterRuntimeUIState.planning
    static let waitingForApproval = DexterRuntimeUIState.waitingPermission
    static let acting = DexterRuntimeUIState.acting
    static let verifying = DexterRuntimeUIState.verifying
    static let done = DexterRuntimeUIState.done
}
