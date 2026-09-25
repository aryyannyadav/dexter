//
//  DexterProfileWorkspaceTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterProfileWorkspaceTests {
    @Test func seedProfilesIncludeCuratedExamples() {
        let profiles = DexterProfileSeedFactory.seedProfiles()
        #expect(profiles.count == 4)
        #expect(profiles.contains { $0.name == "Study Buddy" })
        #expect(profiles.contains { $0.name == "Builder" })
        #expect(profiles.contains { $0.name == "Researcher" })
        #expect(profiles.contains { $0.name == "Personal" })
    }

    @Test func greetingFormatterUsesName() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 24
        components.hour = 14
        _ = calendar.date(from: components)!
        let greeting = DexterHomeGreetingFormatter.greeting(firstName: "Aryan", calendar: calendar)
        #expect(greeting.contains("Aryan"))
    }
}
