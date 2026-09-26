//
//  DexterHubWireEvent.swift
//  leanring-buddy
//
//  JSON payloads sent to Dexter Hub (presentation only — no secrets).
//

import Foundation

enum DexterHubWireEventBuilder {
    static func connectionState(_ connectionState: String) -> Data {
        jsonDictionary([
            "type": "connection",
            "connectionState": connectionState,
        ])
    }

    static func state(
        hubState: String,
        title: String,
        subtitle: String?,
        application: String? = nil,
        interaction: String? = nil,
        journeySteps: [[String: String]]? = nil,
        retrySupported: Bool? = nil,
        verificationOutcome: String? = nil,
        voiceVisualOnly: Bool? = nil
    ) -> Data {
        var payload: [String: Any] = [
            "type": "state",
            "state": hubState,
            "title": title,
        ]
        if let subtitle, !subtitle.isEmpty {
            payload["subtitle"] = subtitle
        }
        if let application, !application.isEmpty {
            payload["application"] = application
        }
        if let interaction, !interaction.isEmpty {
            payload["interaction"] = interaction
        }
        if let journeySteps, !journeySteps.isEmpty {
            payload["journeySteps"] = journeySteps
        }
        if let retrySupported {
            payload["retrySupported"] = retrySupported
        }
        if let verificationOutcome, !verificationOutcome.isEmpty {
            payload["verificationOutcome"] = verificationOutcome
        }
        if let voiceVisualOnly {
            payload["voiceVisualOnly"] = voiceVisualOnly
        }
        return jsonDictionary(payload)
    }

    static func workflowSuggestion(
        phase: String,
        title: String,
        subtitle: String?,
        routineDisplayName: String?,
        trustPreview: String?,
        routineRunSupported: Bool?,
        catalogWorkflowIdentifier: String? = nil
    ) -> Data {
        var payload: [String: Any] = [
            "type": "workflowSuggestion",
            "phase": phase,
            "title": title,
        ]
        if let subtitle, !subtitle.isEmpty {
            payload["subtitle"] = subtitle
        }
        if let routineDisplayName, !routineDisplayName.isEmpty {
            payload["routineDisplayName"] = routineDisplayName
        }
        if let trustPreview, !trustPreview.isEmpty {
            payload["trustPreview"] = trustPreview
        }
        if let routineRunSupported {
            payload["routineRunSupported"] = routineRunSupported
        }
        if let catalogWorkflowIdentifier, !catalogWorkflowIdentifier.isEmpty {
            payload["catalogWorkflowIdentifier"] = catalogWorkflowIdentifier
        }
        return jsonDictionary(payload)
    }

    static func context(
        application: String,
        windowTitle: String?,
        title: String,
        subtitle: String? = nil,
        interaction: String? = nil
    ) -> Data {
        var payload: [String: Any] = [
            "type": "context",
            "application": application,
            "title": title,
        ]
        if let windowTitle, !windowTitle.isEmpty {
            payload["window"] = windowTitle
        }
        if let subtitle, !subtitle.isEmpty {
            payload["subtitle"] = subtitle
        }
        if let interaction, !interaction.isEmpty {
            payload["interaction"] = interaction
        }
        return jsonDictionary(payload)
    }

    static func ambient(
        beat: String,
        hubState: String,
        title: String,
        subtitle: String?,
        application: String?,
        interaction: String = "pointer"
    ) -> Data {
        var payload: [String: Any] = [
            "type": "ambient",
            "beat": beat,
            "state": hubState,
            "title": title,
            "interaction": interaction,
        ]
        if let subtitle, !subtitle.isEmpty {
            payload["subtitle"] = subtitle
        }
        if let application, !application.isEmpty {
            payload["application"] = application
        }
        return jsonDictionary(payload)
    }

    static func permission(
        title: String,
        subtitle: String,
        actionIdentifier: String,
        actionDescription: String,
        interaction: String? = nil,
        journeySteps: [[String: String]]? = nil
    ) -> Data {
        var payload: [String: Any] = [
            "type": "permission",
            "title": title,
            "subtitle": subtitle,
            "actionLabel": actionDescription,
            "action": [
                "id": actionIdentifier,
                "description": actionDescription,
            ],
        ]
        if let interaction, !interaction.isEmpty {
            payload["interaction"] = interaction
        }
        if let journeySteps, !journeySteps.isEmpty {
            payload["journeySteps"] = journeySteps
        }
        return jsonDictionary(payload)
    }

    static func memory(
        phase: String,
        title: String,
        subtitle: String?,
        memoryRecordId: String? = nil,
        memoryActionsSupported: Bool? = nil,
        preferenceReflection: String? = nil
    ) -> Data {
        var payload: [String: Any] = [
            "type": "memory",
            "phase": phase,
            "title": title,
        ]
        if let subtitle, !subtitle.isEmpty {
            payload["subtitle"] = subtitle
        }
        if let memoryRecordId, !memoryRecordId.isEmpty {
            payload["memoryRecordId"] = memoryRecordId
        }
        if let memoryActionsSupported {
            payload["memoryActionsSupported"] = memoryActionsSupported
        }
        if let preferenceReflection, !preferenceReflection.isEmpty {
            payload["preferenceReflection"] = preferenceReflection
        }
        return jsonDictionary(payload)
    }

    static func projectContext(label: String, projectName: String) -> Data {
        jsonDictionary([
            "type": "projectContext",
            "label": label,
            "projectName": projectName,
        ])
    }

    static func watching(applicationName: String) -> Data {
        jsonDictionary([
            "type": "watching",
            "application": applicationName,
        ])
    }

    static func ambientFocus(focusMode: Bool) -> Data {
        jsonDictionary([
            "type": "ambientFocus",
            "focusMode": focusMode,
        ])
    }

    static func teaching(
        phase: String,
        title: String,
        subtitle: String?,
        teachingStyle: String?,
        stepIndex: Int?,
        stepSummary: String?,
        stepPreviews: [[String: Any]]?
    ) -> Data {
        var payload: [String: Any] = [
            "type": "teaching",
            "phase": phase,
            "title": title,
        ]
        if let subtitle, !subtitle.isEmpty {
            payload["subtitle"] = subtitle
        }
        if let teachingStyle, !teachingStyle.isEmpty {
            payload["teachingStyle"] = teachingStyle
        }
        if let stepIndex {
            payload["stepIndex"] = stepIndex
        }
        if let stepSummary, !stepSummary.isEmpty {
            payload["stepSummary"] = stepSummary
        }
        if let stepPreviews, !stepPreviews.isEmpty {
            payload["stepsPreview"] = stepPreviews
        }
        return jsonDictionary(payload)
    }

    static func teachingCleared() -> Data {
        jsonDictionary([
            "type": "teaching",
            "phase": "none",
            "title": "",
        ])
    }

    static func demoHealth(checks: [[String: String]]) -> Data {
        jsonDictionary([
            "type": "demoHealth",
            "checks": checks,
        ])
    }

    static func contextLegacy(application: String, windowTitle: String?, title: String) -> Data {
        context(application: application, windowTitle: windowTitle, title: title, interaction: nil)
    }

    private static func jsonDictionary(_ dictionary: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dictionary, options: [])) ?? Data()
    }
}

enum DexterHubEventBridgeLog {
    static func info(_ message: String) {
        print("[DexterHub] \(message)")
    }

    static func hubState(_ hubState: String) {
        print("[DexterHub] state=\(hubState.uppercased())")
    }
}
