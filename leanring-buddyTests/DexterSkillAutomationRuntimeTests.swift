//
//  DexterSkillAutomationRuntimeTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterSkillAutomationRuntimeTests {
    @Test func canonicalPipelineMatchesSkillToMemoryFlow() {
        let phases = DexterSkillAutomationRuntime.canonicalPipelinePhases
        #expect(phases.first == .skill)
        #expect(phases.contains(.trigger))
        #expect(phases.contains(.toolGateway))
        #expect(phases.last == .memory)
    }

    @Test func envelopeCarriesGoalAndLimits() {
        let envelope = DexterAutomationEnvelope.forManualTurn(
            userMessage: "open Safari",
            skill: DexterSkillCatalog.skill(forIdentifier: .browserResearch)
        )
        #expect(envelope.goal.contains("open Safari"))
        #expect(envelope.actionLimit >= 1)
        #expect(!envelope.stopConditions.isEmpty)
    }

    @Test func proactivePlanDoesNotExecuteWhenAutomationDisabled() {
        let event = DexterProactiveEvent(
            kind: .newFile,
            title: "notes.md",
            detail: "New file."
        )
        let request = DexterSkillAutomationRuntime.buildProactiveRequest(
            event: event,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "proactive")),
            automationRegistration: DexterProactiveAutomationRegistration(eventKind: .newFile),
            userGrantedAutonomousExecution: false
        )
        let plan = DexterSkillAutomationRuntime.plan(request: request)
        #expect(!plan.shouldExecuteAction)
        #expect(plan.proactivePolicyDecision?.mode == .suggest)
    }

    @Test func triggerKindsCoverManualScheduledEventAndContext() {
        #expect(DexterAutomationTrigger.manualInvocation(userMessage: "hi").kind == .manualInvocation)
        #expect(DexterAutomationTrigger.scheduled(description: "every weekday 9am").kind == .scheduled)
        #expect(DexterAutomationTrigger.context(conditionDescription: "vscode active").kind == .context)
        let event = DexterProactiveEvent(kind: .calendarEvent, title: "Standup", detail: "Soon")
        #expect(DexterAutomationTrigger.event(event).kind == .event)
    }

    @Test func proactivePhasesMapOntoLegacyProactivePipeline() {
        let mapped = DexterSkillAutomationRuntime.proactivePhases(
            from: [.trigger, .context, .policy, .plan, .execute, .verify]
        )
        #expect(mapped.contains(.event))
        #expect(mapped.contains(.verification))
    }
}
