import SwiftUI
import Combine
import CoreLocation
import MapKit


@MainActor
class AvailableBusesViewModel: ObservableObject {
    private var etaTask: Task<Void, Never>?


    // MARK: - SortOption
    enum SortOption: String, CaseIterable {
        case departureTime = "Departure Time"
        case duration = "Duration"
    }

    @Published var sortOption: SortOption = .departureTime
    @Published var allRoutes: [RouteModel] = []
    @Published var errorText: String? = nil
    @Published var buses: [Bus] = [] // Kept for compatibility if needed, but using visibleBuses for list

    // List Optimization (Lazy Loading)
    @Published var visibleBuses: [Bus] = []
    private var allFilteredBuses: [Bus] = []
    private let pageSize = 5
    private var currentPage = 1

    // Real-time Trackers
    @Published var liveBusesOnRoute: [Bus] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Search Context Anchor
    private var currentSearchOrigin: String = ""
    private var currentSearchDestination: String = ""
    
    // Filters
    @Published var showOnTime = true
    @Published var showDelayed = true

    init() {
        setupBusesSubscriber()
    }
    
    private func setupBusesSubscriber() {
        BusRepository.shared.$buses
            .receive(on: RunLoop.main)
            .sink { [weak self] allBuses in
                self?.filterLiveBusesForRoute(allBuses)
            }
            .store(in: &cancellables)
    }
    
    private func filterLiveBusesForRoute(_ allGlobalBuses: [Bus]) {
        // Filter buses that are actually on the route being viewed
        // Using headsign or route number if possible
        // This makes sure markers only show for relevant buses
        self.liveBusesOnRoute = allGlobalBuses.filter { bus in
            // Basic matching: either number matches or headsign contains keywords
            let isRelevant = bus.number == self.allRoutes.first?.route_id || 
                            bus.headsign.localizedCaseInsensitiveContains(self.allRoutes.first?.name ?? "")
            return isRelevant && bus.isRunning
        }
    }

    // Route Visualization Data
    @Published var routePolyline: [CLLocationCoordinate2D] = []
    @Published var estimatedDistance: String? = nil
    @Published var estimatedTime: String? = nil



    // Firebase ref removed

    func load(from: String, to: String, fromID: String? = nil, toID: String? = nil, fromCoord: CLLocationCoordinate2D? = nil, toCoord: CLLocationCoordinate2D? = nil, via: String? = nil) {
        self.errorText = nil
        self.buses = []
        self.visibleBuses = []
        self.currentSearchOrigin = from
        self.currentSearchDestination = to
        
        Task {
            do {
                let allStops = try await APIService.shared.fetchAllStops()
                
                // 1. Resolve Coordinates for Source & Destination
                var startCoord = fromCoord
                var endCoord = toCoord
                
                if startCoord == nil || endCoord == nil {
                    if startCoord == nil {
                        startCoord = allStops.first(where: { $0.name.lowercased() == from.lowercased() })?.coordinate
                    }
                    if endCoord == nil {
                        endCoord = allStops.first(where: { $0.name.lowercased() == to.lowercased() })?.coordinate
                    }
                }
                // 2. Fetch Matching Trips from Backend with User identification
                let regNo = SessionManager.shared.currentUserRegNo
                let role = SessionManager.shared.userRole ?? "student"
                let trips = try await APIService.shared.fetchRoutesSearch(
                    fromName: from, 
                    toName: to,
                    regNo: regNo,
                    role: role
                )
                
                // 2.1 Parallelized Data Fetching (Stops & Timelines)
                let uniqueRouteIds = Set(trips.compactMap { $0.routeId })
                
                await withTaskGroup(of: Void.self) { group in
                    // Fetch Route Stops in parallel
                    for rid in uniqueRouteIds {
                        if self.routeStopsCache[rid] == nil {
                            group.addTask {
                                if let stops = try? await APIService.shared.fetchRouteStops(routeId: rid) {
                                    await MainActor.run { self.routeStopsCache[rid] = stops }
                                }
                            }
                        }
                    }
                    
                    // Fetch Timelines in parallel
                    for trip in trips {
                        let tid = trip.tripId
                        if self.tripTimelineCache[tid] == nil {
                            group.addTask {
                                if let result = try? await APIService.shared.fetchTimeline(tripId: tid) {
                                    await MainActor.run { self.tripTimelineCache[tid] = result.stops }
                                }
                            }
                        }
                    }
                }
                
                await MainActor.run {
                    self.buses = trips.map { trip in
                        // IDENTIFY TRUE NEXT STOP FROM DATABASE SEQUENCE
                        var identifiedNextStop = trip.nextStopName
                        
                        if let rid = trip.routeId, let rStops = self.routeStopsCache[rid] {
                            if let fromIdx = rStops.firstIndex(where: { $0.name.lowercased() == from.lowercased() }) {
                                if fromIdx + 1 < rStops.count {
                                    identifiedNextStop = rStops[fromIdx + 1].name
                                }
                            }
                        }
                        
                        let stableUUID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", trip.tripId)) ?? UUID()
                        let newBus = Bus(
                            id: stableUUID,
                            number: trip.busNo ?? "Bus",
                            headsign: trip.routeName ?? "Route",
                            departsAt: self.formatTime(trip.fromDeparture ?? "--:--"),
                            durationText: "\(trip.durationMinutes ?? 0) min",
                            status: .onTime,
                            statusDetail: trip.status ?? "Scheduled",
                            trackingStatus: (trip.status?.lowercased() == "live" || trip.status?.lowercased() == "running") ? .arriving : .scheduled,
                            etaMinutes: trip.durationMinutes,
                            route: Route(
                                from: self.currentSearchOrigin, 
                                to: self.currentSearchDestination, 
                                stops: []
                            ),
                            vehicleId: trip.tripId,
                            extTripId: trip.extTripId,
                            speed: Double(trip.busLiveLocation?.speed_mph ?? 0) * 1.60934, // mph to km/h
                            durationMinutes: trip.durationMinutes,
                            currentStopName: trip.currentStopName,
                            nextStopName: identifiedNextStop, 
                            arrivalsAt: self.formatTime(trip.toArrival ?? "--:--"),
                            currentCoordinate: trip.busLiveLocation.map { Coord(lat: $0.lat, lon: $0.lon) }
                        )
                        
                        // REQUIREMENT: Register in repository so navigation can find it
                        BusRepository.shared.register(bus: newBus)
                        return newBus
                    }
                    self.updateFiltering()
                    
                    if self.buses.isEmpty {
                        self.errorText = "No buses found for this route today."
                    }
                }
                
                // 3. Calculate Accurate Route Polyline & Info
                if let start = startCoord, let end = endCoord {
                    let request = MKDirections.Request()
                    request.source = MKMapItem(location: CLLocation(latitude: start.latitude, longitude: start.longitude), address: nil)
                    request.destination = MKMapItem(location: CLLocation(latitude: end.latitude, longitude: end.longitude), address: nil)
                    request.transportType = .automobile
                    
                    let directions = MKDirections(request: request)
                    let response = try? await directions.calculate()
                    
                    if let route = response?.routes.first {
                        await MainActor.run {
                            self.routePolyline = route.polyline.coordinates
                            let distKm = route.distance / 1000.0
                            self.estimatedDistance = String(format: "%.1f km", distKm)
                            
                            let mins = Int(route.expectedTravelTime / 60.0)
                            self.estimatedTime = "\(mins) min"
                            
                            // DISTANCE-BASED ETA RECALCULATION & LIVE STATUS
                            self.recalculateETAs(
                                allStops: allStops.map { b in 
                                    Stop(id: b.id, name: b.name, coordinate: Coord(lat: b.lat, lon: b.lng), timeText: nil) 
                                },
                                totalDist: route.distance,
                                totalTime: mins,
                                start: start,
                                end: end
                            )
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.errorText = "Unable to load schedules: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private var routeStopsCache: [Int: [Stop]] = [:]
    private var tripTimelineCache: [Int: [TimelineStop]] = [:]

    private func recalculateETAs(allStops: [Stop], totalDist: Double, totalTime: Int, start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) {
        etaTask?.cancel()
        etaTask = Task {
            for i in 0..<self.buses.count {
                if Task.isCancelled { return }
                let bus = self.buses[i]
                
                // 1. Dynamic Speed Resolver (Real-Time Velocity)
                let reportedSpeed = bus.liveTelemetry.speed
                let effectiveSpeedKmph = reportedSpeed > 5.0 ? reportedSpeed : 25.0
                let _ = effectiveSpeedKmph / 3.6
                
                // 2. Terminal Arrival (Using Apple Maps MKDirections for Accuracy)
                if let current = bus.currentCoordinate {
                    let request = MKDirections.Request()
                    request.source = MKMapItem(location: CLLocation(latitude: current.lat, longitude: current.lon), address: nil)
                    request.destination = MKMapItem(location: CLLocation(latitude: end.latitude, longitude: end.longitude), address: nil)
                    request.transportType = .automobile
                    
                    if let response = try? await MKDirections(request: request).calculate(),
                       let route = response.routes.first {
                        let mins = Int(ceil(route.expectedTravelTime / 60.0))
                        
                        await MainActor.run {
                            self.buses[i].etaMinutes = mins
                            self.buses[i].durationText = "\(mins) min"
                            
                            // 3. RE-ENFORCE CONTEXT Naming (Protect against stale/trip-start data)
                            self.buses[i].route.from = self.currentSearchOrigin
                            self.buses[i].route.to = self.currentSearchDestination
                            
                            // 3. Punctuality is handled by the model's delayLabel now
                            if let schedDate = self.parseTimeToday(self.buses[i].arrivalsAt) {
                                let projectedDate = Date().addingTimeInterval(TimeInterval(mins * 60))
                                let delay = Int(projectedDate.timeIntervalSince(schedDate) / 60.0)
                                
                                if delay > 2 {
                                    self.buses[i].status = .delayed
                                    self.buses[i].statusDetail = "\(delay) min delayed"
                                } else {
                                    self.buses[i].status = .onTime
                                    self.buses[i].statusDetail = "On Time"
                                }
                            }
                        }
                    }
                }
                
                // 3. Next Stop Arrival (Apple Maps)
                if let nextName = bus.nextStopName,
                   let nextStop = allStops.first(where: { $0.name.lowercased() == nextName.lowercased() }),
                   let current = bus.currentCoordinate {
                    let etaStr = await calculateNextStopETA(start: current.cl, end: nextStop.coordinate.cl)
                    await MainActor.run {
                        self.buses[i].nextStopETA = etaStr
                    }
                }
            }
            await MainActor.run {
                self.updateFiltering()
            }
        }
    }

    private func calculateNextStopETA(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) async -> String {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: start.latitude, longitude: start.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: end.latitude, longitude: end.longitude), address: nil)
        request.transportType = .automobile
        
        if let response = try? await MKDirections(request: request).calculate(),
           let route = response.routes.first {
            let mins = Int(ceil(route.expectedTravelTime / 60.0))
            return "\(mins) min"
        }
        return "--:--"
    }

    // Overload for initial load compatibility
    private func calculateNextStopETA(departure: String) -> String {
        guard departure != "--:--" else { return "--:--" }
        // For initial display before GPS kicks in, assume 18 mins for Poonamallee as per user requirement
        return offsetTime(departure: formatTime(departure), plusMins: 18)
    }

    private func currentTimePlus(plusMins: Int) -> String {
        let future = Date().addingTimeInterval(TimeInterval(plusMins * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: future)
    }

    private func parseTimeToday(_ timeStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        guard let timeDate = formatter.date(from: timeStr) else { return nil }
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let tComp = Calendar.current.dateComponents([.hour, .minute], from: timeDate)
        comp.hour = tComp.hour
        comp.minute = tComp.minute
        return Calendar.current.date(from: comp)
    }

    private func haversineDistance(q: CLLocationCoordinate2D, p: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let dLat = (p.latitude - q.latitude) * .pi / 180.0
        let dLon = (p.longitude - q.longitude) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(q.latitude * .pi / 180.0) * cos(p.latitude * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    private func offsetTime(departure: String, plusMins: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        let cleanDep = departure.contains(":") ? departure : formatTime(departure)
        if let date = formatter.date(from: cleanDep) {
            let nextDate = date.addingTimeInterval(TimeInterval(plusMins * 60))
            return formatter.string(from: nextDate)
        }
        return "--:--"
    }

    private func formatTime(_ timestamp: String) -> String {
        if timestamp == "--:--" || timestamp.isEmpty { return "--:--" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let clean = timestamp.replacingOccurrences(of: "Z", with: "")
        
        // Try multiple ISO formats (with and without fractional seconds)
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "HH:mm:ss",
            "HH:mm"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: clean) {
                let df = DateFormatter()
                df.dateFormat = "hh:mm a"
                return df.string(from: date)
            }
        }
        
        // Handle simple HH:mm directly if parsing failed
        if timestamp.contains(":") {
            let parts = timestamp.split(separator: "T").last?.split(separator: ":") ?? []
            if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                let period = h >= 12 ? "PM" : "AM"
                let h12 = h % 12 == 0 ? 12 : h % 12
                return String(format: "%02d:%02d %@", h12, m, period)
            }
        }
        
        return timestamp
    }

    func loadMore() {
        guard visibleBuses.count < allFilteredBuses.count else { return }
        let nextIndex = currentPage * pageSize
        let countToLoad = min(pageSize, allFilteredBuses.count - nextIndex)
        if countToLoad > 0 {
            visibleBuses.append(contentsOf: allFilteredBuses[nextIndex..<(nextIndex + countToLoad)])
            currentPage += 1
        }
    }
    
    func updateFiltering() {
        var result = buses
        if !showOnTime  { result = result.filter { $0.status != .onTime } }
        if !showDelayed { result = result.filter { $0.status != .delayed } }
        
        switch sortOption {
        case .departureTime: result.sort { $0.departsAt < $1.departsAt }
        case .duration:      result.sort { $0.durationText < $1.durationText }
        }
        
        self.allFilteredBuses = result
        self.currentPage = 1
        self.visibleBuses = Array(self.allFilteredBuses.prefix(pageSize))
    }

    func applyFilterState(from: String, to: String, fromID: String? = nil, toID: String? = nil, fromCoord: CLLocationCoordinate2D? = nil, toCoord: CLLocationCoordinate2D? = nil, via: String? = nil) {
        updateFiltering()
    }
}
