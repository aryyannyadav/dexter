//
//  DexterOpenApplicationIntentParserTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct DexterOpenApplicationIntentParserTests {
    @Test func recognizesOpenCalculator() {
        #expect(DexterOpenApplicationIntentParser.applicationName(from: "open calculator") == "Calculator")
    }

    @Test func recognizesOpenWhatsApp() {
        #expect(DexterOpenApplicationIntentParser.applicationName(from: "open whatsapp") == "Whatsapp")
    }

    @Test func doesNotTreatHelloAsOpenIntent() {
        #expect(DexterOpenApplicationIntentParser.applicationName(from: "hello") == nil)
    }
}
