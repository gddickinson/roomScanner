//
//  MappingFloorPlanView.swift
//  RoomScanner
//
//  Real-time 2D floor plan with phone position, orientation, and SLAM tracking
//

import SwiftUI
import RoomPlan
import CoreLocation
import ARKit

struct MappingFloorPlanView: View {
    let capturedRoom: CapturedRoom?
    let cameraTransform: simd_float4x4?  // Phone position from ARKit
    let heading: CLLocationDirection?    // Compass heading
    @Binding var positionHistory: [simd_float3]  // Trail of phone positions
    
    @State private var scale: CGFloat = 20.0  // pixels per meter
    @State private var panOffset: CGPoint = .zero
    @State private var lastPanOffset: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.opacity(0.9)
                
                if let room = capturedRoom {
                    Canvas { context, size in
                        // Calculate bounds and scale
                        let bounds = calculateBounds(room: room, history: positionHistory)
                        let displayScale = calculateScale(bounds: bounds, canvasSize: size)
                        let offset = calculateOffset(bounds: bounds, canvasSize: size, scale: displayScale)
                        
                        // Apply pan offset
                        let finalOffset = CGPoint(
                            x: offset.x + panOffset.x,
                            y: offset.y + panOffset.y
                        )
                        
                        // Draw grid with compass orientation
                        drawGrid(context: context, size: size, offset: finalOffset, scale: displayScale, heading: heading)
                        
                        // Draw movement trail
                        drawTrail(context: context, history: positionHistory, offset: finalOffset, scale: displayScale)
                        
                        // Draw walls with corner indicators
                        drawWalls(context: context, walls: room.walls, offset: finalOffset, scale: displayScale)
                        
                        // Draw doors
                        drawDoors(context: context, doors: room.doors, offset: finalOffset, scale: displayScale)
                        
                        // Draw windows
                        drawWindows(context: context, windows: room.windows, offset: finalOffset, scale: displayScale)
                        
                        // Draw objects
                        drawObjects(context: context, objects: room.objects, offset: finalOffset, scale: displayScale)
                        
                        // Draw phone position and orientation
                        if let transform = cameraTransform {
                            drawPhone(context: context, transform: transform, offset: finalOffset, scale: displayScale, heading: heading)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                panOffset = CGPoint(
                                    x: lastPanOffset.x + value.translation.width,
                                    y: lastPanOffset.y + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastPanOffset = panOffset
                            }
                    )
                    
                    // Overlay info
                    VStack {
                        HStack {
                            // Room stats
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Room Map")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                HStack(spacing: 12) {
                                    Label("\(room.walls.count)", systemImage: "square.dashed")
                                    Label("\(room.doors.count)", systemImage: "door.left.hand.open")
                                    Label("\(room.windows.count)", systemImage: "window.vertical.open")
                                    Label("\(room.objects.count)", systemImage: "cube.box")
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            // Compass heading
                            if let heading = heading {
                                VStack(spacing: 2) {
                                    Image(systemName: "location.north.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(-heading))
                                    Text("\(Int(heading))°")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Text(compassDirection(heading))
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        
                        Spacer()
                        
                        // Legend
                        HStack(spacing: 16) {
                            LegendItem(color: .green, label: "Walls")
                            LegendItem(color: .brown, label: "Doors")
                            LegendItem(color: .cyan, label: "Windows")
                            LegendItem(color: .orange, label: "Objects")
                            LegendItem(color: .red, label: "You", icon: "location.fill")
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Initializing SLAM...")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - Compass Direction
    
    private func compassDirection(_ heading: CLLocationDirection) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index]
    }
    
    // MARK: - Bounds Calculation
    
    private func calculateBounds(room: CapturedRoom, history: [simd_float3]) -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity
        
        // Include walls
        for wall in room.walls {
            let pos = wall.transform.columns.3
            let halfW = wall.dimensions.x / 2
            let halfD = wall.dimensions.z / 2
            
            minX = min(minX, Float(pos.x - halfW))
            maxX = max(maxX, Float(pos.x + halfW))
            minZ = min(minZ, Float(pos.z - halfD))
            maxZ = max(maxZ, Float(pos.z + halfD))
        }
        
        // Include position history
        for pos in history {
            minX = min(minX, pos.x)
            maxX = max(maxX, pos.x)
            minZ = min(minZ, pos.z)
            maxZ = max(maxZ, pos.z)
        }
        
        // Add padding
        let padding: Float = 0.5
        return (minX - padding, maxX + padding, minZ - padding, maxZ + padding)
    }
    
    private func calculateScale(bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float), canvasSize: CGSize) -> Float {
        let roomWidth = bounds.maxX - bounds.minX
        let roomDepth = bounds.maxZ - bounds.minZ
        
        guard roomWidth > 0.001 && roomDepth > 0.001 else { return 20.0 }
        
        let scaleX = Float(canvasSize.width) / roomWidth
        let scaleZ = Float(canvasSize.height) / roomDepth
        
        return min(scaleX, scaleZ) * 0.85  // 85% to leave margin
    }
    
    private func calculateOffset(bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float), canvasSize: CGSize, scale: Float) -> CGPoint {
        let roomWidth = bounds.maxX - bounds.minX
        let roomDepth = bounds.maxZ - bounds.minZ
        
        let scaledWidth = roomWidth * scale
        let scaledDepth = roomDepth * scale
        
        let offsetX = (Float(canvasSize.width) - scaledWidth) / 2 - bounds.minX * scale
        let offsetZ = (Float(canvasSize.height) - scaledDepth) / 2 - bounds.minZ * scale
        
        return CGPoint(x: CGFloat(offsetX), y: CGFloat(offsetZ))
    }
    
    // MARK: - Drawing Functions
    
    private func drawGrid(context: GraphicsContext, size: CGSize, offset: CGPoint, scale: Float, heading: CLLocationDirection?) {
        let gridSpacing: CGFloat = CGFloat(scale)  // 1 meter grid
        let lineColor = Color.white.opacity(0.1)
        
        var path = Path()
        
        // Vertical lines
        var x: CGFloat = 0
        while x < size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += gridSpacing
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += gridSpacing
        }
        
        context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
        
        // Draw north indicator if we have compass
        if let heading = heading {
            let centerX = size.width / 2
            let centerY: CGFloat = 50
            let arrowLength: CGFloat = 30
            
            let angle = -heading * .pi / 180.0
            let endX = centerX + arrowLength * CGFloat(sin(angle))
            let endY = centerY - arrowLength * CGFloat(cos(angle))
            
            var northPath = Path()
            northPath.move(to: CGPoint(x: centerX, y: centerY))
            northPath.addLine(to: CGPoint(x: endX, y: endY))
            
            context.stroke(northPath, with: .color(.red.opacity(0.6)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
    
    private func drawTrail(context: GraphicsContext, history: [simd_float3], offset: CGPoint, scale: Float) {
        guard history.count > 1 else { return }
        
        var path = Path()
        let first = history[0]
        path.move(to: CGPoint(
            x: offset.x + CGFloat(first.x * scale),
            y: offset.y + CGFloat(first.z * scale)
        ))
        
        for i in 1..<history.count {
            let pos = history[i]
            path.addLine(to: CGPoint(
                x: offset.x + CGFloat(pos.x * scale),
                y: offset.y + CGFloat(pos.z * scale)
            ))
        }
        
        context.stroke(
            path,
            with: .color(.blue.opacity(0.5)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 3])
        )
    }
    
    private func drawWalls(context: GraphicsContext, walls: [CapturedRoom.Surface], offset: CGPoint, scale: Float) {
        for wall in walls {
            let transform = wall.transform
            let width = wall.dimensions.x
            
            let posX = Float(transform.columns.3.x)
            let posZ = Float(transform.columns.3.z)
            
            // Extract rotation
            let rightX = Float(transform.columns.0.x)
            let rightZ = Float(transform.columns.0.z)
            let length = sqrt(rightX * rightX + rightZ * rightZ)
            
            let dirX = length > 0.001 ? rightX / length : 1.0
            let dirZ = length > 0.001 ? rightZ / length : 0.0
            
            let halfW = width / 2
            
            // Calculate endpoints
            let x1 = posX - dirX * halfW
            let z1 = posZ - dirZ * halfW
            let x2 = posX + dirX * halfW
            let z2 = posZ + dirZ * halfW
            
            // Convert to screen
            let screenX1 = offset.x + CGFloat(x1 * scale)
            let screenZ1 = offset.y + CGFloat(z1 * scale)
            let screenX2 = offset.x + CGFloat(x2 * scale)
            let screenZ2 = offset.y + CGFloat(z2 * scale)
            
            // Draw wall
            var path = Path()
            path.move(to: CGPoint(x: screenX1, y: screenZ1))
            path.addLine(to: CGPoint(x: screenX2, y: screenZ2))
            
            context.stroke(path, with: .color(.green), lineWidth: 6)
            
            // Draw corner dots
            let dotRadius: CGFloat = 5
            context.fill(
                Circle().path(in: CGRect(x: screenX1 - dotRadius, y: screenZ1 - dotRadius, width: dotRadius*2, height: dotRadius*2)),
                with: .color(.yellow)
            )
            context.fill(
                Circle().path(in: CGRect(x: screenX2 - dotRadius, y: screenZ2 - dotRadius, width: dotRadius*2, height: dotRadius*2)),
                with: .color(.yellow)
            )
        }
    }
    
    private func drawDoors(context: GraphicsContext, doors: [CapturedRoom.Surface], offset: CGPoint, scale: Float) {
        for door in doors {
            let pos = door.transform.columns.3
            let width = door.dimensions.x / 2
            
            let screenX = offset.x + CGFloat(Float(pos.x) * scale)
            let screenZ = offset.y + CGFloat(Float(pos.z) * scale)
            let screenW = CGFloat(width * scale)
            
            let rect = CGRect(x: screenX - screenW, y: screenZ - 3, width: screenW * 2, height: 6)
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(.brown.opacity(0.8)))
        }
    }
    
    private func drawWindows(context: GraphicsContext, windows: [CapturedRoom.Surface], offset: CGPoint, scale: Float) {
        for window in windows {
            let pos = window.transform.columns.3
            let width = window.dimensions.x / 2
            
            let screenX = offset.x + CGFloat(Float(pos.x) * scale)
            let screenZ = offset.y + CGFloat(Float(pos.z) * scale)
            let screenW = CGFloat(width * scale)
            
            let rect = CGRect(x: screenX - screenW, y: screenZ - 3, width: screenW * 2, height: 6)
            context.fill(Path(rect), with: .color(.cyan.opacity(0.6)))
            
            // Crosshatch
            var crossPath = Path()
            crossPath.move(to: CGPoint(x: rect.minX, y: rect.midY))
            crossPath.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            context.stroke(crossPath, with: .color(.cyan), lineWidth: 1)
        }
    }
    
    private func drawObjects(context: GraphicsContext, objects: [CapturedRoom.Object], offset: CGPoint, scale: Float) {
        for object in objects {
            let transform = object.transform
            let pos = transform.columns.3
            let width = object.dimensions.x / 2
            let depth = object.dimensions.z / 2
            
            // Extract rotation (same method as walls)
            let rightX = Float(transform.columns.0.x)  // Right vector X
            let rightZ = Float(transform.columns.0.z)  // Right vector Z
            let yaw = atan2(rightZ, rightX)  // Rotation in X-Z plane
            
            let screenX = offset.x + CGFloat(Float(pos.x) * scale)
            let screenZ = offset.y + CGFloat(Float(pos.z) * scale)
            let screenW = CGFloat(width * scale)
            let screenD = CGFloat(depth * scale)
            
            // Create rectangle path
            let rect = CGRect(x: -screenW, y: -screenD, width: screenW * 2, height: screenD * 2)
            let rectPath = Path(roundedRect: rect, cornerRadius: 3)
            
            // Apply rotation and translation transform
            var pathTransform = CGAffineTransform.identity
            pathTransform = pathTransform.translatedBy(x: screenX, y: screenZ)
            pathTransform = pathTransform.rotated(by: CGFloat(yaw))
            
            let transformedPath = rectPath.applying(pathTransform)
            
            // Draw rotated object
            context.fill(transformedPath, with: .color(.orange.opacity(0.4)))
            context.stroke(transformedPath, with: .color(.orange), lineWidth: 1.5)
            
            // Draw orientation indicator (small line showing "front")
            var orientationPath = Path()
            orientationPath.move(to: CGPoint(x: 0, y: 0))
            orientationPath.addLine(to: CGPoint(x: 0, y: -screenD * 1.3))
            
            let orientationTransformed = orientationPath.applying(pathTransform)
            context.stroke(orientationTransformed, with: .color(.orange), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
    
    private func drawPhone(context: GraphicsContext, transform: simd_float4x4, offset: CGPoint, scale: Float, heading: CLLocationDirection?) {
        // Phone position
        let posX = Float(transform.columns.3.x)
        let posZ = Float(transform.columns.3.z)
        
        let screenX = offset.x + CGFloat(posX * scale)
        let screenZ = offset.y + CGFloat(posZ * scale)
        
        // Phone orientation (yaw angle from transform)
        let forward = simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        let yaw = atan2(forward.x, forward.z)
        
        // Draw phone as triangle pointing in direction of movement
        let size: CGFloat = 12
        var phonePath = Path()
        
        // Triangle pointing up (forward)
        phonePath.move(to: CGPoint(x: 0, y: -size))
        phonePath.addLine(to: CGPoint(x: -size*0.7, y: size*0.5))
        phonePath.addLine(to: CGPoint(x: size*0.7, y: size*0.5))
        phonePath.closeSubpath()
        
        // Transform to position and rotation
        var phoneTransform = CGAffineTransform.identity
        phoneTransform = phoneTransform.translatedBy(x: screenX, y: screenZ)
        phoneTransform = phoneTransform.rotated(by: CGFloat(yaw))
        
        let transformedPath = phonePath.applying(phoneTransform)
        
        // Draw phone
        context.fill(transformedPath, with: .color(.red))
        context.stroke(transformedPath, with: .color(.white), lineWidth: 2)
        
        // Draw direction cone (field of view)
        let coneLength: CGFloat = 40
        let coneAngle: CGFloat = .pi / 6  // 30 degrees
        
        var conePath = Path()
        conePath.move(to: CGPoint(x: screenX, y: screenZ))
        
        let angle1 = CGFloat(yaw) - coneAngle
        let angle2 = CGFloat(yaw) + coneAngle
        
        conePath.addLine(to: CGPoint(
            x: screenX + coneLength * sin(angle1),
            y: screenZ + coneLength * cos(angle1)
        ))
        conePath.addLine(to: CGPoint(
            x: screenX + coneLength * sin(angle2),
            y: screenZ + coneLength * cos(angle2)
        ))
        conePath.closeSubpath()
        
        context.fill(conePath, with: .color(.red.opacity(0.2)))
        context.stroke(conePath, with: .color(.red.opacity(0.5)), lineWidth: 1)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}
