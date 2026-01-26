//
//  RoomScannerApp.swift
//  RoomScanner
//
//  3D Room Scanner using iPhone LiDAR
//

import SwiftUI

@main
struct RoomScannerApp: App {
    @StateObject private var scanManager = ScanManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scanManager)
        }
    }
}
