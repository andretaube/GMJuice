//
//  GameCenterProfileView.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import SwiftUI
import GameKit

struct GameCenterProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gameCenterManager: GameCenterManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @AppStorage("cloudkit_sharing_enabled") private var cloudKitSharingEnabled = false
    @State private var friendAvatars: [String: UIImage] = [:]
    @State private var selectedFriendID: String?
    @State private var showingGameCenterDashboard = false

    private var selectedFriend: GKPlayer? {
        guard let id = selectedFriendID else { return nil }
        return gameCenterManager.friends.first(where: { $0.gamePlayerID == id })
    }

    var body: some View {
        NavigationStack {
            List {
                // Local player section
                if let player = gameCenterManager.localPlayer {
                    Section {
                        HStack(spacing: 16) {
                            if let avatar = gameCenterManager.playerAvatar {
                                Image(uiImage: avatar)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.gray)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.displayName)
                                    .font(.headline)

                                if !player.alias.isEmpty {
                                    Text("@\(player.alias)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 8) {
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundStyle(.green)

                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 4) {
                                        Image(systemName: cloudKitSharingEnabled ? "lock.open.fill" : "lock.fill")
                                        Text(cloudKitSharingEnabled ? "Public Profile" : "Private Profile")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(cloudKitSharingEnabled ? .blue : .orange)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Friends list
                Section {
                    if gameCenterManager.friends.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            Text("No Friends Yet")
                                .font(.headline)

                            Text("Invite friends on GameCenter to compare your Steel Challenge performance")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(gameCenterManager.friends, id: \.gamePlayerID) { friend in
                            Button {
                                selectedFriendID = friend.gamePlayerID
                            } label: {
                                HStack(spacing: 12) {
                                    if let avatar = friendAvatars[friend.gamePlayerID] {
                                        Image(uiImage: avatar)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.gray)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.displayName)
                                            .font(.body)
                                            .foregroundStyle(.primary)

                                        if !friend.alias.isEmpty {
                                            Text("@\(friend.alias)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .task {
                                // Load avatar for this friend
                                if friendAvatars[friend.gamePlayerID] == nil {
                                    if let avatar = await gameCenterManager.loadAvatar(for: friend) {
                                        friendAvatars[friend.gamePlayerID] = avatar
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Friends (\(gameCenterManager.friends.count))")
                } footer: {
                    Text("Friends must also use GMJuice and share their profile to appear in comparisons")
                }

                // Actions
                Section {
                    Button {
                        showingGameCenterDashboard = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add Friends in GameCenter")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Opens GameCenter dashboard where you can search for and add friends")
                }
            }
            .navigationTitle("GameCenter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedFriend != nil },
                set: { if !$0 { selectedFriendID = nil } }
            )) {
                if let friend = selectedFriend {
                    FriendComparisonView(friend: friend)
                }
            }
            .sheet(isPresented: $showingGameCenterDashboard) {
                GameCenterDashboard()
            }
        }
    }
}

// MARK: - GameCenter Dashboard

struct GameCenterDashboard: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let viewController = GKGameCenterViewController(state: .dashboard)
        viewController.gameCenterDelegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            dismiss()
        }
    }
}
