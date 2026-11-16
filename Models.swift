//
//  Models.swift
//  RoomScanner
//
//  Data models for room scans
//

import Foundation
import RoomPlan
import simd

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

/// Half-size of a RoomPlan box (surface or object) along the world x, y and z axes, taking its rotation into account:
/// the box's half dimensions projected onto each axis through the rotation columns of its transform.
func surfaceHalfExtents(transform t: simd_float4x4, dimensions d: simd_float3) -> simd_float3 {
    let right = simd_float3(t.columns.0.x, t.columns.0.y, t.columns.0.z)
    let up = simd_float3(t.columns.1.x, t.columns.1.y, t.columns.1.z)
    let back = simd_float3(t.columns.2.x, t.columns.2.y, t.columns.2.z)
    return abs(right) * (d.x / 2) + abs(up) * (d.y / 2) + abs(back) * (d.z / 2)
}
