//
//  DexterEmptyState.swift
//  leanring-buddy
//

import SwiftUI

struct DexterEmptyState: View {
    let onSuggestionSelected: (String) -> Void

    private let suggestions = [
        "Explain what's on my screen",
        "Help me understand this error",
        "Teach me how to do this",
        "What am I looking at?"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hey, I'm Dexter.")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)

                Text("Point at something, ask me anything, or let me help you figure it out.")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    DexterSuggestionCard(title: suggestion) {
                        onSuggestionSelected(suggestion)
                    }
                }
            }
        }
        .frame(maxWidth: 420)
        .padding(.vertical, 8)
    }
}
