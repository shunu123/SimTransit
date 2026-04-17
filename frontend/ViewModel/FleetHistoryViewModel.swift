import SwiftUI
import MapKit
import Combine

@MainActor
final class FleetHistoryViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var allTrips: [HistoryTripDisplay] = []
    @Published var selectedTrip: HistoryTripDisplay? = nil
    @Published var isLoading: Bool = false
    @Published var showRouteList: Bool = false
    
    // Route filtering
    @Published var visibleRoutes: Set<String> = ["Chennai", "Kancheepuram", "Vellore"]
    
    // Destination hub
    // Destination hub (Neutralized to allow backend-only flow)
    let destinationHub = Coord(lat: 0, lon: 0)
    let destinationName = "Destination"
    
    // MARK: - Helper Structs
    struct RouteInfo: Identifiable, Equatable {
        let id: String
        let name: String
        let startCity: String
        let trips: [HistoryTripDisplay]
        let plannedPolyline: [Coord]
        
        static func == (lhs: RouteInfo, rhs: RouteInfo) -> Bool { lhs.id == rhs.id }
        
        var strokeStyle: StrokeStyle {
            return StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        }
        
        var routeColor: Color {
            let lower = startCity.lowercased()
            if lower.contains("chennai") { return .blue }
            if lower.contains("kancheepuram") { return .purple }
            if lower.contains("vellore") { return .orange }
            if lower.contains("thiruvallur") { return .green }
            if lower.contains("tambaram") { return .cyan }
            if lower.contains("poonamallee") { return .indigo }
            if lower.contains("avadi") { return .pink }
            return .red
        }
    }
    
    struct HistoryTripDisplay: Identifiable, Equatable {
        let id: UUID
        let busNumber: String
        let busId: UUID
        let routeName: String
        let startCity: String
        let actualPolyline: [Coord]
        let isDeviated: Bool
        let status: String
        let startTime: String
        let endTime: String
        let reachedTime: String?
        let duration: String
        let stops: [HistoryStop]
        
        var segments: [PathSegment] {
            guard !actualPolyline.isEmpty else { return [] }
            var segments: [PathSegment] = []
            var currentCoords: [Coord] = []
            var currentlyDiverted = actualPolyline.first?.isDiverted ?? false
            
            for coord in actualPolyline {
                if coord.isDiverted == currentlyDiverted {
                    currentCoords.append(coord)
                } else {
                    if !currentCoords.isEmpty {
                        segments.append(PathSegment(coords: currentCoords, isDiverted: currentlyDiverted))
                    }
                    currentCoords = [coord]
                    currentlyDiverted = coord.isDiverted
                }
            }
            if !currentCoords.isEmpty {
                segments.append(PathSegment(coords: currentCoords, isDiverted: currentlyDiverted))
            }
            return segments
        }
    }

    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var groupedRoutes: [RouteInfo] {
        let grouped = Dictionary(grouping: allTrips) { $0.startCity }
        return grouped.map { city, trips in
            RouteInfo(id: city, name: "\(city) → Saveetha", startCity: city, trips: trips, plannedPolyline: trips.first?.actualPolyline ?? [])
        }.sorted { $0.startCity < $1.startCity }
    }
    
    var filteredTrips: [HistoryTripDisplay] {
        allTrips.filter { visibleRoutes.contains($0.startCity) }
    }
    
    var filteredBusesAtDestination: [HistoryTripDisplay] {
        filteredTrips.filter { $0.status == "COMPLETED" }
    }
    
    var filteredGroupedRoutes: [RouteInfo] {
        let grouped = Dictionary(grouping: filteredTrips) { $0.startCity }
        return grouped.map { city, trips in
            RouteInfo(id: city, name: "\(city) → Saveetha", startCity: city, trips: trips, plannedPolyline: trips.first?.actualPolyline ?? [])
        }.sorted { $0.startCity < $1.startCity }
    }
    
    // MARK: - Route Filtering
    func toggleRoute(_ routeName: String) {
        if visibleRoutes.contains(routeName) {
            visibleRoutes.remove(routeName)
        } else {
            visibleRoutes.insert(routeName)
        }
    }
    
    func showAllRoutes() {
        visibleRoutes = Set(groupedRoutes.map { $0.startCity })
    }
    
    func clearAllRoutes() {
        visibleRoutes.removeAll()
    }

    // MARK: - Init
    init() {
        loadHistory(for: selectedDate)
    }
    
    // MARK: - Functions
    func loadHistory(for date: Date) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: date)
        
        self.isLoading = true
        Task {
            do {
                let fleetHistory = try await APIService.shared.fetchFleetHistory(date: dateStr)
                
                await MainActor.run {
                    self.allTrips = fleetHistory.map { trip in
                        let stops = (trip.stops ?? []).map { stop in
                            HistoryStop(
                                id: UUID(),
                                stopName: stop.stop_name,
                                coordinate: Coord(lat: stop.lat, lon: stop.lng),
                                reachedTime: stop.reached_time
                            )
                        }
                        
                        let actualPolyline = (trip.actual_polyline ?? []).map { pt in
                            Coord(lat: pt.lat, lon: pt.lng)
                        }
                        
                        // Find matching bus in repo or create a stable UUID
                        let busId = BusRepository.shared.allBuses.first(where: { 
                            $0.vehicleId == trip.trip_id || $0.busId == trip.bus_id || $0.number == trip.bus_number
                        })?.id ?? UUID()
                        
                        return HistoryTripDisplay(
                            id: UUID(),
                            busNumber: trip.bus_number ?? "N/A",
                            busId: busId,
                            routeName: trip.route_name ?? "Route",
                            startCity: trip.start_city ?? "Unknown",
                            actualPolyline: actualPolyline,
                            isDeviated: false,
                            status: trip.status ?? "COMPLETED",
                            startTime: trip.start_time ?? "--",
                            endTime: trip.end_time ?? "--",
                            reachedTime: trip.end_time,
                            duration: calculateDuration(start: trip.start_time, end: trip.end_time),
                            stops: stops
                        )
                    }
                    self.isLoading = false
                    self.showAllRoutes()
                }
            } catch {
                print("Failed to load history: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.allTrips = []
                }
            }
        }
    }
    
    private func calculateDuration(start: String?, end: String?) -> String {
        guard let start = start, let end = end else { return "--" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        guard let sDate = f.date(from: start), let eDate = f.date(from: end) else { return "--" }
        let diff = eDate.timeIntervalSince(sDate)
        let mins = Int(diff / 60)
        return "\(abs(mins))m"
    }
    
    // MARK: - Timeline Generation
    func generateTimelineEvents(for trip: HistoryTripDisplay, historyStops: [HistoryStop]) -> [TripTimelineEvent] {
        var events: [TripTimelineEvent] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        if let startDate = dateFormatter.date(from: trip.startTime) {
            events.append(TripTimelineEvent(timestamp: startDate, title: "Trip started from \(trip.startCity)", subtitle: "Bus \(trip.busNumber) departed", eventType: .tripStart))
        }
        
        for (index, stop) in historyStops.enumerated() {
            if let timeStr = stop.reachedTime, let date = dateFormatter.date(from: timeStr) {
                let isLastStop = index == historyStops.count - 1
                events.append(TripTimelineEvent(timestamp: date, title: isLastStop ? "Reached destination" : "Reached \(stop.stopName)", subtitle: isLastStop ? stop.stopName : nil, eventType: isLastStop ? .tripEnd : .stopReached))
            }
        }
        
        return events.sorted { $0.timestamp < $1.timestamp }
    }
}
