//
//  ProfileErrorRecovery.swift
//  GMJuice
//
//  Created by Claude on 11/8/25.
//

import SwiftData
import Foundation

struct ProfileErrorRecovery {
    /// Safely execute a block that accesses ShooterProfile data
    /// If a database error occurs, delete the corrupted profile and optionally re-sync
    static func safelyAccessProfile<T>(
        context: ModelContext,
        profileNumber: String,
        autoRecover: Bool = true,
        operation: () throws -> T
    ) -> T? {
        do {
            return try operation()
        } catch {
            print("⚠️ Database error accessing profile \(profileNumber): \(error)")

            if autoRecover {
                print("🔄 Attempting to recover by deleting corrupted profile data...")
                deleteCorruptedProfile(context: context, uspsaNumber: profileNumber)
            }

            return nil
        }
    }

    /// Delete a corrupted profile and all its related data
    static func deleteCorruptedProfile(context: ModelContext, uspsaNumber: String) {
        do {
            // Fetch the profile
            let descriptor = FetchDescriptor<ShooterProfile>(
                predicate: #Predicate { $0.uspsaNumber == uspsaNumber }
            )

            if let profiles = try? context.fetch(descriptor) {
                for profile in profiles {
                    print("🗑️ Deleting corrupted profile: \(profile.uspsaNumber)")
                    context.delete(profile)
                }

                try context.save()
                print("✅ Successfully deleted corrupted profile data")
            }
        } catch {
            print("❌ Error deleting corrupted profile: \(error)")
        }
    }

    /// Attempt to recover from a profile-related error by deleting and re-syncing
    @MainActor
    static func recoverProfile(
        context: ModelContext,
        uspsaNumber: String,
        scraper: SCWebScraper,
        completion: @escaping (Bool) -> Void
    ) {
        // First delete the corrupted data
        deleteCorruptedProfile(context: context, uspsaNumber: uspsaNumber)

        // Then attempt to re-sync
        Task {
            do {
                // Check if SCSA data is enabled via Remote Config
                guard RemoteConfigService.shared.isSCSADataEnabled else {
                    print("🚫 SCSA data recovery disabled via Remote Config")
                    completion(false)
                    return
                }
                
                print("🔄 Re-syncing profile data for: \(uspsaNumber)")
                try await scraper.syncClassificationData(memberNumber: uspsaNumber, context: context)
                print("✅ Successfully recovered profile: \(uspsaNumber)")
                completion(true)
            } catch {
                print("❌ Failed to recover profile: \(error)")
                completion(false)
            }
        }
    }

    /// Wrap a SwiftData query in error handling
    static func safeQuery<T: PersistentModel>(
        context: ModelContext,
        descriptor: FetchDescriptor<T>
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            print("⚠️ Database query error: \(error)")
            // If it's a profile-related query, we could attempt recovery here
            return []
        }
    }
}
