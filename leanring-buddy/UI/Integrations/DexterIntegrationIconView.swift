//
//  DexterIntegrationIconView.swift
//  leanring-buddy
//

import AppKit
import SwiftUI

struct DexterIntegrationIconView: View {
    let integration: DexterIntegration
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 6

    @State private var faviconImage: NSImage?

    private var brand: DexterIntegrationBrandCatalog.Brand {
        DexterIntegrationBrandCatalog.brand(for: integration)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DexterSettingsColors.searchFieldFill)

            iconContent
                .padding(size * 0.12)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(DexterSurfaceColors.border.opacity(0.35), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
        .task(id: faviconTaskIdentifier) {
            await loadFaviconIfNeeded()
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        if let bundleImage = workspaceIconImage(forBundleIdentifiers: brand.bundleIdentifiers) {
            imageView(bundleImage)
        } else if let assetName = brand.assetCatalogName,
                  let assetImage = NSImage(named: assetName) {
            imageView(assetImage)
        } else if let faviconImage {
            imageView(faviconImage)
        } else if let systemSymbolName = brand.systemSymbolName {
            Image(systemName: systemSymbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text(fallbackMonogram)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    private func imageView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var faviconTaskIdentifier: String {
        brand.websiteHost ?? integration.id
    }

    private var fallbackMonogram: String {
        if let monogram = brand.monogram, !monogram.isEmpty {
            return monogram
        }
        return String(integration.name.prefix(1)).uppercased()
    }

    private func workspaceIconImage(forBundleIdentifiers bundleIdentifiers: [String]) -> NSImage? {
        for bundleIdentifier in bundleIdentifiers {
            if let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                return NSWorkspace.shared.icon(forFile: applicationURL.path)
            }
        }
        return nil
    }

    private func loadFaviconIfNeeded() async {
        guard brand.bundleIdentifiers.isEmpty,
              brand.assetCatalogName == nil,
              let websiteHost = brand.websiteHost else {
            return
        }
        let loaded = await DexterIntegrationFaviconLoader.shared.faviconImage(forWebsiteHost: websiteHost)
        await MainActor.run {
            faviconImage = loaded
        }
    }
}
