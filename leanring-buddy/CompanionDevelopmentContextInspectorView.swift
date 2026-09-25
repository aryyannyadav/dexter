//
//  CompanionDevelopmentContextInspectorView.swift
//  leanring-buddy
//

import SwiftUI

#if DEBUG
struct CompanionDevelopmentContextInspectorView: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var isCharacterStatePreviewPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { companionManager.isDevelopmentContextInspectorEnabled },
                set: { companionManager.setDevelopmentContextInspectorEnabled($0) }
            )) {
                Text("Context inspector (dev)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .toggleStyle(.switch)
            .pointerCursor()

            Button("Preview character states") {
                isCharacterStatePreviewPresented = true
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(DexterPastelColors.lavender)
            .buttonStyle(.plain)
            .pointerCursor()
            .sheet(isPresented: $isCharacterStatePreviewPresented) {
                DexterCharacterStatePreviewSheet()
            }

            if companionManager.isDevelopmentContextInspectorEnabled {
                if let snapshot = companionManager.developmentContextInspectorSnapshot {
                    inspectorRow(title: "Pointer", value: snapshot.pointerCoordinatesDescription)
                    inspectorRow(title: "Active app", value: snapshot.activeApplicationDescription)
                    inspectorRow(title: "Active window", value: snapshot.activeWindowDescription)
                    inspectorRow(title: "Display", value: snapshot.displayDescription)
                    inspectorRow(title: "Screenshot", value: snapshot.screenshotStatusDescription)
                } else {
                    Text("Invoke Dexter (push-to-talk) to populate context.")
                        .font(.system(size: 11))
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func inspectorRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
