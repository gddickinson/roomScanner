//
//  ContentView.swift
//  RoomScanner
//
//  Main view showing scan list and export options
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var scanManager: ScanManager
    @State private var showingScanner = false
    @State private var selectedScan: RoomScan?
    
    var body: some View {
        NavigationView {
            ZStack {
                if scanManager.scans.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("No Scans Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap + to scan your first room")
                            .foregroundColor(.secondary)
                        
                        Button(action: { showingScanner = true }) {
                            Label("New Scan", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                } else {
                    // Scan list
                    List {
                        ForEach(scanManager.scans) { scan in
                            ScanRow(scan: scan)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedScan = scan
                                }
                        }
                        .onDelete(perform: deleteScans)
                    }
                }
            }
            .navigationTitle("Room Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if !scanManager.scans.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScanningView()
            }
            .sheet(item: $selectedScan) { scan in
                ScanDetailView(scan: scan)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deleteScans(at offsets: IndexSet) {
        for index in offsets {
            let scan = scanManager.scans[index]
            scanManager.deleteScan(scan)
        }
    }
}

// MARK: - Scan Row

struct ScanRow: View {
    let scan: RoomScan
    
    var body: some View {
        HStack {
            Image(systemName: "cube.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.name)
                    .font(.headline)
                
                Text(scan.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Scan Detail View

struct ScanDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var scanManager: ScanManager
    
    let scan: RoomScan
    @State private var selectedFormat: ExportFormat?
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(scan.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(scan.date, style: .date)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Details")
                }
                
                Section {
                    ForEach(exportFormats) { format in
                        Button(action: {
                            exportScan(format: format)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(format.name)
                                        .foregroundColor(.primary)
                                    Text(format.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } header: {
                    Text("Export Formats")
                } footer: {
                    Text("Files are saved to the app's Documents folder and can be accessed via the Files app or shared directly.")
                }
                
                Section {
                    Button(role: .destructive, action: deleteScan) {
                        HStack {
                            Spacer()
                            Text("Delete Scan")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func exportScan(format: ExportFormat) {
        let fileURL = scanManager.getFileURL(for: scan, format: format.fileExtension)
        
        // Check if file exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            shareURL = fileURL
            showingShareSheet = true
        }
    }
    
    private func deleteScan() {
        scanManager.deleteScan(scan)
        dismiss()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ScanManager())
    }
}
