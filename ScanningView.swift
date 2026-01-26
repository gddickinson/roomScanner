//
//  ScanningView.swift
//  RoomScanner
//
//  RoomPlan scanning with view mode toggle: Floor Plan, Camera, or Hybrid
//

import SwiftUI
import RoomPlan
import Combine
import CoreLocation
import simd

// MARK: - View Mode Enum

enum ScanViewMode: String, CaseIterable {
    case view3D = "3D View"
    case floorPlan = "Floor Plan"
    
    var icon: String {
        switch self {
        case .view3D: return "cube.fill"
        case .floorPlan: return "map.fill"
        }
    }
}

struct ScanningView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var scanManager: ScanManager
    
    @StateObject private var captureController = RoomCaptureController()
    @StateObject private var locationManager = LocationManager()
    @State private var showingSaveDialog = false
    @State private var roomName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var viewMode: ScanViewMode = .view3D
    @State private var showingViewModeSelector = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Main view based on mode
            if captureController.isScanning {
                switch viewMode {
                case .view3D:
                    // 3D visualization of detected geometry
                    Room3DVisualizationView(capturedRoom: captureController.capturedRoom)
                        .ignoresSafeArea()
                    
                case .floorPlan:
                    // 2D floor plan view
                    MappingFloorPlanView(
                        capturedRoom: captureController.capturedRoom,
                        cameraTransform: captureController.estimatedCameraPosition,
                        heading: locationManager.heading,
                        positionHistory: $captureController.positionHistory
                    )
                    .ignoresSafeArea()
                }
            } else {
                // Not scanning - show instructions
                VStack(spacing: 20) {
                    Image(systemName: viewMode == .view3D ? "cube.fill" : "map.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Ready to Scan")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Tap Start to begin scanning")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Overlay controls
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // View mode selector
                    if captureController.isScanning {
                        Menu {
                            ForEach(ScanViewMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewMode = mode
                                    }
                                }) {
                                    Label(mode.rawValue, systemImage: mode.icon)
                                    if viewMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: viewMode.icon)
                                Text(viewMode.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                        }
                    }
                    
                    Spacer()
                    
                    // Scanning status
                    if captureController.isScanning {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Scanning...")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                    }
                }
                .padding()
                
                Spacer()
                
                // Real-time stats (show in 3D view mode)
                if captureController.isScanning, let room = captureController.capturedRoom {
                    if viewMode == .view3D {
                        VStack(spacing: 8) {
                            HStack(spacing: 20) {
                                StatBadge(icon: "square.dashed", value: "\(room.walls.count)", label: "Walls")
                                StatBadge(icon: "door.left.hand.open", value: "\(room.doors.count)", label: "Doors")
                                StatBadge(icon: "window.vertical.open", value: "\(room.windows.count)", label: "Windows")
                                StatBadge(icon: "cube.box", value: "\(room.objects.count)", label: "Objects")
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        }
                        .padding(.bottom, 10)
                    }
                }
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Instructions
                    if captureController.isScanning {
                        VStack(spacing: 8) {
                            switch viewMode {
                            case .view3D:
                                Text("Move around the room")
                                    .font(.headline)
                                Text("Watch detected surfaces appear in 3D")
                                    .font(.subheadline)
                            case .floorPlan:
                                Text("Track your movement")
                                    .font(.headline)
                                Text("Watch the 2D map build in real-time")
                                    .font(.subheadline)
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    }
                    
                    // Control buttons
                    HStack(spacing: 40) {
                        if !captureController.isScanning {
                            Button(action: startScanning) {
                                Label("Start Scan", systemImage: "play.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                        } else {
                            Button(action: stopScanning) {
                                Label("Done", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showingSaveDialog) {
            SaveScanView(
                roomName: $roomName,
                capturedRoom: captureController.capturedRoom,
                onSave: saveScan,
                onCancel: { showingSaveDialog = false }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .navigationBarHidden(true)
        .onAppear {
            locationManager.startUpdating()
        }
        .onDisappear {
            locationManager.stopUpdating()
        }
    }
    
    private func startScanning() {
        captureController.startSession()
    }
    
    private func stopScanning() {
        captureController.stopSession()
        showingSaveDialog = true
    }
    
    private func saveScan() {
        guard let capturedRoom = captureController.capturedRoom else {
            errorMessage = "No scan data available"
            showingError = true
            return
        }
        
        Task {
            do {
                try await scanManager.addScan(name: roomName, capturedRoom: capturedRoom)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Stat Badge Component

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Text(label)
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }
}

// MARK: - Location Manager for Compass

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var heading: CLLocationDirection?
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func startUpdating() {
        manager.requestWhenInUseAuthorization()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
    
    func stopUpdating() {
        manager.stopUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            DispatchQueue.main.async {
                self.heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            }
        }
    }
}

// MARK: - RoomCapture Controller

class RoomCaptureController: NSObject, ObservableObject, RoomCaptureSessionDelegate {
    @Published var isScanning = false
    @Published var capturedRoom: CapturedRoom?
    @Published var estimatedCameraPosition: simd_float4x4?
    @Published var positionHistory: [simd_float3] = []
    @Published var roomSession: RoomCaptureSession?
    
    private var lastPositionUpdate = Date()
    
    func startSession() {
        print("🚀 Starting RoomCaptureSession...")
        let session = RoomCaptureSession()
        session.delegate = self
        
        let config = RoomCaptureSession.Configuration()
        session.run(configuration: config)
        
        roomSession = session
        isScanning = true
        positionHistory.removeAll()
        
        print("✅ Session started and assigned to roomSession")
    }
    
    func stopSession() {
        roomSession?.stop()
        isScanning = false
    }
    
    // MARK: - RoomCaptureSessionDelegate
    
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        DispatchQueue.main.async {
            self.capturedRoom = room
            
            // Estimate camera position from room geometry
            if !room.walls.isEmpty {
                // Calculate room center
                var centerX: Float = 0
                var centerY: Float = 0
                var centerZ: Float = 0
                
                for wall in room.walls {
                    centerX += Float(wall.transform.columns.3.x)
                    centerY += Float(wall.transform.columns.3.y)
                    centerZ += Float(wall.transform.columns.3.z)
                }
                
                let count = Float(room.walls.count)
                centerX /= count
                centerY /= count
                centerZ /= count
                
                // Create estimated camera transform
                var transform = matrix_identity_float4x4
                transform.columns.3 = simd_float4(centerX, centerY, centerZ, 1.0)
                self.estimatedCameraPosition = transform
                
                // Add to history periodically
                let now = Date()
                if now.timeIntervalSince(self.lastPositionUpdate) >= 0.2 {
                    let position = simd_float3(centerX, centerY, centerZ)
                    self.positionHistory.append(position)
                    self.lastPositionUpdate = now
                    
                    // Limit history
                    if self.positionHistory.count > 200 {
                        self.positionHistory.removeFirst()
                    }
                }
            }
        }
    }
    
    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error = error {
            print("Capture session error: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }
}

// MARK: - Save Dialog

struct SaveScanView: View {
    @Binding var roomName: String
    let capturedRoom: CapturedRoom?
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Room name", text: $roomName)
                } header: {
                    Text("Save Scan")
                }
                
                if let room = capturedRoom {
                    Section {
                        HStack {
                            Text("Walls")
                            Spacer()
                            Text("\(room.walls.count)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Doors")
                            Spacer()
                            Text("\(room.doors.count)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Windows")
                            Spacer()
                            Text("\(room.windows.count)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Objects")
                            Spacer()
                            Text("\(room.objects.count)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Detected Elements")
                    }
                }
            }
            .navigationTitle("Save Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(roomName.isEmpty)
                }
            }
        }
    }
}
