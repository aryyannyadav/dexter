//
//  DexterRoutineDueRoutineCoordinator.swift
//  leanring-buddy
//

import AppKit
import Foundation

/// Evaluates persisted routine due dates when the app becomes active — not a separate automation engine.
@MainActor
enum DexterRoutineDueRoutineCoordinator {
    private static var lastApplicationOpenTriggerFireByRoutineID: [UUID: Date] = [:]

    static func install(companionManager: CompanionManager) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                evaluateDueRoutines(companionManager: companionManager)
                evaluateApplicationOpenedRoutines(companionManager: companionManager)
            }
        }
    }

    static func evaluateDueRoutines(companionManager: CompanionManager) {
        let dueRoutines = companionManager.dexterRoutineStore.routines.filter { routine in
            routine.trigger.kind == .schedule
                && routine.isRunnable
                && DexterRoutineDueDateEvaluator.isRoutineDue(routine)
        }
        for routine in dueRoutines {
            companionManager.runDexterRoutine(routineID: routine.id, runKind: .scheduled)
        }
    }

    static func evaluateApplicationOpenedRoutines(companionManager: CompanionManager) {
        guard let frontBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        let candidates = companionManager.dexterRoutineStore.routines.filter { routine in
            routine.trigger.kind == .applicationOpened
                && routine.isRunnable
                && routine.trigger.applicationBundleIdentifier == frontBundleId
        }
        let calendar = Calendar.current
        for routine in candidates {
            if let lastFire = lastApplicationOpenTriggerFireByRoutineID[routine.id],
               calendar.isDateInToday(lastFire) {
                continue
            }
            lastApplicationOpenTriggerFireByRoutineID[routine.id] = Date()
            companionManager.runDexterRoutine(routineID: routine.id, runKind: .applicationContext)
        }
    }
}
