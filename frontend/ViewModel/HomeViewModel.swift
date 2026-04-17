import Foundation
import Combine
import Speech
import AVFoundation
import CoreLocation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Search Fields
    @Published var fromText: String = ""
    @Published var toText: String = ""
    @Published var fromID: String? = nil
    @Published var toID: String? = nil
    @Published var fromSuggestions: [BusStop] = []
    @Published var toSuggestions: [BusStop] = []

    
    // Objects with coordinates for map routing
    @Published var fromStop: BusStop? = nil
    @Published var toStop: BusStop? = nil


    // MARK: - Secondary Search
    @Published var busNumberSearch: String = ""
    @Published var stopSearchText: String = ""

    // MARK: - History / Manual Sheet
    @Published var isHistoryMode: Bool = false
    @Published var historyDate: Date = Date()

    // MARK: - Fleet History toggle (bottom bar)
    @Published var isFleetHistoryMode: Bool = false
    
    // MARK: - Persistent Recent Searches
    @Published var recentSearches: [RecentSearch] = []
    @Published var recentBusNumbers: [String] = []

    // MARK: - Voice
    @Published var voice: VoiceAssistant = VoiceAssistant()
    @Published var isSpeechAuthorized: Bool = false
    @Published var isListening: Bool = false
    @Published var transcript: String = ""

    // MARK: - Permissions overlay
    @Published var showPermissions: Bool = false

    // MARK: - Dynamic Header
    @Published var dynamicHeaderInfo: String = ""
    @Published var showDynamicHeader: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isSearchingFrom: Bool = false
    @Published var isSearchingTo: Bool = false

    // MARK: - Router (set by HomeView.onAppear)
    var router: AppRouter?

    // MARK: - Dependencies
    private let locationManager: LocationManager

    // MARK: - Init
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        loadRecentSearches()
        
        // Auto-process when voice assistant detects silence
        voice.onSilenceRecognized = { [weak self] in
            Task { @MainActor in
                self?.processVoiceCommand()
            }
        }
        
        // Modern async sequence bindings
        Task { [weak self] in
            for await val in voice.$isListening.values {
                self?.isListening = val
            }
        }
        
        Task { [weak self] in
            for await val in voice.$transcript.values {
                self?.transcript = val
            }
        }
    }

    func loadRecentSearches() {
        if !UserDefaults.standard.bool(forKey: "didClearOldDataForDelhi") {
            SearchHistoryService.shared.clearAll()
            BusSearchHistoryService.shared.clear()
            UserDefaults.standard.set(true, forKey: "didClearOldDataForDelhi")
        }

        Task {
            isLoading = true
            
            // 1. Load local history immediately (Fast)
            let localSearches = SearchHistoryService.shared.all().map { 
                RecentSearch(id: Int.random(in: 1000...9999), from_stop_id: "local", to_stop_id: "local", from_name: $0.from, to_name: $0.to, ts: "")
            }
            let busNumbers = BusSearchHistoryService.shared.all()
            
            await MainActor.run {
                self.recentSearches = localSearches
                self.recentBusNumbers = busNumbers
            }

            // 2. Fetch from backend and merge (Might be slower)
            do {
                let user = SessionManager.shared.currentUser
                let role = SessionManager.shared.userRole ?? "student"
                let backendSearches = try await APIService.shared.fetchRecentSearches(role: role, userId: user?.id)
                
                await MainActor.run {
                    var finalSearches = localSearches
                    for b in backendSearches {
                        if !finalSearches.contains(where: { $0.from_name == b.from_name && $0.to_name == b.to_name }) {
                            finalSearches.append(b)
                        }
                    }
                    self.recentSearches = finalSearches
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Failed to load backend searches: \(error.localizedDescription)")
                }
            }
        }
    }

    func useRecentSearch(_ search: RecentSearch) {
        fromText = search.from_name
        toText = search.to_name
        fromID = search.from_stop_id
        toID = search.to_stop_id
        
        // Show the search view as a fallback, but try direct navigation first
        Task {
            isLoading = true
            do {
                // If local/name-based, we might not have IDs
                if search.from_stop_id == "local" || search.to_stop_id == "local" || search.from_stop_id == "unknown" {
                    throw APIError.decodingError("Local search requires AvailableBusesView fallback")
                }

                let trips = try await APIService.shared.searchTrips(fromStopId: search.from_stop_id, toStopId: search.to_stop_id)
                
                await MainActor.run {
                    if let trip = trips.first {
                        // Construct a bus object to register it in the repo for schedule view
                        let bus = mapTripToBus(trip, from: search.from_name, to: search.to_name)
                        BusRepository.shared.register(bus: bus)
                        router?.go(.busSchedule(busID: bus.id.uuidString, searchPoint: search.from_name, destinationStop: search.to_name))
                    } else {
                        router?.go(.availableBuses(
                            from: fromText,
                            to: toText,
                            fromID: fromID,
                            toID: toID,
                            fromLat: fromStop?.coordinate.latitude,
                            fromLon: fromStop?.coordinate.longitude,
                            toLat: toStop?.coordinate.latitude,
                            toLon: toStop?.coordinate.longitude,
                            via: nil
                        ))


                    }
                }
            } catch {
                print("Search failed for direct navigation: \(error)")
                await MainActor.run {
                    router?.go(.availableBuses(
                        from: fromText,
                        to: toText,
                        fromID: fromID,
                        toID: toID,
                        fromLat: fromStop?.coordinate.latitude,
                        fromLon: fromStop?.coordinate.longitude,
                        toLat: toStop?.coordinate.latitude,
                        toLon: toStop?.coordinate.longitude,
                        via: nil
                    ))


                }
            }
            isLoading = false
        }
    }

    private func mapTripToBus(_ trip: SearchTrip, from: String, to: String) -> Bus {
        // Simple mapping similar to AvailableBusesViewModel
        let ds = (trip.fromDeparture ?? "--").replacingOccurrences(of: "Z", with: "")
        var departsAtStr = "--"
        let parts = ds.components(separatedBy: "T")
        let timeString = parts.count > 1 ? parts[1] : ""
        let timeParts = timeString.components(separatedBy: ":")
        if timeParts.count >= 2 {
            let hourStr = timeParts[0]
            let minStr = timeParts[1]
            if let hr = Int(hourStr) {
                let ampm = hr >= 12 ? "PM" : "AM"
                let hr12 = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
                departsAtStr = String(format: "%02d:%@ %@", hr12, minStr, ampm)
            }
        }

        let existingId = BusRepository.shared.allBuses.first(where: { bus in
            if let extID = bus.extTripId, extID == trip.extTripId { return true }
            if let vid = bus.vehicleId, vid == trip.tripId { return true }
            return false
        })?.id ?? UUID()

        return Bus(
            id: existingId,
            number: trip.busNo ?? "N/A",
            headsign: trip.label ?? trip.routeName ?? "College Bus",
            departsAt: departsAtStr,
            durationText: "\(trip.durationMinutes ?? 0)m",
            status: .onTime,
            statusDetail: trip.status ?? "Scheduled",
            trackingStatus: TrackingStatus(rawValue: trip.status?.capitalized ?? "Scheduled") ?? .scheduled,
            etaMinutes: trip.durationMinutes,
            route: Route(from: from, to: to, stops: []),
            vehicleId: trip.tripId,
            busId: trip.busId,
            extTripId: trip.extTripId
        )
    }

    // MARK: - Permissions

    func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        isSpeechAuthorized = (speechStatus == .authorized)
    }

    func requestPermissions() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        session.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.isSpeechAuthorized = granted
            }
        }
        #else
        // On macOS, recording permissions are handled differently, often via Info.plist or System Preferences.
        // For now, assume authorized if we can access the engine.
        self.isSpeechAuthorized = true
        #endif
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isSpeechAuthorized = (status == .authorized)
                self?.showPermissions = false
            }
        }
    }

    func skipPermissions() {
        showPermissions = false
    }

    // MARK: - Voice Command

    func processVoiceCommand() {
        let transcript = voice.transcript.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }
        
        Task {
            // Show loading if needed, or just process
            if let response = await LLMVoiceParser.shared.parseIntent(transcript: transcript) {
                handleLLMResponse(response)
            } else {
                voice.speak(text: "I couldn't quite understand that online. Please check your connection.")
            }
        }
    }
    
    @MainActor
    private func handleLLMResponse(_ res: LLMIntentResponse) {
        print("🎯 Command: \(res.command)")
        
        // Always speak back if the backend provided a response
        if let feedback = res.speech_response {
            voice.speak(text: feedback)
        }
        
        switch res.command {
        case "SEARCH":
            if let from = res.from_stop, let to = res.to_stop {
                fromText = from
                toText = to
                router?.go(AppRouter.AppPage.availableBuses(from: from, to: to))
            } else if let from = res.from_stop {
                fromText = from
                // Wait for destination
            } else if let to = res.to_stop {
                toText = to
                // Wait for starting point
            }
            
        case "TRACK":
            if let num = res.bus_number {
                self.busNumberSearch = num
                router?.go(AppRouter.AppPage.trackByNumber(autoStartVoice: false))
            }
            
        case "NAVIGATE":
            if let screen = res.screen {
                switch screen.uppercased() {
                case "HELP": router?.go(.help)
                case "REPORT": router?.go(.report)
                case "ABOUT": router?.go(.about)
                case "LOGOUT":
                    SessionManager.shared.logout()
                    router?.popToRoot()
                case "HISTORY": router?.go(.recentSearches)
                case "FLEET_MAP": router?.go(.activeFleet)
                case "SETTINGS": router?.go(.settings)
                case "ALL_ROUTES": router?.go(.allRoutes)
                case "BACK": router?.back()
                case "HOME": router?.popToRoot()
                default: break
                }
            }
            
        case "STATUS":
            // Just status, speech handled above
            break
            
        default:
            print("Unknown voice command: \(res.command)")
        }
    }
    
    private func normalizeNumbers(_ text: String) -> String {
        var result = text
        let map = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
            "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
            "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
            "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
            "eighteen": "18", "nineteen": "19", "twenty": "20", "thirty": "30",
            "forty": "40", "fifty": "50", "sixty": "60", "seventy": "70",
            "eighty": "80", "ninety": "90"
        ]
        for (word, digit) in map {
            result = result.replacingOccurrences(of: "\\b\(word)\\b", with: digit, options: .regularExpression)
        }
        return result
    }
    
    private func levenshtein(_ a: String, _ b: String) -> Int {
        let empty = [Int](repeating: 0, count: b.count)
        var last = [Int](0...b.count)
        for (i, char1) in a.enumerated() {
            var cur = [i + 1] + empty
            for (j, char2) in b.enumerated() {
                cur[j + 1] = char1 == char2 ? last[j] : Swift.min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last ?? 0
    }

    // MARK: - Suggestions

    func updateFromSuggestions() {
        let query = fromText.lowercased()
        if query.isEmpty {
            self.fromSuggestions = []
            return
        }
        
        // 1. Local history suggestions (Available from 1 character)
        let historyMatches = SearchHistoryService.shared.all()
            .filter { $0.from.lowercased().starts(with: query) }
            .map { BusStop(id: "0", name: $0.from, lat: 0, lng: 0) }
        
        if query.count < 3 {
            self.fromSuggestions = []
            self.isSearchingFrom = false
            return
        }
        
        self.isSearchingFrom = true
        
        Task {
            // 2. API suggestions (Available from 2 characters)
            let regNo = SessionManager.shared.currentUserRegNo
            let role = SessionManager.shared.userRole ?? "student"
            let results = await StopSuggestionService.shared.suggestions(query: query, regNo: regNo, role: role)
            await MainActor.run { 
                guard self.fromText.lowercased() == query else { return }
                
                // Combine and deduplicate
                var combined = historyMatches
                for r in results {
                    if !combined.contains(where: { $0.name.lowercased() == r.name.lowercased() }) {
                        combined.append(r)
                    }
                }
                
                if combined.count == 1 && combined[0].name.lowercased() == query {
                    self.fromSuggestions = []
                } else {
                    self.fromSuggestions = combined 
                }
                self.isSearchingFrom = false
            }
        }
    }

    func updateToSuggestions() {
        let query = toText.lowercased()
        if query.isEmpty {
            self.toSuggestions = []
            return
        }
        
        // 1. Local history suggestions (Available from 1 character)
        let historyMatches = SearchHistoryService.shared.all()
            .filter { $0.to.lowercased().starts(with: query) }
            .map { BusStop(id: "0", name: $0.to, lat: 0, lng: 0) }
            
        if query.count < 3 {
            self.toSuggestions = []
            self.isSearchingTo = false
            return
        }
        
        self.isSearchingTo = true
        
        Task {
            // 2. API suggestions (Available from 2 characters)
            let regNo = SessionManager.shared.currentUserRegNo
            let role = SessionManager.shared.userRole ?? "student"
            let results = await StopSuggestionService.shared.suggestions(query: query, regNo: regNo, role: role)
            await MainActor.run { 
                guard self.toText.lowercased() == query else { return }
                
                // Combine and deduplicate
                var combined = historyMatches
                for r in results {
                    if !combined.contains(where: { $0.name.lowercased() == r.name.lowercased() }) {
                        combined.append(r)
                    }
                }
                
                if combined.count == 1 && combined[0].name.lowercased() == query {
                    self.toSuggestions = []
                } else {
                    self.toSuggestions = combined 
                }
                self.isSearchingTo = false
            }
        }
    }

    func selectFrom(_ stop: BusStop) {
        fromText = stop.name
        fromID = stop.id
        fromStop = stop
        fromSuggestions = []
    }

    func selectTo(_ stop: BusStop) {
        toText = stop.name
        toID = stop.id
        toStop = stop
        toSuggestions = []
    }

    // MARK: - Final Validation before Search
    
    /// Checks if typed stop names exist in the database and resolves them to IDs/Coordinates
    /// Returns true if both from and to are valid.
    func validateStopsBeforeSearch() async -> Bool {
        // If already resolved, we're good
        if fromID != nil && toID != nil && fromStop != nil && toStop != nil { return true }
        
        do {
            let allStops = try await APIService.shared.fetchAllStops()
            
            // Try to resolve 'From' stop
            if fromID == nil || fromStop == nil {
                let match = allStops.first { $0.name.lowercased() == fromText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                if let m = match {
                    selectFrom(m)
                }
            }
            
            // Try to resolve 'To' stop
            if toID == nil || toStop == nil {
                let match = allStops.first { $0.name.lowercased() == toText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                if let m = match {
                    selectTo(m)
                }
            }
            
            return fromID != nil && toID != nil
            
        } catch {
            print("Validation fetch failed: \(error)")
            return false
        }
    }

    // MARK: - Swap

    func swap() {
        let tempText = fromText
        let tempID = fromID
        let tempStop = fromStop
        
        fromText = toText
        fromID = toID
        fromStop = toStop
        
        toText = tempText
        toID = tempID
        toStop = tempStop
        
        fromSuggestions = []
        toSuggestions = []
    }
    
    func clearManualSearch() {
        self.busNumberSearch = ""
    }

    // MARK: - Dynamic Header Helpers
    
    func prepareDynamicHeader() {
        dynamicHeaderInfo = getTimeBasedGreeting()
        showDynamicHeader = true
    }

    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Have a Good Night"
        }
    }
}
