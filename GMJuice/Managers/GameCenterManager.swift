//
//  GameCenterManager.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import GameKit
import SwiftUI

@MainActor
class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false
    @Published var localPlayer: GKLocalPlayer?
    @Published var friends: [GKPlayer] = []
    @Published var playerAvatar: UIImage?
    @Published var authenticationError: String?

    private init() {}

    /// Authenticate with GameCenter
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    print("❌ GameCenter authentication error: \(error.localizedDescription)")
                    self.authenticationError = error.localizedDescription
                    self.isAuthenticated = false
                    return
                }

                if let viewController = viewController {
                    // Need to present authentication view controller
                    // This will be handled by the presenting view
                    print("⚠️ GameCenter needs authentication view controller")
                    return
                }

                if GKLocalPlayer.local.isAuthenticated {
                    print("✅ GameCenter authenticated")
                    self.isAuthenticated = true
                    self.localPlayer = GKLocalPlayer.local
                    self.authenticationError = nil

                    // Load player avatar
                    await self.loadPlayerAvatar()

                    // Load friends
                    await self.loadFriends()
                } else {
                    print("⚠️ GameCenter not authenticated")
                    self.isAuthenticated = false
                }
            }
        }
    }

    /// Load the local player's avatar image
    func loadPlayerAvatar() async {
        guard let player = localPlayer else { return }

        do {
            let photo = try await player.loadPhoto(for: .normal)
            self.playerAvatar = photo
            print("✅ Loaded player avatar")
        } catch {
            print("⚠️ Failed to load player avatar: \(error.localizedDescription)")
        }
    }

    /// Load the player's friends list
    func loadFriends() async {
        guard isAuthenticated else {
            print("⚠️ Cannot load friends - not authenticated")
            return
        }

        do {
            print("🔄 Loading friends from GameCenter...")
            let friends = try await GKLocalPlayer.local.loadFriends()
            self.friends = friends
            print("✅ Loaded \(friends.count) friends from GameCenter")

            if friends.isEmpty {
                print("⚠️ GameCenter returned 0 friends. This could mean:")
                print("   - You have no friends on GameCenter")
                print("   - Friends haven't accepted your request yet")
                print("   - GameCenter permissions are restricted")
            } else {
                for friend in friends {
                    print("   Friend: \(friend.displayName) (alias: \(friend.alias))")
                }
            }
        } catch {
            print("❌ Failed to load friends: \(error.localizedDescription)")
            print("   Error details: \(error)")
            self.friends = []
        }
    }

    /// Load avatar for a specific player
    func loadAvatar(for player: GKPlayer) async -> UIImage? {
        do {
            return try await player.loadPhoto(for: .small)
        } catch {
            print("⚠️ Failed to load avatar for player: \(error.localizedDescription)")
            return nil
        }
    }
}
