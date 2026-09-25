//
//  DexterTypography.swift
//  leanring-buddy
//

import SwiftUI

enum DexterTypography {
    /// Large marketing / home hero (rare).
    static func display() -> Font {
        .system(size: 28, weight: .semibold, design: .default)
    }

    /// Home dashboard hero greeting.
    static func hero() -> Font {
        .system(size: 32, weight: .semibold, design: .rounded)
    }

    /// “Your Dexters” and major section headings.
    static func sectionTitle() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }

    /// Card titles on home / suggestions.
    static func cardTitle() -> Font {
        .system(size: 16, weight: .semibold, design: .default)
    }

    /// Micro labels (badges, tiny metadata).
    static func micro() -> Font {
        .system(size: 9, weight: .semibold, design: .rounded)
    }

    /// Window / chat header title.
    static func headline() -> Font {
        .system(size: 15, weight: .semibold, design: .default)
    }

    /// Page titles (Settings, Home sections).
    static func title() -> Font {
        .system(size: 22, weight: .semibold, design: .default)
    }

    /// Section headers, card titles.
    static func section() -> Font {
        .system(size: 11, weight: .semibold, design: .default)
    }

    /// Primary reading text.
    static func body() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    /// Home chat message body — slightly larger for comfortable reading.
    static func chatBody() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    /// Compact bubble copy (reference messaging density).
    static func messageCompact() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }

    static let chatLineSpacing: CGFloat = 5
    static let messageCompactLineSpacing: CGFloat = 4

    /// Sidebar row secondary line, timestamps.
    static func metadata() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }

    static func bodyMedium() -> Font {
        .system(size: 13, weight: .medium, design: .default)
    }

    /// Descriptions, helper copy.
    static func secondary() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }

    /// Timestamps, footnotes.
    static func caption() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }

    /// SCREEN CONTEXT READY · QWEN3.5:9B · THINKING
    static func status() -> Font {
        .system(size: 10, weight: .semibold, design: .monospaced)
    }

    static func statusLarge() -> Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }

    /// Numeric / technical readouts.
    static func monospacedCaption() -> Font {
        .system(size: 10, weight: .medium, design: .monospaced)
    }
}
