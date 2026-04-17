import Foundation
import CoreLocation

// Shared models used for navigation in AppRouter


struct TripTimelineEvent: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let title: String
    let subtitle: String?
    let eventType: EventType
    
    enum EventType: String, Hashable {
        case tripStart = "Trip Started"
        case stopReached = "Stop Reached"
        case halt = "Halted"
        case deviation = "Route Deviation"
        case tripEnd = "Trip Completed"
    }
    
    init(id: UUID = UUID(), timestamp: Date, title: String, subtitle: String? = nil, eventType: EventType) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.subtitle = subtitle
        self.eventType = eventType
    }
}
