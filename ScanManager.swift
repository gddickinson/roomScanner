//
//  ScanManager.swift
//  RoomScanner
//
//  Manages room scans and data persistence
//

import Foundation
import RoomPlan
import SwiftUI
import Combine
import simd

@MainActor
class ScanManager: ObservableObject {
    @Published var scans: [RoomScan] = []
    @Published var isScanning = false
    
    private let scansKey = "savedScans"
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    init() {
        loadScans()
    }
    
    // MARK: - Scan Management
    
    func addScan(name: String, capturedRoom: CapturedRoom) async throws {
        let fileName = "\(UUID().uuidString)"
        let scan = RoomScan(name: name, fileName: fileName)
        
        // Save in multiple formats
        try await saveRoomData(capturedRoom: capturedRoom, fileName: fileName)
        
        scans.append(scan)
        saveScans()
    }
    
    func deleteScan(_ scan: RoomScan) {
        // Delete files
        let baseURL = documentsURL.appendingPathComponent(scan.fileName)
        for ext in ["usd", "usdz", "json"] {
            let fileURL = baseURL.appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Remove from list
        scans.removeAll { $0.id == scan.id }
        saveScans()
    }
    
    // MARK: - Export Functions
    
    private func saveRoomData(capturedRoom: CapturedRoom, fileName: String) async throws {
        let baseURL = documentsURL.appendingPathComponent(fileName)
        
        // Export USD
        let usdURL = baseURL.appendingPathExtension("usd")
        try capturedRoom.export(to: usdURL, exportOptions: .model)
        
        // Export USDZ (compressed)
        let usdzURL = baseURL.appendingPathExtension("usdz")
        try capturedRoom.export(to: usdzURL, exportOptions: .model)
        
        // Export custom JSON format for Python
        let jsonURL = baseURL.appendingPathExtension("json")
        let jsonData = try exportToJSON(capturedRoom: capturedRoom)
        try jsonData.write(to: jsonURL)
    }
    
    func exportToJSON(capturedRoom: CapturedRoom) throws -> Data {
        var jsonData: [String: Any] = [:]
        
        // Calculate room dimensions
        let dims = calculateDimensions(from: capturedRoom.walls)
        jsonData["dimensions"] = [
            "width": dims.0,
            "height": dims.1,
            "length": dims.2
        ]
        
        // Walls
        var walls: [[String: Any]] = []
        for wall in capturedRoom.walls {
            walls.append(createWallDict(from: wall))
        }
        jsonData["walls"] = walls
        
        // Doors
        var doors: [[String: Any]] = []
        for door in capturedRoom.doors {
            doors.append(createDoorDict(from: door))
        }
        jsonData["doors"] = doors
        
        // Windows
        var windows: [[String: Any]] = []
        for window in capturedRoom.windows {
            windows.append(createWindowDict(from: window))
        }
        jsonData["windows"] = windows
        
        // Objects
        var objects: [[String: Any]] = []
        for object in capturedRoom.objects {
            objects.append(createObjectDict(from: object))
        }
        jsonData["objects"] = objects
        
        return try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
    }
    
    // MARK: - Helper Functions
    
    private func calculateDimensions(from walls: [CapturedRoom.Surface]) -> (Float, Float, Float) {
        guard !walls.isEmpty else { return (0, 0, 0) }
        
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minY: Float = .infinity
        var maxY: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity
        
        for wall in walls {
            let x = Float(wall.transform.columns.3.x)
            let y = Float(wall.transform.columns.3.y)
            let z = Float(wall.transform.columns.3.z)
            let w = Float(wall.dimensions.x) / 2
            let h = Float(wall.dimensions.y) / 2
            let d = Float(wall.dimensions.z) / 2
            
            minX = min(minX, x - w)
            maxX = max(maxX, x + w)
            minY = min(minY, y - h)
            maxY = max(maxY, y + h)
            minZ = min(minZ, z - d)
            maxZ = max(maxZ, z + d)
        }
        
        return (maxX - minX, maxY - minY, maxZ - minZ)
    }
    
    private func createWallDict(from wall: CapturedRoom.Surface) -> [String: Any] {
        let t = wall.transform
        let posX = Float(t.columns.3.x)
        let posY = Float(t.columns.3.y)
        let posZ = Float(t.columns.3.z)
        
        let row0 = [Float(t.columns.0.x), Float(t.columns.0.y), Float(t.columns.0.z), Float(t.columns.0.w)]
        let row1 = [Float(t.columns.1.x), Float(t.columns.1.y), Float(t.columns.1.z), Float(t.columns.1.w)]
        let row2 = [Float(t.columns.2.x), Float(t.columns.2.y), Float(t.columns.2.z), Float(t.columns.2.w)]
        let row3 = [Float(t.columns.3.x), Float(t.columns.3.y), Float(t.columns.3.z), Float(t.columns.3.w)]
        
        return [
            "id": wall.identifier.uuidString,
            "dimensions": [
                "width": Float(wall.dimensions.x),
                "height": Float(wall.dimensions.y),
                "thickness": Float(wall.dimensions.z)
            ],
            "transform": [
                "position": ["x": posX, "y": posY, "z": posZ],
                "matrix": [row0, row1, row2, row3]
            ]
        ]
    }
    
    private func createDoorDict(from door: CapturedRoom.Surface) -> [String: Any] {
        let t = door.transform
        
        // Extract rotation (same method as walls - using right vector in X-Z plane)
        let rightX = Float(t.columns.0.x)
        let rightZ = Float(t.columns.0.z)
        let yawRadians = atan2(rightZ, rightX)
        let yawDegrees = yawRadians * 180.0 / .pi
        
        return [
            "id": door.identifier.uuidString,
            "dimensions": [
                "width": Float(door.dimensions.x),
                "height": Float(door.dimensions.y),
                "depth": Float(door.dimensions.z)
            ],
            "transform": [
                "position": [
                    "x": Float(t.columns.3.x),
                    "y": Float(t.columns.3.y),
                    "z": Float(t.columns.3.z)
                ],
                "rotation": [
                    "yaw_radians": yawRadians,
                    "yaw_degrees": yawDegrees
                ]
            ]
        ]
    }
    
    private func createWindowDict(from window: CapturedRoom.Surface) -> [String: Any] {
        let t = window.transform
        
        // Extract rotation (same method as walls - using right vector in X-Z plane)
        let rightX = Float(t.columns.0.x)
        let rightZ = Float(t.columns.0.z)
        let yawRadians = atan2(rightZ, rightX)
        let yawDegrees = yawRadians * 180.0 / .pi
        
        return [
            "id": window.identifier.uuidString,
            "dimensions": [
                "width": Float(window.dimensions.x),
                "height": Float(window.dimensions.y),
                "depth": Float(window.dimensions.z)
            ],
            "transform": [
                "position": [
                    "x": Float(t.columns.3.x),
                    "y": Float(t.columns.3.y),
                    "z": Float(t.columns.3.z)
                ],
                "rotation": [
                    "yaw_radians": yawRadians,
                    "yaw_degrees": yawDegrees
                ]
            ]
        ]
    }
    
    private func createObjectDict(from object: CapturedRoom.Object) -> [String: Any] {
        let t = object.transform
        
        // Extract rotation (same method as walls - using right vector in X-Z plane)
        let rightX = Float(t.columns.0.x)
        let rightZ = Float(t.columns.0.z)
        let yawRadians = atan2(rightZ, rightX)
        let yawDegrees = yawRadians * 180.0 / .pi
        
        return [
            "id": object.identifier.uuidString,
            "category": String(describing: object.category),
            "dimensions": [
                "width": Float(object.dimensions.x),
                "height": Float(object.dimensions.y),
                "depth": Float(object.dimensions.z)
            ],
            "transform": [
                "position": [
                    "x": Float(t.columns.3.x),
                    "y": Float(t.columns.3.y),
                    "z": Float(t.columns.3.z)
                ],
                "rotation": [
                    "yaw_radians": yawRadians,
                    "yaw_degrees": yawDegrees
                ]
            ],
            "confidence": String(describing: object.confidence)
        ]
    }
    
    func getFileURL(for scan: RoomScan, format: String) -> URL {
        documentsURL
            .appendingPathComponent(scan.fileName)
            .appendingPathExtension(format)
    }
    
    // MARK: - Persistence
    
    private func saveScans() {
        if let encoded = try? JSONEncoder().encode(scans) {
            UserDefaults.standard.set(encoded, forKey: scansKey)
        }
    }
    
    private func loadScans() {
        if let data = UserDefaults.standard.data(forKey: scansKey),
           let decoded = try? JSONDecoder().decode([RoomScan].self, from: data) {
            scans = decoded
        }
    }
}
