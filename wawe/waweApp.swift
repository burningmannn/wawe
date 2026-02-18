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
    
    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
