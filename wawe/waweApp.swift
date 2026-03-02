//
//  WaweApp.swift
//  wawe
//
//  Created by burningmannn on 02.12.2025.
//

import SwiftUI

@main
struct WaweApp: App {
    @StateObject private var container = AppContainer()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(container: container)

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
