//
//  CloudKitManager.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import CloudKit
import SwiftData
import Foundation

/// Manages syncing USPSA profile data to CloudKit Public Database for sharing with GameCenter friends
///
/// Privacy Policy:
/// - Only syncs official match scores used for classification (usedForClassification == true)
/// - NEVER syncs training runs or practice data
/// - All data is public and read-only by friends
@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var lastError: String?

    private let container = CKContainer.default()
    private let publicDatabase: CKDatabase

    // Record type for storing USPSA profiles
    private let recordType = "USPSAProfile"

    private init() {
        self.publicDatabase = container.publicCloudDatabase
        self.lastSyncDate = UserDefaults.standard.object(forKey: "cloudkit_last_sync") as? Date
    }

    /// Sync the user's USPSA profile to CloudKit
    /// Only syncs classification scores, never training runs
    func syncUSPSAProfile(memberNumber: String, context: ModelContext) async throws {
        guard !memberNumber.isEmpty else {
            throw NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Member number is required"])
        }

        isSyncing = true
        defer { isSyncing = false }

        // Get GameCenter player ID if authenticated
        let gamePlayerID = await GameCenterManager.shared.localPlayer?.gamePlayerID

        // Check if schema exists, if not CloudKit will auto-create it on first save
        print("📋 Syncing to CloudKit (schema will be auto-created if needed)")

        // Fetch only classification scores (usedForClassification == true)
        let descriptor = FetchDescriptor<SCMatchScore>(
            predicate: #Predicate { $0.memberNumber == memberNumber && $0.usedForClassification == true },
            sortBy: [SortDescriptor(\SCMatchScore.scoreDate, order: .reverse)]
        )

        let classificationScores = try context.fetch(descriptor)

        print("📤 Syncing \(classificationScores.count) classification scores to CloudKit")

        // Fetch shooter profile
        let profileDescriptor = FetchDescriptor<ShooterProfile>()
        let profiles = try context.fetch(profileDescriptor)
        guard let profile = profiles.first else {
            throw NSError(domain: "CloudKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No shooter profile found"])
        }

        // Fetch existing record or create new one
        let recordID = CKRecord.ID(recordName: "uspsa_\(memberNumber)")
        let record: CKRecord

        do {
            // Try to fetch existing record
            record = try await publicDatabase.record(for: recordID)
            print("✅ Found existing CloudKit record, updating...")
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist, create new one
            record = CKRecord(recordType: recordType, recordID: recordID)
            print("📝 Creating new CloudKit record...")
        } catch {
            // Other fetch error, rethrow
            throw error
        }

        // Store profile metadata
        record["memberNumber"] = memberNumber as CKRecordValue
        record["lastUpdated"] = Date() as CKRecordValue

        // Store GameCenter player ID for auto-lookup by friends
        if let gamePlayerID = gamePlayerID {
            record["gamePlayerID"] = gamePlayerID as CKRecordValue
            print("📱 Linked GameCenter ID to profile")
        }

        // Store division classifications
        var divisionData: [String: Any] = [:]
        for divProfile in profile.divisions {
            var divData: [String: Any] = [
                "classification": divProfile.classification.rawValue
            ]

            if let currentPercentage = divProfile.currentPercentage {
                divData["currentPercentage"] = NSDecimalNumber(decimal: currentPercentage).doubleValue
            }

            if let highPercentage = divProfile.highPercentage {
                divData["highPercentage"] = NSDecimalNumber(decimal: highPercentage).doubleValue
            }

            divisionData[divProfile.division.rawValue] = divData
        }

        // Convert division data to JSON
        let divisionJSON = try JSONSerialization.data(withJSONObject: divisionData)
        record["divisions"] = String(data: divisionJSON, encoding: .utf8) as? CKRecordValue

        // Store classification scores (only the ones used for classification)
        var scoresData: [[String: Any]] = []
        for score in classificationScores {
            scoresData.append([
                "stageCode": score.stageCode,
                "stageName": score.stageName,
                "divisionCode": score.divisionCode,
                "time": NSDecimalNumber(decimal: score.time).doubleValue,
                "peakTime": NSDecimalNumber(decimal: score.peakTime).doubleValue,
                "matchName": score.matchName,
                "scoreDate": score.scoreDate.timeIntervalSince1970
            ])
        }

        let scoresJSON = try JSONSerialization.data(withJSONObject: scoresData)
        record["classificationScores"] = String(data: scoresJSON, encoding: .utf8) as? CKRecordValue

        // Save to CloudKit
        try await publicDatabase.save(record)

        // Update last sync date
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "cloudkit_last_sync")

        print("✅ Successfully synced USPSA profile to CloudKit")
    }

    /// Delete the user's USPSA profile from CloudKit
    func deleteUSPSAProfile(memberNumber: String) async throws {
        guard !memberNumber.isEmpty else {
            throw NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Member number is required"])
        }

        let recordID = CKRecord.ID(recordName: "uspsa_\(memberNumber)")

        do {
            try await publicDatabase.deleteRecord(withID: recordID)
            print("✅ Successfully deleted USPSA profile from CloudKit")

            // Clear last sync date
            lastSyncDate = nil
            UserDefaults.standard.removeObject(forKey: "cloudkit_last_sync")
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist - that's fine
            print("⚠️ No CloudKit record to delete (already removed)")
        } catch {
            print("❌ Failed to delete CloudKit record: \(error)")
            throw error
        }
    }

    /// Fetch a friend's USPSA profile from CloudKit by GameCenter player ID
    func fetchFriendProfileByGameCenter(gamePlayerID: String) async throws -> FriendPerformance {
        print("🔍 Looking up friend by GameCenter ID: \(gamePlayerID)")

        // Query for record with this gamePlayerID
        let predicate = NSPredicate(format: "gamePlayerID == %@", gamePlayerID)
        let query = CKQuery(recordType: recordType, predicate: predicate)

        let (results, _) = try await publicDatabase.records(matching: query)

        // Get the first matching record
        guard let (_, recordResult) = results.first else {
            throw NSError(domain: "CloudKitManager", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Friend needs to re-sync their USPSA profile to enable auto-lookup."
            ])
        }

        let record = try recordResult.get()

        // Get member number from the record
        guard let memberNumber = record["memberNumber"] as? String else {
            throw NSError(domain: "CloudKitManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse member number"])
        }

        print("✅ Found friend's profile: \(memberNumber)")

        // Parse the rest of the record
        return try parseFriendProfile(from: record, memberNumber: memberNumber)
    }

    /// Fetch a friend's USPSA profile from CloudKit by member number
    func fetchFriendProfile(memberNumber: String) async throws -> FriendPerformance {
        let recordID = CKRecord.ID(recordName: "uspsa_\(memberNumber)")
        let record = try await publicDatabase.record(for: recordID)
        return try parseFriendProfile(from: record, memberNumber: memberNumber)
    }

    /// Parse a friend's profile from a CloudKit record
    private func parseFriendProfile(from record: CKRecord, memberNumber: String) throws -> FriendPerformance {
        // Parse divisions
        guard let divisionsJSON = record["divisions"] as? String,
              let divisionsData = divisionsJSON.data(using: .utf8),
              let divisionDict = try JSONSerialization.jsonObject(with: divisionsData) as? [String: [String: Any]] else {
            throw NSError(domain: "CloudKitManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse division data"])
        }

        var divisions: [FriendPerformance.DivisionPerformance] = []
        for (divCode, divData) in divisionDict {
            if let classification = divData["classification"] as? String,
               let currentPercent = divData["currentPercentage"] as? Double {
                divisions.append(FriendPerformance.DivisionPerformance(
                    divisionCode: divCode,
                    classification: classification,
                    currentPercentage: Decimal(currentPercent),
                    highPercentage: (divData["highPercentage"] as? Double).map { Decimal($0) }
                ))
            }
        }

        // Parse classification scores
        var scores: [FriendPerformance.StageScore] = []
        if let scoresJSON = record["classificationScores"] as? String,
           let scoresData = scoresJSON.data(using: .utf8),
           let scoresArray = try JSONSerialization.jsonObject(with: scoresData) as? [[String: Any]] {

            for scoreDict in scoresArray {
                if let stageCode = scoreDict["stageCode"] as? String,
                   let stageName = scoreDict["stageName"] as? String,
                   let divisionCode = scoreDict["divisionCode"] as? String,
                   let time = scoreDict["time"] as? Double,
                   let peakTime = scoreDict["peakTime"] as? Double,
                   let matchName = scoreDict["matchName"] as? String,
                   let scoreDateInterval = scoreDict["scoreDate"] as? TimeInterval {

                    scores.append(FriendPerformance.StageScore(
                        stageCode: stageCode,
                        stageName: stageName,
                        divisionCode: divisionCode,
                        time: Decimal(time),
                        peakTime: Decimal(peakTime),
                        matchName: matchName,
                        scoreDate: Date(timeIntervalSince1970: scoreDateInterval)
                    ))
                }
            }
        }

        let lastUpdated = record["lastUpdated"] as? Date

        return FriendPerformance(
            memberNumber: memberNumber,
            divisions: divisions,
            classificationScores: scores,
            lastUpdated: lastUpdated
        )
    }
}

// MARK: - Data Models

struct FriendPerformance {
    let memberNumber: String
    let divisions: [DivisionPerformance]
    let classificationScores: [StageScore]
    let lastUpdated: Date?

    struct DivisionPerformance {
        let divisionCode: String
        let classification: String
        let currentPercentage: Decimal
        let highPercentage: Decimal?
    }

    struct StageScore {
        let stageCode: String
        let stageName: String
        let divisionCode: String
        let time: Decimal
        let peakTime: Decimal
        let matchName: String
        let scoreDate: Date
    }
}
