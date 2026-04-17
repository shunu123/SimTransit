import Foundation
import CoreLocation

// MARK: - Core Support Models

struct TransitGPS: Codable, Hashable, Equatable {
    let lat: Double
    let lon: Double
    let heading: Int
    let speed_mph: Int
}

enum JSONValue: Codable, Hashable, Equatable {
    case string(String)
    case double(Double)
    case bool(Bool)
    case int(Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
        } else if let x = try? container.decode(Double.self) {
            self = .double(x)
        } else if let x = try? container.decode(Int.self) {
            self = .int(x)
        } else if let x = try? container.decode(Bool.self) {
            self = .bool(x)
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONValue"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x): try container.encode(x)
        case .double(let x): try container.encode(x)
        case .bool(let x): try container.encode(x)
        case .int(let x): try container.encode(x)
        }
    }
    
    var doubleValueValue: Double? {
        switch self {
        case .string(let s): return Double(s)
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }
}

struct TimelineStop: Codable, Identifiable, Hashable, Equatable {
    var id: String { "\(stopId)" }

    let stopOrder: Int
    let stopId: Int
    let stopName: String
    private let rawLat: JSONValue
    private let rawLng: JSONValue
    
    var lat: Double { rawLat.doubleValueValue ?? 0.0 }
    var lng: Double { rawLng.doubleValueValue ?? 0.0 }

    let schedArrival: String?
    let schedDeparture: String?
    let realtimeEta: String?
    let delaySec: Int?
    let isReached: Bool?
    let isMajor: Bool?
    let eta: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case stopOrder      = "stop_order"
        case stopId         = "stop_id"
        case stopName       = "stop_name"
        case rawLat         = "lat"
        case rawLng         = "lng"
        case schedArrival   = "sched_arrival"
        case schedDeparture = "sched_departure"
        case realtimeEta    = "realtime_eta"
        case delaySec       = "delay_sec"
        case isReached      = "is_reached"
        case isMajor        = "is_major"
        case eta
        case status
    }
}

struct TransitTimelineResponse: Codable, Hashable, Equatable {
    let ok: Bool
    let timeline: [TimelineStop]
    let polyline: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case timeline
        case polyline = "route_polyline"
    }
}

struct SearchTrip: Codable, Identifiable, Hashable, Equatable {
    var id: Int { tripId }

    let tripId: Int
    let extTripId: String?
    let busId: Int?
    let busNo: String?
    let label: String?
    let routeId: Int?
    let routeName: String?
    let extRouteId: String?
    let fromDeparture: String?
    let toArrival: String?
    let durationMinutes: Int?
    let status: String?
    let busLiveLocation: TransitGPS?
    let nextStopName: String?
    let currentStopName: String?
    let routeStartName: String?
    let routeEndName: String?

    enum CodingKeys: String, CodingKey {
        case tripId          = "trip_id"
        case extTripId       = "ext_trip_id"
        case busId           = "bus_id"
        case busNo           = "bus_no"
        case label
        case routeId         = "route_id"
        case routeName       = "route_name"
        case extRouteId      = "ext_route_id"
        case fromDeparture   = "from_departure"
        case toArrival       = "to_arrival"
        case durationMinutes = "duration_minutes"
        case status
        case busLiveLocation = "bus_live_location"
        case nextStopName    = "next_stop_name"
        case currentStopName = "current_stop_name"
        case routeStartName  = "route_start_name"
        case routeEndName    = "route_end_name"
    }
}

// MARK: - Extensions for TimelineStop Processing

extension TimelineStop {
    func toStop() -> Stop {
        var timeText: String? = nil
        var date: Date? = nil
        let displayTimeStr = realtimeEta ?? schedArrival ?? eta
        
        // India Standard Time
        let ist = TimeZone(identifier: "Asia/Kolkata") ?? TimeZone(secondsFromGMT: 19800)!
        
        if let timeStr = displayTimeStr {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = iso.date(from: timeStr)
            
            if date == nil {
                let isoNoFraction = ISO8601DateFormatter()
                isoNoFraction.formatOptions = [.withInternetDateTime]
                date = isoNoFraction.date(from: timeStr)
            }
            
            if date == nil {
                let f = DateFormatter()
                f.calendar = Calendar(identifier: .iso8601)
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(secondsFromGMT: 0)
                
                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
                    "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                    "yyyy-MM-dd HH:mm:ss",
                    "HH:mm:ss"
                ]
                for format in formats {
                    f.dateFormat = format
                    if let d = f.date(from: timeStr) {
                        date = d
                        break
                    }
                }
            }
            
            if let d = date {
                let tf = DateFormatter()
                tf.timeZone = ist
                tf.dateFormat = "h:mm a"
                timeText = tf.string(from: d)
            } else {
                let parts = timeStr.components(separatedBy: CharacterSet(charactersIn: "T "))
                if let last = parts.last, last.contains(":") {
                    let timeParts = last.components(separatedBy: ":")
                    if timeParts.count >= 2 {
                        timeText = "\(timeParts[0]):\(timeParts[1])"
                    }
                }
            }
        }
        
        let departureEta = estimateDeparture(arrivalEta: realtimeEta ?? eta, schedArr: schedArrival, schedDep: schedDeparture)
        
        return Stop(
            id: "\(stopId)",
            name: stopName,
            coordinate: Coord(lat: lat, lon: lng),
            timeText: timeText ?? "--:--",
            isMajorStop: isMajor ?? false,
            stopOrder: stopOrder,
            realtimeArrival: date,
            scheduledArrival: schedArrival,
            scheduledDeparture: schedDeparture,
            realtimeEta: realtimeEta ?? eta,
            realtimeDepartureEta: departureEta
        )
    }

    private func estimateDeparture(arrivalEta: String?, schedArr: String?, schedDep: String?) -> String? {
        guard let arr = arrivalEta else { return schedDep }
        let ist = TimeZone(identifier: "Asia/Kolkata") ?? TimeZone(secondsFromGMT: 19800)!
        
        if let sArr = schedArr, let sDep = schedDep {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            f.timeZone = ist
            if let dArr = f.date(from: sArr), let dDep = f.date(from: sDep) {
                let dwell = dDep.timeIntervalSince(dArr)
                if dwell > 0 {
                    let iso = ISO8601DateFormatter()
                    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let aDate = iso.date(from: arr) {
                        return iso.string(from: aDate.addingTimeInterval(dwell))
                    } else if let aDate = f.date(from: arr) {
                        return f.string(from: aDate.addingTimeInterval(dwell))
                    }
                }
            }
        }
        
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let aDate = iso.date(from: arr) {
            return iso.string(from: aDate.addingTimeInterval(30))
        }
        return schedDep
    }
}

// MARK: - CTA API Response Models

struct TransitTrackResponse: Codable, Hashable, Equatable {
    let route_id: String
    let trip_id: String?
    let from_stop: String
    let to_stop: String
    let schedule: TransitSchedule
    let duration: String
    let timeline: [TransitTimelineStop]
    let bus_live_location: TransitGPS?
    let polyline: [TransitPolylinePoint]
}

struct TransitSchedule: Codable, Hashable, Equatable {
    let departure_time: String
    let arrival_time: String
}

struct TransitTimelineStop: Codable, Hashable, Equatable {
    let stop_id: String
    let stop_name: String
    let eta: String
    let is_current: Bool
}

struct TransitPolylinePoint: Codable, Hashable, Equatable {
    let lat: Double
    let lng: Double
    let typ: String?
}

struct TransitDirection: Codable {
    let dir: String
}

// MARK: - New Unified Trip Models
struct TransitFullTripResponse: Codable, Hashable, Equatable {
    let ok: Bool
    let vid: String
    let route: String
    let direction: String
    let live_location: TransitGPS?
    let polyline: [TransitPolylinePoint]
    let timeline: [TimelineStop]
}
