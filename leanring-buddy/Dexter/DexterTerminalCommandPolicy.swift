//
//  DexterTerminalCommandPolicy.swift
//  leanring-buddy
//

import Foundation

/// Approved terminal command templates — models must reference a template id, not raw shell strings.
enum DexterTerminalCommandPolicy {
    static let maxOutputBytes = 32_768
    static let executionTimeoutSeconds: TimeInterval = 45

    struct ApprovedCommand: Equatable {
        let templateIdentifier: String
        let executablePath: String
        let fixedArguments: [String]
        let allowsSinglePathArgument: Bool
        let readOnly: Bool
    }

    static let approvedTemplates: [ApprovedCommand] = [
        ApprovedCommand(
            templateIdentifier: "inspect_pwd",
            executablePath: "/bin/pwd",
            fixedArguments: [],
            allowsSinglePathArgument: false,
            readOnly: true
        ),
        ApprovedCommand(
            templateIdentifier: "inspect_list_directory",
            executablePath: "/bin/ls",
            fixedArguments: ["-la"],
            allowsSinglePathArgument: true,
            readOnly: true
        ),
        ApprovedCommand(
            templateIdentifier: "git_status_short",
            executablePath: "/usr/bin/git",
            fixedArguments: ["status", "--short"],
            allowsSinglePathArgument: false,
            readOnly: true
        ),
        ApprovedCommand(
            templateIdentifier: "swift_version",
            executablePath: "/usr/bin/swift",
            fixedArguments: ["--version"],
            allowsSinglePathArgument: false,
            readOnly: true
        )
    ]

    enum Resolution: Equatable {
        case approved(executablePath: String, arguments: [String], workingDirectoryURL: URL?, readOnly: Bool)
        case rejected(reason: String)
    }

    static func resolve(
        terminalAction: String,
        parameters: [String: String]
    ) -> Resolution {
        if parameters["command"] != nil && parameters["commandTemplate"] == nil {
            return .rejected(
                reason: "Raw shell commands are not allowed. Use commandTemplate with an approved template id."
            )
        }

        guard let templateIdentifier = parameters["commandTemplate"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !templateIdentifier.isEmpty
        else {
            return .rejected(reason: "Terminal actions require an explicit commandTemplate id.")
        }

        guard let template = approvedTemplates.first(where: { $0.templateIdentifier == templateIdentifier }) else {
            return .rejected(reason: "Unknown or disallowed command template: \(templateIdentifier).")
        }

        if terminalAction == "inspect" && !template.readOnly {
            return .rejected(reason: "inspect only allows read-only command templates.")
        }

        var arguments = template.fixedArguments
        if template.allowsSinglePathArgument {
            guard let pathArgument = parameters["pathArgument"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !pathArgument.isEmpty
            else {
                return .rejected(reason: "This template requires a single approved pathArgument.")
            }
            switch DexterApprovedFilePathPolicy.evaluate(path: pathArgument) {
            case .approved(let resolvedURL):
                arguments.append(resolvedURL.path)
            case .rejected(let reason):
                return .rejected(reason: reason)
            }
        }

        var workingDirectoryURL: URL?
        if let workingDirectory = parameters["workingDirectory"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !workingDirectory.isEmpty {
            switch DexterApprovedFilePathPolicy.evaluate(path: workingDirectory) {
            case .approved(let resolvedURL):
                workingDirectoryURL = resolvedURL.deletingLastPathComponent()
                if FileManager.default.fileExists(atPath: resolvedURL.path) {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        workingDirectoryURL = resolvedURL
                    }
                }
            case .rejected(let reason):
                return .rejected(reason: reason)
            }
        }

        if containsShellMetacharacters(in: arguments) {
            return .rejected(reason: "Command arguments contain disallowed shell metacharacters.")
        }

        return .approved(
            executablePath: template.executablePath,
            arguments: arguments,
            workingDirectoryURL: workingDirectoryURL,
            readOnly: template.readOnly
        )
    }

    static func templateIsAllowedForTerminalAction(_ terminalAction: String, templateIdentifier: String) -> Bool {
        guard let template = approvedTemplates.first(where: { $0.templateIdentifier == templateIdentifier }) else {
            return false
        }
        switch terminalAction {
        case "inspect", "captureOutput":
            return template.readOnly
        case "run":
            return !template.readOnly
        default:
            return false
        }
    }

    private static func containsShellMetacharacters(in arguments: [String]) -> Bool {
        let forbiddenCharacters: Set<Character> = ["|", "&", ";", "`", "$", "(", ")", "<", ">", "\n", "\r"]
        return arguments.contains { argument in
            argument.contains(where: { forbiddenCharacters.contains($0) })
        }
    }
}
