//
//  DexterPermissionCheckLog.swift
//  leanring-buddy
//

import Foundation

enum DexterPermissionCheckLog {
    static func log(caller: String, permissionValuesChanged: Bool) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[PERMISSION-CHECK] caller=\(caller) timestamp=\(timestamp) changed=\(permissionValuesChanged)")
    }
}
