//
//  DexterHomeGreetingFormatter.swift
//  leanring-buddy
//

import Foundation

enum DexterHomeGreetingFormatter {
    static func greeting(firstName: String, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: Date())
        let salutation: String
        switch hour {
        case 5..<12: salutation = "Good morning"
        case 12..<17: salutation = "Good afternoon"
        case 17..<22: salutation = "Good evening"
        default: salutation = "Good night"
        }
        return "\(salutation), \(firstName)."
    }
}
