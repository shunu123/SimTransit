import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
final class StudentDashboardViewModel: ObservableObject {
    // MARK: - Published State
    // MARK: - Published State
    @Published var currentUserLocation: CLLocation?
    @Published var allStops: [BusStop] = []
    
    // Top 2 Nearest Stops
    @Published var nearbyStops: [BusStop] = []
    @Published var routes: [String: MKRoute] = [:] // stopId -> route
    @Published var walkingTimes: [String: TimeInterval] = [:] // stopId -> time
    @Published var distances: [String: Double] = [:] // stopId -> km
    
    @Published var selectedStop: BusStop?
    @Published var arrivingBuses: [Bus] = []
    @Published var liveBuses: [String: WSVehicle] = [:] // vid -> vehicle
    
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - Dependencies
    private let locationManager = LocationManager.shared
    private let apiService = APIService.shared
    private let wsService = WebSocketService.shared
    private let shortestPathService = ShortestPathService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var isFirstLoad = true
    
    init() {
        setupBindings()
        
        // Auto-select first stop when nearbyStops changes
        $nearbyStops
            .sink { [weak self] stops in
                if let first = stops.first, self?.selectedStop == nil {
                    self?.selectStop(first)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBindings() {
        locationManager.$userLocation
            .sink { [weak self] location in
                guard let self = self, let location = location else { return }
                self.currentUserLocation = location
                if self.isFirstLoad {
                    self.isFirstLoad = false
                    self.refreshDashboard()
                }
            }
            .store(in: &cancellables)
            
        wsService.gpsPublisher
            .sink { [weak self] vehicles in
                guard let self = self else { return }
                for vehicle in vehicles {
                    if let vid = vehicle.vid {
                        self.liveBuses[vid] = vehicle
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func refreshDashboard() {
        isLoading = true
        Task {
            do {
                let all = try await apiService.fetchAllStops()
                self.allStops = all
                if let loc = currentUserLocation {
                    findNearbyStops(from: loc)
                }
            } catch {
                self.error = "Could not load stops: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func findNearbyStops(from location: CLLocation) {
        // 1. Filter stops within 5km (5000 meters) and sort by proximity (straight-line for ranking)
        let filteredAndSorted = allStops
            .filter { stop in
                CLLocation(latitude: stop.lat, longitude: stop.lng).distance(from: location) <= 5000
            }
            .sorted { s1, s2 in
                let d1 = CLLocation(latitude: s1.lat, longitude: s1.lng).distance(from: location)
                let d2 = CLLocation(latitude: s2.lat, longitude: s2.lng).distance(from: location)
                return d1 < d2
            }
        
        // 2. Limit to top 10 closest stops for detailed route calculation
        let discovered = Array(filteredAndSorted.prefix(10))
        self.nearbyStops = discovered
        
        // 3. Batch calculate actual walking routes for accuracy
        for stop in discovered {
            calculateWalkingRoute(to: stop, from: location)
        }
        
        // 4. Auto-select the nearest stop if none selected
        if let first = discovered.first, selectedStop == nil {
            selectStop(first)
        }
    }
    
    func selectStop(_ stop: BusStop) {
        self.selectedStop = stop
        if let loc = currentUserLocation {
            calculateWalkingRoute(to: stop, from: loc)
        }
    }
    
    private func calculateWalkingRoute(to stop: BusStop, from location: CLLocation) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: stop.coordinate))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.routes[stop.id] = route
                    self.walkingTimes[stop.id] = route.expectedTravelTime
                    // USE ACTUAL ROUTE DISTANCE (meters -> km)
                    self.distances[stop.id] = route.distance / 1000.0
                }
            }
        }
    }
    
    func openInMaps() {
        guard let selected = selectedStop else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: selected.coordinate))
        mapItem.name = selected.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
    
    deinit {
        Task { @MainActor [wsService] in
            wsService.disconnect()
        }
    }
}
