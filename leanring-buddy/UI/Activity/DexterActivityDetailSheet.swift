//
//  DexterActivityDetailSheet.swift
//  leanring-buddy
//

import SwiftUI

struct DexterActivityDetailSheet: View {
    @ObservedObject var companionManager: CompanionManager
    let record: DexterActivityRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DexterMetrics.space16) {
                    Text(record.title)
                        .font(DexterTypography.title())
                        .foregroundColor(DexterSurfaceColors.textPrimary)

                    HStack(spacing: DexterMetrics.space8) {
                        Text(DexterActivityPresentation.statusLabel(for: record.status))
                            .font(DexterTypography.bodyMedium())
                            .foregroundColor(DexterPastelColors.lavender)
                        Text(DexterActivityPresentation.timeLabel(for: record.timestamp))
                            .font(DexterTypography.caption())
                            .foregroundColor(DexterColors.textTertiary)
                    }

                    if let detail = record.detail {
                        detailSection(detail: detail)
                    }

                    actionButtons
                }
                .padding(DexterMetrics.space20)
            }
            .background(DexterSurfaceColors.background)
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 360)
    }

    @ViewBuilder
    private func detailSection(detail: DexterActivityDetail) -> some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space12) {
            if let requested = detail.requestedUtterance, !requested.isEmpty {
                detailRow(label: "Requested", value: requested)
            }
            if let actionLabel = detail.actionLabel, !actionLabel.isEmpty {
                detailRow(label: "Action", value: actionLabel)
            }
            if let result = detail.resultSummary, !result.isEmpty {
                detailRow(label: "Result", value: result)
            }
            if let verification = detail.verificationSummary, !verification.isEmpty {
                detailRow(label: "Verified", value: verification)
            }
            if let memoryPreview = detail.memoryContentPreview, !memoryPreview.isEmpty {
                detailRow(label: "Memory", value: "“\(memoryPreview)”")
            }
            if let workspacePath = detail.workspaceDisplayPath, !workspacePath.isEmpty {
                detailRow(label: "Location", value: workspacePath)
            }
            if let routineName = detail.routineName, !routineName.isEmpty {
                detailRow(label: "Routine", value: routineName)
            }
            if let suggestionTitle = detail.suggestionTitle, !suggestionTitle.isEmpty {
                detailRow(label: "Suggestion", value: suggestionTitle)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space8) {
            if let conversationId = record.relatedConversationId {
                Button("Open conversation") {
                    dismiss()
                    if let conversation = companionManager.dexterRecentConversations.first(where: { $0.id == conversationId }) {
                        companionManager.openRecentDexterConversation(conversation)
                        NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
                    }
                }
                .buttonStyle(.plain)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterPastelColors.lavender)
                .pointerCursor()
            }

            if record.kind == .memory, let profileId = record.dexterProfileId {
                Button("Open Memory") {
                    dismiss()
                    companionManager.pendingUniversalCommandProfileId = profileId
                    NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
                }
                .buttonStyle(.plain)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterPastelColors.lavender)
                .pointerCursor()
            }

            if let routineId = record.relatedRoutineId {
                Button("Open routine") {
                    dismiss()
                    companionManager.pendingUniversalCommandRoutineId = routineId
                    NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
                }
                .buttonStyle(.plain)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterPastelColors.lavender)
                .pointerCursor()
            }
        }
        .padding(.top, DexterMetrics.space8)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
            Text(value)
                .font(DexterTypography.body())
                .foregroundColor(DexterSurfaceColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
