//
//  DexterIntegrationBrandCatalog.swift
//  leanring-buddy
//

import Foundation

/// Maps integrations to macOS app bundle IDs, asset catalog names, or website hosts for favicons.
enum DexterIntegrationBrandCatalog {
    struct Brand: Equatable {
        var bundleIdentifiers: [String] = []
        var assetCatalogName: String?
        var websiteHost: String?
        var systemSymbolName: String?
        var monogram: String?

        static func monogram(from name: String) -> Brand {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let letter = trimmed.first.map { String($0).uppercased() } ?? "?"
            return Brand(monogram: letter)
        }
    }

    static func brand(for integration: DexterIntegration) -> Brand {
        if let builtIn = builtInBrandByIntegrationID[integration.id] {
            return builtIn
        }

        if integration.id.hasPrefix("custom-") {
            return brandForCustomConnector(named: integration.name)
        }

        if integration.id.hasPrefix("discovery-") {
            if let host = websiteHostByServiceName[integration.name] {
                return Brand(websiteHost: host)
            }
            return Brand.monogram(from: integration.name)
        }

        if let host = websiteHostByServiceName[integration.name] {
            return Brand(websiteHost: host)
        }

        return Brand.monogram(from: integration.name)
    }

    private static func brandForCustomConnector(named connectorName: String) -> Brand {
        let trimmed = connectorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let host = url.host, !host.isEmpty {
            return Brand(websiteHost: host)
        }
        if trimmed.contains("."), !trimmed.contains(" ") {
            let hostCandidate = trimmed
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .split(separator: "/")
                .first
                .map(String.init)
            if let hostCandidate, hostCandidate.contains(".") {
                return Brand(websiteHost: hostCandidate)
            }
        }
        return Brand(systemSymbolName: "cable.connector", monogram: String(trimmed.prefix(1)).uppercased())
    }

    private static let builtInBrandByIntegrationID: [String: Brand] = [
        "vscode": Brand(bundleIdentifiers: ["com.microsoft.VSCode"]),
        "terminal": Brand(bundleIdentifiers: [
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable",
            "com.apple.Terminal"
        ]),
        "browser": Brand(bundleIdentifiers: [
            "company.thebrowser.Browser",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.brave.Browser",
            "com.apple.Safari"
        ]),
        "github": Brand(websiteHost: "github.com"),
        "openclaw-gateway": Brand(websiteHost: "openclaw.ai", systemSymbolName: "cpu")
    ]

    /// Hosts for discovery reference rows (and name-based lookups).
    static let websiteHostByServiceName: [String: String] = [
        "Notion": "notion.so",
        "Linear": "linear.app",
        "Google Docs": "docs.google.com",
        "Google Calendar": "calendar.google.com",
        "LinkedIn": "linkedin.com",
        "Slack": "slack.com",
        "Gmail": "gmail.com",
        "Google Sheets": "sheets.google.com",
        "Google Drive": "drive.google.com",
        "Obsidian": "obsidian.md",
        "Airtable": "airtable.com",
        "Apaleo": "apaleo.com",
        "Asana": "asana.com",
        "Attio": "attio.com",
        "Basecamp": "basecamp.com",
        "Box": "box.com",
        "Cal.com": "cal.com",
        "Calendly": "calendly.com",
        "Canva": "canva.com",
        "Capsule CRM": "capsulecrm.com",
        "ClickUp": "clickup.com",
        "Confluence": "atlassian.com",
        "Contentful": "contentful.com",
        "CrowdIn": "crowdin.com",
        "Dart": "dart.dev",
        "Daytona": "daytona.io",
        "Dialpad": "dialpad.com",
        "Discord": "discord.com",
        "Discord Bot": "discord.com",
        "Dropbox": "dropbox.com",
        "Google Analytics": "analytics.google.com",
        "Google BigQuery": "cloud.google.com",
        "Google Classroom": "classroom.google.com",
        "Google Maps": "maps.google.com",
        "Google Meet": "meet.google.com",
        "Google Photos": "photos.google.com",
        "Google Search Console": "search.google.com",
        "Google Slides": "slides.google.com",
        "Google Tasks": "tasks.google.com",
        "Gorgias": "gorgias.com",
        "Greenhouse": "greenhouse.io",
        "Gumroad": "gumroad.com",
        "Harvest": "getharvest.com",
        "HubSpot": "hubspot.com",
        "Hugging Face": "huggingface.co",
        "Instagram": "instagram.com",
        "Intercom": "intercom.com",
        "Jira": "atlassian.com",
        "Kit": "kit.com",
        "Linkhut": "linkhut.io",
        "Miro": "miro.com",
        "Monday": "monday.com",
        "Moneybird": "moneybird.com",
        "Mural": "mural.co",
        "NotebookLM": "notebooklm.google.com",
        "Omnisend": "omnisend.com",
        "OneDrive": "onedrive.live.com",
        "Outlook": "outlook.com",
        "PagerDuty": "pagerduty.com",
        "Pinterest": "pinterest.com",
        "Pinterest Ads": "pinterest.com",
        "Prisma": "prisma.io",
        "Productboard": "productboard.com",
        "Pushbullet": "pushbullet.com",
        "QuickBooks": "quickbooks.intuit.com",
        "Reddit": "reddit.com",
        "Reddit Ads": "reddit.com",
        "Roam": "roamresearch.com",
        "Salesforce": "salesforce.com",
        "Sentry": "sentry.io",
        "Service8": "service8.com",
        "SharePoint": "sharepoint.com",
        "Shippo": "goshippo.com",
        "Slackbot": "slack.com",
        "Splitwise": "splitwise.com",
        "Square": "squareup.com",
        "Stack Exchange": "stackexchange.com",
        "Stripe": "stripe.com",
        "Timely": "timelyapp.com",
        "Todoist": "todoist.com",
        "Trello": "trello.com",
        "Twitch": "twitch.tv",
        "Typeform": "typeform.com",
        "WakaTime": "wakatime.com",
        "Webex": "webex.com",
        "WhatsApp": "whatsapp.com",
        "Wrike": "wrike.com",
        "Yandex": "yandex.com",
        "YNAB": "ynab.com",
        "YouTube": "youtube.com",
        "Zendesk": "zendesk.com",
        "Zeplin": "zeplin.io",
        "Zoho": "zoho.com",
        "Zoho Bigin": "bigin.zoho.com",
        "Zoho Books": "books.zoho.com",
        "Zoho Desk": "desk.zoho.com",
        "Zoho Inventory": "inventory.zoho.com",
        "Zoho Invoice": "invoice.zoho.com",
        "Zoho Mail": "mail.zoho.com",
        "Zoom": "zoom.us",
        "Visual Studio Code": "code.visualstudio.com",
        "Terminal": "apple.com",
        "Browser": "google.com",
        "GitHub": "github.com",
        "OpenClaw Gateway": "openclaw.ai"
    ]
}
