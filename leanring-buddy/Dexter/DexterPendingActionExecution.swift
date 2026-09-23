//
//  DexterPendingActionExecution.swift
//  leanring-buddy
//

import Foundation

struct DexterPendingActionExecution: Equatable {
    let action: DexterAction
    let context: DexterContext
    let hasPersistedScreenContentGrant: Bool
    let confirmationContent: DexterActionConfirmationContent
}
