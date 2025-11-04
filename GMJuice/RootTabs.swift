//
//  RootTabs.swift
//  GMJuice
//
//  Created by Andre Taube on 10/6/25.
//


import SwiftUI

struct RootTabs: View {
    var body: some View {
        TabView {
            TrainView()
                .tabItem {
                    Label("Train", systemImage: "target")
                }

            MatchesView()
                .tabItem {
                    Label("Classification", systemImage: "trophy.fill")
                }

            CoachingHomeView()
                .tabItem {
                    Label("Coaching", systemImage: "brain.head.profile")
                }

            SettingsMainView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
