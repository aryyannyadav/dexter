//
//  DexterTeachingOverlay.swift
//  leanring-buddy
//

import SwiftUI

/// Full-screen teaching annotation layer for one display (embedded in `BlueCursorView`).
struct DexterTeachingOverlay: View {
    let session: DexterTeachingOverlaySession
    let screenFrame: CGRect

    @State private var annotationOpacities: [UUID: Double] = [:]

    var body: some View {
        ZStack {
            ForEach(session.annotations) { annotation in
                DexterAnnotationRenderer(
                    annotation: annotation,
                    renderedOpacity: annotationOpacities[annotation.id] ?? 0
                )
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .allowsHitTesting(false)
        .onAppear {
            animateAnnotationsIn()
        }
        .onChange(of: session.id) { _, _ in
            animateAnnotationsIn()
        }
        .onDisappear {
            animateAnnotationsOut()
        }
    }

    private func animateAnnotationsIn() {
        for annotation in session.annotations {
            annotationOpacities[annotation.id] = 0
        }
        withAnimation(DexterAnimation.gentleEase) {
            for annotation in session.annotations {
                annotationOpacities[annotation.id] = annotation.targetOpacity
            }
        }
    }

    private func animateAnnotationsOut() {
        withAnimation(DexterAnimation.gentleEase) {
            for annotation in session.annotations {
                annotationOpacities[annotation.id] = 0
            }
        }
    }
}
