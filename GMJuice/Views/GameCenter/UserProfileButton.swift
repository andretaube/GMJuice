//
//  UserProfileButton.swift
//  GMJuice
//
//  Created by Claude on 11/6/25.
//

import SwiftUI

struct UserProfileButton: View {
    @EnvironmentObject var gameCenterManager: GameCenterManager
    @State private var showingProfile = false

    var body: some View {
        Button {
            showingProfile = true
        } label: {
            if gameCenterManager.isAuthenticated, let avatar = gameCenterManager.playerAvatar {
                // Show GameCenter avatar
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                // Show default icon
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
        .sheet(isPresented: $showingProfile) {
            if gameCenterManager.isAuthenticated {
                GameCenterProfileView()
            } else {
                GameCenterOnboardingView()
            }
        }
    }
}
