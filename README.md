# 🚌 WhereIsMyBus

A next-generation college bus tracking system designed for high performance and real-time visualization.

## 🚀 Key Features

### ⚡ Performance Optimizations
- **Quadtree Spatial Index**: Efficiently manages thousands of map markers by partitioning space, ensuring smooth interaction regardless of fleet size.
- **Marker Clustering**: Automatically groups nearby buses into clusters at lower zoom levels, reducing visual clutter and CPU usage.
- **Lazy Loading (Pagination)**: The bus list is loaded in batches of 5 with on-scroll fetching, ensuring instantaneous UI responsiveness.

### 📍 Real-Time Tracking
- **Live Telemetry**: Real-time GPS updates delivered via WebSocket.
- **Visual Routes**: Dynamic map visualization of bus routes and active stops.
- **Chennai-Specific Testing**: Pre-seeded with realistic data for Chennai transit routes.

## 📂 Project Structure

```text
WhereIsMyBus/
├── frontend/             # iOS Application (Swift/SwiftUI)
│   ├── WhereIsMyBus.xcodeproj
│   ├── ViewModels/       # Business logic and state management
│   ├── Services/         # Networking and tracking algorithms
│   └── ...
└── README.md
```

## 🛠️ Setup Instructions

### Frontend (iOS)
1. Open `frontend/WhereIsMyBus.xcodeproj` in Xcode.
2. Ensure you are targeting a device or simulator with iOS 16.0+.
3. Update `APIConfig.swift` to point to your backend server URL.
4. Build and Run (⌘R).

## 📄 License
This project is for educational and testing purposes for college transit systems.
