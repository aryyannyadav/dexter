//
//  DexterHubMemoryActionHandler.swift
//
//  Routes Hub memory actions to existing Mac memory UI / store (no parallel backend).
//

import Foundation

enum DexterHubMemoryActionHandler {
    static func handleInboundPayload(_ object: [String: Any], memoryStore: MemoryStore?) {
        if object["type"] as? String == "memoryAction" {
            handleMemoryAction(object, memoryStore: memoryStore)
            return
        }
    }

    private static func handleMemoryAction(_ object: [String: Any], memoryStore: MemoryStore?) {
        guard let action = object["action"] as? String else { return }
        let memoryRecordIdentifier = object["memoryRecordId"] as? String

        switch action {
        case "view":
            guard let memoryRecordIdentifier else { return }
            NotificationCenter.default.post(
                name: .dexterHubViewMemoryRecordRequested,
                object: nil,
                userInfo: [DexterHubMemoryActionNotifications.memoryRecordIdentifierUserInfoKey: memoryRecordIdentifier]
            )
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            DexterHubEventBridgeLog.info("memoryAction=VIEW id=\(memoryRecordIdentifier)")
        case "forget":
            guard let memoryRecordIdentifier,
                  let recordUUID = UUID(uuidString: memoryRecordIdentifier)
            else { return }
            memoryStore?.removePersistentEntry(id: recordUUID)
            DexterHubEventBridgeLog.info("memoryAction=FORGET id=\(memoryRecordIdentifier)")
        default:
            break
        }
    }
}
