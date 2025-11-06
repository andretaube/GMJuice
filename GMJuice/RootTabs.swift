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
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }

            TrainView()
                .tabItem {
                    Label("Train", systemImage: "target")
                }

            CoachingHomeView()
                .tabItem {
                    Label("Analysis", systemImage: "chart.bar.xaxis")
                }

            SettingsMainView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
