//
//  DexterApplicationReferenceResolver.swift
//  leanring-buddy
//

import Foundation

struct DexterApplicationReference: Equatable {
    let displayName: String
    let bundleIdentifier: String?
    /// Value passed to OpenClaw `launch_app` / `kill_app` (`app` field): display name or bundle ID.
    let openClawApplicationToken: String
}

enum DexterApplicationReferenceResolver {
    static func resolve(userInput: String) -> DexterApplicationReference {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInput.isEmpty {
            return DexterApplicationReference(
                displayName: userInput,
                bundleIdentifier: nil,
                openClawApplicationToken: userInput
            )
        }

        if let bundleMatchedReference = referenceMatchingBundleIdentifier(trimmedInput) {
            return bundleMatchedReference
        }

        if let installedReference = referenceFromInstalledApplication(named: trimmedInput) {
            return installedReference
        }

        let formattedDisplayName = DexterApplicationReferenceResolver.titleCasedDisplayName(from: trimmedInput)
        return DexterApplicationReference(
            displayName: formattedDisplayName,
            bundleIdentifier: nil,
            openClawApplicationToken: formattedDisplayName
        )
    }

    static func bundleIdentifierMatches(userInput: String, bundleIdentifier: String) -> Bool {
        if let applicationURL = DexterInstalledApplicationLauncher.resolveApplicationURL(named: userInput),
           let installedBundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier {
            return installedBundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }

        let resolvedReference = resolve(userInput: userInput)
        if let resolvedBundleIdentifier = resolvedReference.bundleIdentifier {
            return resolvedBundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
        let normalizedInput = normalizeApplicationName(userInput)
        let normalizedBundle = bundleIdentifier.lowercased()
        if normalizedBundle.contains(normalizedInput), !normalizedInput.isEmpty {
            return true
        }
        let bundleSuffix = bundleIdentifier.split(separator: ".").last.map(String.init) ?? ""
        return normalizeApplicationName(bundleSuffix) == normalizedInput
    }

    static func normalizeApplicationName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: ".app", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func referenceMatchingBundleIdentifier(_ trimmedInput: String) -> DexterApplicationReference? {
        guard looksLikeBundleIdentifier(trimmedInput) else { return nil }

        if let applicationURL = DexterInstalledApplicationLauncher.resolveApplicationURL(matchingBundleIdentifier: trimmedInput),
           let bundle = Bundle(url: applicationURL)?.bundleIdentifier {
            let displayName = Bundle(url: applicationURL)?.displayNameFromInfoDictionary
                ?? applicationURL.deletingPathExtension().lastPathComponent
            return DexterApplicationReference(
                displayName: displayName,
                bundleIdentifier: bundle,
                openClawApplicationToken: displayName
            )
        }

        return DexterApplicationReference(
            displayName: trimmedInput,
            bundleIdentifier: trimmedInput,
            openClawApplicationToken: trimmedInput
        )
    }

    private static func referenceFromInstalledApplication(named applicationName: String) -> DexterApplicationReference? {
        guard let applicationURL = DexterInstalledApplicationLauncher.resolveApplicationURL(named: applicationName) else {
            return nil
        }
        let bundle = Bundle(url: applicationURL)?.bundleIdentifier
        let displayName = Bundle(url: applicationURL)?.displayNameFromInfoDictionary
            ?? applicationURL.deletingPathExtension().lastPathComponent
        return DexterApplicationReference(
            displayName: displayName,
            bundleIdentifier: bundle,
            openClawApplicationToken: displayName
        )
    }

    private static func looksLikeBundleIdentifier(_ value: String) -> Bool {
        value.contains(".") && !value.contains(" ")
    }

    private static func titleCasedDisplayName(from rawToken: String) -> String {
        rawToken
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}

private extension Bundle {
    var displayNameFromInfoDictionary: String? {
        if let displayName = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let bundleName = object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        return nil
    }
}

enum DexterApplicationLifecycleToolInvocationEnricher {
    static func enrich(_ toolInvocation: DexterToolInvocation) -> DexterToolInvocation {
        switch toolInvocation.toolKind {
        case .launchApplication, .quitApplication, .focusApplication:
            guard let rawApplicationName = toolInvocation.parameters["applicationName"] else {
                return toolInvocation
            }
            let reference = DexterApplicationReferenceResolver.resolve(userInput: rawApplicationName)
            var parameters = toolInvocation.parameters
            parameters["applicationName"] = reference.displayName
            parameters["openClawApplicationToken"] = reference.openClawApplicationToken
            if let bundleIdentifier = reference.bundleIdentifier {
                parameters["bundleIdentifier"] = bundleIdentifier
            }
            return DexterToolInvocation(
                registeredToolName: toolInvocation.registeredToolName,
                toolKind: toolInvocation.toolKind,
                actionIdentifier: toolInvocation.actionIdentifier,
                parameters: parameters
            )
        default:
            return toolInvocation
        }
    }
}
