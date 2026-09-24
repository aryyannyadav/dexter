//
//  DexterLocalFileToolExecutor.swift
//  leanring-buddy
//

import Foundation

enum DexterLocalFileToolExecutor {
    static func execute(toolInvocation: DexterToolInvocation) -> DexterToolGatewayOutcome {
        let fileAction = toolInvocation.parameters["fileAction"] ?? ""
        switch fileAction {
        case "search":
            return searchFiles(parameters: toolInvocation.parameters)
        case "read":
            return readFile(parameters: toolInvocation.parameters)
        case "create":
            return createFile(parameters: toolInvocation.parameters)
        case "write":
            return writeFile(parameters: toolInvocation.parameters)
        case "move":
            return moveFile(parameters: toolInvocation.parameters)
        case "rename":
            return renameFile(parameters: toolInvocation.parameters)
        case "delete":
            return deleteFile(parameters: toolInvocation.parameters)
        default:
            return .dispatchFailed(message: "Unknown file action.", rawOutput: nil)
        }
    }

    private static func searchFiles(parameters: [String: String]) -> DexterToolGatewayOutcome {
        guard let query = parameters["query"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty
        else {
            return .dispatchFailed(message: "file.search requires a non-empty query.", rawOutput: nil)
        }

        let searchRootPath = parameters["searchRoot"] ?? "~/Documents"
        switch DexterApprovedFilePathPolicy.evaluate(path: searchRootPath) {
        case .rejected(let reason):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case .approved(let resolvedURL):
            let rootURL = resolvedURL.hasDirectoryPath ? resolvedURL : resolvedURL.deletingLastPathComponent()
            guard FileManager.default.fileExists(atPath: rootURL.path) else {
                return .dispatchFailed(message: "Search root does not exist.", rawOutput: nil)
            }

            let matches = findFiles(namedLike: query, under: rootURL, limit: 25)
            let payload = DexterFileOperationResultPayload(
                fileAction: "search",
                path: rootURL.path,
                destinationPath: nil,
                exists: nil,
                contentPreview: nil,
                matchedPaths: matches
            )
            return .dispatchSucceeded(
                runtimeTaskIdentifier: UUID().uuidString,
                rawOutput: payload.encodedJSON()
            )
        }
    }

    private static func readFile(parameters: [String: String]) -> DexterToolGatewayOutcome {
        guard let path = parameters["path"] else {
            return .dispatchFailed(message: "file.read requires path.", rawOutput: nil)
        }
        switch DexterApprovedFilePathPolicy.evaluate(path: path) {
        case .rejected(let reason):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case .approved(let resolvedURL):
            guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
                return .dispatchFailed(message: "File does not exist.", rawOutput: payloadJSON(fileAction: "read", path: resolvedURL.path, exists: false))
            }
            guard let data = try? Data(contentsOf: resolvedURL) else {
                return .dispatchFailed(message: "Could not read file.", rawOutput: nil)
            }
            if data.count > DexterApprovedFilePathPolicy.maxReadBytes {
                return .dispatchFailed(message: "File exceeds Dexter read size limit.", rawOutput: nil)
            }
            let content = String(decoding: data, as: UTF8.self)
            let preview = DexterTerminalOutputSanitizer.sanitizeAndTruncate(content, maxBytes: 8_192)
            let payload = DexterFileOperationResultPayload(
                fileAction: "read",
                path: resolvedURL.path,
                destinationPath: nil,
                exists: true,
                contentPreview: preview,
                matchedPaths: nil
            )
            return .dispatchSucceeded(runtimeTaskIdentifier: UUID().uuidString, rawOutput: payload.encodedJSON())
        }
    }

    private static func createFile(parameters: [String: String]) -> DexterToolGatewayOutcome {
        guard let path = parameters["path"] else {
            return .dispatchFailed(message: "file.create requires path.", rawOutput: nil)
        }
        let content = parameters["content"] ?? ""
        if content.utf8.count > DexterApprovedFilePathPolicy.maxWriteBytes {
            return .dispatchFailed(message: "Content exceeds write size limit.", rawOutput: nil)
        }

        switch DexterApprovedFilePathPolicy.evaluate(path: path) {
        case .rejected(let reason):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case .approved(let resolvedURL):
            if FileManager.default.fileExists(atPath: resolvedURL.path) {
                return .dispatchFailed(message: "File already exists.", rawOutput: payloadJSON(fileAction: "create", path: resolvedURL.path, exists: true))
            }
            let parent = resolvedURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            do {
                try Data(content.utf8).write(to: resolvedURL, options: .atomic)
            } catch {
                return .dispatchFailed(message: "Could not create file: \(error.localizedDescription)", rawOutput: nil)
            }
            return successPayload(fileAction: "create", path: resolvedURL.path, exists: true, contentPreview: content)
        }
    }

    private static func writeFile(parameters: [String: String]) -> DexterToolGatewayOutcome {
        guard let path = parameters["path"] else {
            return .dispatchFailed(message: "file.write requires path.", rawOutput: nil)
        }
        guard let content = parameters["content"] else {
            return .dispatchFailed(message: "file.write requires content.", rawOutput: nil)
        }
        if content.utf8.count > DexterApprovedFilePathPolicy.maxWriteBytes {
            return .dispatchFailed(message: "Content exceeds write size limit.", rawOutput: nil)
        }

        switch DexterApprovedFilePathPolicy.evaluate(path: path) {
        case .rejected(let reason):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case .approved(let resolvedURL):
            do {
                try Data(content.utf8).write(to: resolvedURL, options: .atomic)
            } catch {
                return .dispatchFailed(message: "Could not write file: \(error.localizedDescription)", rawOutput: nil)
            }
            return successPayload(fileAction: "write", path: resolvedURL.path, exists: true, contentPreview: content)
        }
    }

    private static func moveFile(parameters: [String: String]) -> DexterToolGatewayOutcome {
        guard let path = parameters["path"], let destinationPath = parameters["destinationPath"] else {
            return .dispatchFailed(message: "file.move requires path and destinationPath.", rawOutput: nil)
        }
        switch (DexterApprovedFilePathPolicy.evaluate(path: path), DexterApprovedFilePathPolicy.evaluate(path: destinationPath)) {
        case (.rejected(let reason), _):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case (_, .rejected(let reason)):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case (.approved(let sourceURL), .approved(let destinationURL)):
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                return .dispatchFailed(message: "Source file does not exist.", rawOutput: nil)
            }
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                return .dispatchFailed(message: "Destination already exists.", rawOutput: nil)
            }
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            } catch {
                return .dispatchFailed(message: "Move failed: \(error.localizedDescription)", rawOutput: nil)
            }
            let payload = DexterFileOperationResultPayload(
                fileAction: "move",
                path: sourceURL.path,
                destinationPath: destinationURL.path,
                exists: false,
                contentPreview: nil,
                matchedPaths: nil
            )
            return .dispatchSucceeded(runtimeTaskIdentifier: UUID().uuidString, rawOutput: payload.encodedJSON())
        }
    }

    private static func renameFile(parameters: [String: String]) -> DexterToolGatewayOutcome {
        guard let path = parameters["path"], let newName = parameters["newName"]?.trimmingCharacters(in: .whitespacesAndNewlines), !newName.isEmpty else {
            return .dispatchFailed(message: "file.rename requires path and newName.", rawOutput: nil)
        }
        if newName.contains("/") {
            return .dispatchFailed(message: "newName must be a file name, not a path.", rawOutput: nil)
        }
        switch DexterApprovedFilePathPolicy.evaluate(path: path) {
        case .rejected(let reason):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case .approved(let sourceURL):
            let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(newName)
            switch DexterApprovedFilePathPolicy.evaluate(path: destinationURL.path) {
            case .rejected(let reason):
                return .dispatchFailed(message: reason, rawOutput: nil)
            case .approved:
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    return .dispatchFailed(message: "Source file does not exist.", rawOutput: nil)
                }
                do {
                    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                } catch {
                    return .dispatchFailed(message: "Rename failed: \(error.localizedDescription)", rawOutput: nil)
                }
                let payload = DexterFileOperationResultPayload(
                    fileAction: "rename",
                    path: sourceURL.path,
                    destinationPath: destinationURL.path,
                    exists: false,
                    contentPreview: nil,
                    matchedPaths: nil
                )
                return .dispatchSucceeded(runtimeTaskIdentifier: UUID().uuidString, rawOutput: payload.encodedJSON())
            }
        }
    }

    private static func deleteFile(parameters: [String: String]) -> DexterToolGatewayOutcome {
        guard let path = parameters["path"] else {
            return .dispatchFailed(message: "file.delete requires path.", rawOutput: nil)
        }
        switch DexterApprovedFilePathPolicy.evaluate(path: path) {
        case .rejected(let reason):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case .approved(let resolvedURL):
            guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
                return .dispatchFailed(message: "File does not exist.", rawOutput: payloadJSON(fileAction: "delete", path: resolvedURL.path, exists: false))
            }
            do {
                try FileManager.default.removeItem(at: resolvedURL)
            } catch {
                return .dispatchFailed(message: "Delete failed: \(error.localizedDescription)", rawOutput: nil)
            }
            return successPayload(fileAction: "delete", path: resolvedURL.path, exists: false, contentPreview: nil)
        }
    }

    private static func findFiles(namedLike query: String, under rootURL: URL, limit: Int) -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let loweredQuery = query.lowercased()
        var matches: [String] = []
        for case let fileURL as URL in enumerator {
            if matches.count >= limit { break }
            if fileURL.lastPathComponent.lowercased().contains(loweredQuery) {
                matches.append(fileURL.path)
            }
        }
        return matches
    }

    private static func successPayload(
        fileAction: String,
        path: String,
        exists: Bool?,
        contentPreview: String?
    ) -> DexterToolGatewayOutcome {
        let payload = DexterFileOperationResultPayload(
            fileAction: fileAction,
            path: path,
            destinationPath: nil,
            exists: exists,
            contentPreview: contentPreview,
            matchedPaths: nil
        )
        return .dispatchSucceeded(runtimeTaskIdentifier: UUID().uuidString, rawOutput: payload.encodedJSON())
    }

    private static func payloadJSON(fileAction: String, path: String, exists: Bool) -> String {
        DexterFileOperationResultPayload(
            fileAction: fileAction,
            path: path,
            destinationPath: nil,
            exists: exists,
            contentPreview: nil,
            matchedPaths: nil
        ).encodedJSON()
    }
}

struct DexterFileOperationResultPayload: Equatable {
    let fileAction: String
    let path: String
    let destinationPath: String?
    let exists: Bool?
    let contentPreview: String?
    let matchedPaths: [String]?

    func encodedJSON() -> String {
        var object: [String: Any] = [
            "fileAction": fileAction,
            "path": path
        ]
        if let destinationPath { object["destinationPath"] = destinationPath }
        if let exists { object["exists"] = exists }
        if let contentPreview { object["contentPreview"] = contentPreview }
        if let matchedPaths { object["matchedPaths"] = matchedPaths }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func decode(from rawOutput: String?) -> DexterFileOperationResultPayload? {
        guard let rawOutput,
              let data = rawOutput.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return DexterFileOperationResultPayload(
            fileAction: object["fileAction"] as? String ?? "",
            path: object["path"] as? String ?? "",
            destinationPath: object["destinationPath"] as? String,
            exists: object["exists"] as? Bool,
            contentPreview: object["contentPreview"] as? String,
            matchedPaths: object["matchedPaths"] as? [String]
        )
    }
}
