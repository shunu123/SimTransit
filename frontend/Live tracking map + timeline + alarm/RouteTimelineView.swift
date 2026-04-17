import SwiftUI

struct RouteTimelineView: View {
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject var vm: LiveTrackingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header - High Resolution Arrival/Departure Info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Service No")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.current.secondaryText.opacity(0.6))
                        Text(vm.bus.number)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(theme.current.text)
                    }
                    Spacer()
                    Button(action: { vm.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.current.secondaryText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // The Tabular Header Bar (Light Teal/Mint)
                HStack(spacing: 0) {
                    Text("Arrival")
                        .frame(width: 80, alignment: .leading)
                    Text("Stop Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Departure")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.7, green: 0.87, blue: 0.86)) // Teal #B2DFDB
                .foregroundStyle(Color.black.opacity(0.7))
            }
            .background(theme.current.card)

            ScrollView(showsIndicators: false) {
                if vm.isLoadingTimeline {
                    loadingState
                } else if vm.stops.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(0..<vm.stops.count, id: \.self) { index in
                            stopRow(for: index)
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .background(theme.current.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func stopRow(for index: Int) -> some View {
        let s = vm.stops[index]
        
        let normalize = { (txt: String) in txt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let sName = normalize(s.name)
        let isSource = vm.sourceName.isEmpty ? (index == 0) : (sName.contains(normalize(vm.sourceName)) || normalize(vm.sourceName).contains(sName))
        
        let globalIndex = vm.bus.route.stops.firstIndex(where: { $0.id == s.id }) ?? index
        
        let isPast = globalIndex < vm.bus.currentStopIndex
        let isCurrent = globalIndex == vm.bus.currentStopIndex
        let isLast = index == vm.stops.count - 1
        
        let isRunning = (vm.bus.liveTelemetry.speedKmph ?? 0) > 5
        let (status, statusColor): (String, Color) = {
            if vm.isWaitingForGPS {
                return ("Scheduled", theme.current.secondaryText.opacity(0.4))
            } else if globalIndex < vm.bus.currentStopIndex {
                return ("Left", Color.blue.opacity(0.8))
            } else if globalIndex == vm.bus.currentStopIndex {
                return (isRunning ? "Left" : "Arrived", isRunning ? Color.blue.opacity(0.8) : Color.green.opacity(0.8))
            } else {
                return ("Approximation", theme.current.secondaryText.opacity(0.6))
            }
        }()
        
        // Dynamic Progress Logic
        let progress = isCurrent ? getProgress(for: index) : 0
        let upperLineColor = (!vm.isWaitingForGPS && globalIndex <= vm.bus.currentStopIndex && !isSource) ? Color.blue.opacity(0.8) : theme.current.secondaryText.opacity(0.2)
        let lowerLineColor = (!vm.isWaitingForGPS && globalIndex < vm.bus.currentStopIndex) ? Color.blue.opacity(0.8) : theme.current.secondaryText.opacity(0.2)
        
        ZStack(alignment: .top) {
            // Background for current stop (subtle highlight)
            if isCurrent {
                Color.blue.opacity(0.05)
                    .edgesIgnoringSafeArea(.horizontal)
            }
            
            HStack(spacing: 0) {
                // Column 1: Arrival Time
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if isSource {
                            Text("Source")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.current.secondaryText.opacity(0.4))
                        }
                    }
                    
                    Text(formatTime(s.scheduledArrival))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(isPast ? theme.current.secondaryText.opacity(0.5) : theme.current.text)
                    
                    if !isPast {
                        let eta = etaLabel(for: s, at: index)
                        if eta != "--:--" {
                            let isDelayed = checkIsDelayed(live: eta, sched: s.scheduledArrival)
                            Text("ETA: \(eta)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isDelayed ? .red : .green)
                        }
                    }
                }
                .frame(width: 80, alignment: .leading)
                
                // Column 2: Indicator & Line (The Moving Core)
                VStack(spacing: 0) {
                    // Upper line
                    Rectangle()
                        .fill(upperLineColor)
                        .frame(width: 2, height: 25)
                    
                    // The Stop Circle
                    Circle()
                        .fill((!vm.isWaitingForGPS && globalIndex <= vm.bus.currentStopIndex) ? Color.blue.opacity(0.8) : Color(red: 0.7, green: 0.87, blue: 0.86))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2)
                        )
                    
                    // Lower line
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(lowerLineColor)
                            .frame(width: 2, height: 35)
                        
                        // Partially blue lower line if current progress
                        if isCurrent && !isLast {
                            Rectangle()
                                .fill(Color.blue.opacity(0.8))
                                .frame(width: 2, height: 35 * progress)
                            
                            // Moving Bus Icon
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 14, height: 14)
                                    .shadow(radius: 2)
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white)
                            }
                            .offset(y: (35 * progress) - 7)
                        }
                    }
                }
                .frame(width: 40)
                
                // Column 3: Stop Name & Status
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name.uppercased())
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(isPast ? theme.current.secondaryText.opacity(0.6) : theme.current.text)
                    
                    if !isPast, status == "Approximation", let mins = minutesToStop(for: s, at: index), mins > 0 {
                        Text("Arriving in \(formatDuration(minutes: mins))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(mins <= 5 ? .red : .green)
                    } else {
                        Text(status)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isPast ? Color.blue.opacity(0.4) : statusColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Column 4: Departure Time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(s.scheduledDeparture))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(isPast ? theme.current.secondaryText.opacity(0.5) : theme.current.text)
                    
                    // Actual departure time if passed
                    if globalIndex <= vm.bus.currentStopIndex, let realDep = s.realtimeDepartureEta {
                        Text(formatTime(realDep))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.green.opacity(isPast ? 0.6 : 1.0))
                    } else {
                        Text("-")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.current.secondaryText.opacity(0.2))
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func getProgress(for index: Int) -> Double {
        guard index >= 0 && index < vm.stops.count - 1 else { return 0 }
        let currentPolyIdx = Int(vm.currentIndex)
        
        let startPolyIdx = findPolyIdx(for: vm.stops[index])
        let endPolyIdx = findPolyIdx(for: vm.stops[index+1])
        
        guard endPolyIdx > startPolyIdx else { return 0 }
        
        let progress = Double(currentPolyIdx - startPolyIdx) / Double(endPolyIdx - startPolyIdx)
        return min(max(progress, 0), 1)
    }

    private func findPolyIdx(for stop: Stop) -> Int {
        let path = vm.fullRoutePath
        guard !path.isEmpty else { return 0 }
        
        var closestIdx = 0
        var minDistance = Double.infinity
        
        // Basic optimization: search range around current index or just full if small
        for (idx, coord) in path.enumerated() {
            let dLat = coord.lat - stop.coordinate.lat
            let dLon = coord.lon - stop.coordinate.lon
            let d = dLat * dLat + dLon * dLon
            if d < minDistance {
                minDistance = d
                closestIdx = idx
            }
        }
        return closestIdx
    }

    private func checkIsDelayed(live: String, sched: String?) -> Bool {
        guard let sched = sched else { return false }
        let l = live.replacingOccurrences(of: " ", with: "")
        let s = formatScheduledTime(sched).replacingOccurrences(of: " ", with: "")
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        guard let lDate = df.date(from: l), let sDate = df.date(from: s) else { return false }
        return lDate.timeIntervalSince(sDate) > 60 // 1 minute late
    }

    /// Formats any time string (ISO full, HH:mm:ss, HH:mm, h:mm a) → "h:mm a"
    private func formatTime(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "--:--" }
        if raw.contains(" AM") || raw.contains(" PM") { return raw }
        
        let ist = TimeZone(identifier: "Asia/Kolkata") ?? .current
        
        // Full ISO datetime (e.g. realtimeEta "2026-04-13T10:31:00+05:30")
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return shortTime(d, tz: ist) }
        
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        if let d = iso2.date(from: raw) { return shortTime(d, tz: ist) }
        
        // Backend datetime (often missing 'T'): "yyyy-MM-dd HH:mm:ss"
        let fFull = DateFormatter()
        fFull.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fFull.timeZone = ist
        if let d = fFull.date(from: raw) { return shortTime(d, tz: ist) }
        
        // HH:mm:ss or HH:mm (database schedule fields)
        for fmt in ["HH:mm:ss", "HH:mm"] {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.timeZone = ist
            if let d = f.date(from: raw) { return shortTime(d, tz: ist) }
        }
        
        // Last resort: extract time chunk if space exists, else take first 5
        if raw.contains(" "), let timePart = raw.split(separator: " ").last {
            return String(timePart.prefix(5))
        }
        
        return String(raw.prefix(5))
    }
    
    /// Formats a scheduled arrival string ("HH:mm:ss" from DB) to "HH:mm"
    private func formatScheduledTime(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "--:--" }
        let ist = TimeZone(identifier: "Asia/Kolkata") ?? .current
        for fmt in ["HH:mm:ss", "HH:mm"] {
            let f = DateFormatter()
            f.dateFormat = fmt
            f.timeZone = ist
            if let d = f.date(from: raw) {
                let out = DateFormatter()
                out.dateFormat = "HH:mm"
                out.timeZone = ist
                return out.string(from: d)
            }
        }
        return String(raw.prefix(5))
    }
    
    private func shortTime(_ date: Date, tz: TimeZone) -> String {
        let out = DateFormatter()
        out.dateFormat = "HH:mm"
        out.timeZone = tz
        return out.string(from: date)
    }
    
    private func formatDuration(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min\(minutes == 1 ? "" : "s")"
        } else {
            let hrs = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hrs) hr\(hrs == 1 ? "" : "s")"
            }
            return "\(hrs) hr \(mins) min"
        }
    }
    
    /// Returns the ETA label for a stop.
    /// Priority: (1) Apple Maps live ETA from ViewModel, (2) realtimeEta ISO string from backend,
    /// (3) scheduledArrival from DB (the most reliable fallback).
    private func etaLabel(for stop: Stop, at index: Int) -> String {
        // 1. Apple Maps live ETA (minutes remaining)
        let mins = vm.etaToStop(index: index)
        if mins > 0 {
            let eta = Date().addingTimeInterval(TimeInterval(mins * 60))
            return shortTime(eta, tz: TimeZone(identifier: "Asia/Kolkata") ?? .current)
        }
        
        // 2. Backend realtime ETA ISO string
        if let rt = stop.realtimeEta, !rt.isEmpty {
            return formatTime(rt)
        }
        
        // 3. Scheduled arrival from DB — the ground truth
        if let sched = stop.scheduledArrival, !sched.isEmpty {
            return formatScheduledTime(sched)
        }
        
        return "--:--"
    }
    
    private func minutesToStop(for stop: Stop, at index: Int) -> Int? {
        let mins = vm.etaToStop(index: index)
        if mins > 0 { return mins }
        
        // Trust the clock time over the date, since backend dates may be misaligned
        let timeString = etaLabel(for: stop, at: index)
        if timeString == "--:--" { return nil }
        
        let ist = TimeZone(identifier: "Asia/Kolkata") ?? .current
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = ist
        guard let targetTime = f.date(from: timeString) else { return nil }
        
        let now = Date()
        var cal = Calendar.current
        cal.timeZone = ist
        
        let nowComps = cal.dateComponents([.year, .month, .day], from: now)
        let targetComps = cal.dateComponents([.hour, .minute], from: targetTime)
        
        var targetDateComps = DateComponents()
        targetDateComps.year = nowComps.year
        targetDateComps.month = nowComps.month
        targetDateComps.day = nowComps.day
        targetDateComps.hour = targetComps.hour
        targetDateComps.minute = targetComps.minute
        
        guard let calculatedDate = cal.date(from: targetDateComps) else { return nil }
        
        var diff = Int(calculatedDate.timeIntervalSince(now) / 60)
        
        // If difference is highly negative (e.g. now is 23:00, target is 01:00 today), it must be tomorrow
        if diff < -720 {
            diff += 1440
        }
        
        // If bus is slightly late (in the past by less than an hour), just show "In 1 min"
        if diff < 0 && diff > -60 {
            return 1
        }
        
        if diff > 0 { return diff }
        
        return nil
    }

    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            ProgressView()
                .scaleEffect(1.2)
                .tint(theme.current.accent)
            Text("Updating Timeline...")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(theme.current.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "bus.doubledecker.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.current.secondaryText.opacity(0.2))
            Text("No stops found for this trip")
                .font(.headline)
                .foregroundStyle(theme.current.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}


