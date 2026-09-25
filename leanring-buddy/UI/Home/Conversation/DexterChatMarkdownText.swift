//
//  DexterChatMarkdownText.swift
//  leanring-buddy
//

import SwiftUI

enum DexterChatMarkdownSegment: Equatable {
    case prose(String)
    case codeBlock(language: String?, code: String)
}

/// Renders assistant/user markdown with selectable text and compact code surfaces.
struct DexterChatMarkdownText: View {
    let text: String
    var foregroundColor: Color = DexterSurfaceColors.textPrimary
    var isError: Bool = false

    var body: some View {
        if segments.isEmpty {
            Text("")
                .font(DexterTypography.chatBody())
        } else {
            VStack(alignment: .leading, spacing: DexterSpacing.sm) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .prose(let prose):
                        markdownText(prose)
                    case .codeBlock(let language, let code):
                        codeBlockView(language: language, code: code)
                    }
                }
            }
        }
    }

    private var segments: [DexterChatMarkdownSegment] {
        DexterChatMarkdownSegmentParser.parse(text)
    }

    @ViewBuilder
    private func markdownText(_ prose: String) -> some View {
        if let attributed = DexterChatMarkdownAttributedStringBuilder.make(from: prose) {
            Text(attributed)
                .font(DexterTypography.chatBody())
                .foregroundColor(isError ? DexterSurfaceColors.warning : foregroundColor)
                .lineSpacing(DexterTypography.chatLineSpacing)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
        } else {
            Text(prose)
                .font(DexterTypography.chatBody())
                .foregroundColor(isError ? DexterSurfaceColors.warning : foregroundColor)
                .lineSpacing(DexterTypography.chatLineSpacing)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
        }
    }

    private func codeBlockView(language: String?, code: String) -> some View {
        let trimmedCode = code.trimmingCharacters(in: .newlines)
        return VStack(alignment: .leading, spacing: DexterSpacing.xs) {
            HStack {
                if let language, !language.isEmpty {
                    Text(language.uppercased())
                        .font(DexterTypography.metadata())
                        .foregroundColor(DexterSurfaceColors.textMuted)
                }
                Spacer(minLength: 0)
                Button("Copy") {
                    DexterConversationClipboard.copy(trimmedCode)
                }
                .buttonStyle(.plain)
                .font(DexterTypography.metadata())
                .foregroundColor(DexterPastelColors.lavender)
                .pointerCursor()
            }
            ScrollView(.horizontal, showsIndicators: true) {
                Text(trimmedCode)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .textSelection(.enabled)
            }
        }
        .padding(DexterSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                .fill(DexterSurfaceColors.surface.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                .stroke(DexterSurfaceColors.border.opacity(0.6), lineWidth: 1)
        )
    }
}

enum DexterChatMarkdownAttributedStringBuilder {
    static func make(from prose: String) -> AttributedString? {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return try? AttributedString(markdown: prose, options: options)
    }
}

enum DexterChatMarkdownSegmentParser {
    static func parse(_ text: String) -> [DexterChatMarkdownSegment] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var segments: [DexterChatMarkdownSegment] = []
        var proseBuffer = ""
        var index = trimmed.startIndex

        while index < trimmed.endIndex {
            if trimmed[index...].hasPrefix("```") {
                if !proseBuffer.isEmpty {
                    segments.append(.prose(proseBuffer))
                    proseBuffer = ""
                }
                let fenceStart = index
                index = trimmed.index(index, offsetBy: 3)
                var languageLine = ""
                while index < trimmed.endIndex, trimmed[index] != "\n" {
                    languageLine.append(trimmed[index])
                    index = trimmed.index(after: index)
                }
                if index < trimmed.endIndex, trimmed[index] == "\n" {
                    index = trimmed.index(after: index)
                }
                let language = languageLine.trimmingCharacters(in: .whitespacesAndNewlines)
                var code = ""
                var closedFence = false
                while index < trimmed.endIndex {
                    if trimmed[index...].hasPrefix("```") {
                        segments.append(.codeBlock(language: language.isEmpty ? nil : language, code: code))
                        index = trimmed.index(index, offsetBy: 3)
                        closedFence = true
                        break
                    }
                    code.append(trimmed[index])
                    index = trimmed.index(after: index)
                }
                if !closedFence {
                    proseBuffer = String(trimmed[fenceStart...])
                    break
                }
            } else {
                proseBuffer.append(trimmed[index])
                index = trimmed.index(after: index)
            }
        }

        if !proseBuffer.isEmpty {
            segments.append(.prose(proseBuffer))
        }
        return segments
    }
}
