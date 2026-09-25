//
//  DexterProgressMessage.swift
//  leanring-buddy
//

import Combine
import SwiftUI

struct DexterProgressStep: Identifiable, Equatable {
    enum Status: Equatable {
        case completed
        case inProgress
        case pending
    }

    let id: UUID
    let title: String
    let status: Status
}

struct DexterProgressMessage: View {
    let profile: DexterProfile
    let headline: String
    let steps: [DexterProgressStep]
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DexterMessageMetrics.avatarToBubbleGap) {
            DexterAvatar(
                profile: profile,
                size: DexterAvatarSize.sm,
                characterState: .working,
                animationEnabled: true
            )

            VStack(alignment: .leading, spacing: DexterSpacing.sm) {
                Text(headline)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterSurfaceColors.textPrimary)

                if isExpanded {
                    VStack(alignment: .leading, spacing: DexterSpacing.xs) {
                        ForEach(steps) { step in
                            HStack(spacing: DexterSpacing.sm) {
                                stepIcon(for: step.status)
                                Text(step.title)
                                    .font(DexterTypography.metadata())
                                    .foregroundColor(
                                        step.status == .inProgress
                                            ? DexterSurfaceColors.textPrimary
                                            : DexterSurfaceColors.textSecondary
                                    )
                            }
                        }
                    }
                } else {
                    Button {
                        isExpanded = true
                    } label: {
                        Text(collapsedSummary)
                            .font(DexterTypography.metadata())
                            .foregroundColor(DexterSurfaceColors.textMuted)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }
            .padding(DexterSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.messageBubble, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DexterPastelColors.lavender.opacity(0.1),
                                DexterSurfaceColors.surface.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterRadii.messageBubble, style: .continuous)
                    .stroke(DexterPastelColors.lavender.opacity(0.2), lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dexter progress, \(headline)")
    }

    private var collapsedSummary: String {
        let count = steps.count
        if count == 1 {
            return "1 progress step"
        }
        return "\(count) progress steps"
    }

    @ViewBuilder
    private func stepIcon(for status: DexterProgressStep.Status) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DexterSurfaceColors.success)
        case .inProgress:
            Circle()
                .fill(profile.accentColor)
                .frame(width: 6, height: 6)
        case .pending:
            Circle()
                .stroke(DexterSurfaceColors.textMuted.opacity(0.5), lineWidth: 1)
                .frame(width: 6, height: 6)
        }
    }
}

@MainActor
final class DexterConversationProgressTracker: ObservableObject {
    @Published private(set) var steps: [DexterProgressStep] = []
    @Published var isExpanded = false

    private var trackedDetailLines: [String] = []

    func reset() {
        steps = []
        trackedDetailLines = []
        isExpanded = false
    }

    func ingest(
        runtimeState: DexterRuntimeUIState,
        statusDetail: String,
        progressSummary: String?
    ) {
        switch runtimeState {
        case .idle, .done, .cancelled, .listening, .understanding, .thinking:
            if runtimeState.isTerminal || runtimeState == .idle {
                markAllStepsCompleted()
            }
            return
        case .failed:
            markAllStepsCompleted()
            return
        case .planning, .waitingPermission, .acting, .verifying:
            break
        }

        let candidateLine = sanitizedLine(from: statusDetail)
            ?? sanitizedLine(from: progressSummary)
        guard let candidateLine else { return }

        if trackedDetailLines.last == candidateLine {
            return
        }
        if !trackedDetailLines.contains(candidateLine) {
            trackedDetailLines.append(candidateLine)
        }
        rebuildSteps(currentLine: candidateLine)
    }

    private func sanitizedLine(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().contains("openclaw") { return nil }
        if trimmed.hasPrefix("[DEXTER]") { return nil }
        return trimmed
    }

    private func rebuildSteps(currentLine: String) {
        guard let currentIndex = trackedDetailLines.firstIndex(of: currentLine) else { return }
        steps = trackedDetailLines.enumerated().map { index, line in
            let status: DexterProgressStep.Status
            if index < currentIndex {
                status = .completed
            } else if index == currentIndex {
                status = .inProgress
            } else {
                status = .pending
            }
            return DexterProgressStep(id: UUID(), title: line, status: status)
        }
    }

    private func markAllStepsCompleted() {
        guard !steps.isEmpty else { return }
        steps = steps.map { step in
            DexterProgressStep(id: step.id, title: step.title, status: .completed)
        }
    }

    func markAllStepsCompletedIfNeeded() {
        markAllStepsCompleted()
    }

    var shouldShowInConversation: Bool {
        !steps.isEmpty
    }
}
