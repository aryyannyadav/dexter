//
//  DexterMicPermissionLog.swift
//  leanring-buddy
//

import AVFoundation
import Foundation

enum DexterMicPermissionLog {
    static func log(
        status: AVAuthorizationStatus,
        requestStarted: Bool? = nil,
        requestResult: Bool? = nil
    ) {
        var parts = ["status=\(describe(status))"]
        if let requestStarted {
            parts.append("requestStarted=\(requestStarted)")
        }
        if let requestResult {
            parts.append("requestResult=\(requestResult)")
        }
        print("[MIC-PERM] " + parts.joined(separator: " "))
    }

    private static func describe(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }
}
