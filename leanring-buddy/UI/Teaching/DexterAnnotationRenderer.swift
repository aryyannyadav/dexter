//
//  DexterAnnotationRenderer.swift
//  leanring-buddy
//

import SwiftUI

struct DexterAnnotationRenderer: View {
    let annotation: DexterAnnotation
    var renderedOpacity: Double

    private let accent = DexterPastelColors.sky
    private let highlightFill = DexterPastelColors.lavender.opacity(0.18)
    private let ringStroke = DexterPastelColors.sky.opacity(0.92)

    var body: some View {
        Group {
            switch annotation.kind {
            case .arrow:
                arrowShape
            case .circle:
                circleShape
            case .rectangle:
                rectangleShape
            case .highlight:
                highlightShape
            case .targetRing:
                targetRingShape
            case .pointer:
                pointerShape
            case .textLabel:
                labelShape
            case .stepNumber:
                stepBadge
            }
        }
        .opacity(renderedOpacity)
        .animation(DexterAnimation.gentleEase, value: renderedOpacity)
    }

    private var arrowShape: some View {
        let endPoint = CGPoint(
            x: annotation.center.x + annotation.size.width,
            y: annotation.center.y + annotation.size.height
        )
        return Path { path in
            path.move(to: annotation.center)
            path.addLine(to: endPoint)
        }
        .stroke(accent.opacity(0.92), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .overlay(
            DexterArrowHead()
                .fill(accent)
                .frame(width: 12, height: 12)
                .position(endPoint)
        )
    }

    private var circleShape: some View {
        Circle()
            .stroke(ringStroke, lineWidth: 1.5)
            .frame(width: annotation.size.width, height: annotation.size.height)
            .position(annotation.center)
    }

    private var rectangleShape: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(ringStroke, lineWidth: 2)
            .frame(width: annotation.size.width, height: annotation.size.height)
            .position(annotation.center)
    }

    private var highlightShape: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(highlightFill)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accent.opacity(0.35), lineWidth: 1)
            )
            .frame(width: annotation.size.width, height: annotation.size.height)
            .position(annotation.center)
    }

    private var targetRingShape: some View {
        ZStack {
            Circle()
                .stroke(DexterColors.glowBlue.opacity(0.22), lineWidth: 5)
                .frame(width: annotation.size.width + 10, height: annotation.size.height + 10)
            Circle()
                .stroke(ringStroke, lineWidth: 2)
                .frame(width: annotation.size.width, height: annotation.size.height)
        }
        .position(annotation.center)
    }

    private var pointerShape: some View {
        Circle()
            .fill(accent)
            .frame(width: annotation.size.width, height: annotation.size.height)
            .shadow(color: DexterPastelColors.lavender.opacity(0.55), radius: 6)
            .position(annotation.center)
    }

    private var labelShape: some View {
        Text(annotation.text ?? "")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DexterColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DexterColors.cardBackgroundElevated.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(DexterPastelColors.lavender.opacity(0.45), lineWidth: 1)
                    )
            )
            .position(annotation.center)
    }

    private var stepBadge: some View {
        ZStack {
            Circle()
                .fill(DexterPastelColors.sky.opacity(0.22))
            Circle()
                .stroke(accent, lineWidth: 1.5)
            Text("\(annotation.stepNumber ?? 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(accent)
        }
        .frame(width: 28, height: 28)
        .position(annotation.center)
    }
}

private struct DexterArrowHead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
