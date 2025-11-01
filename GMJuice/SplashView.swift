//
//  SplashView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/8/25.
//

import SwiftUI

struct SplashView: View {
    @State private var motivationalMessage: String = ""

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
            motivationalMessage = MotivationalMessages.randomElement() ?? "Go train!"
        }
    }
}

#Preview {
    SplashView()
}
