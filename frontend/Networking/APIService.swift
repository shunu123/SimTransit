import Foundation

struct APIListResponse<T: Decodable>: Decodable {
    let ok: Bool
    let data: [T]
}

struct APIObjectResponse<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
}

// Transit models moved to TransitModels.swift
// Models consolidated in Model/BusModels.swift and Networking/APIConfig.swift


enum APIError: LocalizedError {
    case serverError(Int, String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .serverError(let code, let msg):
            return "Server error \(code): \(msg)"
        case .decodingError(let msg):
            return "Data error: \(msg)"
        }
    }
}

// MARK: - Admin Creation Models
struct CreateTripStopIn: Encodable {
    let stop_id: Int
    let stop_order: Int
    let arrival: String
    let departure: String
}

struct CreateTripIn: Encodable {
    let bus_id: Int
    let route_id: Int
    let service_date: String
    let start_time: String
    let end_time: String
    let stops: [CreateTripStopIn]
}

struct LLMIntentResponse: Decodable {
    let command: String
    let from_stop: String?
    let to_stop: String?
    let bus_number: String?
    let screen: String?
    let speech_response: String?
    let language_code: String?
}

final class APIService {

    static let shared = APIService()
    private init() {}

    private let decoder = JSONDecoder()

    func parseVoiceIntent(transcript: String) async throws -> LLMIntentResponse {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/voice/intent") else {
            throw APIError.decodingError("Invalid URL for voice intent")
        }
        let body = ["transcript": transcript]
        return try await post(url, body: body, as: LLMIntentResponse.self)
    }

    private func fetch<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        print("API CALL:", url.absoluteString)

        var request = URLRequest(url: url)
        // Required for loca.lt tunnels — bypasses the browser reminder page
        request.addValue("true", forHTTPHeaderField: "bypass-tunnel-reminder")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("STATUS:", http.statusCode)
            
            guard (200...299).contains(http.statusCode) else {
                var msg = "Server error \(http.statusCode)"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let detailStr = json["detail"] as? String {
                        msg = detailStr
                    } else if let detailDict = json["detail"] as? [String: Any],
                              let err = detailDict["error"] as? String {
                        msg = err
                    }
                } else if let rawStr = String(data: data, encoding: .utf8) {
                    msg = rawStr
                }
                throw APIError.decodingError(msg)
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ DECODING ERROR:", error)
            if let rawString = String(data: data, encoding: .utf8) {
                print("📝 Raw Response Body: \(rawString)")
            }
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func post<T: Decodable, B: Encodable>(_ url: URL, body: B, as type: T.Type) async throws -> T {
        print("API POST:", url.absoluteString)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        // Required for loca.lt tunnels — bypasses the browser reminder page
        request.addValue("true", forHTTPHeaderField: "bypass-tunnel-reminder")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("STATUS:", http.statusCode)
            guard (200...299).contains(http.statusCode) else {
                var msg = "Unknown error"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let detailStr = json["detail"] as? String {
                        msg = detailStr
                    } else if let detailDict = json["detail"] as? [String: Any],
                              let err = detailDict["error"] as? String {
                        msg = err
                    }
                } else if let rawStr = String(data: data, encoding: .utf8)?.prefix(200).description {
                    msg = rawStr
                }
                throw APIError.decodingError(msg)
            }
        }

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Stops
    func fetchStops(routeId: String, dir: String) async throws -> [BusStop] {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/stops?rt=\(routeId)&dir=\(dir)") else {
            throw APIError.decodingError("Invalid URL for fetchStops")
        }
        struct TransitStop: Decodable {
            let stpid: String
            let stpnm: String
            let lat: Double
            let lon: Double
        }
        let resp = try await fetch(url, as: [TransitStop].self)
        return resp.map { BusStop(id: $0.stpid, name: $0.stpnm, lat: $0.lat, lng: $0.lon) }
    }

    func fetchAllStops() async throws -> [BusStop] {
        guard let url = URL(string: "\(APIConfig.baseURL)/stops") else {
            throw APIError.decodingError("Invalid URL for fetchAllStops")
        }
        struct DBStop: Decodable {
            let id: Int
            let name: String
            let lat: Double
            let lng: Double
        }
        let resp = try await fetch(url, as: APIListResponse<DBStop>.self)
        return resp.data.map { BusStop(id: "\($0.id)", name: $0.name, lat: $0.lat, lng: $0.lng) }
    }

    func fetchRoutes(q: String = "", offset: Int = 0) async throws -> (routes: [BusRoute], total: Int) {
        guard var comps = URLComponents(string: "\(APIConfig.baseURL)/api/routes") else {
            throw APIError.decodingError("Invalid URL for fetchRoutes")
        }
        comps.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        struct RouteData: Decodable {
            let id: Int
            let name: String
            let ext_route_id: String?
        }
        
        struct PaginatedResponse: Decodable {
            let ok: Bool
            let data: [RouteData]
            let total: Int
        }
        
        let resp = try await fetch(comps.url!, as: PaginatedResponse.self)
        let routes = resp.data.map { 
            BusRoute(id: $0.id, name: $0.name, ext_route_id: $0.ext_route_id, from_name: nil, to_name: nil, stops: nil) 
        }
        return (routes, resp.total)
    }

    // MARK: - All Daily Buses
    func fetchBuses(forRoute: String? = nil) async throws -> [DailyBusTrip] {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
        guard var comps = URLComponents(string: "\(APIConfig.baseURL)/buses") else {
            throw APIError.decodingError("Invalid URL for fetchBuses")
        }
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "service_date", value: today)]
        if let forRoute { queryItems.append(URLQueryItem(name: "route", value: forRoute)) }
        comps.queryItems = queryItems
        
        let resp = try await fetch(comps.url!, as: APIListResponse<DailyBusTrip>.self)
        
        // Register these buses in the repository so they are available for mapping
        await MainActor.run {
            for trip in resp.data {
                 let stableUUID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", trip.tripId)) ?? UUID()
                 let bus = Bus(
                     id: stableUUID,
                     number: trip.busNo ?? "N/A",
                     headsign: trip.routeName ?? "Transit Route",
                     departsAt: "--",
                     durationText: "--",
                     status: .onTime,
                     statusDetail: "Live",
                     trackingStatus: .scheduled,
                     etaMinutes: nil,
                     route: Route(from: "", to: "", stops: []),
                     vehicleId: trip.tripId,
                     busId: trip.busId,
                     extTripId: trip.extTripId
                 )
                 BusRepository.shared.register(bus: bus)
            }
        }
        
        return resp.data
    }

    // MARK: - Search Trips
    func searchRealtime(routeId: String, fromStopId: String) async throws -> [SearchTrip] {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/search/realtime")!
        comps.queryItems = [
            URLQueryItem(name: "rt", value: routeId),
            URLQueryItem(name: "stpid", value: fromStopId)
        ]
        
        // This endpoint returns a list of SearchTrip already formatted by the backend
        let resp = try await fetch(comps.url!, as: APIListResponse<SearchTrip>.self)
        return resp.data
    }

    func searchTrips(fromStopId: String, toStopId: String, routeId: String = "20", dir: String = "Eastbound") async throws -> [SearchTrip] {
        guard var comps = URLComponents(string: "\(APIConfig.baseURL)/api/track") else {
            throw APIError.decodingError("Invalid URL for searchTrips")
        }
        comps.queryItems = [
            URLQueryItem(name: "route_id", value: routeId),
            URLQueryItem(name: "from_stop_id", value: fromStopId),
            URLQueryItem(name: "to_stop_id", value: toStopId),
            URLQueryItem(name: "dir", value: dir)
        ]

        guard let url = comps.url else { throw APIError.decodingError("Invalid URL components for searchTrips") }
        let resp = try await fetch(url, as: TransitTrackResponse.self)
        
        let durStr = resp.duration.replacingOccurrences(of: "m", with: "")
        
        // Convert the backend structure to the iOS SearchTrip model expected by SwiftUI
        let isLive = resp.bus_live_location != nil
        let trip = SearchTrip(
            tripId: Int(resp.trip_id ?? resp.route_id) ?? 0,
            extTripId: resp.trip_id ?? resp.route_id,
            busId: nil,
            busNo: "Transit Route \(resp.route_id)",
            label: resp.duration,
            routeId: Int(resp.route_id) ?? 0,
            routeName: "Route \(resp.route_id)",
            extRouteId: resp.route_id,
            fromDeparture: resp.schedule.departure_time,
            toArrival: resp.schedule.arrival_time,
            durationMinutes: Int(durStr),
            status: isLive ? "Live" : "Scheduled",
            busLiveLocation: resp.bus_live_location,
            nextStopName: nil,
            currentStopName: nil,
            routeStartName: resp.from_stop,
            routeEndName: resp.to_stop
        )
        return [trip]
    }

    /// Name-based bus search — calls /api/routes/search with stop name strings.
    /// Returns all buses that travel from `fromName` → `toName` without requiring stop IDs.
    func fetchRoutesSearch(fromName: String, toName: String, regNo: String? = nil, role: String? = nil) async throws -> [SearchTrip] {
        guard let fromEnc = fromName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let toEnc = toName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        var urlString = "\(APIConfig.baseURL)/api/routes/search?from_stop=\(fromEnc)&to_stop=\(toEnc)"
        if let r = regNo { urlString += "&reg_no=\(r)" }
        if let rl = role { urlString += "&role=\(rl)" }
        guard let url = URL(string: urlString) else { throw APIError.decodingError("Invalid URL for fetchRoutesSearch") }
        let resp = try await fetch(url, as: APIListResponse<SearchTrip>.self)
        return resp.data
    }

    func fetchFullTripDetails(routeId: String, direction: String, vehicleId: String) async throws -> TransitFullTripResponse {
        guard var comps = URLComponents(string: "\(APIConfig.baseURL)/api/trip/full_details") else {
             throw APIError.decodingError("Invalid URL for fetchFullTripDetails")
        }
        comps.queryItems = [
            URLQueryItem(name: "rt", value: routeId),
            URLQueryItem(name: "dir", value: direction),
            URLQueryItem(name: "vid", value: vehicleId)
        ]
        guard let url = comps.url else { throw APIError.decodingError("Invalid URL components for fetchFullTripDetails") }
        return try await fetch(url, as: TransitFullTripResponse.self)
    }

    func fetchRouteStops(routeId: Int) async throws -> [Stop] {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/routes/\(routeId)/stops") else {
            throw APIError.decodingError("Invalid URL for fetchRouteStops")
        }
        struct StopNode: Decodable {
            let stop_id: Int
            let name: String
            let lat: Double
            let lng: Double
            let stop_order: Int
        }
        let resp = try await fetch(url, as: APIListResponse<StopNode>.self)
        return resp.data.map { node in
            Stop(id: "\(node.stop_id)", name: node.name, coordinate: Coord(lat: node.lat, lon: node.lng), timeText: nil, stopOrder: node.stop_order)
        }
    }


    // MARK: - Timeline
    func fetchTimeline(tripId: Int? = nil, extTripId: String? = nil) async throws -> (stops: [TimelineStop], polyline: String?) {
        let identifier = "\(tripId ?? 0)"
        guard var comps = URLComponents(string: "\(APIConfig.baseURL)/api/trip/timeline") else {
            throw APIError.decodingError("Invalid URL for fetchTimeline")
        }
        var items = [URLQueryItem(name: "trip_id", value: identifier)]
        if let etid = extTripId {
            items.append(URLQueryItem(name: "ext_trip_id", value: etid))
        }
        comps.queryItems = items
        guard let url = comps.url else { throw APIError.decodingError("Invalid URL components for fetchTimeline") }
        
        do {
            let resp = try await fetch(url, as: TransitTimelineResponse.self)
            return (resp.timeline, resp.polyline)
        } catch {
            print("API: Error fetching timeline for \(identifier): \(error.localizedDescription)")
            // Fallback: If the response is a raw list (legacy support)
            if let legacyResp = try? await fetch(url, as: [TimelineStop].self) {
                return (legacyResp, nil)
            }
            throw error
        }
    }

    // MARK: - Latest GPS
    func fetchLatestGPS(tripId: Int? = nil, extTripId: String? = nil) async throws -> GPSPoint? {
        guard var comps = URLComponents(string: "\(APIConfig.baseURL)/api/gps/latest") else {
             throw APIError.decodingError("Invalid URL for fetchLatestGPS")
        }
        var items: [URLQueryItem] = []
        if let tid = tripId {
            items.append(URLQueryItem(name: "trip_id", value: "\(tid)"))
        }
        if let etid = extTripId {
            items.append(URLQueryItem(name: "ext_trip_id", value: etid))
        }
        comps.queryItems = items

        guard let url = comps.url else { throw APIError.decodingError("Invalid URL components for fetchLatestGPS") }
        let resp = try await fetch(url, as: APIObjectResponse<GPSPoint>.self)
        return resp.data
    }

    // MARK: - Live GPS for Trip
    func fetchTripLatestGPS(tripId: Int? = nil, extTripId: String? = nil) async throws -> GPSPoint? {
        let identifier = extTripId ?? "\(tripId ?? 0)"
        let url = URL(string: "\(APIConfig.baseURL)/trips/\(identifier)/latest-gps")!
        
        struct GPSResponse: Decodable {
            let ok: Bool
            let data: GPSPoint?
            let error: String?
        }
        
        let resp = try await fetch(url, as: GPSResponse.self)
        if !resp.ok { 
            print("API: fetchTripLatestGPS failed: \(resp.error ?? "unknown")")
            return nil 
        }
        return resp.data
    }

    // MARK: - Live Fleet Mapping
    func fetchLiveFleetGPS() async throws -> [GPSPoint] {
        guard let url = URL(string: "\(APIConfig.baseURL)/gps/live") else {
            throw APIError.decodingError("Invalid URL for fetchLiveFleetGPS")
        }
        let resp = try await fetch(url, as: APIListResponse<GPSPoint>.self)
        return resp.data
    }

    // MARK: - Update GPS
    func updateGPS(tripId: Int, busId: Int, lat: Double, lng: Double, speed: Double? = nil, heading: Double? = nil) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/gps") else {
            throw APIError.decodingError("Invalid URL for updateGPS")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = GPSIn(
            trip_id: tripId,
            bus_id: busId,
            lat: lat,
            lng: lng,
            speed: speed,
            heading: heading,
            ts: nil
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("GPS update failed with status: \(http.statusCode)")
        }
    }

    // MARK: - Recent Searches
    func saveRecentSearch(fromStopId: String, toStopId: String, fromName: String, toName: String, userId: Int? = nil) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/recent_searches") else {
            throw APIError.decodingError("Invalid URL for saveRecentSearch")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "from_stop_id": fromStopId,
            "to_stop_id": toStopId,
            "from_name": fromName,
            "to_name": toName,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let uid = userId {
            body["user_id"] = uid
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("saveRecentSearch failed with status: \(http.statusCode)")
        } else {
            print("saveRecentSearch success")
        }
    }

    func saveStudentStopSearch(studentId: Int, lat: Double, lng: Double, nearestStopId: Int, distance: Double) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/student-stop-search") else {
            throw APIError.decodingError("Invalid URL for saveStudentStopSearch")
        }
        let body: [String: Any] = [
            "student_id": studentId,
            "current_lat": lat,
            "current_lng": lng,
            "nearest_stop_id": nearestStopId,
            "distance": distance,
            "search_time": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("saveStudentStopSearch failed: \(http.statusCode)")
        }
    }

    func fetchBusesForStop(stopId: String) async throws -> [DailyBusTrip] {
        guard let url = URL(string: "\(APIConfig.baseURL)/buses?stop_id=\(stopId)") else {
            throw APIError.decodingError("Invalid URL for fetchBusesForStop")
        }
        let resp = try await fetch(url, as: APIListResponse<DailyBusTrip>.self)
        return resp.data
    }

    func fetchRecentSearches(role: String = "student", userId: Int? = nil) async throws -> [RecentSearch] {
        guard var urlComp = URLComponents(string: "\(APIConfig.baseURL)/recent_searches") else {
             throw APIError.decodingError("Invalid URL for fetchRecentSearches")
        }
        var items = [URLQueryItem(name: "role", value: role)]
        if let uid = userId {
            items.append(URLQueryItem(name: "user_id", value: "\(uid)"))
        }
        urlComp.queryItems = items
        
        guard let url = urlComp.url else { throw APIError.decodingError("Invalid URL components for fetchRecentSearches") }
        let resp = try await fetch(url, as: APIListResponse<RecentSearch>.self)
        return resp.data
    }

    func fetchTripHistory(tripId: Int, date: String? = nil) async throws -> [GPSPoint] {
        var urlString = "\(APIConfig.baseURL)/api/gps/history?trip_id=\(tripId)"
        if let d = date { urlString += "&date=\(d)" }
        let url = URL(string: urlString)!
        let resp = try await fetch(url, as: APIListResponse<GPSPoint>.self)
        return resp.data
    }

    func fetchTripCoordinates(tripId: Int, date: String? = nil) async throws -> [Coord] {
        var urlString = "\(APIConfig.baseURL)/api/trip/\(tripId)/points"
        if let d = date { urlString += "?date=\(d)" }
        let url = URL(string: urlString)!
        struct Point: Decodable { let latitude: Double; let longitude: Double }
        let resp = try await fetch(url, as: APIListResponse<Point>.self)
        return resp.data.map { Coord(lat: $0.latitude, lon: $0.longitude) }
    }
    
    func fetchFleetHistory(date: String) async throws -> [FleetTrip] {
        let url = URL(string: "\(APIConfig.baseURL)/fleet/history?date=\(date)")!
        let resp = try await fetch(url, as: FleetHistoryResponse.self)
        return resp.data
    }

    // AUTH
    func login(regNoOrEmail: String, password: String) async throws -> (user: User?, requiresOTP: Bool, target: String?) {
        let url = URL(string: "\(APIConfig.baseURL)/login")!
        let body = ["reg_no_or_email": regNoOrEmail, "password": password]
        let resp = try await post(url, body: body, as: AuthResponse.self)
        
        if resp.requires_otp == true {
            return (nil, true, resp.target)
        }
        
        if let user = resp.user {
            return (user: user, requiresOTP: false, target: nil)
        }
        throw APIError.serverError(401, resp.detail ?? "Login failed")
    }

    func register(userData: [String: Any]) async throws -> Bool {
        guard let url = URL(string: "\(APIConfig.baseURL)/register") else {
            throw APIError.decodingError("Invalid URL for register")
        }
        
        let resp = try await post(url, body: userData.compactMapValues { "\($0)" }, as: GenericResponse.self)
        return resp.ok
    }

    func register(name: String, email: String, phone: String, pin: String, role: String) async throws -> User {
        guard let url = URL(string: "\(APIConfig.baseURL)/register") else {
            throw APIError.decodingError("Invalid URL for register")
        }
        let body: [String: Any] = ["name": name, "email": email, "phone": phone, "pin": pin, "role": role]
        let resp = try await post(url, body: body.compactMapValues { "\($0)" }, as: AuthResponse.self)
        guard let user = resp.user else { throw APIError.serverError(500, "Registration failed") }
        return user
    }

    func sendOTP(target: String, isAdmin: Bool = false, isRegistration: Bool = false) async throws -> (ok: Bool, target: String?) {
        guard let url = URL(string: "\(APIConfig.baseURL)/send_otp") else {
            throw APIError.decodingError("Invalid URL for sendOTP")
        }
        let body: [String: Any] = ["target": target, "is_admin": isAdmin, "is_registration": isRegistration]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
             let msg = String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unknown API Error"
             throw APIError.serverError(http.statusCode, msg)
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ok = json["ok"] as? Bool {
            return (ok, json["target"] as? String)
        }
        
        return (true, nil)
    }

    func verifyOTP(target: String, otp: String, isAdmin: Bool) async throws -> User? {
        if let url = URL(string: "\(APIConfig.baseURL)/verify_otp") {
            let body: [String: Any] = ["target": target, "otp": otp, "is_admin": isAdmin]
            let resp = try await post(url, body: body.compactMapValues { "\($0)" }, as: AuthResponse.self)
            return resp.user
        }
        return nil
    }

    func verifyOTP(phone: String, otp: String) async throws -> String {
        if let url = URL(string: "\(APIConfig.baseURL)/verify_otp") {
            let body: [String: Any] = ["phone": phone, "code": otp]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                 let msg = String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unknown API Error"
                 throw APIError.serverError(http.statusCode, msg)
            }
            
            let decoder = JSONDecoder()
            let resp = try decoder.decode(AuthResponse.self, from: data)
            guard let token = resp.token else { throw APIError.serverError(401, "Invalid OTP") }
            return token
        }
        throw APIError.decodingError("Invalid URL for verifyOTP")
    }
    
    func resetPassword(phone: String, newPin: String) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/reset_password") else {
            throw APIError.decodingError("Invalid URL for resetPassword")
        }
        let body: [String: Any] = ["phone": phone, "new_pin": newPin]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
             let msg = String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unknown API Error"
             throw APIError.serverError(http.statusCode, msg)
        }
    }

    // SUPPORT
    // ───────────────────────── SUPPORT & REPORTING ──────────────────────

    /// Reports a general issue (simplified version)
    func reportIssue(title: String, description: String, userId: Int?) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/report") else {
            throw APIError.decodingError("Invalid URL for reportIssue")
        }
        let body: [String: Any] = [
            "title": title,
            "description": description,
            "user_id": userId ?? 0
        ]
        _ = try await post(url, body: body.compactMapValues { "\($0)" }, as: GenericResponse.self)
    }

    /// Primary method for and User Feedback/Issue reporting
    func postReport(email: String?, subject: String, message: String, category: String) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/report") else {
            throw APIError.decodingError("Invalid URL for postReport")
        }
        let body: [String: Any] = [
            "email": email ?? "anonymous",
            "subject": subject,
            "message": message,
            "category": category
        ]
        _ = try await post(url, body: body.compactMapValues { "\($0)" }, as: GenericResponse.self)
    }

    /// Posts a contact message from the Help screen
    func postContact(name: String, email: String, subject: String, message: String) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/contact") else {
            throw APIError.decodingError("Invalid URL for postContact")
        }
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "subject": subject,
            "message": message
        ]
        _ = try await post(url, body: body.compactMapValues { "\($0)" }, as: GenericResponse.self)
    }

    /// Reports a driver-specific issue
    func postDriverReport(email: String, busNumber: String, driverInfo: String, description: String) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/report_driver") else {
            throw APIError.decodingError("Invalid URL for postDriverReport")
        }
        let body: [String: Any] = [
            "user_email": email,
            "bus_number": busNumber,
            "driver_info": driverInfo,
            "description": description
        ]
        _ = try await post(url, body: body.compactMapValues { "\($0)" }, as: GenericResponse.self)
    }

    /// Admin: Fetch all registered students
    func fetchStudents() async throws -> [StudentRecord] {
        guard let url = URL(string: "\(APIConfig.baseURL)/students") else {
            throw APIError.decodingError("Invalid URL for fetchStudents")
        }
        let res = try await fetch(url, as: StudentsResponse.self)
        if !res.ok {
            throw APIError.serverError(0, "Failed to load students")
        }
        return res.students
    }

    // MARK: - Admin Scheduling
    func createTrip(_ trip: CreateTripIn) async throws {
        guard let url = URL(string: "\(APIConfig.baseURL)/trips") else {
            throw APIError.decodingError("Invalid URL for createTrip")
        }
        let _ = try await post(url, body: trip, as: APIObjectResponse<Int>.self)
    }
}

struct GPSIn: Codable {
    let trip_id: Int
    let bus_id: Int
    let lat: Double
    let lng: Double
    var speed: Double? = nil
    var heading: Double? = nil
    var ts: String? = nil
}

// MARK: - Admin History Models
struct AdminHistoryStop: Codable, Identifiable {
    var id: Int { stop_id }
    let stop_id: Int
    let stop_name: String
    let lat: Double
    let lng: Double
    let stop_order: Int
    let sched_arrival: String?
    let sched_departure: String?
    let actual_arrival: String?
    let actual_departure: String?
    let status: String?
    let delay_mins: Int?
}

struct AdminHistoryMapPoint: Codable {
    let lat: Double
    let lng: Double
    let speed: Double?
    let ts: String?
}

struct AdminHistoryTrip: Codable, Identifiable {
    let trip_id: Int?
    let bus_number: String?
    let route_name: String?
    let points: [AdminHistoryMapPoint]?
    let ext_vehicle_id: String?
    
    var id: String {
        if let tid = trip_id, tid != 0 { return "\(tid)" }
        return ext_vehicle_id ?? bus_number ?? UUID().uuidString
    }
}

private struct AdminHistoryTimelineResponse: Codable {
    let ok: Bool
    let trip_id: Int?
    let date: String?
    let timeline: [AdminHistoryStop]?
    let error: String?
}

private struct AdminHistoryMapResponse: Codable {
    let ok: Bool
    let date: String?
    let trips: [AdminHistoryTrip]?
    let error: String?
}

private struct AdminHistoryDatesResponse: Codable {
    let ok: Bool
    let dates: [String]
}

// MARK: - Admin History API methods
extension APIService {
    func fetchAdminHistoryDates() async throws -> [String] {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/admin/history/dates") else {
            throw APIError.decodingError("Invalid URL for fetchAdminHistoryDates")
        }
        let resp = try await fetch(url, as: AdminHistoryDatesResponse.self)
        return resp.dates
    }

    func fetchAdminHistoryTimeline(date: String, tripId: Int?) async throws -> [AdminHistoryStop] {
        let tid = tripId ?? 0
        let url = URL(string: "\(APIConfig.baseURL)/api/admin/history/timeline?date=\(date)&trip_id=\(tid)")!
        let resp = try await fetch(url, as: AdminHistoryTimelineResponse.self)
        return resp.timeline ?? []
    }

    func fetchAdminHistoryMap(date: String, routeName: String? = nil, tripId: Int? = nil) async throws -> [AdminHistoryTrip] {
        var urlStr = "\(APIConfig.baseURL)/api/admin/history/map?date=\(date)"
        if let r = routeName { urlStr += "&route_name=\(r.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? r)" }
        if let t = tripId   { urlStr += "&trip_id=\(t)" }
        let url = URL(string: urlStr)!
        let resp = try await fetch(url, as: AdminHistoryMapResponse.self)
        return resp.trips ?? []
    }
}
