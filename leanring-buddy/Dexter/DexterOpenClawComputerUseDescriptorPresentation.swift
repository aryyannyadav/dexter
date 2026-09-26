//
//  DexterOpenClawComputerUseDescriptorPresentation.swift
//  leanring-buddy
//

import Foundation

struct DexterOpenClawComputerUseFeatureRow: Identifiable, Equatable {
    let id: String
    let title: String
    let isAvailable: Bool
    let detail: String?
}

enum DexterOpenClawComputerUseDescriptorPresentation {
    static func featureRows(
        computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot,
        discoveryReport: DexterOpenClawCapabilityDiscoveryReport
    ) -> [DexterOpenClawComputerUseFeatureRow] {
        guard discoveryReport.isCapabilityAvailable(.computerAct) else {
            return []
        }

        let advertisedActions = Set(computerUseDescriptor.advertisedActions)

        return [
            featureRow(
                id: "screen",
                title: "Screen understanding",
                isAvailable: discoveryReport.isCapabilityAvailable(.screenSnapshot),
                unavailableDetail: "screen.snapshot is not available on the connected node."
            ),
            featureRow(
                id: "pointer",
                title: "Mouse & keyboard",
                isAvailable: advertisedActions.contains("left_click")
                    && advertisedActions.contains("type")
                    && advertisedActions.contains("key"),
                unavailableDetail: "Pointer or keyboard actions are not advertised by the provider."
            ),
            featureRow(
                id: "app_lifecycle",
                title: "App control",
                isAvailable: advertisedActions.contains("launch_app")
                    && advertisedActions.contains("kill_app"),
                unavailableDetail: "launch_app or kill_app is not advertised by the provider."
            ),
            featureRow(
                id: "window_control",
                title: "Window control",
                isAvailable: advertisedActions.contains("bring_to_front")
                    || advertisedActions.contains("list_windows"),
                unavailableDetail: "Window actions are not advertised by the provider."
            ),
            featureRow(
                id: "accessibility_tree",
                title: "Accessibility tree",
                isAvailable: advertisedActions.contains("get_accessibility_tree"),
                unavailableDetail: "get_accessibility_tree is not advertised by the provider."
            ),
            featureRow(
                id: "browser",
                title: "Browser control",
                isAvailable: discoveryReport.isCapabilityAvailable(.browserProxy),
                unavailableDetail: "Browser proxy is not available on the connected node."
            ),
            featureRow(
                id: "terminal",
                title: "System / terminal",
                isAvailable: discoveryReport.isCapabilityAvailable(.systemRun),
                unavailableDetail: "system.run is not available on the connected node."
            ),
            featureRow(
                id: "files",
                title: "Workspace files",
                isAvailable: discoveryReport.isCapabilityAvailable(.file),
                unavailableDetail: "File commands are not available on the connected node."
            )
        ]
    }

    private static func featureRow(
        id: String,
        title: String,
        isAvailable: Bool,
        unavailableDetail: String
    ) -> DexterOpenClawComputerUseFeatureRow {
        DexterOpenClawComputerUseFeatureRow(
            id: id,
            title: title,
            isAvailable: isAvailable,
            detail: isAvailable ? nil : unavailableDetail
        )
    }
}
