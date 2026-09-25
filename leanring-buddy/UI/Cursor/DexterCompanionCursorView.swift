//
//  DexterCompanionCursorView.swift
//  leanring-buddy
//

import SwiftUI

/// Shared overlay + Settings preview cursor glyph (classic triangle or character artwork).
struct DexterCompanionCursorView: View {
    enum PresentationContext {
        case overlay
        case settingsPreview
    }

    let style: DexterCursorStyleOption
    let accentColor: Color
    let rotationDegrees: Double
    let flightScale: CGFloat
    var showsAccentGlow: Bool = true
    var presentationContext: PresentationContext = .overlay

    @State private var intrinsicImageSize: CGSize = .zero

    var body: some View {
        Group {
            if style == .classic {
                classicTriangleBody
            } else {
                characterArtworkBody
            }
        }
        .scaleEffect(flightScale)
        .animation(.easeInOut(duration: DexterAnimation.standard), value: style)
        .onAppear {
            refreshIntrinsicImageSize()
        }
        .onChange(of: style) { _, _ in
            refreshIntrinsicImageSize()
        }
    }

    private var classicTriangleBody: some View {
        Triangle()
            .fill(accentColor)
            .frame(
                width: DexterCompanionCursorMetrics.classicTriangleDrawSize,
                height: DexterCompanionCursorMetrics.classicTriangleDrawSize
            )
            .rotationEffect(.degrees(rotationDegrees))
            .shadow(
                color: showsAccentGlow ? accentColor : .clear,
                radius: showsAccentGlow ? 8 + (flightScale - 1.0) * 20 : 0,
                x: 0,
                y: 0
            )
    }

    @ViewBuilder
    private var characterArtworkBody: some View {
        if let assetImageName = style.layoutSpec.assetImageName {
            if DexterCompanionCursorAssets.isCharacterArtworkAvailable(for: style) {
                switch presentationContext {
                case .settingsPreview:
                    settingsPreviewCharacterImage(assetImageName: assetImageName)
                case .overlay:
                    overlayCharacterImage(assetImageName: assetImageName)
                }
            } else {
                DexterCompanionCursorMissingAssetLabel(
                    assetImageName: assetImageName,
                    isCompact: presentationContext == .overlay
                )
            }
        }
    }

    private func settingsPreviewCharacterImage(assetImageName: String) -> some View {
        Image(assetImageName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(
                maxWidth: DexterCompanionCursorAssets.previewMaximumBounds,
                maxHeight: DexterCompanionCursorAssets.previewMaximumBounds
            )
    }

    private func overlayCharacterImage(assetImageName: String) -> some View {
        let layout = DexterCompanionCursorLayout.layout(
            for: style,
            intrinsicImageSize: intrinsicImageSize
        )

        return ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: layout.footprintSize.width, height: layout.footprintSize.height)

            Image(assetImageName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: layout.drawSize.width, height: layout.drawSize.height)
                .offset(
                    x: layout.imageTopLeadingOffset.width,
                    y: layout.imageTopLeadingOffset.height
                )
                .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
        }
        .frame(width: layout.footprintSize.width, height: layout.footprintSize.height)
    }

    private func refreshIntrinsicImageSize() {
        if let assetImageName = style.layoutSpec.assetImageName,
           let size = DexterCompanionCursorAssets.intrinsicImageSizeInPoints(for: assetImageName) {
            intrinsicImageSize = size
        } else if let assetImageName = style.layoutSpec.assetImageName {
            intrinsicImageSize = .zero
            DexterCompanionCursorAssets.reportMissingAssetIfNeeded(assetImageName)
        }
    }
}

private struct DexterCompanionCursorMissingAssetLabel: View {
    let assetImageName: String
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("Missing asset")
                .font(.system(size: isCompact ? 7 : 9, weight: .semibold))
                .foregroundColor(DexterColors.error)
            Text(assetImageName)
                .font(.system(size: isCompact ? 6 : 8, weight: .medium, design: .monospaced))
                .foregroundColor(DexterColors.textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(isCompact ? 2 : 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(DexterColors.error.opacity(0.55), lineWidth: 1)
        )
        .onAppear {
            DexterCompanionCursorAssets.reportMissingAssetIfNeeded(assetImageName)
        }
    }
}
