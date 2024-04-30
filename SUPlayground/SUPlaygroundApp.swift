//
//  SUPlaygroundApp.swift
//  SUPlayground
//
//  Created by jean.333 on 4/21/24.
//

import SwiftUI

@main
struct SUPlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(store: Store(initialValue: AppState(), reducer: counterReducer(state:action:)))
        }
    }
}
