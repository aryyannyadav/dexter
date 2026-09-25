//
//  DexterSettingsRouter.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterSettingsRouter: ObservableObject {
    @Published var selectedPage: DexterSettingsPage
    @Published private(set) var showsBackNavigation: Bool = false

    init(initialPage: DexterSettingsPage = .general) {
        self.selectedPage = initialPage
    }

    func open(page: DexterSettingsPage) {
        selectedPage = page
        showsBackNavigation = false
    }

    func requestBackNavigation() {
        showsBackNavigation = true
    }
}
