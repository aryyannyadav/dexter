//
//  DexterMicrophoneState.swift
//  leanring-buddy
//

import Foundation

enum DexterMicrophonePermissionState: Equatable {
    case notDetermined
    case requesting
    case denied
    case authorized
    case unavailable
}

enum DexterMicrophoneRuntimeState: Equatable {
    case idle
    case starting
    case listening
    case processing
    case error
}

enum DexterScreenPermissionState: Equatable {
    case unknown
    case denied
    case granted
}
