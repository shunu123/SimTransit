import Foundation
import Combine
import SwiftUI
import CoreLocation
import MapKit

@MainActor
final class LiveTrackingViewModel: ObservableObject {
    @Published var bus: Bus

    @Published var traveledPath: [Coord] = []
    @Published var fullRoutePath: [Coord] = []
    @Published var currentIndex: Double = 0.0
    @Published var remainingPath: [Coord] = []
    @Published var connectionToRoute: [Coord] = [] // Segment from GPS to nearest road point
    @Published var autoRecenter: Bool = true
    @Published var isLive: Bool = true
    @Published var isHistorical: Bool = false {
        didSet { loadHistoryData() }
    }
    @Published var selectedDate: Date = Date() {
        didSet { loadHistoryData() }
    }
    @Published var isHistoryEmpty: Bool = false
    @Published var isHistoryScheduled: Bool = false
    @Published var showScheduledStopsOnly: Bool = false {
        didSet { if showScheduledStopsOnly { populateScheduledHistory() } }
    }
    @Published var historyTripStatus: String? = nil
    @Published var historySearchRange: String? = nil
    @Published var currentSpeed: Int = 0
    @Published var speedKmph: Int? = nil // Requirement B: Live speed
    @Published var lastStopTime: String = "--:--"
    @Published var nearestStopName: String = ""
    @Published var nextStopName: String = ""
    @Published var isLoadingTimeline: Bool = false
    @Published var isAtStop: Bool = false
    @Published var now: Date = Date()
    @Published var currentCoordinate: Coord = Coord(lat: 0, lon: 0)
    @Published var sourceName: String = ""
    @Published var destName: String = ""
    
    // Requirement: Two-color route visualization (Pickup vs Trip)
    @Published var pickupPath: [Coord] = []
    @Published var tripPath: [Coord] = []
    @Published var isApproachingSource: Bool = false
    
    private var lastDirectionsUpdate: Date? = nil
    private var isFetchingDirections: Bool = false
    
    // Arrival and Duration Taken
    @Published var arrivalAtNextStop: String? = nil
    @Published var durationTakenMinutes: Int = 0
    @Published var estimatedDistance: String? = nil
    @Published var estimatedTime: String? = nil
    @Published var scheduledArrivalTime: String? = nil
    @Published var delayStatus: String? = nil
    private var tripStartTime: Date? = nil
    
    // UI Labels for Floating Card
    @Published var busName: String = ""
    @Published var durationToDestination: String = "--"
    
    var currentTimeString: String {
        let df = DateFormatter()
        df.dateFormat = "h:mm"
        return df.string(from: now)
    }
    
    var plannedPolyline: [Coord] {
        return fullRoutePath
    }

    var actualPolyline: [Coord] {
        let busToTrack = selectedBusForDetail ?? bus
        if busToTrack.id == bus.id {
            return traveledPath
        } else {
            let stopsCount = max(1, displayedStops.count)
            let pointsPerStop = Double(fullRoutePath.count) / Double(stopsCount)
            let stopIdx = busToTrack.currentStopIndex
            let count = Int(Double(stopIdx) * pointsPerStop)
            return Array(fullRoutePath.prefix(max(0, count)))
        }
    }

    // Phase 5: Dynamic Pin Detection
    var deviationStartCoord: Coord? {
        // First point of the first off-route segment
        return actualOffRouteSegments.first?.coords.first
    }

    var rejoiningCoord: Coord? {
        // First point of the last on-route segment, IF there was an off-route segment before it
        guard let firstOffEnd = actualOffRouteSegments.last?.coords.last else { return nil }
        // Find the first on-route point AFTER the last off-route point
        let onSegments = actualOnRouteSegments
        for seg in onSegments {
            if let first = seg.coords.first, actualPolyline.firstIndex(where: { $0.id == first.id }) ?? 0 > actualPolyline.firstIndex(where: { $0.id == firstOffEnd.id }) ?? 0 {
                return first
            }
        }
        return nil
    }
    
    var deviationStartStopIndex: Int? {
        guard let start = deviationStartCoord else { return nil }
        return bus.route.stops.enumerated().min(by: { 
            distance($0.element.coordinate, start) < distance($1.element.coordinate, start)
        })?.offset
    }
    
    @Published var displayedStops: [Stop] = [] { // Source-relative stops
        didSet {
            // Re-snap whenever stops change (e.g. async backend load)
            let stopsSnapshot = displayedStops
            Task {
                let snapped = await RoadSnapService.shared.snap(stops: stopsSnapshot)
                await MainActor.run {
                    self.fullRoutePath = snapped
                    print("Road snap updated: \(snapped.count) pts for \(stopsSnapshot.count) stops")
                }
            }
        }
    }

    @Published var otherBuses: [Bus] = []
    private var otherBusIndices: [Double] = []

    @Published var showUpcoming: Bool = true
    @Published var showDeparted: Bool = true
    @Published var showScheduled: Bool = false
    
    // alarm
    @Published var alarmStopName: String = ""
    @Published var alarmStopsBefore: Int = 2
    @Published var alarmEnabled: Bool = false
    private var wsSubscription: AnyCancellable?
    
    @Published var selectedBusForDetail: Bus?
    
    let sourceCoord: Coord?
    let destinationCoord: Coord?
    private let sourceStop: String?
    private let destinationStop: String?
    var isIsolatedMode: Bool {
        selectedBusForDetail?.isDeviated ?? false
    }

    var reachedStops: [Stop] {
        let busToTrack = selectedBusForDetail ?? bus
        let stopsCount = max(1, displayedStops.count)
        let idx = (busToTrack.id == bus.id) ? Int(currentIndex) : (busToTrack.currentStopIndex * Int(Double(fullRoutePath.count) / Double(stopsCount)))
        let pointsPerStop = Double(fullRoutePath.count) / Double(stopsCount)
        let currentStopIdxInt = pointsPerStop > 0 ? Int(Double(idx) / pointsPerStop) : 0
        return Array(displayedStops.prefix(currentStopIdxInt + 1))
    }

    @Published var actualOnRouteSegments: [PathSegment] = []
    @Published var actualOffRouteSegments: [PathSegment] = []
    
    // Apple Maps Integration
    @Published var appleMapsETAs: [String: Int] = [:]
    private var lastETARefresh: Date = .distantPast

    @Published var isWaitingForGPS: Bool = true
    private var lastLiveUpdate: Date = .distantPast

    private func updatePathSegments() {
        let fullRoute = fullRoutePath
        let actualPath = traveledPath
        guard !actualPath.isEmpty else { 
            actualOnRouteSegments = []
            actualOffRouteSegments = []
            return 
        }
        
        var onSegs: [PathSegment] = []
        var offSegs: [PathSegment] = []
        
        var currentOnCoords: [Coord] = []
        var currentOffCoords: [Coord] = []
        
        let tolerance = 0.0005 // Approx 50 meters
        
        for coord in actualPath {
            let isOffRoute = !fullRoute.contains(where: { abs($0.lat - coord.lat) < tolerance && abs($0.lon - coord.lon) < tolerance })
            
            if isOffRoute {
                if !currentOnCoords.isEmpty {
                    onSegs.append(PathSegment(coords: currentOnCoords, isDiverted: false))
                    currentOnCoords = []
                }
                currentOffCoords.append(coord)
            } else {
                if !currentOffCoords.isEmpty {
                    offSegs.append(PathSegment(coords: currentOffCoords, isDiverted: true))
                    currentOffCoords = []
                }
                currentOnCoords.append(coord)
            }
        }
        
        if !currentOnCoords.isEmpty { onSegs.append(PathSegment(coords: currentOnCoords, isDiverted: false)) }
        if !currentOffCoords.isEmpty { offSegs.append(PathSegment(coords: currentOffCoords, isDiverted: true)) }
        
        self.actualOnRouteSegments = onSegs
        self.actualOffRouteSegments = offSegs
    }

    private var timer: Timer?
    private var haltTicks: Int = 0

    var isFuture: Bool {
        Calendar.current.startOfDay(for: selectedDate) > Calendar.current.startOfDay(for: Date())
    }

    init(bus: Bus, isHistorical: Bool = false, date: Date? = nil, sourceStop: String? = nil, destinationStop: String? = nil, sourceCoord: Coord? = nil, destinationCoord: Coord? = nil) {
        self.bus = bus
        self.sourceStop = sourceStop
        self.destinationStop = destinationStop
        
        self.sourceName = sourceStop ?? bus.route.startPointName
        self.destName = destinationStop ?? bus.route.endPointName
        self.busName = bus.number
        
        // Defensive: Ignore 0,0 coordinates which cause map to jump to equator
        self.sourceCoord = (sourceCoord?.lat == 0 && sourceCoord?.lon == 0) ? nil : sourceCoord
        self.destinationCoord = (destinationCoord?.lat == 0 && destinationCoord?.lon == 0) ? nil : destinationCoord
        self.selectedDate = date ?? Date()
        
        // Immediate initialization of header names from search results
        if let source = sourceStop { self.bus.route.startPointName = source }
        if let destination = destinationStop { self.bus.route.endPointName = destination }
        
        // 1. FILTER STOPS PERSISTENTLY (CRITICAL: NEVER EMPTY)
        var displayStops = bus.route.stops
        if let source = sourceStop, let destination = destinationStop {
            displayStops = bus.stopsFromTo(sourceName: source, destinationName: destination)
        } else if let source = sourceStop {
            displayStops = bus.stopsFrom(sourceName: source)
        }
        
        // If bus.route.stops was empty (e.g. from a search that didn't fetch full timeline yet)
        // ensure we atleast have the source/destination as pseudo-stops if coordinates mapping exists
        if displayStops.isEmpty {
             if let sName = sourceStop, let sC = sourceCoord {
                 displayStops.append(Stop(id: "source", name: sName, coordinate: sC, timeText: "08:00", isMajorStop: true, stopOrder: 0))
             }
             if let dName = destinationStop, let dC = destinationCoord {
                 displayStops.append(Stop(id: "dest", name: dName, coordinate: dC, timeText: "09:00", isMajorStop: true, stopOrder: 999))
             }
        }
        
        self.displayedStops = displayStops
        print("LiveTrackingViewModel: Initialized with \(displayStops.count) stops (Source: \(sourceStop ?? "nil"))")

        // 2. Build path from relevant stops immediately
        let plannedPath = TrackingSimulationService.shared.buildPath(stops: displayStops)
        self.bus.route.plannedPolyline = plannedPath
        self.fullRoutePath = plannedPath
        
        if isHistorical || isFuture {
            self.traveledPath = isFuture ? [] : plannedPath
            self.currentIndex = isFuture ? 0.0 : Double(max(0, plannedPath.count - 1))
        } else {
            self.traveledPath = []
            self.currentIndex = 0.0
            
            // Load other buses for context
            let all = BusRepository.shared.allBuses
            self.otherBuses = all.filter { b in
                b.id != bus.id && 
                b.route.from == bus.route.from && 
                b.route.to == bus.route.to
            }
        }
        
        // COORDINATE: Default to (0,0) if no telemetry is present. 
        // DO NOT fallback to first stop as it causes fake pins.
        self.currentCoordinate = bus.currentCoordinate ?? Coord(lat: 0, lon: 0)
        print("LiveTrackingViewModel: Initial coordinate set to \(self.currentCoordinate.lat), \(self.currentCoordinate.lon)")
        
        // Reset stale search data
        self.estimatedDistance = nil
        self.estimatedTime = nil
        self.delayStatus = nil
        
        loadHistoryData()
        
        // Always try to refresh timeline info from backend, but never clear existing stops if it fails
        self.isLoadingTimeline = displayStops.isEmpty
        loadTimelineIfNeeded()
        
        // Always trigger road snapping (Apple Maps road matching)
        if !displayStops.isEmpty {
            snapToRoads()
        }
        
        // Initialize scheduled arrival time from bus or last stop
        self.scheduledArrivalTime = bus.arrivalsAt
    }

    @Published var isUsingDBPath: Bool = false
    
    private func snapToRoads() {
        let stopsSnapshot = displayedStops
        Task {
            let snapped = await RoadSnapService.shared.snap(stops: stopsSnapshot)
            await MainActor.run {
                // If we get a valid snapped roadmap, always prefer it over the straight-line skeleton
                if !snapped.isEmpty {
                    self.fullRoutePath = snapped
                    self.remainingPath = snapped // Initialize remaining path so bold line shows up
                    print("Road snapping success: \(snapped.count) points")
                }
            }
        }
    }
    
    private func decodeDBPolyline(_ poly: String) -> [Coord] {
        // 1. Try JSON Decoding (Recommended: [{"lat": 1.2, "lng": 3.4}, ...])
        if let data = poly.data(using: .utf8) {
            struct DBPoint: Codable { let lat: Double; let lng: Double }
            if let points = try? JSONDecoder().decode([DBPoint].self, from: data) {
                return points.map { Coord(lat: $0.lat, lon: $0.lng) }
            }
        }
        
        // 2. Try Pipe/Comma format decoding (Fallback: lat,lng|lat,lng)
        let pairs = poly.components(separatedBy: "|")
        if pairs.count > 1 {
            var coords: [Coord] = []
            for pair in pairs {
                let parts = pair.components(separatedBy: ",")
                if parts.count == 2, let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)), 
                   let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    coords.append(Coord(lat: lat, lon: lon))
                }
            }
            if !coords.isEmpty { return coords }
        }
        
        return []
    }
    
    private func loadTimelineIfNeeded() {
        Task {
            do {
                let idParam = bus.extTripId ?? (bus.vehicleId != nil ? "\(bus.vehicleId!)" : nil)
                guard let identifier = idParam, identifier != "0" else {
                    print("LiveTrackingViewModel: No valid trip identifier found for bus \(bus.number). Using original stops.")
                    await MainActor.run { 
                        self.isLoadingTimeline = false 
                        if self.displayedStops.isEmpty {
                            self.displayedStops = self.bus.route.stops
                        }
                    }
                    return
                }
                print("LiveTrackingViewModel: Fetching timeline for trip \(identifier)...")
                let result = try await APIService.shared.fetchTimeline(tripId: bus.vehicleId, extTripId: bus.extTripId)
                let timelineStops = result.stops
                let dbPolylineString = result.polyline
                
                let newStops = timelineStops.sorted { $0.stopOrder < $1.stopOrder }.map { $0.toStop() }
                
                await MainActor.run {
                    if let poly = dbPolylineString, !poly.isEmpty {
                        // Attempt to decode database polyline
                        let coords = self.decodeDBPolyline(poly)
                        if !coords.isEmpty {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                self.fullRoutePath = coords
                                self.remainingPath = coords // Default to full path so bold blue line shows up
                                self.isUsingDBPath = true // Crucial: Prevents road-snap from overwriting high-res path
                                self.bus.route.plannedPolyline = coords // Ensures MapPolyline renders these specific coords
                            }
                            print("LiveTrackingViewModel: Using high-resolution path from database (\(coords.count) points)")
                        }
                    }

                    if !newStops.isEmpty {
                        print("LiveTrackingViewModel: Received \(newStops.count) stops from backend for \(identifier). Updating UI...")
                        self.bus.route.stops = newStops
                        
                        // Re-filter displayedStops for the active segment
                        var displayStops = newStops
                        if let source = self.sourceStop, let destination = self.destinationStop {
                             // Use bus helper or local filtering
                             displayStops = self.bus.stopsFromTo(sourceName: source, destinationName: destination)
                        } 
                        
                        withAnimation {
                            self.displayedStops = displayStops
                            // Requirement: Replace generic header labels with actual start/end stop names
                            self.bus.route.startPointName = displayStops.first?.name ?? "Start"
                            self.bus.route.endPointName = displayStops.last?.name ?? "End"
                        }
                        
                        print("LiveTrackingViewModel: UI refreshed with actual schedule names.")
                        
                        // If we didn't have a DB polyline but got new stops, trigger a road snap
                        if !self.isUsingDBPath {
                            self.snapToRoads()
                        }
                    }
                    self.isLoadingTimeline = false
                    recalculateTwoColorPaths()
                }
            } catch {
                print("LiveTrackingViewModel: Error loading timeline - \(error.localizedDescription)")
                await MainActor.run { 
                    self.isLoadingTimeline = false 
                    if self.displayedStops.isEmpty {
                         self.displayedStops = self.bus.route.stops
                    }
                }
            }
        }
    }


    private func populateScheduledHistory() {
        let stopsToTrack = self.displayedStops.isEmpty ? self.bus.route.stops : self.displayedStops
        self.bus.historyStops = stopsToTrack.map { HistoryStop(stopName: $0.name, reachedTime: nil) }
        self.fullRoutePath = TrackingSimulationService.shared.buildPath(stops: stopsToTrack)
        self.traveledPath = []
        self.currentIndex = 0
    }

    private func loadHistoryData() {
        self.selectedBusForDetail = nil // Requirement: History mode tracks primary bus only
        self.showScheduledStopsOnly = false
        
        // Force live mode if today is selected
        if Calendar.current.isDateInToday(self.selectedDate) && isHistorical {
            self.isHistorical = false
            return
        }
        
        if isHistorical {
            // 1. Calculate IST Range (Requirement: 00:00:00 to 23:59:59 IST)
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: self.selectedDate)
            components.hour = 0
            components.minute = 0
            components.second = 0
            let start = calendar.date(from: components) ?? self.selectedDate
            components.hour = 23
            components.minute = 59
            components.second = 59
            let end = calendar.date(from: components) ?? self.selectedDate
            
            let df = DateFormatter()
            df.dateFormat = "MMM dd, HH:mm"
            self.historySearchRange = "\(df.string(from: start)) — \(df.string(from: end))"
            
            // 2. Check Schedule (Simulated: Scheduled for weekdays)
            // 3. Fetch History Record from Backend
            guard let tripId = bus.vehicleId else {
                self.isHistoryEmpty = true
                return
            }
            
            let dateStr = {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: self.selectedDate)
            }()
            
            Task {
                do {
                    let gpsPoints = try await APIService.shared.fetchTripHistory(tripId: tripId, date: dateStr)
                    await MainActor.run {
                        if gpsPoints.isEmpty {
                            self.isHistoryEmpty = true
                            print("No history GPS points found for trip \(tripId) on \(dateStr)")
                        } else {
                            self.isHistoryEmpty = false
                            self.historyTripStatus = "Completed"
                            self.traveledPath = gpsPoints.map { Coord(lat: $0.lat, lon: $0.lng) }
                            if let last = self.traveledPath.last {
                                let closestIdx = findClosestIndex(on: fullRoutePath, to: last)
                                self.currentIndex = Double(closestIdx)
                            }
                            print("Loaded \(gpsPoints.count) history points for trip \(tripId) on \(dateStr)")
                        }
                    }
                } catch {
                    print("Failed to load history for trip \(tripId) on \(dateStr): \(error.localizedDescription)")
                    await MainActor.run { self.isHistoryEmpty = true }
                }
            }
        } else {
            self.isHistoryEmpty = false
            self.isHistoryScheduled = true
            self.historySearchRange = nil
            // Live mode starts with empty history, populated as it moves
            let stopsToTrack = self.displayedStops.isEmpty ? self.bus.route.stops : self.displayedStops
            self.bus.historyStops = stopsToTrack.map { HistoryStop(stopName: $0.name, reachedTime: nil) }
        }
    }

    var stops: [Stop] { displayedStops }

    var __unused_coord: Coord {
        if fullRoutePath.isEmpty { 
            return bus.route.stops.first?.coordinate ?? Coord(lat: 0, lon: 0) 
        }
        let idx = Int(min(currentIndex, Double(max(0, fullRoutePath.count - 1))))
        return fullRoutePath[idx]
    }

    // Backend Integration
    // We now fetch directly from the Transit Proxy
    private func syncWithFullDetails() {
        if isHistorical { return }
        
        let rt = bus.extRouteId ?? String(bus.route.id.uuidString.prefix(2)) // Fallback or extracted
        let dir = bus.statusDetail?.contains("East") == true ? "Eastbound" : "Westbound" // Dynamic heuristic or from state
        let vid = String(bus.vehicleId ?? 0)
        
        let finalRt = rt
        let finalVid = vid
        
        Task {
            do {
                print("LiveTrackingViewModel: Syncing full details for Route \(finalRt), VID \(finalVid)...")
                // Only show loading if we have NO stops yet
                if self.displayedStops.isEmpty { self.isLoadingTimeline = true }
                
                let details = try await APIService.shared.fetchFullTripDetails(routeId: finalRt, direction: dir, vehicleId: finalVid)
                
                await MainActor.run {
                    self.isLoadingTimeline = false
                    // 1. Update Polylines
                    if !details.polyline.isEmpty {
                        self.fullRoutePath = details.polyline.map { Coord(lat: $0.lat, lon: $0.lng) }
                    }
                    
                    // 2. Update Timeline / Stops
                    let newStops = details.timeline.map { $0.toStop() }
                    
                    if !newStops.isEmpty {
                        self.bus.route.stops = newStops
                        
                        // 3. Update History Status
                        self.bus.historyStops = details.timeline.map { stop in
                            HistoryStop(
                                stopName: stop.stopName, 
                                coordinate: Coord(lat: stop.lat, lon: stop.lng),
                                reachedTime: stop.status == "Reached" ? stop.eta : nil
                            )
                        }
                    } else if self.displayedStops.isEmpty {
                        // Fallback if timeline is empty but we expected data
                        print("LiveTrackingViewModel: Warning - Backend returned empty timeline")
                    }
                    
                    // 4. Update Current Location via Gateway
                    // Instead of manual direct assignment (which causes jumping), 
                    // we route the API location through our central validation gateway.
                    if let liveLoc = details.live_location {
                        self.handleGPSUpdate(
                            lat: liveLoc.lat, 
                            lon: liveLoc.lon, 
                            speed: 0, // Speed can stay 0 here as it's a fallback API
                            bearing: nil, 
                            isFromWebSocket: false
                        )
                    }
                    
                    // Ensure road-aware paths and timeline UI are updated
                    self.recalculateDisplayedStops()
                    self.recalculateTwoColorPaths()
                }
            } catch {
                print("LiveTrackingViewModel: Full details sync failed:", error)
            }
        }
    }

    private func fetchBackendData() {
        syncWithFullDetails()
    }

    func start() {
        print("LiveTrackingViewModel: Starting... isHistorical=\(isHistorical)")
        stop()
        
        syncWithFullDetails()
        
        if isHistorical || isFuture {
            if isFuture {
                self.traveledPath = []
                self.currentIndex = 0.0
            } else if self.traveledPath.isEmpty {
                // If no real history was fetched, fallback to full route
                self.traveledPath = fullRoutePath
                self.currentIndex = Double(max(0, fullRoutePath.count - 1))
            }
            return
        }

        // Fetch historical path for the current trip to show previous movement
        if let tid = bus.vehicleId {
            Task {
                do {
                    let points = try await APIService.shared.fetchTripCoordinates(tripId: tid)
                    await MainActor.run {
                        self.traveledPath = points
                        self.autoRecenter = true
                        self.updateNextStopInfo()
                    }
                } catch {
                    print("Error fetching trip coordinates: \(error)")
                }
            }
        }
        
        isLive = true
        
        // 1. WebSocket Subscription (Primary Data Source)
        WebSocketService.shared.connect()
        wsSubscription = WebSocketService.shared.gpsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (vehicles: [WSVehicle]) in
                guard let self = self else { return }
                // Normalizing IDs for matching (handling "Bus 1" vs "Bus1" vs "1")
                let cleanOurTripId = (self.bus.extTripId ?? "").replacingOccurrences(of: " ", with: "").lowercased()
                let cleanOurBusNo = self.bus.number.replacingOccurrences(of: " ", with: "").lowercased().replacingOccurrences(of: "bus", with: "")
                
                if let update = vehicles.first(where: { 
                    let vVid = ($0.vid ?? "").replacingOccurrences(of: " ", with: "").lowercased().replacingOccurrences(of: "bus", with: "")
                    let vRt = ($0.rt ?? "").replacingOccurrences(of: " ", with: "").lowercased().replacingOccurrences(of: "bus", with: "")

                    // Aggressive Matching: Check if numeric ID parts match or route name matches bus number
                    return (!cleanOurTripId.isEmpty && vVid.contains(cleanOurTripId)) || 
                           (!cleanOurBusNo.isEmpty && vVid == cleanOurBusNo) ||
                           (!cleanOurBusNo.isEmpty && vRt.contains(cleanOurBusNo))
                }) {
                    // Trigger centralized GPS processing
                    self.handleGPSUpdate(
                        lat: update.latDouble, 
                        lon: update.lonDouble, 
                        speed: update.spd, 
                        bearing: update.hdg, 
                        isFromWebSocket: true
                    )
                }
            }
        
        // 2. Throttled Animation Timer (1.0s)
        // Every 1.0s we move bit by bit to reduce CPU load and keep movement smooth
        // 3. HTTP Polling Backup (Reliable Database Source)
        Task {
            while isLive {
                do {
                    // Use extTripId first, fallback to normalized bus number (e.g. "Bus 1" -> "Bus1")
                    let tidForPolling = bus.extTripId ?? bus.number.replacingOccurrences(of: " ", with: "")
                    if let latest = try await APIService.shared.fetchTripLatestGPS(tripId: bus.vehicleId, extTripId: tidForPolling) {
                        await MainActor.run {
                            self.handleGPSUpdate(
                                lat: latest.lat, 
                                lon: latest.lng, 
                                speed: latest.speed, 
                                bearing: nil, 
                                isFromWebSocket: false
                            )
                        }
                    }
                } catch {
                    print("LiveTrackingViewModel: GPS Polling error: \(error)")
                }
                
                try? await Task.sleep(nanoseconds: 5_000_000_000) // Poll every 5 seconds
            }
        }
    }
    
    func refresh() {
        Task { @MainActor in
            self.tick()
        }
        fetchBackendData()
        snapToRoads()
    }

    func stop() {
        isLive = false // Stop polling loop
        timer?.invalidate()
        timer = nil
        wsSubscription?.cancel()
        wsSubscription = nil
    }

    private func tick() {
        self.now = Date()
        updatePathSegments()
        
        // Update isAtStop status
        if !displayedStops.isEmpty && bus.currentStopIndex < displayedStops.count {
            let stop = displayedStops[bus.currentStopIndex]
            let dist = distance(currentCoordinate, stop.coordinate)
            isAtStop = dist < 0.0005 // Approx 50 meters
        }
        
        // Fast polling for the specific bus we are tracking (every 15s as a fallback to websockets)
        if !isHistorical {
            fastPollingTick += 1
            if fastPollingTick >= 15 {
                fastPollingTick = 0
                syncWithFullDetails()
            }
            
            // APPLE MAPS ETA REFRESH (Every 1 minute)
            if Date().timeIntervalSince(lastETARefresh) > 60 {
                refreshAppleMapsETAs()
            }
        }

        if isHistorical { return }
        
        // Re-calculate last major stop time
        let currentStopIndexInt = bus.currentStopIndex
        let passedStops = displayedStops.prefix(currentStopIndexInt + 1)

        if let lastMajorStop = passedStops.last(where: { $0.isMajorStop }) {
            self.lastStopTime = lastMajorStop.timeText ?? "--:--"
        } else {
            self.lastStopTime = displayedStops.first?.timeText ?? "--:--"
        }
        
        // 7. Reached Destination Logic
        if !fullRoutePath.isEmpty && currentIndex >= Double(fullRoutePath.count - 1) && !bus.hasReachedDestination {
            self.bus.hasReachedDestination = true
            self.bus.trackingStatus = .ended
            self.bus.statusDetail = "Arrived"
        }
    }
    
    func updateNextStopInfo() {
        let stops = displayedStops
        guard !stops.isEmpty else { return }
        
        // 1. Find the trip progress: find the nearest point on the full route path
        
        
        // 2. Find Nearest Stop and Next Stop
        // Heuristic: Find the stop with the smallest distance that hasn't been passed.
        // A stop is "passed" if its stopOrder is less than our current estimated stop index.
        
        let pathCount = Double(max(1, fullRoutePath.count))
        let stopsCount = Double(max(1, stops.count))
        let pointsPerStop = pathCount / stopsCount
        
        let currentPassIdx = Int(currentIndex / max(1.0, pointsPerStop))
        
        // The display logic for next stop
        if currentPassIdx + 1 < stops.count {
            let targetStop = stops[currentPassIdx + 1]
            self.nextStopName = targetStop.name
            self.arrivalAtNextStop = targetStop.timeText
        } else {
            self.nextStopName = "Destination Reached"
            self.arrivalAtNextStop = "--:--"
        }
        
        // 3. Final Destination Duration
        if let mins = self.appleMapsETAs["destination"] {
            self.durationToDestination = "\(mins) min"
        } else if let last = stops.last {
            self.durationToDestination = last.timeText ?? "--"
        }
    }
    
    
    // updateOtherBuses removed as we rely on backend data
    private func updateOtherBuses() {
        // No-op or removed. Keeping empty method if called elsewhere, 
        // but I removed the call in tick, so safe to remove.
        // Actually, ensuring filteredOtherBuses logic works without indices updates.
        // Since we update otherBuses in fetchBackendData, we don't need to simulate movement.
    }
    
    // Requirement B: Helper properties
    var nextStop: Stop? {
        guard !displayedStops.isEmpty, !fullRoutePath.isEmpty else { return nil }
        let busToTrack = selectedBusForDetail ?? bus
        let stopsCount = Double(max(1, displayedStops.count))
        let pathCount = Double(max(1, fullRoutePath.count))
        let liveIndexValue = (busToTrack.id == bus.id) ? Int(currentIndex / (pathCount / stopsCount)) : busToTrack.currentStopIndex
        
        let clampedIndex = min(max(0, liveIndexValue), max(0, displayedStops.count - 1))
        if clampedIndex + 1 < displayedStops.count {
            return displayedStops[clampedIndex + 1]
        }
        return nil
    }
    
    func etaToStop(index: Int) -> Int {
        guard index >= 0, index < displayedStops.count else { return 0 }
        let stop = displayedStops[index]
        return appleMapsETAs[stop.id] ?? 0
    }

    private func parseTimeToday(_ timeStr: String) -> Date? {
        let ist = TimeZone(identifier: "Asia/Kolkata") ?? TimeZone(secondsFromGMT: 19800)!
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = ist
        guard let timeDate = f.date(from: timeStr) else { return nil }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let timeComps = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
        components.hour = timeComps.hour
        components.minute = timeComps.minute
        components.second = timeComps.second
        
        return calendar.date(from: components)
    }

    private func refreshAppleMapsETAs() {
        // Requirement 1 & 3: Handle Not Running or No GPS
        guard bus.isRunning, 
              currentCoordinate.lat != 0, 
              !fullRoutePath.isEmpty else {
            // Fallback to scheduled: Clear any stale live ETAs
            if !displayedStops.isEmpty {
                for i in 0..<displayedStops.count {
                    displayedStops[i].realtimeEta = nil
                    displayedStops[i].realtimeDepartureEta = nil
                }
                self.estimatedTime = nil
                self.delayStatus = "Scheduled"
            }
            return 
        }
        
        let currentPos = currentCoordinate.cl
        let busIdx = findClosestIndex(on: fullRoutePath, to: currentCoordinate)
        
        Task {
            // 1. Only call Apple Maps for the Final Destination
            let lastIdx = displayedStops.count - 1
            guard lastIdx >= 0 else { return }
            let destinationStop = displayedStops[lastIdx]
            
            let request = MKDirections.Request()
            request.source = MKMapItem(location: CLLocation(latitude: currentPos.latitude, longitude: currentPos.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: destinationStop.coordinate.cl.latitude, longitude: destinationStop.coordinate.cl.longitude), address: nil)
            request.transportType = .automobile
            
            do {
                let response = try await MKDirections(request: request).calculate()
                if let route = response.routes.first {
                    let totalMins = Int(route.expectedTravelTime / 60.0)
                    let distMeters = calculatePathDistance(fromIndex: busIdx, toIndex: findClosestIndex(on: fullRoutePath, to: destinationStop.coordinate))
                    let distKm = distMeters / 1000.0
                    
                    await MainActor.run {
                        self.estimatedDistance = String(format: "%.1f km", distKm)
                        self.estimatedTime = "\(totalMins) min"
                        self.appleMapsETAs["destination"] = totalMins
                        self.updateDelayStatus(travelMinutes: totalMins)
                        self.refreshStopETAs() 
                    }
                }
            } catch {
                print("Apple Maps ETA error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                self.lastETARefresh = Date()
            }
        }
    }
    
    /// High-precision roadway distance calculation (Sum of polyline segments)
    /// Requirement: High-precision stop-by-stop ETA calculation
    /// Uses polyline distance to distribute total Apple Maps time across all stops
    func refreshStopETAs() {
        let busToTrack = selectedBusForDetail ?? bus
        let stopsSnapshot = displayedStops
        guard stopsSnapshot.count >= 2, !fullRoutePath.isEmpty else { return }
        
        // 1. Find bus's current position on the polyline
        let busCoord = currentCoordinate
        let busIdx = findClosestIndex(on: fullRoutePath, to: busCoord)
        
        // 2. Identify the next stop
        let nextStopIdx = busToTrack.currentStopIndex
        guard nextStopIdx < stopsSnapshot.count else { return }
        
        // 3. Get total destination time from existing estimation
        guard let totalMins = appleMapsETAs["destination"] else { return }
        
        // 4. Calculate Roadway Distance to Destination (Total)
        let totalDistToDest = calculatePathDistance(fromIndex: busIdx, toIndex: fullRoutePath.count - 1)
        guard totalDistToDest > 0 else { return }
        
        // 5. Update every upcoming stop
        var cumulativeMins: Double = 0
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"

        for i in nextStopIdx..<stopsSnapshot.count {
            let stop = stopsSnapshot[i]
            let stopIdxInPoly = findClosestIndex(on: fullRoutePath, to: stop.coordinate)
            
            // Road distance from bus to this specific stop
            let distToStop = calculatePathDistance(fromIndex: busIdx, toIndex: stopIdxInPoly)
            
            // Proportional Time Calculation
            let stopMinsRaw = (distToStop / totalDistToDest) * Double(totalMins)
            
            // Requirement 4: Ensure every subsequent stop is different
            // FORCE PROGRESSION: Each stop must be at least 1-2 minutes apart
            let finalMins = max(cumulativeMins + 1.0, stopMinsRaw)
            cumulativeMins = finalMins
            
            let etaDate = Date().addingTimeInterval(TimeInterval(finalMins * 60))
            let etaStr = df.string(from: etaDate)
            
            // Update the stop in the published array
            if i < self.displayedStops.count {
                self.displayedStops[i].realtimeEta = etaStr
                
                // Heuristic: Estimated Departure (ETD)
                let dwellTime: Double = 45 // seconds
                let etdDate = etaDate.addingTimeInterval(dwellTime)
                self.displayedStops[i].realtimeDepartureEta = df.string(from: etdDate)
                
                // If this is the FIRST upcoming stop, update top cards
                if i == nextStopIdx {
                    let outDf = DateFormatter()
                    outDf.dateFormat = "h:mm a"
                    self.arrivalAtNextStop = outDf.string(from: etaDate)
                    self.nextStopName = stop.name
                }
            }
        }
        
        // Final card sync
        self.estimatedTime = "\(totalMins) min"
    }

    private func calculatePathDistance(fromIndex: Int, toIndex: Int) -> Double {
        guard !fullRoutePath.isEmpty else { return 0 }
        let s = min(fromIndex, toIndex)
        let e = max(fromIndex, toIndex)
        if s == e { return 0 }
        
        var totalDist: Double = 0
        for i in s..<e {
            let p1 = fullRoutePath[i]
            let p2 = fullRoutePath[i+1]
            totalDist += haversineDistance(c1: p1, c2: p2)
        }
        return totalDist
    }
    
    private func haversineDistance(c1: Coord, c2: Coord) -> Double {
        let loc1 = CLLocation(latitude: c1.lat, longitude: c1.lon)
        let loc2 = CLLocation(latitude: c2.lat, longitude: c2.lon)
        return loc1.distance(from: loc2)
    }

    private func updateDelayStatus(travelMinutes: Int) {
        let schedStr = scheduledArrivalTime ?? displayedStops.last?.timeText
        guard let sStr = schedStr else {
            self.delayStatus = "No Schedule"
            return
        }
        
        let df = DateFormatter()
        df.dateFormat = sStr.contains("M") ? "h:mm a" : "HH:mm"
        
        guard let schedDate = df.date(from: sStr) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: schedDate)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        guard let fullSchedDate = calendar.date(from: components) else { return }
        
        let projectedArrival = now.addingTimeInterval(TimeInterval(travelMinutes * 60))
        let diffSecs = projectedArrival.timeIntervalSince(fullSchedDate)
        let diffMins = Int(diffSecs / 60.0)
        
        if diffMins > 2 {
            self.delayStatus = "\(diffMins) min delayed"
        } else if diffMins < -2 {
            self.delayStatus = "Early"
        } else {
            self.delayStatus = "On Time"
        }
    }

    func formattedETATime(at index: Int) -> String {
        let minutesRemaining = etaToStop(index: index)
        let etaDate = Date().addingTimeInterval(TimeInterval(minutesRemaining * 60))
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df.string(from: etaDate)
    }
    
    var totalDurationToDestination: Int {
        guard !displayedStops.isEmpty else { return 0 }
        return etaToStop(index: displayedStops.count - 1)
    }
    
    func recalculateTwoColorPaths() {
        guard !fullRoutePath.isEmpty else { return }
        
        let normalize = { (txt: String) in txt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let sName = normalize(sourceName)
        let dName = normalize(destName)
        
        let sourceIdx: Int = {
            if let c = sourceCoord, c.lat != 0 { return findClosestIndex(on: fullRoutePath, to: c) }
            if !sName.isEmpty, let matchedIndex = bus.route.stops.firstIndex(where: { 
                normalize($0.name).contains(sName) || sName.contains(normalize($0.name))
            }) {
                let matched = bus.route.stops[matchedIndex]
                if matched.coordinate.lat != 0 { return findClosestIndex(on: fullRoutePath, to: matched.coordinate) }
                let fraction = Double(matchedIndex) / Double(max(1, bus.route.stops.count - 1))
                return min(fullRoutePath.count - 1, Int(fraction * Double(fullRoutePath.count - 1)))
            }
            if let first = displayedStops.first, first.coordinate.lat != 0 { return findClosestIndex(on: fullRoutePath, to: first.coordinate) }
            return 0
        }()
        
        let destIdx: Int = {
            if let c = destinationCoord, c.lat != 0 { return findClosestIndex(on: fullRoutePath, to: c) }
            if !dName.isEmpty, let matchedIndex = bus.route.stops.firstIndex(where: { 
                normalize($0.name).contains(dName) || dName.contains(normalize($0.name))
            }) {
                let matched = bus.route.stops[matchedIndex]
                if matched.coordinate.lat != 0 { return findClosestIndex(on: fullRoutePath, to: matched.coordinate) }
                let fraction = Double(matchedIndex) / Double(max(1, bus.route.stops.count - 1))
                return min(fullRoutePath.count - 1, Int(fraction * Double(fullRoutePath.count - 1)))
            }
            if let last = displayedStops.last, last.coordinate.lat != 0 { return findClosestIndex(on: fullRoutePath, to: last.coordinate) }
            return fullRoutePath.count - 1
        }()
        
        let start = min(sourceIdx, destIdx)
        let end = max(sourceIdx, destIdx)
        
        withAnimation(.easeInOut) {
            if start <= end && end < fullRoutePath.count {
                self.tripPath = Array(fullRoutePath[start...end])
            } else {
                self.tripPath = fullRoutePath
            }
            
            let busToTrack = selectedBusForDetail ?? bus
            // Current position index
            var currentV = currentCoordinate
            if busToTrack.id != bus.id && !displayedStops.isEmpty {
                currentV = displayedStops[min(max(0, busToTrack.currentStopIndex), displayedStops.count - 1)].coordinate
            }
            
            let vIdx = findClosestIndex(on: fullRoutePath, to: currentV)
            
            // Pickup Path (Red/Orange): From live bus to the upcoming stop
            // Requirement: Road-aware path (Apple Maps integrated)
            if vIdx < start {
                // Throttled roadway fetch
                if shouldUpdateRoadwayPath() {
                    fetchRoadwayPickupPath(from: currentV, to: fullRoutePath[start])
                }
                
                // Fallback to polyline slice until Apple Maps returns
                if pickupPath.isEmpty {
                    self.pickupPath = Array(fullRoutePath[vIdx...start])
                }
                self.isApproachingSource = true
            } else if vIdx == start {
                self.pickupPath = [currentV]
                self.isApproachingSource = true
            } else {
                self.pickupPath = [currentV, fullRoutePath[start]]
                self.isApproachingSource = true
            }
        }
    }
    
    private func shouldUpdateRoadwayPath() -> Bool {
        if isFetchingDirections { return false }
        guard let last = lastDirectionsUpdate else { return true }
        // Throttle to 30 seconds
        return Date().timeIntervalSince(last) > 30
    }
    
    private func fetchRoadwayPickupPath(from: Coord, to: Coord) {
        isFetchingDirections = true
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: from.lat, longitude: from.lon), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: to.lat, longitude: to.lon), address: nil)
        request.transportType = .automobile
        
        Task {
            do {
                let response = try await MKDirections(request: request).calculate()
                if let route = response.routes.first {
                    let coords = route.polyline.coordinates
                    await MainActor.run {
                        self.pickupPath = coords.map { Coord(lat: $0.latitude, lon: $0.longitude) }
                        self.lastDirectionsUpdate = Date()
                        self.isFetchingDirections = false
                    }
                }
            } catch {
                print("MKDirections pickup path failed: \(error)")
                await MainActor.run { self.isFetchingDirections = false }
            }
        }
    }

    private func handleGPSUpdate(lat: Double, lon: Double, speed: Double?, bearing: Double?, isFromWebSocket: Bool) {
        guard lat != 0 && lon != 0 else { return }
        
        let newPoint = Coord(lat: lat, lon: lon)
        
        // 1. WebSocket Priority & Staleness Logic
        // Increase cooling period to 30s. If we have live data, polling coordinates are strictly ignored.
        if !isFromWebSocket && Date().timeIntervalSince(lastLiveUpdate) < 30 {
            print("LiveTrackingViewModel: Ignoring polling update. WebSocket is active.")
            return 
        }
        
        if isFromWebSocket { 
            self.lastLiveUpdate = Date() 
        }

        // 2. Movement Threshold & Monotonic Check
        let dist = distance(self.currentCoordinate, newPoint)
        
        var snappedPoint = newPoint
        var closestIdx = 0
        
        if !self.fullRoutePath.isEmpty {
            closestIdx = self.findClosestIndex(on: self.fullRoutePath, to: newPoint)
            snappedPoint = self.fullRoutePath[closestIdx]
            
            // MONOTONIC PROGRESS CHECK: 
            // If the new coordinate moves the bus BACKWARDS on the route by more than 5 indices,
            // it's almost certainly a stale update. Ignore it.
            if self.currentIndex > 0 && Double(closestIdx) < (self.currentIndex - 5.0) {
                print("LiveTrackingViewModel: Ignoring 'backwards' jump. (Current: \(self.currentIndex), New: \(closestIdx))")
                return
            }
        }

        // Jitter Suppression: Only update if moved > ~10 meters or if first update
        if self.currentCoordinate.lat != 0 && dist < 0.0001 { return }

        // 3. Update Position With Smooth Transition
        withAnimation(.easeInOut(duration: 1.5)) {
            self.currentCoordinate = snappedPoint
            self.bus.currentCoordinate = snappedPoint
            
            if !self.fullRoutePath.isEmpty {
                self.currentIndex = Double(closestIdx)
                self.traveledPath = Array(self.fullRoutePath.prefix(closestIdx + 1))
                self.remainingPath = Array(self.fullRoutePath[closestIdx...])
                self.connectionToRoute = [newPoint, snappedPoint]
            } else {
                if self.traveledPath.isEmpty || distance(self.traveledPath.last ?? newPoint, newPoint) > 0.0001 {
                    self.traveledPath.append(newPoint)
                }
            }
            
            self.bus.actualPolyline = self.traveledPath
            self.isWaitingForGPS = false
            
            // 3.1 Synchronize Stop Telemetry using proximity-based stop advancement
            if !self.bus.route.stops.isEmpty {
                let newStopIdx = self.nearestForwardStopIndex(to: newPoint)
                let prevIdx = self.bus.currentStopIndex
                
                // Only advance forward — never move backward
                if newStopIdx > prevIdx {
                    // Stamp actual arrival time on every newly passed stop
                    let now = Date()
                    let tf = DateFormatter()
                    tf.dateFormat = "HH:mm"
                    tf.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
                    let nowStr = tf.string(from: now)
                    
                    for i in prevIdx..<min(newStopIdx, self.bus.route.stops.count) {
                        self.bus.route.stops[i].realtimeEta = nowStr
                        if let dIdx = self.displayedStops.firstIndex(where: { $0.id == self.bus.route.stops[i].id }) {
                            self.displayedStops[dIdx].realtimeEta = nowStr
                        }
                    }
                    self.bus.currentStopIndex = newStopIdx
                }
                
                let currentIdx = self.bus.currentStopIndex
                if currentIdx < self.bus.route.stops.count {
                    self.nearestStopName = self.bus.route.stops[currentIdx].name
                }
                if currentIdx + 1 < self.bus.route.stops.count {
                    let nextStop = self.bus.route.stops[currentIdx + 1]
                    self.nextStopName = nextStop.name
                    self.arrivalAtNextStop = nextStop.scheduledArrival.flatMap { s in
                        // Show scheduled time for next stop from DB
                        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
                        f.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
                        if let d = f.date(from: s) {
                            let out = DateFormatter(); out.dateFormat = "HH:mm"; out.timeZone = f.timeZone
                            return out.string(from: d)
                        }
                        return String(s.prefix(5))
                    } ?? nextStop.displayTime(isRunning: self.bus.isRunning) ?? "--:--"
                } else {
                    self.nextStopName = "Arrived"
                    self.arrivalAtNextStop = "--:--"
                }
                
                self.recalculateDisplayedStops()
            }
        }

        // 4. Update Telemetry
        self.bus.liveTelemetry.speed = speed ?? 0
        self.bus.liveTelemetry.bearing = bearing ?? 0
        self.bus.liveTelemetry.speedKmph = Int((speed ?? 0) * 1.60934)
        self.bus.liveTelemetry.lastUpdate = Date()
        
        // 5. Trigger sub-state refreshes
        self.tick()
    }

    private func findClosestIndex(on path: [Coord], to target: Coord) -> Int {
        var closestIdx = 0
        var minDistance = Double.infinity
        
        for (idx, coord) in path.enumerated() {
            let d = distance(coord, target)
            if d < minDistance {
                minDistance = d
                closestIdx = idx
            }
        }
        return closestIdx
    }
    
    private func distance(_ c1: Coord, _ c2: Coord) -> Double {
        let dLat = c1.lat - c2.lat
        let dLon = c1.lon - c2.lon
        return sqrt(dLat * dLat + dLon * dLon)
    }

    private func nearestForwardStopIndex(to point: Coord) -> Int {
        let fullStops = bus.route.stops
        guard !fullStops.isEmpty else { return 0 }
        let currentIdx = bus.currentStopIndex
        
        // Search from current stop to the end to find the closest one
        var bestIdx = currentIdx
        if currentIdx >= fullStops.count { return bestIdx }
        var minStopDist = distance(point, fullStops[currentIdx].coordinate)
        
        // Threshold for auto-arriving: 0.002 degrees (~200 meters)
        let arrivalThreshold = 0.002 
        
        for i in currentIdx..<fullStops.count {
            if fullStops[i].coordinate.lat == 0 { continue }
            let d = distance(point, fullStops[i].coordinate)
            
            // If we are significantly close to a future stop, we've arrived there
            if d < arrivalThreshold {
                return i
            }
            
            // Keep track of the mathematically closest stop ahead of us
            if d < minStopDist {
                minStopDist = d
                bestIdx = i
            }
        }
        
        return bestIdx
    }
    
    private func recalculateDisplayedStops() {
        guard !bus.route.stops.isEmpty else { return }
        var displayStops = bus.route.stops
        
        let normalize = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        if let source = self.sourceStop, let destination = self.destinationStop {
             let srcIdx = bus.route.stops.firstIndex(where: { normalize($0.name).contains(normalize(source)) || normalize(source).contains(normalize($0.name)) }) ?? 0
             let dstIdx = bus.route.stops.firstIndex(where: { normalize($0.name).contains(normalize(destination)) || normalize(destination).contains(normalize($0.name)) }) ?? (bus.route.stops.count - 1)
             
             let startIdx = min(self.bus.currentStopIndex, srcIdx)
             let endIdx = max(srcIdx, dstIdx)
             
             if startIdx <= endIdx && endIdx < bus.route.stops.count {
                 displayStops = Array(bus.route.stops[startIdx...endIdx])
             }
        } else if let source = self.sourceStop {
             let srcIdx = bus.route.stops.firstIndex(where: { normalize($0.name).contains(normalize(source)) || normalize(source).contains(normalize($0.name)) }) ?? 0
             let startIdx = min(self.bus.currentStopIndex, srcIdx)
             if startIdx < bus.route.stops.count {
                 displayStops = Array(bus.route.stops[startIdx...])
             }
        }
        
        if self.displayedStops.map({$0.id}) != displayStops.map({$0.id}) {
             self.displayedStops = displayStops
        }
    }

    private var fastPollingTick: Int = 0
    private func syncActiveBusCoord() async {
        do {
            if let gps = try await APIService.shared.fetchLatestGPS(tripId: bus.vehicleId, extTripId: bus.extTripId) {
                let point = Coord(lat: gps.lat, lon: gps.lng)
                let spd = gps.speed ?? 0.0
                let ts = gps.ts
                
                await MainActor.run {
                    BusRepository.shared.updateBusTelemetry(id: self.bus.id, point: point, speed: spd, timestampRaw: ts)
                    
                    // Route through central handler instead of manual property set
                    self.handleGPSUpdate(lat: point.lat, lon: point.lon, speed: spd, bearing: nil, isFromWebSocket: false)
                    
                    if let startStr = self.displayedStops.first?.scheduledArrival, 
                       let startDate = self.parseTimeToday(startStr) {
                        self.durationTakenMinutes = Int(Date().timeIntervalSince(startDate) / 60)
                        if self.durationTakenMinutes < 0 { self.durationTakenMinutes = 0 }
                    }
                    
                    self.recalculateTwoColorPaths()
                    self.refreshAppleMapsETAs()
                    print("syncActiveBusCoord [\(bus.number)]: Telemetry updated in repository")
                }
            } else {
                print("syncActiveBusCoord [\(bus.number)]: No GPS data found")
            }
        } catch {
            print("Fast syncActiveBusCoord failed: \(error.localizedDescription)")
        }
    }
}
