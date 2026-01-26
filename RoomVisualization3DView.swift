//
//  RoomVisualization3DView.swift
//  RoomScanner
//
//  Real-time 3D visualization of captured room geometry
//  Shows walls, floors, doors, windows, objects as they're detected
//

import SwiftUI
import SceneKit
import RoomPlan
import Combine

// MARK: - 3D Scene Manager

class RoomScene3DManager: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    let scene = SCNScene()
    private var wallNodes: [UUID: SCNNode] = [:]
    private var floorNodes: [UUID: SCNNode] = [:]
    private var doorNodes: [UUID: SCNNode] = [:]
    private var windowNodes: [UUID: SCNNode] = [:]
    private var objectNodes: [UUID: SCNNode] = [:]
    
    init() {
        setupScene()
    }
    
    private func setupScene() {
        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 2, z: 5)
        cameraNode.look(at: SCNVector3(x: 0, y: 1, z: 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.6, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // Add directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = UIColor(white: 0.8, alpha: 1.0)
        directionalLight.position = SCNVector3(x: 0, y: 5, z: 0)
        directionalLight.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directionalLight)
        
        // Add grid floor for reference
        addReferenceGrid()
    }
    
    private func addReferenceGrid() {
        let gridSize: Float = 10
        let gridSpacing: Float = 1
        
        for i in 0...Int(gridSize) {
            let offset = Float(i) - gridSize / 2
            
            // Lines along X axis
            let lineX = SCNGeometry.line(
                from: SCNVector3(x: -gridSize/2, y: 0, z: offset),
                to: SCNVector3(x: gridSize/2, y: 0, z: offset)
            )
            lineX.firstMaterial?.diffuse.contents = UIColor(white: 0.3, alpha: 0.3)
            let nodeX = SCNNode(geometry: lineX)
            scene.rootNode.addChildNode(nodeX)
            
            // Lines along Z axis
            let lineZ = SCNGeometry.line(
                from: SCNVector3(x: offset, y: 0, z: -gridSize/2),
                to: SCNVector3(x: offset, y: 0, z: gridSize/2)
            )
            lineZ.firstMaterial?.diffuse.contents = UIColor(white: 0.3, alpha: 0.3)
            let nodeZ = SCNNode(geometry: lineZ)
            scene.rootNode.addChildNode(nodeZ)
        }
    }
    
    func updateRoom(_ capturedRoom: CapturedRoom?) {
        guard let room = capturedRoom else { return }
        
        // Update walls
        updateWalls(room.walls)
        
        // Update floors
        updateFloors(room.floors)
        
        // Update doors
        updateDoors(room.doors)
        
        // Update windows
        updateWindows(room.windows)
        
        // Update objects
        updateObjects(room.objects)
    }
    
    private func updateWalls(_ walls: [CapturedRoom.Surface]) {
        updateSurfaceNodes(walls, nodes: &wallNodes, color: .systemBlue.withAlphaComponent(0.5))
    }
    
    private func updateFloors(_ floors: [CapturedRoom.Surface]) {
        updateSurfaceNodes(floors, nodes: &floorNodes, color: .systemGray.withAlphaComponent(0.3))
    }
    
    private func updateDoors(_ doors: [CapturedRoom.Surface]) {
        updateSurfaceNodes(doors, nodes: &doorNodes, color: .systemBrown.withAlphaComponent(0.6))
    }
    
    private func updateWindows(_ windows: [CapturedRoom.Surface]) {
        updateSurfaceNodes(windows, nodes: &windowNodes, color: .systemCyan.withAlphaComponent(0.4))
    }
    
    private func updateSurfaceNodes(_ surfaces: [CapturedRoom.Surface], nodes: inout [UUID: SCNNode], color: UIColor) {
        // Track which surfaces still exist
        let existingSurfaces = Set(surfaces.map { $0.identifier })
        
        // Remove nodes that no longer exist
        for (id, node) in nodes {
            if !existingSurfaces.contains(id) {
                node.removeFromParentNode()
                nodes.removeValue(forKey: id)
            }
        }
        
        // Add or update surfaces
        for surface in surfaces {
            if let existingNode = nodes[surface.identifier] {
                // Update existing node
                updateNodeTransform(existingNode, with: surface.transform)
            } else {
                // Create new node
                let node = createSurfaceNode(surface: surface, color: color)
                scene.rootNode.addChildNode(node)
                nodes[surface.identifier] = node
            }
        }
    }
    
    private func createSurfaceNode(surface: CapturedRoom.Surface, color: UIColor) -> SCNNode {
        let dimensions = surface.dimensions
        
        let geometry = SCNBox(
            width: CGFloat(dimensions.x),
            height: CGFloat(dimensions.y),
            length: CGFloat(dimensions.z),
            chamferRadius: 0
        )
        
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.transparency = 0.7
        
        let node = SCNNode(geometry: geometry)
        updateNodeTransform(node, with: surface.transform)
        
        return node
    }
    
    private func updateNodeTransform(_ node: SCNNode, with transform: simd_float4x4) {
        node.simdTransform = transform
    }
    
    private func updateObjects(_ objects: [CapturedRoom.Object]) {
        // Track which objects still exist
        let existingObjects = Set(objects.map { $0.identifier })
        
        // Remove nodes that no longer exist
        for (id, node) in objectNodes {
            if !existingObjects.contains(id) {
                node.removeFromParentNode()
                objectNodes.removeValue(forKey: id)
            }
        }
        
        // Add or update objects
        for object in objects {
            if let existingNode = objectNodes[object.identifier] {
                // Update existing node
                updateNodeTransform(existingNode, with: object.transform)
            } else {
                // Create new node
                let node = createObjectNode(object: object)
                scene.rootNode.addChildNode(node)
                objectNodes[object.identifier] = node
            }
        }
    }
    
    private func createObjectNode(object: CapturedRoom.Object) -> SCNNode {
        let dimensions = object.dimensions
        
        let geometry = SCNBox(
            width: CGFloat(dimensions.x),
            height: CGFloat(dimensions.y),
            length: CGFloat(dimensions.z),
            chamferRadius: 0.02
        )
        
        // Color based on object category
        let color = colorForObjectCategory(object.category)
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.transparency = 0.8
        
        let node = SCNNode(geometry: geometry)
        updateNodeTransform(node, with: object.transform)
        
        // Add label
        addLabelToNode(node, text: "\(object.category)")
        
        return node
    }
    
    private func colorForObjectCategory(_ category: CapturedRoom.Object.Category) -> UIColor {
        switch category {
        case .storage:
            return .systemOrange
        case .refrigerator:
            return .systemGray
        case .stove:
            return .systemRed
        case .bed:
            return .systemPurple
        case .sink:
            return .systemBlue
        case .washerDryer:
            return .systemGreen
        case .toilet:
            return .systemCyan
        case .bathtub:
            return .systemTeal
        case .oven:
            return .systemRed
        case .dishwasher:
            return .systemIndigo
        case .table:
            return .systemBrown
        case .sofa:
            return .systemPink
        case .chair:
            return .systemYellow
        case .fireplace:
            return .systemOrange
        case .television:
            return .black
        case .stairs:
            return .systemGray
        @unknown default:
            return .systemGray
        }
    }
    
    private func addLabelToNode(_ node: SCNNode, text: String) {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.01)
        textGeometry.font = UIFont.systemFont(ofSize: 0.1)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)
        textNode.position = SCNVector3(0, 0.5, 0)
        
        node.addChildNode(textNode)
    }
}

// MARK: - SceneKit View Representable

struct RoomVisualization3DView: UIViewRepresentable {
    @ObservedObject var sceneManager: RoomScene3DManager
    let capturedRoom: CapturedRoom?
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = sceneManager.scene
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.showsStatistics = false
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        sceneManager.updateRoom(capturedRoom)
    }
}

// MARK: - SwiftUI Wrapper

struct Room3DVisualizationView: View {
    @StateObject private var sceneManager = RoomScene3DManager()
    let capturedRoom: CapturedRoom?
    
    var body: some View {
        ZStack {
            RoomVisualization3DView(sceneManager: sceneManager, capturedRoom: capturedRoom)
                .ignoresSafeArea()
            
            // Instructions overlay
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                            Text("Walls")
                                .font(.caption)
                        }
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.brown)
                                .frame(width: 10, height: 10)
                            Text("Doors")
                                .font(.caption)
                        }
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 10, height: 10)
                            Text("Windows")
                                .font(.caption)
                        }
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10, height: 10)
                            Text("Objects")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Pinch/drag instructions
                Text("Pinch to zoom • Drag to rotate")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                    .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - SCNGeometry Extension for Lines

extension SCNGeometry {
    static func line(from start: SCNVector3, to end: SCNVector3) -> SCNGeometry {
        let indices: [Int32] = [0, 1]
        let source = SCNGeometrySource(vertices: [start, end])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        return SCNGeometry(sources: [source], elements: [element])
    }
}
