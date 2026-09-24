//
//  DexterPointerSemanticTargetResolver.swift
//  leanring-buddy
//

import Foundation

/// Fuses Accessibility, application metadata, OCR, and local vision into one semantic target.
enum DexterPointerSemanticTargetResolver {
    static func resolve(
        accessibilityHint: DexterAccessibilityHintAtPointer,
        activeApplication: DexterActiveApplicationContext?,
        activeWindow: DexterActiveWindowContext?,
        ocrResult: DexterPointerOCRAnalysisResult,
        visionResult: DexterPointerVisionAnalysisResult,
        elementLocationCorroboratesPointer: Bool = false
    ) -> DexterPointerSemanticTarget {
        var evidence: [DexterPointerEvidenceContribution] = []
        var confidence: Double = 0

        let accessibilityTitle = normalized(accessibilityHint.title)
        let accessibilityRole = normalized(accessibilityHint.roleDescription)
        let accessibilityValue = normalized(accessibilityHint.valueDescription)

        if accessibilityHint.availability == .available {
            if let accessibilityTitle {
                evidence.append(
                    DexterPointerEvidenceContribution(
                        source: .accessibility,
                        detail: "title: \(accessibilityTitle)",
                        weight: 0.42
                    )
                )
                confidence += 0.42
            }
            if let accessibilityRole {
                evidence.append(
                    DexterPointerEvidenceContribution(
                        source: .accessibility,
                        detail: "role: \(accessibilityRole)",
                        weight: 0.18
                    )
                )
                confidence += 0.18
            }
            if let accessibilityValue {
                evidence.append(
                    DexterPointerEvidenceContribution(
                        source: .accessibility,
                        detail: "value: \(accessibilityValue)",
                        weight: 0.12
                    )
                )
                confidence += 0.12
            }
        }

        let applicationContextLabel = applicationMetadataLabel(from: activeApplication)
        if let applicationContextLabel {
            evidence.append(
                DexterPointerEvidenceContribution(
                    source: .applicationMetadata,
                    detail: applicationContextLabel,
                    weight: 0.08
                )
            )
            confidence += 0.08
        }

        let windowContextLabel = windowMetadataLabel(from: activeWindow)
        if let windowContextLabel {
            evidence.append(
                DexterPointerEvidenceContribution(
                    source: .applicationMetadata,
                    detail: "window \(windowContextLabel)",
                    weight: 0.06
                )
            )
            confidence += 0.06
        }

        let ocrText = normalized(ocrResult.textAtPointer) ?? normalized(ocrResult.nearbyText)
        if ocrResult.availability == .available, let ocrText {
            evidence.append(
                DexterPointerEvidenceContribution(
                    source: .ocr,
                    detail: ocrText,
                    weight: 0.22
                )
            )
            confidence += accessibilityTitle == nil ? 0.22 : 0.12
        }

        var visionAppearanceHint: String?
        if visionResult.availability == .available {
            if let appearanceDescription = normalized(visionResult.appearanceDescription) {
                visionAppearanceHint = appearanceDescription
                evidence.append(
                    DexterPointerEvidenceContribution(
                        source: .vision,
                        detail: appearanceDescription,
                        weight: 0.1
                    )
                )
                confidence += 0.1
            } else if visionResult.isPredominantlyRed {
                visionAppearanceHint = "predominantly red at pointer"
                evidence.append(
                    DexterPointerEvidenceContribution(
                        source: .vision,
                        detail: visionAppearanceHint!,
                        weight: 0.1
                    )
                )
                confidence += 0.1
            }
        }

        if let elementEvidence = DexterPointerElementLocationCorroboration.visionEvidenceContribution(
            isCorroborated: elementLocationCorroboratesPointer
        ) {
            evidence.append(elementEvidence)
            confidence += elementEvidence.weight
        }

        let primaryLabel = primaryLabel(
            accessibilityTitle: accessibilityTitle,
            accessibilityRole: accessibilityRole,
            ocrText: ocrText,
            visionHint: visionAppearanceHint
        )

        return DexterPointerSemanticTarget(
            primaryLabel: primaryLabel,
            roleDescription: accessibilityRole,
            valueDescription: accessibilityValue,
            applicationContextLabel: applicationContextLabel,
            windowContextLabel: windowContextLabel,
            ocrTextNearPointer: ocrText,
            visionAppearanceHint: visionAppearanceHint,
            evidence: evidence,
            confidence: min(confidence, 1.0)
        )
    }

    private static func primaryLabel(
        accessibilityTitle: String?,
        accessibilityRole: String?,
        ocrText: String?,
        visionHint: String?
    ) -> String {
        if let accessibilityTitle {
            return accessibilityTitle
        }
        if let ocrText {
            return ocrText
        }
        if let accessibilityRole {
            return accessibilityRole
        }
        if let visionHint {
            return visionHint
        }
        return "UI element at pointer"
    }

    private static func applicationMetadataLabel(from application: DexterActiveApplicationContext?) -> String? {
        guard let application, application.availability == .available else { return nil }
        if let localizedName = normalized(application.localizedName) {
            if let bundleIdentifier = normalized(application.bundleIdentifier) {
                return "\(localizedName) (\(bundleIdentifier))"
            }
            return localizedName
        }
        return normalized(application.bundleIdentifier)
    }

    private static func windowMetadataLabel(from window: DexterActiveWindowContext?) -> String? {
        guard let window, window.availability == .available else { return nil }
        return normalized(window.title)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
