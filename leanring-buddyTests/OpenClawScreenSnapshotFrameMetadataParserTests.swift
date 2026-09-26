//
//  OpenClawScreenSnapshotFrameMetadataParserTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct OpenClawScreenSnapshotFrameMetadataParserTests {
    @Test func parsesTopLevelFrameMetadata() {
        let output = """
        {"displayFrameId":"frame-123","width":1920,"observationId":"obs-9"}
        """
        let metadata = OpenClawScreenSnapshotFrameMetadataParser.parse(from: output)
        #expect(metadata?.displayFrameId == "frame-123")
        #expect(metadata?.refWidth == 1920)
        #expect(metadata?.observationId == "obs-9")
    }

    @Test func parsesNestedResultFrameMetadata() {
        let output = """
        {"ok":true,"result":{"frameId":"frame-abc","refWidth":1280}}
        """
        let metadata = OpenClawScreenSnapshotFrameMetadataParser.parse(from: output)
        #expect(metadata?.frameId == "frame-abc")
        #expect(metadata?.displayFrameId == "frame-abc")
        #expect(metadata?.refWidth == 1280)
    }
}
