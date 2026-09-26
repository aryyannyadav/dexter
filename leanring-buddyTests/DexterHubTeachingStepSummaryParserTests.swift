import Testing
@testable import leanring_buddy

@Suite("DexterHubTeachingStepSummaryParser")
struct DexterHubTeachingStepSummaryParserTests {
    @Test("parses numbered lesson steps for Hub preview")
    func parsesNumberedLessonSteps() {
        let text = """
        Here is the plan:
        1. Click Settings
        2. Open Privacy & Security
        Step 3: Enable Screen Recording
        """
        let previews = DexterHubTeachingStepSummaryParser.parseStepPreviews(from: text)
        #expect(previews.count == 3)
        #expect(previews[0].index == 1)
        #expect(previews[0].label == "Click Settings")
        #expect(previews[1].label.contains("Privacy"))
    }
}
