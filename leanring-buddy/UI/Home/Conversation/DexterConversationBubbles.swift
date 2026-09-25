//
//  DexterConversationBubbles.swift
//  leanring-buddy
//

import AppKit
import SwiftUI

struct DexterMessageBubble: View {
    let text: String
    var isError: Bool = false
    var showsTail: Bool = true
    var maxWidth: CGFloat
    var sanitizesVisionPayload: Bool = true

    private var displayText: String {
        guard sanitizesVisionPayload else { return text }
        return DexterVisionObservationParser.userFacingChatDisplayText(from: text)
    }

    var body: some View {
        DexterChatMarkdownText(text: displayText, isError: isError)
            .padding(.horizontal, DexterMessageMetrics.horizontalPadding)
            .padding(.vertical, DexterMessageMetrics.verticalPadding)
            .background(assistantBubbleBackground)
            .overlay(assistantBubbleBorder)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .bottomLeading) {
                if showsTail {
                    DexterBubbleTail(corner: .bottomLeading)
                        .fill(assistantFillColor)
                        .frame(width: DexterMessageMetrics.tailSize, height: DexterMessageMetrics.tailSize)
                        .offset(x: 10, y: 4)
                }
            }
    }

    private var assistantFillColor: Color {
        if isError {
            return DexterSurfaceColors.warning.opacity(0.12)
        }
        return DexterSurfaceColors.surfaceElevated.opacity(0.88)
    }

    private var assistantBubbleBackground: some View {
        RoundedRectangle(cornerRadius: DexterRadii.messageBubble, style: .continuous)
            .fill(assistantFillColor)
    }

    private var assistantBubbleBorder: some View {
        RoundedRectangle(cornerRadius: DexterRadii.messageBubble, style: .continuous)
            .stroke(
                isError ? DexterSurfaceColors.warning.opacity(0.35) : DexterSurfaceColors.border.opacity(0.55),
                lineWidth: 1
            )
    }
}

struct UserMessageBubble: View {
    let text: String
    var isError: Bool = false
    var showsTail: Bool = true
    var accentColor: Color
    var maxWidth: CGFloat

    var body: some View {
        Text(text)
            .font(DexterTypography.messageCompact())
            .foregroundColor(isError ? DexterSurfaceColors.error : DexterSurfaceColors.textPrimary)
            .lineSpacing(DexterTypography.messageCompactLineSpacing)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .padding(.horizontal, DexterMessageMetrics.horizontalPadding)
            .padding(.vertical, DexterMessageMetrics.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.messageBubble, style: .continuous)
                    .fill(userFillColor)
            )
            .frame(maxWidth: maxWidth, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(
                RoundedRectangle(cornerRadius: DexterRadii.messageBubble, style: .continuous)
                    .stroke(userBorderColor, lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if showsTail {
                    DexterBubbleTail(corner: .bottomTrailing)
                        .fill(userFillColor)
                        .frame(width: DexterMessageMetrics.tailSize, height: DexterMessageMetrics.tailSize)
                        .offset(x: -10, y: 4)
                }
            }
    }

    private var userFillColor: Color {
        if isError {
            return DexterSurfaceColors.error.opacity(0.12)
        }
        return DexterPastelColors.lavender.opacity(0.28)
    }

    private var userBorderColor: Color {
        if isError {
            return DexterSurfaceColors.error.opacity(0.3)
        }
        return DexterPastelColors.lavender.opacity(0.45)
    }
}

private struct DexterBubbleTail: Shape {
    enum Corner {
        case bottomLeading
        case bottomTrailing
    }

    let corner: Corner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch corner {
        case .bottomLeading:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .bottomTrailing:
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        return path
    }
}

enum DexterConversationClipboard {
    static func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
