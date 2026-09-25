//
//  DexterIntegrationBrandCatalogTests.swift
//  leanring-buddyTests
//

import XCTest
@testable import leanring_buddy

final class DexterIntegrationBrandCatalogTests: XCTestCase {
    func testBuiltInGitHubUsesWebsiteHost() {
        let integration = DexterIntegration(
            id: "github",
            name: "GitHub",
            kind: .operational,
            connectionState: .notConnected
        )
        let brand = DexterIntegrationBrandCatalog.brand(for: integration)
        XCTAssertEqual(brand.websiteHost, "github.com")
    }

    func testDiscoveryReferenceMapsServiceNameToHost() {
        let integration = DexterIntegration(
            id: "discovery-notion",
            name: "Notion",
            kind: .discoveryReference,
            connectionState: .unsupported
        )
        let brand = DexterIntegrationBrandCatalog.brand(for: integration)
        XCTAssertEqual(brand.websiteHost, "notion.so")
    }

    func testVSCodeUsesBundleIdentifier() {
        let integration = DexterIntegration(
            id: "vscode",
            name: "Visual Studio Code",
            kind: .operational,
            connectionState: .notConnected
        )
        let brand = DexterIntegrationBrandCatalog.brand(for: integration)
        XCTAssertEqual(brand.bundleIdentifiers, ["com.microsoft.VSCode"])
    }
}
