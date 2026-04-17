import Foundation
import Combine

@MainActor
final class BusRepository: ObservableObject {
    static let shared = BusRepository()

    @Published private(set) var buses: [Bus] = []
    var allBuses: [Bus] { buses }
    private var timer: Timer?

    private var lastUpdateTime: Date = Date()
    private let updateInterval: TimeInterval = 1.0 // Minimum 1s between full UI refreshes
    
    func notifyUpdate() {
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) >= updateInterval {
            lastUpdateTime = now
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    private init() {
        startDailyLoad()
    }


    func bus(by id: UUID) -> Bus? {
        buses.first { $0.id == id }
    }
    
    func bus(byNumber number: String) -> Bus? {
        buses.first { $0.number == number }
    }

    func allRoutes() -> [Route] {
        Array(Set(buses.map { $0.route }))
            .sorted { $0.from < $1.from }
    }
    
    /// Register (or update) a bus in the repository. Used when search results
    /// hydrate a bus with full stop data.
    func register(bus: Bus) {
        if let idx = buses.firstIndex(where: { $0.id == bus.id }) {
            buses[idx] = bus
        } else {
            buses.append(bus)
        }
    }
    
    func ensureStops(for busID: UUID) async {
        // Sanitized: Backend integration removed
    }
    
    // MARK: - Live Sync
    
    func startDailyLoad() {
        Task {
            do {
                _ = try await APIService.shared.fetchBuses()
                notifyUpdate()
            } catch {
                print("BusRepository: Daily load failed: \(error)")
            }
        }
    }
    
    func startLiveSync() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                await self.syncCoords()
            }
        }
    }
    
    func updateBusTelemetry(id: UUID, point: Coord, speed: Double, timestampRaw: String?) {
        guard let idx = buses.firstIndex(where: { $0.id == id }) else { return }
        buses[idx].currentCoordinate = point
        buses[idx].liveTelemetry.speed = speed
        buses[idx].liveTelemetry.lastUpdate = Date()
        notifyUpdate()
    }
    
    private func syncCoords() async {
        do {
            let points = try await APIService.shared.fetchLiveFleetGPS()
            for pt in points {
                if let idx = buses.firstIndex(where: { $0.vehicleId == pt.trip_id || $0.extTripId == pt.ext_trip_id }) {
                    buses[idx].currentCoordinate = Coord(lat: pt.lat, lon: pt.lng)
                    buses[idx].liveTelemetry.speed = pt.speed ?? 0
                    buses[idx].liveTelemetry.bearing = pt.heading ?? 0
                    buses[idx].liveTelemetry.lastUpdate = Date()
                }
            }
            notifyUpdate()
        } catch {
            print("BusRepository: Sync failed: \(error)")
        }
    }
    
    func stopLiveSync() {
        timer?.invalidate()
        timer = nil
    }
    
    private func distance(_ c1: Coord, _ c2: Coord) -> Double {
        let dLat = c1.lat - c2.lat
        let dLon = c1.lon - c2.lon
        return sqrt(dLat * dLat + dLon * dLon)
    }
}

