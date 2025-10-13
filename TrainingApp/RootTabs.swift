//
//  RootTabs.swift
//  TrainingApp
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

            LogView()
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
            
            ShooterProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            
        }
    }
}
