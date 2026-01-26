//
//  FloorPlanPreview.swift
//  RoomScanner
//
//  Real-time 2D floor plan visualization during scanning
//

import SwiftUI
import RoomPlan
import simd

struct FloorPlanPreview: View {
    let capturedRoom: CapturedRoom?
    let viewSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            guard let room = capturedRoom else { return }
            
            // Calculate bounds and scale
            let bounds = calculateBounds(room: room)
            let scale = calculateScale(bounds: bounds, canvasSize: size)
            let offset = calculateOffset(bounds: bounds, canvasSize: size, scale: scale)
            
            // Draw walls
            for wall in room.walls {
                drawWall(wall, in: context, scale: scale, offset: offset)
            }
            
            // Draw doors
            for door in room.doors {
                drawDoor(door, in: context, scale: scale, offset: offset)
            }
            
            // Draw windows
            for window in room.windows {
                drawWindow(window, in: context, scale: scale, offset: offset)
            }
            
            // Draw objects
            for object in room.objects {
                drawObject(object, in: context, scale: scale, offset: offset)
            }
        }
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
    }
    
    // MARK: - Bounds Calculation
    
    private func calculateBounds(room: CapturedRoom) -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity
        
        for wall in room.walls {
            let pos = wall.transform.columns.3
            let halfW = wall.dimensions.x / 2
            let halfD = wall.dimensions.z / 2
            
            minX = min(minX, Float(pos.x - halfW))
            maxX = max(maxX, Float(pos.x + halfW))
            minZ = min(minZ, Float(pos.z - halfD))
            maxZ = max(maxZ, Float(pos.z + halfD))
        }
        
        // Add padding
        let padding: Float = 0.5
        return (minX - padding, maxX + padding, minZ - padding, maxZ + padding)
    }
    
    private func calculateScale(bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float), canvasSize: CGSize) -> Float {
        let roomWidth = bounds.maxX - bounds.minX
        let roomDepth = bounds.maxZ - bounds.minZ
        
        let scaleX = Float(canvasSize.width) / roomWidth
        let scaleZ = Float(canvasSize.height) / roomDepth
        
        return min(scaleX, scaleZ) * 0.9  // 90% to leave margin
    }
    
    private func calculateOffset(bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float), canvasSize: CGSize, scale: Float) -> (x: Float, z: Float) {
        let roomWidth = bounds.maxX - bounds.minX
        let roomDepth = bounds.maxZ - bounds.minZ
        
        let scaledWidth = roomWidth * scale
        let scaledDepth = roomDepth * scale
        
        let offsetX = (Float(canvasSize.width) - scaledWidth) / 2 - bounds.minX * scale
        let offsetZ = (Float(canvasSize.height) - scaledDepth) / 2 - bounds.minZ * scale
        
        return (offsetX, offsetZ)
    }
    
    // MARK: - Drawing Functions
    
    private func drawWall(_ wall: CapturedRoom.Surface, in context: GraphicsContext, scale: Float, offset: (x: Float, z: Float)) {
        let pos = wall.transform.columns.3
        let halfW = wall.dimensions.x / 2
        
        // Get wall corners in 3D space
        let x = Float(pos.x)
        let z = Float(pos.z)
        
        // Extract rotation from transform to get proper wall orientation
        let matrix = wall.transform
        let rightX = Float(matrix.columns.0.x)
        let rightZ = Float(matrix.columns.0.z)
        let length = sqrt(rightX * rightX + rightZ * rightZ)
        
        let dirX = length > 0.001 ? rightX / length : 1.0
        let dirZ = length > 0.001 ? rightZ / length : 0.0
        
        // Calculate endpoints
        let x1 = x - dirX * halfW
        let z1 = z - dirZ * halfW
        let x2 = x + dirX * halfW
        let z2 = z + dirZ * halfW
        
        // Convert to screen coordinates
        let screenX1 = CGFloat(x1 * scale + offset.x)
        let screenZ1 = CGFloat(z1 * scale + offset.z)
        let screenX2 = CGFloat(x2 * scale + offset.x)
        let screenZ2 = CGFloat(z2 * scale + offset.z)
        
        // Draw wall line (thicker)
        var path = Path()
        path.move(to: CGPoint(x: screenX1, y: screenZ1))
        path.addLine(to: CGPoint(x: screenX2, y: screenZ2))
        
        context.stroke(
            path,
            with: .color(.green),
            lineWidth: 6
        )
        
        // Draw corner dots
        context.fill(
            Circle().path(in: CGRect(x: screenX1 - 4, y: screenZ1 - 4, width: 8, height: 8)),
            with: .color(.green)
        )
        context.fill(
            Circle().path(in: CGRect(x: screenX2 - 4, y: screenZ2 - 4, width: 8, height: 8)),
            with: .color(.green)
        )
    }
    
    private func drawDoor(_ door: CapturedRoom.Surface, in context: GraphicsContext, scale: Float, offset: (x: Float, z: Float)) {
        let pos = door.transform.columns.3
        let width = door.dimensions.x / 2
        
        let x = Float(pos.x)
        let z = Float(pos.z)
        
        let screenX = CGFloat(x * scale + offset.x)
        let screenZ = CGFloat(z * scale + offset.z)
        let screenW = CGFloat(width * scale)
        
        // Draw door as a rectangle
        let rect = CGRect(x: screenX - screenW, y: screenZ - 2, width: screenW * 2, height: 4)
        context.fill(Path(rect), with: .color(.brown))
    }
    
    private func drawWindow(_ window: CapturedRoom.Surface, in context: GraphicsContext, scale: Float, offset: (x: Float, z: Float)) {
        let pos = window.transform.columns.3
        let width = window.dimensions.x / 2
        
        let x = Float(pos.x)
        let z = Float(pos.z)
        
        let screenX = CGFloat(x * scale + offset.x)
        let screenZ = CGFloat(z * scale + offset.z)
        let screenW = CGFloat(width * scale)
        
        // Draw window as a rectangle
        let rect = CGRect(x: screenX - screenW, y: screenZ - 2, width: screenW * 2, height: 4)
        context.fill(Path(rect), with: .color(.cyan))
    }
    
    private func drawObject(_ object: CapturedRoom.Object, in context: GraphicsContext, scale: Float, offset: (x: Float, z: Float)) {
        let transform = object.transform
        let pos = transform.columns.3
        let width = object.dimensions.x / 2
        let depth = object.dimensions.z / 2
        
        // Extract rotation (same method as walls)
        let rightX = Float(transform.columns.0.x)  // Right vector X
        let rightZ = Float(transform.columns.0.z)  // Right vector Z
        let yaw = atan2(rightZ, rightX)  // Rotation in X-Z plane
        
        let x = Float(pos.x)
        let z = Float(pos.z)
        
        let screenX = CGFloat(x * scale + offset.x)
        let screenZ = CGFloat(z * scale + offset.z)
        let screenW = CGFloat(width * scale)
        let screenD = CGFloat(depth * scale)
        
        // Create rectangle path centered at origin
        let rect = CGRect(x: -screenW, y: -screenD, width: screenW * 2, height: screenD * 2)
        let rectPath = Path(rect)
        
        // Apply rotation and translation
        var pathTransform = CGAffineTransform.identity
        pathTransform = pathTransform.translatedBy(x: screenX, y: screenZ)
        pathTransform = pathTransform.rotated(by: CGFloat(yaw))
        
        let transformedPath = rectPath.applying(pathTransform)
        
        // Draw rotated object
        context.fill(transformedPath, with: .color(.yellow.opacity(0.6)))
        context.stroke(transformedPath, with: .color(.orange), lineWidth: 1)
        
        // Draw orientation indicator (small line showing "front")
        var orientationPath = Path()
        orientationPath.move(to: CGPoint(x: 0, y: 0))
        orientationPath.addLine(to: CGPoint(x: 0, y: -screenD * 1.2))
        
        let orientationTransformed = orientationPath.applying(pathTransform)
        context.stroke(orientationTransformed, with: .color(.orange), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}
