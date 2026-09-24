//
//  DexterRegisteredToolLocalExecution.swift
//  leanring-buddy
//

import Foundation

enum DexterRegisteredToolLocalExecution {
    static func isLocallyExecuted(_ actionRequest: AgentActionRequest) -> Bool {
        guard let toolKind = DexterTool.toolKind(for: actionRequest) else {
            return false
        }
        switch toolKind {
        case .fileOperation, .terminalOperation:
            return true
        default:
            return false
        }
    }
}
