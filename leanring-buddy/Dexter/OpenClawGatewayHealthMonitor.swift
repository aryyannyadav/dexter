//
//  OpenClawGatewayHealthMonitor.swift
//  leanring-buddy
//

import Combine
import Foundation

enum OpenClawGatewayConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case unavailable
    case error(String)

    var isConnected: Bool {
        self == .connected
    }
}

/// Probes the local OpenClaw Gateway via the installed CLI (`openclaw gateway probe --json`).
final class OpenClawGatewayHealthMonitor: ObservableObject {
    static let shared = OpenClawGatewayHealthMonitor()

    @Published private(set) var connectionState: OpenClawGatewayConnectionState = .unavailable
    @Published private(set) var detectedOpenClawVersion: String?
    @Published private(set) var loopbackWebSocketURL: String?
    @Published private(set) var preferredNodeSnapshot: OpenClawNodeCapabilitySnapshot = .unavailable
    @Published private(set) var capabilityDiscoveryReport: DexterOpenClawCapabilityDiscoveryReport =
        DexterOpenClawCapabilityDiscovery.report(gatewayConnected: false, nodeSnapshot: .unavailable)

    var statusLine: String {
        switch connectionState {
        case .connected:
            let versionSuffix = detectedOpenClawVersion.map { " • \($0)" } ?? ""
            return "OpenClaw • Local • Connected\(versionSuffix)"
        case .connecting:
            return "OpenClaw • Local • Connecting…"
        case .disconnected:
            return "OpenClaw • Local • Offline"
        case .unavailable:
            return "OpenClaw • Local • Not installed"
        case .error:
            return "OpenClaw • Local • Error"
        }
    }

    private let localEnvironment: OpenClawLocalEnvironment
    private var lastSuccessfulRefreshDate: Date?
    private var lastAttemptDate: Date?
    private let minimumRefreshIntervalSeconds: TimeInterval = 30

    init(localEnvironment: OpenClawLocalEnvironment = OpenClawLocalEnvironment()) {
        self.localEnvironment = localEnvironment
        if localEnvironment.openClawExecutableURL != nil {
            DexterOpenClawLog.log("local runtime detected")
        }
    }

    func refreshHealthIfNeeded(force: Bool = false) async {
        let now = Date()
        if !force,
           let lastAttemptDate,
           now.timeIntervalSince(lastAttemptDate) < minimumRefreshIntervalSeconds {
            return
        }
        lastAttemptDate = now
        await refreshHealth()
    }

    func refreshHealth() async {
        guard let openClawExecutableURL = localEnvironment.openClawExecutableURL else {
            await publishState(.unavailable, version: nil, loopbackURL: nil)
            return
        }

        await publishState(.connecting, version: detectedOpenClawVersion, loopbackURL: loopbackWebSocketURL)
        DexterOpenClawLog.log("gateway connecting")

        var resolvedVersion = detectedOpenClawVersion
        if resolvedVersion == nil {
            resolvedVersion = await readOpenClawVersion(executableURL: openClawExecutableURL)
            if let resolvedVersion {
                await MainActor.run { detectedOpenClawVersion = resolvedVersion }
            }
        }

        do {
            let probeOutput = try await runOpenClawProcess(
                executableURL: openClawExecutableURL,
                arguments: ["gateway", "probe", "--json"]
            )
            let envelope = OpenClawGatewayProbeJSONParser.parse(from: probeOutput)
            if envelope?.ok == true {
                await publishState(.connected, version: detectedOpenClawVersion, loopbackURL: envelope?.network?.localLoopbackUrl)
                lastSuccessfulRefreshDate = Date()
                DexterOpenClawLog.log("gateway connected")
                await refreshNodeCapabilities(executableURL: openClawExecutableURL)
            } else {
                await publishNodeSnapshot(.unavailable)
                await publishState(.disconnected, version: detectedOpenClawVersion, loopbackURL: envelope?.network?.localLoopbackUrl)
                DexterOpenClawLog.log("gateway unreachable")
            }
        } catch {
            await publishNodeSnapshot(.unavailable)
            await publishState(.error("Gateway probe failed"), version: detectedOpenClawVersion, loopbackURL: loopbackWebSocketURL)
            DexterOpenClawLog.log("gateway probe failed")
        }
    }

    func refreshNodeCapabilities(executableURL: URL? = nil) async {
        let resolvedExecutableURL = executableURL ?? localEnvironment.openClawExecutableURL
        guard let resolvedExecutableURL else {
            await publishNodeSnapshot(.unavailable)
            return
        }

        do {
            let nodesStatusOutput = try await OpenClawCLIProcessRunner.run(
                executableURL: resolvedExecutableURL,
                arguments: ["nodes", "status", "--json"],
                environment: localEnvironment.augmentedProcessEnvironment()
            )
            let nodeSnapshot = OpenClawNodesStatusJSONParser.preferredLocalNodeSnapshot(from: nodesStatusOutput) ?? .unavailable
            await publishNodeSnapshot(nodeSnapshot)
            logNodeCapabilitySnapshot(nodeSnapshot)
        } catch {
            await publishNodeSnapshot(.unavailable)
            DexterOpenClawLog.log("node status probe failed")
        }
    }

    private func logNodeCapabilitySnapshot(_ nodeSnapshot: OpenClawNodeCapabilitySnapshot) {
        if nodeSnapshot.isConnected {
            DexterOpenClawLog.log("node connected")
        } else if nodeSnapshot.isPaired {
            DexterOpenClawLog.log("node paired but disconnected")
        } else {
            DexterOpenClawLog.log("node not paired")
        }

        let computerCapability = nodeSnapshot.hasComputerActCommand && nodeSnapshot.isConnected ? "available" : "unavailable"
        DexterOpenClawLog.log("computer capability=\(computerCapability)")

        let systemRunCapability = nodeSnapshot.hasSystemRunCommand && nodeSnapshot.isConnected ? "available" : "unavailable"
        DexterOpenClawLog.log("system.run=\(systemRunCapability)")

        let browserCapability = nodeSnapshot.hasBrowserProxyCommand && nodeSnapshot.isConnected ? "available" : "unavailable"
        DexterOpenClawLog.log("browser capability=\(browserCapability)")

        let screenCapability = nodeSnapshot.hasScreenSnapshotCommand && nodeSnapshot.isConnected ? "available" : "unavailable"
        DexterOpenClawLog.log("screen capability=\(screenCapability)")

        let accessibilityPermission = nodeSnapshot.permissions.accessibilityGranted ? "granted" : "missing"
        DexterOpenClawLog.log("permissions accessibility=\(accessibilityPermission)")

        let screenRecordingPermission = nodeSnapshot.permissions.screenRecordingGranted ? "granted" : "missing"
        DexterOpenClawLog.log("permissions screenRecording=\(screenRecordingPermission)")
    }

    @MainActor
    private func publishNodeSnapshot(_ nodeSnapshot: OpenClawNodeCapabilitySnapshot) {
        preferredNodeSnapshot = nodeSnapshot
        refreshCapabilityDiscoveryReport()
    }

    @MainActor
    private func publishState(
        _ state: OpenClawGatewayConnectionState,
        version: String?,
        loopbackURL: String?
    ) {
        connectionState = state
        if let version {
            detectedOpenClawVersion = version
        }
        loopbackWebSocketURL = loopbackURL
        refreshCapabilityDiscoveryReport()
    }

    @MainActor
    private func refreshCapabilityDiscoveryReport() {
        capabilityDiscoveryReport = DexterOpenClawRuntimeCapabilityRegistry.buildDiscoveryReport(
            gatewayConnected: connectionState.isConnected,
            nodeSnapshot: preferredNodeSnapshot
        )
    }

    private func readOpenClawVersion(executableURL: URL) async -> String? {
        do {
            let output = try await runOpenClawProcess(executableURL: executableURL, arguments: ["--version"])
            return OpenClawVersionParser.parse(from: output)
        } catch {
            return nil
        }
    }

    private func runOpenClawProcess(executableURL: URL, arguments: [String]) async throws -> String {
        try await OpenClawCLIProcessRunner.run(
            executableURL: executableURL,
            arguments: arguments,
            environment: localEnvironment.augmentedProcessEnvironment()
        )
    }
}

enum OpenClawVersionParser {
    static func parse(from output: String) -> String? {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedOutput.hasPrefix("OpenClaw ") else { return nil }
        let versionToken = trimmedOutput
            .replacingOccurrences(of: "OpenClaw ", with: "")
            .split(separator: " ")
            .first
        return versionToken.map(String.init)
    }
}

struct OpenClawGatewayProbeEnvelope: Decodable {
    let ok: Bool?
    let capability: String?
    let network: OpenClawGatewayProbeNetwork?
}

struct OpenClawGatewayProbeNetwork: Decodable {
    let localLoopbackUrl: String?
}

enum OpenClawGatewayProbeJSONParser {
    static func parse(from output: String) -> OpenClawGatewayProbeEnvelope? {
        guard let firstOpeningBraceIndex = output.firstIndex(of: "{"),
              let lastClosingBraceIndex = output.lastIndex(of: "}"),
              firstOpeningBraceIndex <= lastClosingBraceIndex
        else {
            return nil
        }

        let jsonCandidate = String(output[firstOpeningBraceIndex...lastClosingBraceIndex])
        guard let data = jsonCandidate.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(OpenClawGatewayProbeEnvelope.self, from: data)
    }
}
