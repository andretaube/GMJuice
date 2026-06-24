//
//  Constants.swift
//  GMJuice
//
//  Created by Claude on 11/5/25.
//

import Foundation

// MARK: - UserDefaults Keys

/// UserDefaults keys for app preferences
enum UserDefaultsKeys {
    /// The USPSA number of the current user (to identify which ShooterProfile is "mine")
    static let currentUserUSPSANumber = "current_user_uspsa_number"
}

// MARK: - Helper Extensions

extension UserDefaults {
    /// Get the current user's USPSA number
    var currentUserUSPSANumber: String? {
        get { string(forKey: UserDefaultsKeys.currentUserUSPSANumber) }
        set { set(newValue, forKey: UserDefaultsKeys.currentUserUSPSANumber) }
    }
}

