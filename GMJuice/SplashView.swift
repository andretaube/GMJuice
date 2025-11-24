//
//  SplashView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/8/25.
//

import SwiftUI

struct SplashView: View {
    @StateObject private var motivationalService = MotivationalMessagesService.shared
    @State private var motivationalMessage: String = ""
    @State private var messageIsSet: Bool = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let imageWidth = geo.size.width * 0.356

                VStack(spacing: 20) {
                    Image("GMJuiceRound")
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageWidth)

                    Text(motivationalMessage)
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            updateMessage()
        }
        .onChange(of: motivationalService.remoteMessages) { _, _ in
            updateMessageFromFirebase()
        }
    }
    
    private func updateMessage() {
        // Set initial message immediately (may be fallback)
        guard !messageIsSet else { return }
        motivationalMessage = motivationalService.getRandomMessage()
        
        // If using fallback, don't mark as set so Firebase can override
        if motivationalService.remoteMessages == nil {
            print("💭 Using fallback message, waiting for Firebase...")
        } else {
            messageIsSet = true
        }
    }
    
    private func updateMessageFromFirebase() {
        // Update with Firebase message if not already set with Firebase data
        guard !messageIsSet else { return }
        motivationalMessage = motivationalService.getRandomMessage()
        messageIsSet = true
        print("🔥 Updated to Firebase message")
    }
}

#Preview {
    SplashView()
}
