# RoomScanner - LiDAR 3D Room Scanning App

A native iOS app for scanning rooms using iPhone's LiDAR sensor and exporting 3D data for Python analysis.

## Features

- 📱 Uses iPhone 16 Pro's LiDAR sensor and ARKit
- 🏠 Automatic room detection with RoomPlan framework
- 🪟 Detects walls, doors, windows, and furniture
- 📊 Multiple export formats: USD, USDZ, and JSON
- 🐍 Python-friendly JSON export for custom analysis
- 💾 Save and manage multiple room scans

## Requirements

### iOS App
- iPhone 16 Pro (or any iPhone with LiDAR: 12 Pro, 13 Pro, 14 Pro, 15 Pro, 16 Pro)
- iOS 17.0 or later
- Xcode 15.0 or later (for building)

### Python (for data analysis)
- Python 3.8+
- NumPy (for data processing)
- Matplotlib (optional, for visualization)

## Installation

### Building the iOS App

1. **Open Xcode** and create a new iOS App project:
   - Product Name: `RoomScanner`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: iOS 17.0

2. **Add the source files** to your project:
   - `RoomScannerApp.swift` (replace the default App file)
   - `ContentView.swift` (replace the default)
   - `ScanningView.swift`
   - `ScanManager.swift`
   - `Models.swift`

3. **Update Info.plist**:
   - Replace with the provided `Info.plist` file
   - Key requirement: Camera usage description for LiDAR access

4. **Configure signing**:
   - Select your development team in "Signing & Capabilities"
   - Change the bundle identifier to something unique

5. **Add required frameworks**:
   In your target's "Frameworks, Libraries, and Embedded Content", ensure:
   - RoomPlan.framework
   - ARKit.framework
   - RealityKit.framework
   - SwiftUI.framework

6. **Build and run** on your iPhone 16 Pro

### Python Setup

```bash
# Install required packages
pip install numpy matplotlib

# Optional: Create a virtual environment first
python -m venv room_scanner_env
source room_scanner_env/bin/activate  # On Windows: room_scanner_env\Scripts\activate
pip install numpy matplotlib
```

## Usage

### Scanning a Room

1. **Launch the app** on your iPhone
2. **Tap the + button** to start a new scan
3. **Grant camera permissions** when prompted
4. **Tap "Start Scan"** and slowly move around the room:
   - Point the camera at walls, floors, ceiling
   - Move slowly and steadily
   - Ensure good lighting
   - Cover all areas of the room
5. **Tap "Done"** when you've covered the entire room
6. **Name your scan** and save

### Exporting Data

1. **Tap on a saved scan** in the list
2. **Choose an export format**:
   - **USD**: Best for viewing in AR/3D apps (QuickLook)
   - **USDZ**: Compressed version, good for sharing
   - **JSON**: For Python analysis (recommended for your use case)
3. **Share or save** the file via the iOS share sheet
4. **Transfer to your computer**:
   - AirDrop
   - iCloud Drive
   - USB file transfer
   - Email/messaging

### Python Analysis

```python
from room_scan_loader import RoomScan, visualize_floor_plan

# Load a scan
scan = RoomScan('my_living_room.json')

# Print summary
print(scan.summary())

# Get room dimensions
dims = scan.get_room_dimensions()
print(f"Room: {dims['width']:.2f}m × {dims['length']:.2f}m × {dims['height']:.2f}m")

# Get wall positions
walls = scan.get_wall_positions()
print(f"Found {len(walls)} walls")

# Get detected objects
objects = scan.get_object_categories()
print(f"Objects: {objects}")

# Visualize floor plan
visualize_floor_plan(scan, show_objects=True)
```

## JSON Data Format

The exported JSON contains:

```json
{
  "dimensions": {
    "width": 4.5,
    "length": 6.2,
    "height": 2.8
  },
  "walls": [
    {
      "id": "uuid",
      "dimensions": {"width": 4.5, "height": 2.8, "thickness": 0.1},
      "transform": {
        "position": {"x": 0, "y": 0, "z": 0},
        "matrix": [[...], [...], [...], [...]]
      }
    }
  ],
  "doors": [...],
  "windows": [...],
  "objects": [
    {
      "id": "uuid",
      "category": "table",
      "dimensions": {"width": 1.5, "height": 0.7, "depth": 0.8},
      "transform": {"position": {...}},
      "confidence": "high"
    }
  ]
}
```

### Coordinate System

- **X**: Left/Right (meters)
- **Y**: Up/Down (height, meters)
- **Z**: Forward/Backward (depth, meters)
- Origin typically at scan start position

All distances are in **meters**.

## Customizing the Python Loader

You can extend the `RoomScan` class for your specific needs:

```python
class MyRoomAnalyzer(RoomScan):
    def calculate_floor_area(self):
        """Calculate approximate floor area"""
        dims = self.get_room_dimensions()
        return dims['width'] * dims['length']
    
    def get_furniture_density(self):
        """Calculate furniture items per square meter"""
        area = self.calculate_floor_area()
        return len(self.objects) / area if area > 0 else 0
    
    def export_to_custom_format(self, output_path):
        """Export to your custom format"""
        # Your custom processing here
        pass
```

## Troubleshooting

### App Issues

**"RoomPlan not available"**
- Ensure you're running on a LiDAR-equipped iPhone
- Check iOS version (requires iOS 16+)

**Scan quality is poor**
- Ensure good lighting
- Move slower
- Cover all areas thoroughly
- Avoid reflective surfaces

**App won't build**
- Check signing & capabilities
- Verify all frameworks are linked
- Update to latest Xcode

### Python Issues

**"File not found"**
- Check file path is correct
- Ensure file was successfully transferred from iPhone

**Import errors**
- Install required packages: `pip install numpy matplotlib`

## Advanced Usage

### Batch Processing Multiple Rooms

```python
from pathlib import Path
from room_scan_loader import RoomScan

scan_dir = Path('scans/')
scans = {}

for json_file in scan_dir.glob('*.json'):
    scan = RoomScan(json_file)
    scans[json_file.stem] = scan
    print(f"{json_file.stem}: {scan.get_room_dimensions()}")
```

### Combining Multiple Rooms

```python
# You can combine scans by transforming coordinates
# Example: align rooms to create full house map

def combine_rooms(scans, transforms):
    """
    Combine multiple room scans into one coordinate system
    
    scans: list of RoomScan objects
    transforms: list of 4x4 transformation matrices
    """
    # Your implementation here
    pass
```

## Tips for Best Results

1. **Scanning technique**:
   - Start from one corner
   - Move in a systematic pattern
   - Scan ceiling and floor too
   - Re-scan areas if quality seems low

2. **Room preparation**:
   - Good, even lighting
   - Remove clutter if possible
   - Open doors/close doors as desired

3. **Data processing**:
   - Use wall positions to define room boundaries
   - Object positions are approximate
   - Transform matrices contain full orientation data
   - Confidence scores indicate detection quality

## Future Enhancements

Possible additions to the app:
- Multi-room stitching within the app
- Real-time measurement display
- Point cloud export
- Custom object labeling
- Photo textures for walls

## Project Structure

```
RoomScanner/
├── RoomScannerApp.swift      # App entry point
├── ContentView.swift          # Main UI - scan list
├── ScanningView.swift         # RoomPlan scanning interface
├── ScanManager.swift          # Data management & export
├── Models.swift               # Data structures
├── Info.plist                 # App configuration
└── room_scan_loader.py        # Python data loader
```

## License

This project is provided as-is for your personal use.

## Credits

Built using:
- Apple RoomPlan framework
- ARKit
- SwiftUI

---

**Happy Scanning! 📱🏠**

For questions or issues, please refer to Apple's RoomPlan documentation:
https://developer.apple.com/documentation/roomplan
