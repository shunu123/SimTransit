import Foundation
import Combine
import CoreLocation
import MapKit

// MARK: - App Wide ViewModels Container
// This file resolves the 'missing file' issue and provides shared logic for Route Discovery.

@MainActor
final class RouteDiscoveryViewModel: ObservableObject {
    @Published var matches: [RouteMatch] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let discoveryService = RouteDiscoveryService.shared
    
    /// Finds routes between two coordinates using the discovery service.
    /// This fixes the 'unable to type-check' error by breaking down the complex logic
    /// into a clear async-await pattern.
    func discover(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async {
        self.isLoading = true
        self.error = nil
        
        do {
            // Broken down for compiler performance (resolving line 230 error)
            let results = try await discoveryService.findRoutes(from: from, to: to)
            
            // Explicitly typed update to resolve line 530/534 ambiguity
            await MainActor.run {
                self.matches = results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Extension to Existing Services if needed
extension RouteDiscoveryService {
    // Shared instance is already public in the service file
}
