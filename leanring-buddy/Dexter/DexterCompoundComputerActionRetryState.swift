//
//  DexterCompoundComputerActionRetryState.swift
//  leanring-buddy
//

import Foundation

struct DexterCompoundComputerActionRetryState: Equatable {
    let plannedActions: [DexterAction]
    let resumeFromStepIndex: Int
}
