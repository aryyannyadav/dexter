//
//  OpenClawComputerUseContract.swift
//  leanring-buddy
//

import Foundation

/// OpenClaw 2026.9.x computer-use wire values (`computer.act` / `screen.snapshot`).
enum OpenClawComputerUseContract {
    /// Matches OpenClaw `COMPUTER_EXECUTION_ID_PATTERN` (lowercase UUID v4).
    static func newExecutionIdentifier() -> String {
        UUID().uuidString.lowercased()
    }

    static func isValidExecutionIdentifier(_ executionIdentifier: String) -> Bool {
        let pattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#
        return executionIdentifier.range(of: pattern, options: .regularExpression) != nil
    }
}

enum OpenClawComputerActJSONValue: Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var anyJSONValue: Any {
        switch self {
        case .string(let stringValue):
            return stringValue
        case .int(let intValue):
            return intValue
        case .double(let doubleValue):
            return doubleValue
        case .bool(let boolValue):
            return boolValue
        }
    }
}
