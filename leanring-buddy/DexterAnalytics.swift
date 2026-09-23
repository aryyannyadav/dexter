//
//  DexterAnalytics.swift
//  leanring-buddy
//
//  Centralized PostHog analytics wrapper. All event names and properties
//  are defined here so instrumentation is consistent and easy to audit.
//

import Foundation
import PostHog

enum DexterAnalytics {

    // MARK: - Setup

    static func configure() {
        guard let projectAPIKey = AppBundleConfiguration.stringValue(forKey: "PostHogProjectAPIKey") else {
            return
        }
        let analyticsHost = AppBundleConfiguration.stringValue(forKey: "PostHogHost")
            ?? "https://us.i.posthog.com"
        let config = PostHogConfig(apiKey: projectAPIKey, host: analyticsHost)
        PostHogSDK.shared.setup(config)
    }

    // MARK: - App Lifecycle

    static func trackAppOpened() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        PostHogSDK.shared.capture("app_opened", properties: [
            "app_version": version
        ])
    }

    // MARK: - Onboarding

    static func trackOnboardingStarted() {
        PostHogSDK.shared.capture("onboarding_started")
    }

    static func trackOnboardingReplayed() {
        PostHogSDK.shared.capture("onboarding_replayed")
    }

    static func trackOnboardingVideoCompleted() {
        PostHogSDK.shared.capture("onboarding_video_completed")
    }

    static func trackOnboardingDemoTriggered() {
        PostHogSDK.shared.capture("onboarding_demo_triggered")
    }

    // MARK: - Permissions

    static func trackAllPermissionsGranted() {
        PostHogSDK.shared.capture("all_permissions_granted")
    }

    static func trackPermissionGranted(permission: String) {
        PostHogSDK.shared.capture("permission_granted", properties: [
            "permission": permission
        ])
    }

    // MARK: - Voice Interaction

    static func trackPushToTalkStarted() {
        PostHogSDK.shared.capture("push_to_talk_started")
    }

    static func trackPushToTalkReleased() {
        PostHogSDK.shared.capture("push_to_talk_released")
    }

    static func trackUserMessageSent(transcript: String) {
        PostHogSDK.shared.capture("user_message_sent", properties: [
            "character_count": transcript.count
        ])
    }

    static func trackAIResponseReceived(response: String) {
        PostHogSDK.shared.capture("ai_response_received", properties: [
            "character_count": response.count
        ])
    }

    static func trackElementPointed(elementLabel: String?) {
        PostHogSDK.shared.capture("element_pointed", properties: [
            "element_label": elementLabel ?? "unknown"
        ])
    }

    // MARK: - Errors

    static func trackResponseError(error: String) {
        PostHogSDK.shared.capture("response_error", properties: [
            "error_length": error.count
        ])
    }

    static func trackTTSError(error: String) {
        PostHogSDK.shared.capture("tts_error", properties: [
            "error_length": error.count
        ])
    }
}
