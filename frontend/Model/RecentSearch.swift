import Foundation

/// Represents a recently searched from-to route.
struct RecentSearch: Codable, Identifiable, Hashable {
    let id: Int
    let from_stop_id: String
    let to_stop_id: String
    let from_name: String
    let to_name: String
    let ts: String
}
