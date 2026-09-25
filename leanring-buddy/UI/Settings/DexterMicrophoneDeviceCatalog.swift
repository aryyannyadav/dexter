//
//  DexterMicrophoneDeviceCatalog.swift
//  leanring-buddy
//

import AVFoundation
import Combine
import Foundation

struct DexterMicrophoneInputDevice: Identifiable, Equatable {
    let id: String
    let displayName: String
}

enum DexterMicrophoneDeviceCatalog {
    static func availableInputDevices() -> [DexterMicrophoneInputDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discoverySession.devices.map { device in
            DexterMicrophoneInputDevice(id: device.uniqueID, displayName: device.localizedName)
        }
    }
}

@MainActor
final class DexterMicrophoneSettingsStore: ObservableObject {
    static let shared = DexterMicrophoneSettingsStore()

    @Published var preferredInputDeviceIdentifier: String? {
        didSet {
            if let preferredInputDeviceIdentifier {
                UserDefaults.standard.set(preferredInputDeviceIdentifier, forKey: preferredDeviceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: preferredDeviceKey)
            }
        }
    }

    private let preferredDeviceKey = "dexterPreferredMicrophoneDeviceIdentifier"

    private init() {
        preferredInputDeviceIdentifier = UserDefaults.standard.string(forKey: preferredDeviceKey)
    }
}
