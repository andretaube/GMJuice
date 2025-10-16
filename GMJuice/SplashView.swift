//
//  SplashView.swift
//  GMJuice
//
//  Created by Andre Taube on 10/8/25.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            GeometryReader { geo in
                let imageWidth = geo.size.width * 0.356
                Image("GMJuiceRound")
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageWidth)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}
