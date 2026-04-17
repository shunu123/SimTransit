import CoreLocation

struct Coord: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let lat: Double
    let lon: Double
    var isDiverted: Bool = false

    nonisolated init(id: UUID = UUID(), lat: Double, lon: Double, isDiverted: Bool = false) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.isDiverted = isDiverted
    }

    nonisolated var cl: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// Single, unique ping type
struct LocationPing: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let coordinate: Coord

    init(id: UUID = UUID(), timestamp: Date, coordinate: Coord) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = coordinate
    }
}

struct PathSegment: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var coords: [Coord]
    var isDiverted: Bool
}

/// GPS track point for trip history replay
struct TripTrackPoint: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let coordinate: Coord
    let speed: Double? // km/h
    let heading: Double? // degrees
    
    init(id: UUID = UUID(), timestamp: Date, coordinate: Coord, speed: Double? = nil, heading: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.speed = speed
        self.heading = heading
    }
}

enum BusStatus: String, Codable, CaseIterable {
    case onTime = "On Time"
    case delayed = "Delayed"
}

struct TripRecord: Codable, Hashable {
    var date: String // "yyyy-MM-dd"
    var isDeviated: Bool
    var status: String // "Normal", "Deviated", "Completed"
    var plannedPolyline: [Coord]
    var actualPolyline: [Coord]
    var historyStops: [HistoryStop]
}

struct StateInfo: Codable, Hashable {
    let fromState: String
    let fromCity: String
    let toState: String
    let toCity: String
}

struct Stop: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let coordinate: Coord
    let timeText: String?
    let isMajorStop: Bool
    let platformNumber: String?
    let stopOrder: Int 
    let realtimeArrival: Date?
    let scheduledArrival: String?
    let scheduledDeparture: String?
    var realtimeEta: String?
    var realtimeDepartureEta: String?

    enum TimeSource: String, Codable {
        case live = "LIVE"
        case scheduled = "SCHED"
    }

    struct StopTiming: Codable {
        let time: String
        let source: TimeSource
        var delayMinutes: Int? = nil
    }

    func timingResult(isRunning: Bool) -> StopTiming? {
        if isRunning, let eta = realtimeEta, !eta.isEmpty {
            // Calculate delay if possible
            var delay: Int? = nil
            if let sched = scheduledArrival {
                delay = calculateDelay(live: eta, sched: sched)
            }
            return StopTiming(time: formatToShortTime(eta), source: .live, delayMinutes: delay)
        }
        
        if let sched = scheduledArrival {
            return StopTiming(time: formatToShortTime(sched), source: .scheduled)
        }
        
        return nil
    }

    private func formatToShortTime(_ timeStr: String) -> String {
        guard !timeStr.isEmpty else { return "--:--" }
        
        // 1. If it's a full ISO string (2026-04-01THH:mm:ss...)
        if timeStr.contains("T") {
            let parts = timeStr.components(separatedBy: "T")
            if parts.count > 1 {
                let timePart = parts[1] // HH:mm:ss...
                let timeComponents = timePart.components(separatedBy: ":")
                if timeComponents.count >= 2 {
                    return "\(timeComponents[0]):\(timeComponents[1])"
                }
            }
        }
        
        // 2. If it's HH:mm:ss format
        if timeStr.contains(":") {
            let parts = timeStr.components(separatedBy: ":")
            if parts.count >= 2 {
                // Ensure we only take the first two parts (HH and mm)
                let hh = parts[0].suffix(2)
                let mm = parts[1].prefix(2)
                return "\(hh):\(mm)"
            }
        }
        
        return timeStr
    }

    private func calculateDelay(live: String, sched: String) -> Int? {
        // Highly granular delay calculation
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        
        // Normalize live time for comparison if ISO
        let normalizedLive = formatToShortTime(live)
        
        guard let liveDate = df.date(from: normalizedLive), 
              let schedDate = df.date(from: sched) else { return nil }
        
        let diff = liveDate.timeIntervalSince(schedDate)
        let mins = Int(diff / 60)
        return mins > 1 ? mins : nil
    }

    func displayTime(isRunning: Bool) -> String? {
        return timingResult(isRunning: isRunning)?.time
    }

    init(id: String = UUID().uuidString, name: String, coordinate: Coord, timeText: String?, isMajorStop: Bool = true, platformNumber: String? = nil, stopOrder: Int = 0, realtimeArrival: Date? = nil, scheduledArrival: String? = nil, scheduledDeparture: String? = nil, realtimeEta: String? = nil, realtimeDepartureEta: String? = nil) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.timeText = timeText
        self.isMajorStop = isMajorStop
        self.platformNumber = platformNumber
        self.stopOrder = stopOrder
        self.realtimeArrival = realtimeArrival
        self.scheduledArrival = scheduledArrival
        self.scheduledDeparture = scheduledDeparture
        self.realtimeEta = realtimeEta
        self.realtimeDepartureEta = realtimeDepartureEta
    }
}

struct HistoryStop: Identifiable, Hashable, Codable {
    let id: UUID
    let stopName: String
    let coordinate: Coord?
    let reachedTime: String? // "HH:MM" or nil

    init(id: UUID = UUID(), stopName: String, coordinate: Coord? = nil, reachedTime: String?) {
        self.id = id
        self.stopName = stopName
        self.coordinate = coordinate
        self.reachedTime = reachedTime
    }
}

struct Route: Identifiable, Hashable, Codable {
    var id: UUID
    var from: String
    var to: String
    var startPointName: String = "Start"
    var endPointName: String = "End"
    var stops: [Stop]
    var plannedPolyline: [Coord] = []

    init(id: UUID = UUID(), from: String, to: String, stops: [Stop], plannedPolyline: [Coord] = []) {
        self.id = id
        self.from = from
        self.to = to
        self.stops = stops
        self.plannedPolyline = plannedPolyline
    }
}

enum TrackingStatus: String, Codable, CaseIterable {
    case scheduled = "Scheduled"
    case arriving = "Arriving"
    case arrived = "Arrived"
    case departed = "Departed"
    case halted = "Halted"
    case ended = "Ended"
}

struct TrackingMetadata: Codable, Hashable {
    var isHalted: Bool = false
    var lastUpdate: Date = Date()
    var speed: Double = 0.0
    var bearing: Double = 0.0
    var speedKmph: Int? = nil // Requirement B: Live Telemetry
    
    init(isHalted: Bool = false, lastUpdate: Date = Date(), speed: Double = 0.0, bearing: Double = 0.0, speedKmph: Int? = nil) {
        self.isHalted = isHalted
        self.lastUpdate = lastUpdate
        self.speed = speed
        self.bearing = bearing
        self.speedKmph = speedKmph
    }
}

struct Bus: Identifiable, Hashable, Codable {
    var id: UUID
    var number: String
    var headsign: String
    var departsAt: String
    var durationText: String
    var status: BusStatus
    var statusDetail: String?
    var trackingStatus: TrackingStatus
    var etaMinutes: Int?
    var route: Route
    var currentCoordinate: Coord? = nil
    var stateInfo: StateInfo?
    var vehicleId: Int? = nil // Backend ID (Trip ID)
    var busId: Int? = nil // Backend Bus ID
    var extTripId: String? = nil // Stable DTC Trip ID
    var extRouteId: String? = nil // Original Transit Route ID
    
    // New fields for University Tracking
    var isDeviated: Bool = false
    var currentStopIndex: Int = 0 
    var liveTelemetry: TrackingMetadata = TrackingMetadata()
    
    var actualPolyline: [Coord] = [] // Requirement C: Actual path
    var historyStops: [HistoryStop] = [] // Requirement A: History binding
    
    // Phase 2: Reached State
    var hasReachedDestination: Bool = false
    var durationMinutes: Int? = nil // Requirement: minutes as int
    var currentStopName: String? = nil
    var nextStopName: String? = nil
    var arrivalsAt: String = "--:--"
    var nextStopETA: String = "--:--"

    // New: Calculate delay label based on current time and ETA
    var delayLabel: String {
        guard let schedStr = (arrivalsAt != "--:--" ? arrivalsAt : nil), let eta = etaMinutes else { return "Scheduled" }
        
        let df = DateFormatter()
        df.dateFormat = schedStr.contains("M") ? "h:mm a" : "HH:mm"
        
        guard let schedDate = df.date(from: schedStr) else { return "Scheduled" }
        
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: schedDate)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        guard let fullSchedDate = calendar.date(from: components) else { return "Scheduled" }
        
        // Day-wrap logic: If scheduled time is significantly in the past (e.g. > 12 hours), 
        // assume it refers to the next day.
        var finalSchedDate = fullSchedDate
        if now.timeIntervalSince(fullSchedDate) > 43200 { // 12 hours
            finalSchedDate = calendar.date(byAdding: .day, value: 1, to: fullSchedDate) ?? fullSchedDate
        } else if fullSchedDate.timeIntervalSince(now) > 43200 {
            // If scheduled is > 12 hours in future, assume it's for today but we are early
        }

        let projectedArrival = now.addingTimeInterval(TimeInterval(eta * 60))
        let diffSecs = projectedArrival.timeIntervalSince(finalSchedDate)
        let diffMins = Int(diffSecs / 60.0)
        
        if diffMins > 120 {
            return isRunning ? "Live" : "Delayed"
        } else if diffMins > 2 {
            return "\(diffMins) min delayed"
        } else if diffMins < -2 {
            return "Early"
        } else {
            return "On Time"
        }
    }
    
    // History Tracking
    var tripHistory: [String: TripRecord] = [:] // Map: "yyyy-MM-dd" -> TripRecord

    var isRunning: Bool {
        trackingStatus == .arriving || (trackingStatus == .halted && !isDeviated)
    }

    var isNightOwl: Bool {
        let nightOwl = ["N1", "4", "N5", "N9", "N20", "N22", "N34", "N49", "N53", "N60", "N62", "N63", "66", "N77", "79", "N81", "N87"]
        let rt = extRouteId?.uppercased() ?? number.uppercased()
        return nightOwl.contains(rt)
    }

    init(
        id: UUID = UUID(),
        number: String,
        headsign: String,
        departsAt: String,
        durationText: String,
        status: BusStatus,
        statusDetail: String?,
        trackingStatus: TrackingStatus = .scheduled,
        etaMinutes: Int? = nil,
        route: Route,
        stateInfo: StateInfo? = nil,
        vehicleId: Int? = nil,
        busId: Int? = nil,
        extTripId: String? = nil,
        isDeviated: Bool = false,
        currentStopIndex: Int = 0,
        speed: Double = 0.0,
        actualPolyline: [Coord] = [],
        historyStops: [HistoryStop] = [],
        hasReachedDestination: Bool = false,
        durationMinutes: Int? = nil,
        currentStopName: String? = nil,
        nextStopName: String? = nil,
        arrivalsAt: String = "--:--",
        nextStopETA: String = "--:--",
        currentCoordinate: Coord? = nil,
        tripHistory: [String: TripRecord] = [:]
    ) {
        self.id = id
        self.number = number
        self.headsign = headsign
        self.departsAt = departsAt
        self.durationText = durationText
        self.status = status
        self.statusDetail = statusDetail
        self.trackingStatus = trackingStatus
        self.etaMinutes = etaMinutes
        self.route = route
        self.stateInfo = stateInfo
        self.vehicleId = vehicleId
        self.busId = busId
        self.extTripId = extTripId
        self.isDeviated = isDeviated
        self.currentStopIndex = currentStopIndex
        self.liveTelemetry = TrackingMetadata(speed: speed)
        self.actualPolyline = actualPolyline
        self.historyStops = historyStops
        self.hasReachedDestination = hasReachedDestination
        self.durationMinutes = durationMinutes
        self.currentStopName = currentStopName
        self.nextStopName = nextStopName
        self.arrivalsAt = arrivalsAt
        self.nextStopETA = nextStopETA
        self.currentCoordinate = currentCoordinate
        self.tripHistory = tripHistory
    }

    func statusRelativeTo(stopName: String) -> TrackingStatus {
        if isDeviated { return .halted }
        
        let normalizedTarget = stopName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let targetIndex = route.stops.firstIndex(where: { 
            let name = $0.name.lowercased()
            return name.contains(normalizedTarget) || normalizedTarget.contains(name)
        }) else {
            return trackingStatus
        }
        
        if currentStopIndex > targetIndex {
            return .departed
        } else if currentStopIndex == targetIndex {
            return trackingStatus
        } else {
            return trackingStatus == .scheduled ? .scheduled : .arriving
        }
    }

    var displayETA: Int? {
        if isDeviated { return nil }
        return etaMinutes
    }

    func stopsFrom(sourceName: String) -> [Stop] {
        let normalizedSource = sourceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let sourceIndex = route.stops.firstIndex(where: { 
            let name = $0.name.lowercased()
            return name.contains(normalizedSource) || normalizedSource.contains(name)
        }) else {
            return route.stops
        }
        return Array(route.stops[sourceIndex...])
    }

    /// Returns only the stops between (and including) the given source and destination names.
    func stopsFromTo(sourceName: String, destinationName: String) -> [Stop] {
        let src = sourceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dst = destinationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard let fromIdx = route.stops.firstIndex(where: {
            let n = $0.name.lowercased()
            return n.contains(src) || src.contains(n)
        }) else { return stopsFrom(sourceName: sourceName) }

        guard let toIdx = route.stops.firstIndex(where: {
            let n = $0.name.lowercased()
            return n.contains(dst) || dst.contains(n)
        }) else { return stopsFrom(sourceName: sourceName) }

        let lo = min(fromIdx, toIdx)
        let hi = max(fromIdx, toIdx)
        return Array(route.stops[lo...hi])
    }

    func timeAtStop(name: String) -> String? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return route.stops.first(where: { 
            let sName = $0.name.lowercased()
            return sName.contains(normalized) || normalized.contains(sName)
        })?.timeText
    }

    func durationBetween(from: String, to: String) -> Int {
        let stops = route.stops
        let normalizedFrom = from.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTo = to.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let fromIdx = stops.firstIndex(where: { 
            let name = $0.name.lowercased()
            return name.contains(normalizedFrom) || normalizedFrom.contains(name)
        }) ?? 0
        
        let toIdx = stops.firstIndex(where: { 
            let name = $0.name.lowercased()
            return name.contains(normalizedTo) || normalizedTo.contains(name)
        }) ?? (stops.count - 1)
        
        return max(0, toIdx - fromIdx) * 10 
    }
}

struct BusRoute: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let ext_route_id: String?
    let from_name: String?
    let to_name: String?
    var stops: [Stop]?

    var isNightOwl: Bool {
        let nightOwl = ["N1", "4", "N5", "N9", "N20", "N22", "N34", "N49", "N53", "N60", "N62", "N63", "66", "N77", "79", "N81", "N87"]
        let rt = ext_route_id?.uppercased() ?? ""
        return nightOwl.contains(rt)
    }
}

// MARK: - API Response Models for Fleet History
struct FleetHistoryResponse: Codable {
    let ok: Bool
    let date: String
    let data: [FleetTrip]
}

struct FleetTrip: Codable, Identifiable {
    var id: UUID { UUID() }
    let trip_id: Int
    let bus_id: Int
    let bus_number: String?
    let route_name: String?
    let start_city: String?
    let status: String?
    let start_time: String?
    let end_time: String?
    let actual_polyline: [FleetGPSPoint]?
    let stops: [FleetStop]?
}

struct FleetStop: Codable {
    let stop_name: String
    let lat: Double
    let lng: Double
    let reached_time: String?
}

struct FleetGPSPoint: Codable {
    let lat: Double
    let lng: Double
    let speed: Double?
    let heading: Double?
    let ts: String?
}

// User and Auth Models
struct User: Codable, Identifiable {
    let id: Int
    let reg_no: String
    let first_name: String?
    let last_name: String?
    let email: String?
    let year: Int?
    let mobile_no: String?
    let college_name: String?
    let department: String?
    let specialization: String?
    let degree: String?
    let location: String?
    let bus_stop: String?
    let role: String? // 'student' or 'admin'
}

struct AuthResponse: Codable {
    let ok: Bool
    let user: User?
    let detail: String?
    let requires_otp: Bool?
    let target: String?
    let token: String?
}

struct GenericResponse: Codable {
    let ok: Bool
    let msg: String?
    let detail: String?
}

// MARK: - Admin Models
struct StudentRecord: Codable, Identifiable {
    let id: Int
    let reg_no: String
    let first_name: String?
    let last_name: String?
    let year: Int?
    let mobile_no: String?
    let email: String?
    let college_name: String?
    let department: String?
    let degree: String?
    let location: String?
    let bus_stop: String?

    var displayName: String {
        let f = first_name ?? ""
        let l = last_name ?? ""
        return "\(f) \(l)".trimmingCharacters(in: .whitespaces).isEmpty ? "Unknown" : "\(f) \(l)"
    }
}

struct StudentsResponse: Codable {
    let ok: Bool
    let students: [StudentRecord]
}
