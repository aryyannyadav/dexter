//
//  DexterStringNonEmptyTrimming.swift
//  leanring-buddy
//

import Foundation

extension String {
    var nonEmptyTrimmedValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
