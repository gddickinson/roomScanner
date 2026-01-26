//
//  Models.swift
//  RoomScanner
//
//  Data models for room scans
//

import Foundation
import RoomPlan

struct RoomScan: Identifiable, Codable {
    let id: UUID
    let name: String
    let date: Date
    let fileName: String
    var thumbnailData: Data?
    
    init(name: String, fileName: String) {
        self.id = UUID()
        self.name = name
        self.date = Date()
        self.fileName = fileName
    }
}

struct ExportFormat: Identifiable {
    let id = UUID()
    let name: String
    let fileExtension: String
    let description: String
}

let exportFormats = [
    ExportFormat(name: "USD (Universal Scene Description)", 
                 fileExtension: "usd", 
                 description: "Apple's 3D format, best for AR/VR"),
    ExportFormat(name: "USDZ (USD Archive)", 
                 fileExtension: "usdz", 
                 description: "Compressed USD, ideal for sharing"),
    ExportFormat(name: "JSON (Custom)", 
                 fileExtension: "json", 
                 description: "Raw data export for Python processing")
]
