import SwiftUI
import MapKit

func calculateBearing(from: Coord, to: Coord) -> Double {
    let lat1 = from.lat * .pi / 180
    let lon1 = from.lon * .pi / 180
    let lat2 = to.lat * .pi / 180
    let lon2 = to.lon * .pi / 180
    
    let dLon = lon2 - lon1
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let y = sin(dLon) * cos(lat2)
    let radians = atan2(y, x)
    return (radians * 180 / .pi) 
}

struct LiveTrackingMapView: View {
    @EnvironmentObject var theme: ThemeManager
    @StateObject var vm: LiveTrackingViewModel

    init(bus: Bus, isHistorical: Bool = false, selectedDate: Date = Date(), sourceStop: String? = nil, destinationStop: String? = nil, sourceCoord: Coord? = nil, destinationCoord: Coord? = nil) {
        _vm = StateObject(wrappedValue: LiveTrackingViewModel(bus: bus, isHistorical: isHistorical, date: selectedDate, sourceStop: sourceStop, destinationStop: destinationStop, sourceCoord: sourceCoord, destinationCoord: destinationCoord))
    }


    @State private var position: MapCameraPosition = .automatic
    @State private var showAlarm = false

    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingCalendar = false
    @State private var showingBusDetails = false
    @State private var showingTimeline = false
    
    // Scoped properties for builders
    private var busToTrack: Bus {
        vm.selectedBusForDetail ?? vm.bus
    }
    
    private var isDeviatedMode: Bool {
        busToTrack.isDeviated
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.isHistorical && vm.isHistoryEmpty && !vm.showScheduledStopsOnly {
                emptyHistoryView
            } else {
                Map(position: $position, interactionModes: .all) {
                    mapContent
                }
                .onChange(of: position) {
                    if vm.autoRecenter && !vm.isHistorical {
                        vm.autoRecenter = false
                    }
                }
                .ignoresSafeArea()
                
                if vm.isHistorical {
                    VStack {
                        Spacer()
                        if let range = vm.historySearchRange {
                            Text("Searching history from \(range)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Capsule())
                                .padding(.bottom, vm.isHistoryEmpty ? 20 : 250) // Adjust if dashboard is up
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                }
            }
            
            if !isDeviatedMode {
                if !(vm.isHistorical && vm.isHistoryEmpty) {
                    topControls
                    zoomControls
                    mapOverlays
                } else {
                    topControls
                }
            } else {
                topControls
                deviationAlertOverlay
            }

            if vm.isWaitingForGPS && !vm.isHistorical {
                VStack {
                    Spacer().frame(height: 120)
                    HStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Waiting for GPS data from \(busToTrack.number)...")
                            .font(.subheadline.bold())
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.8)))
                    .foregroundStyle(.white)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .zIndex(10)
            }
            
            // Recenter/Fetch Button
            if !vm.autoRecenter && !vm.isHistorical && !vm.isWaitingForGPS {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring()) {
                                vm.autoRecenter = true
                                if let coord = vm.currentCoordinate.lat != 0 ? vm.currentCoordinate : nil {
                                    position = .region(MKCoordinateRegion(center: coord.cl, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                Text("Refetch")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(theme.current.accent))
                            .foregroundStyle(.white)
                            .shadow(radius: 5, y: 3)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 300) // Above the sheet
                    }
                }
                .zIndex(5)
            }
        }
        .sheet(isPresented: .constant(true)) {
            VStack(spacing: 0) {
                // Puller Handle
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                FloatingTrackingCard(vm: vm)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                
                // 1. Bus Info Header (Visible in Collapsed/Medium/Large)
                // Header is now integrated into the floating card
                
                Divider().padding(.vertical)
                
                // 2. Timeline (Scrollable)
                ScrollView(showsIndicators: false) {
                    RouteTimelineView(vm: vm)
                        .padding(.bottom, 30)
                }
            }
            .presentationDetents([.height(280), .medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingCalendar) {
            VStack {
                DatePicker("Select Date", selection: $vm.selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(theme.current.accent)
                    .padding()
                
                PrimaryButton(title: "View Historical Route") {
                    showingCalendar = false
                    vm.isHistorical = true
                    vm.start()
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            vm.start()
            if let liveCoord = vm.currentCoordinate.lat != 0 ? vm.currentCoordinate : nil {
                position = .region(MKCoordinateRegion(center: liveCoord.cl, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
            } else {
                position = .region(regionForStops(vm.stops))
            }
        }
        .onChange(of: vm.isHistorical) { (old: Bool, isHist: Bool) in
            if isHist {
                withAnimation {
                    position = .region(regionForStops(vm.stops))
                }
            }
        }
        .onChange(of: vm.currentCoordinate) { (old: Coord, newCoord: Coord) in
            guard vm.autoRecenter && !vm.isHistorical else { return }
            withAnimation(.easeInOut(duration: 3.0)) {
                position = .region(
                    MKCoordinateRegion(
                        center: newCoord.cl,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
        .onChange(of: vm.stops) { (old: [Stop], newStops: [Stop]) in
            guard !newStops.isEmpty else { return }
            if vm.currentCoordinate.lat != 0 {
                // Keep focus on bus if moving
                return 
            }
            withAnimation(.easeInOut(duration: 1.5)) {
                position = .region(regionForStops(newStops))
            }
        }
        .onChange(of: vm.bus) { (old: Bus, newBus: Bus) in
            // Refresh path calculation if bus model core changes
            // e.g. switching between different buses in search
            vm.recalculateTwoColorPaths()
        }
        .onChange(of: vm.selectedBusForDetail) { _, newBus in
            if let bus = newBus, !bus.route.stops.isEmpty {
                withAnimation(.easeInOut(duration: 1.5)) {
                    position = .region(regionForStops(bus.route.stops))
                }
            }
        }
        .sheet(isPresented: $showAlarm) {
            SetAlarmSheetView(vm: vm)
                .environmentObject(theme)
        }
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
        // Underlay: Full Planned Route (Gray Dashed) - Only show if high-fidelity path is missing
        if vm.fullRoutePath.isEmpty {
            MapPolyline(coordinates: vm.plannedPolyline.map { $0.cl })
                .stroke(Color.gray.opacity(0.6), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [6, 6]))
        }

        if busToTrack.isDeviated {
            deviatedMapContent(for: busToTrack)
        } else {
            standardMapContent(for: busToTrack)
        }
    }

    @MapContentBuilder
    private func deviatedMapContent(for busToTrack: Bus) -> some MapContent {
        // 1. Orange segments (On-route actual path)
        ForEach(vm.actualOnRouteSegments) { segment in
            MapPolyline(coordinates: segment.coords.map { $0.cl })
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }

        // 2. Red segments (Off-route deviation actual path)
        ForEach(vm.actualOffRouteSegments) { segment in
            MapPolyline(coordinates: segment.coords.map { $0.cl })
                .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        
        if vm.isHistorical {
            historyMarkers(for: busToTrack)
            rejoinMarkers()
        } else {
            Annotation("", coordinate: vm.currentCoordinate.cl) {
                BusMapMarker(bus: busToTrack, theme: theme, isMain: true, isSelected: true)
            }
        }
    }

    @MapContentBuilder
    private func rejoinMarkers() -> some MapContent {
        if let start = vm.deviationStartCoord {
            Annotation("Deviation", coordinate: start.cl) {
                VStack(spacing: 0) {
                    Text("Deviation Start")
                        .font(.system(size: 8, weight: .bold))
                        .padding(4)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(180))
                        .offset(y: -4)
                }
            }
        }
        
        if let rejoin = vm.rejoiningCoord {
            Annotation("Rejoin", coordinate: rejoin.cl) {
                VStack(spacing: 0) {
                    Text("Rejoined Route")
                        .font(.system(size: 8, weight: .bold))
                        .padding(4)
                        .background(theme.current.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.current.accent)
                        .rotationEffect(.degrees(180))
                        .offset(y: -4)
                }
            }
        }
    }

    @MapContentBuilder
    private func historyMarkers(for busToTrack: Bus) -> some MapContent {
        if let first = busToTrack.actualPolyline.first {
            Annotation("Start", coordinate: first.cl) {
                MarkerLabel(text: "Start (\(busToTrack.historyStops.first?.reachedTime ?? "--:--"))", color: .green)
            }
        }
        
        if let last = busToTrack.actualPolyline.last {
            Annotation("End", coordinate: last.cl) {
                MarkerLabel(text: "End (\(busToTrack.historyStops.last?.reachedTime ?? "--:--"))", color: .red)
            }
        }
    }

    @MapContentBuilder
    private func standardMapContent(for busToTrack: Bus) -> some MapContent {
        // 1. Searched Segment (Solid highlighted path ONLY)
        if !vm.tripPath.isEmpty {
            MapPolyline(coordinates: vm.tripPath.map { $0.cl })
                .stroke(theme.current.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }


        
        // 4. Deviation Log (Red)
        ForEach(vm.actualOffRouteSegments) { segment in
            MapPolyline(coordinates: segment.coords.map { $0.cl })
                .stroke(Color.red, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        }

        // 3. Stop Annotations
        ForEach(Array(vm.stops.enumerated()), id: \.element.id) { index, s in
            let normalize = { (txt: String) in txt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            let sName = normalize(s.name)
            let isSource = vm.sourceName.isEmpty ? (index == 0) : (sName.contains(normalize(vm.sourceName)) || normalize(vm.sourceName).contains(sName))
            let isEnd = index == vm.stops.count - 1
            
            let sourceIndex = vm.stops.firstIndex(where: { 
                let n = normalize($0.name)
                return vm.sourceName.isEmpty ? false : (n.contains(normalize(vm.sourceName)) || normalize(vm.sourceName).contains(n))
            }) ?? 0
            
            let isIntermediate = index > sourceIndex && index < vm.stops.count - 1
            
            let validCoord: CLLocationCoordinate2D = {
                if s.coordinate.lat != 0 && s.coordinate.lon != 0 { return s.coordinate.cl }
                guard !vm.fullRoutePath.isEmpty, vm.stops.count > 1 else { return s.coordinate.cl }
                let fraction = Double(index) / Double(vm.stops.count - 1)
                let polyIndex = min(vm.fullRoutePath.count - 1, Int(fraction * Double(vm.fullRoutePath.count - 1)))
                return vm.fullRoutePath[polyIndex].cl
            }()
            
            if isSource {
                Annotation(s.name, coordinate: validCoord) {
                    StopLocationMarker(icon: "📍", color: .green, isTerminal: true)
                }
            } else if isEnd {
                Annotation(s.name, coordinate: validCoord) {
                    StopLocationMarker(icon: "📍", color: .red, isTerminal: true)
                }
            } else if isIntermediate {
                Annotation(s.name, coordinate: validCoord) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(theme.current.accent, lineWidth: 2))
                        .shadow(radius: 1)
                }
            }
        }

        // 4. Live Bus Marker
        if !vm.isHistorical && (!vm.isIsolatedMode || vm.selectedBusForDetail?.id == vm.bus.id) && vm.currentCoordinate.lat != 0 {
            Annotation("", coordinate: vm.currentCoordinate.cl) {
                BusMapMarker(bus: vm.bus, theme: theme, isMain: true, isSelected: vm.selectedBusForDetail?.id == vm.bus.id)
                    .onTapGesture { 
                        withAnimation(.spring()) { 
                            vm.selectedBusForDetail = vm.bus 
                            vm.autoRecenter = false
                        }
                    }
            }
        }
        
        // 5. Other Visible Buses
        if !vm.isHistorical && !vm.isIsolatedMode {
            let visibleBuses = vm.otherBuses.filter { bus in
                switch bus.trackingStatus {
                case .arriving, .halted: return vm.showUpcoming
                case .departed: return vm.showDeparted
                case .scheduled: return vm.showScheduled
                default: return false
                }
            }
            ForEach(visibleBuses) { otherBus in
                if otherBus.currentStopIndex >= 0 && otherBus.currentStopIndex < otherBus.route.stops.count {
                    let stop = otherBus.route.stops[otherBus.currentStopIndex]
                    Annotation("", coordinate: stop.coordinate.cl) {
                        BusMapMarker(bus: otherBus, theme: theme, isMain: false, isSelected: vm.selectedBusForDetail?.id == otherBus.id)
                            .onTapGesture { 
                                withAnimation(.spring()) { 
                                    vm.selectedBusForDetail = otherBus 
                                    vm.autoRecenter = false
                                }
                            }
                    }
                }
            }
        }

    @ViewBuilder
    private var mapOverlays: some View {
        // Phase 2: Removed Planned/Actual legend as Deviated mode must be "just map + red line"
        EmptyView()
    }


    @ViewBuilder
    private var historicalDashboard: some View {
        let displayBus = vm.selectedBusForDetail ?? vm.bus
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(displayBus.number)
                    .font(.title3.bold())
                    .foregroundStyle(theme.current.accent)
                
                Spacer()
                
                let status = vm.historyTripStatus ?? "COMPLETED"
                let isDeviated = status.uppercased() == "DEVIATED"
                
                Text(status)
                    .font(.caption.bold())
                    .foregroundStyle(isDeviated ? .red : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isDeviated ? Color.red : Color.green).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            if displayBus.isDeviated {
                Text("Trip deviated on this date")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(.top, -8)
            }
            
            HStack {
                Text(vm.bus.route.startPointName)
                Image(systemName: "arrow.right")
                Text(vm.bus.route.endPointName)
            }
            .font(.subheadline.bold())
            .foregroundStyle(.gray)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let historyStops = displayBus.historyStops
                    ForEach(Array(historyStops.enumerated()), id: \.element.id) { idx, hStop in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Circle().fill(hStop.reachedTime != nil ? theme.current.accent : .gray.opacity(0.3)).frame(width: 6, height: 6)
                                Text(hStop.stopName).font(.subheadline.bold())
                                
                                let timeLabel: String = {
                                    if let time = hStop.reachedTime { return " — \(time)" }
                                    
                                    if vm.isHistorical {
                                        let status = (vm.historyTripStatus ?? "COMPLETED").uppercased()
                                        let isDone = status == "COMPLETED" || status == "REACHED" || status == "ENDED" || status == "ARRIVED" || status == "NORMAL" || status == "DEVIATED"
                                        
                                        if isDone {
                                            return " — Time unavailable"
                                        } else {
                                            if historyStops.suffix(from: idx).contains(where: { $0.reachedTime != nil }) {
                                                return " — Time unavailable"
                                            }
                                            return " — Not reached"
                                        }
                                    }
                                    return displayBus.hasReachedDestination ? " — Time unavailable" : " — Not reached"
                                }()
                                
                                Text(timeLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                
                                Spacer()
                                
                                if let _ = hStop.reachedTime, idx > 0 {
                                    Text("+10 min")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray.opacity(0.6))
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Check if deviation started after this stop (but before next)
                            if displayBus.isDeviated && idx < historyStops.count - 1 {
                                let stopName = hStop.stopName
                                if let realIdx = vm.bus.route.stops.firstIndex(where: { $0.name == stopName }),
                                   realIdx == vm.deviationStartStopIndex {
                                    deviationTimelineMark
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    @ViewBuilder
    private var liveDashboard: some View {
        let displayBus = vm.selectedBusForDetail ?? vm.bus
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayBus.number)
                        .font(.title3.bold())
                        .foregroundStyle(theme.current.accent)
                    
                    let statusText: String = {
                        if displayBus.hasReachedDestination { return "REACHED" }
                        if displayBus.isDeviated { return "DEVIATED" }
                        if vm.isApproachingSource && !vm.pickupPath.isEmpty { return "APPROACHING PICKUP" }
                        return (displayBus.liveTelemetry.speedKmph ?? 0) <= 1 ? "STOPPED" : "RUNNING"
                    }()
                    
                    Text(statusText)
                        .font(.caption.bold())
                        .foregroundStyle(
                            statusText == "DEVIATED" ? .red : 
                            (statusText == "REACHED" ? .blue : 
                            (statusText == "APPROACHING PICKUP" ? .orange : .green))
                        )
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    if displayBus.hasReachedDestination {
                        // Destination reached state
                        Text("TOTAL TRIP")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                        Text("\(displayBus.durationMinutes ?? 60)m")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(theme.current.accent)
                    } else if (displayBus.liveTelemetry.speedKmph ?? 0) <= 1 {
                        // Stopped state refinement: Replace speed section with prominently displayed Stop Name (if it's not too long)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("STOPPED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.red)
                            Text(vm.nearestStopName.isEmpty ? "Near location" : vm.nearestStopName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }
                    } else {
                        // Speed behavior
                        Text("SPEED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                        
                        if let speed = displayBus.liveTelemetry.speedKmph {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(speed)")
                                    .font(.system(size: 32, weight: .black))
                                Text("km/h")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(theme.current.accent)
                        } else {
                            Text("-- km/h")
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(.gray)
                            Text("Updating...")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            
            HStack {
                Text(vm.sourceName.isEmpty ? (vm.displayedStops.first?.name ?? "Source") : vm.sourceName)
                Image(systemName: "arrow.right")
                Text(vm.destName.isEmpty ? (vm.displayedStops.last?.name ?? "Destination") : vm.destName)
            }
            .font(.subheadline.bold())
            .foregroundStyle(.gray)
            
            Divider()
            
            if displayBus.hasReachedDestination {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bus reached destination")
                        .font(.headline.bold())
                    Text("Reached in \(displayBus.durationMinutes ?? 60) minutes")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if (displayBus.liveTelemetry.speedKmph ?? 0) <= 1 {
                            Text("Stopped at")
                                .font(.caption.bold())
                                .foregroundStyle(.gray)
                            Text(vm.nearestStopName.isEmpty ? "Stopped near current location" : vm.nearestStopName)
                                .font(.headline.bold())
                        } else {
                            Text("Next Stop")
                                .font(.caption.bold())
                                .foregroundStyle(.gray)
                            Text(vm.nextStopName.isEmpty ? (vm.nextStop?.name ?? "Arriving Soon") : vm.nextStopName)
                                .font(.headline.bold())
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Duration Taken")
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                        Text("\(vm.durationTakenMinutes) mins")
                            .font(.headline.bold())
                            .foregroundStyle(theme.current.accent)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ETA to Destination")
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                        Text("\(vm.durationToDestination) mins")
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Arrival at Next Stop")
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                        Text(vm.arrivalAtNextStop ?? "--:--")
                            .font(.subheadline.bold())
                    }
                }
            }
            
            HStack(spacing: 12) {
                if !displayBus.isDeviated {
                    Button { showAlarm = true } label: {
                        Text("Set Arrival Alarm")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 15).fill(Color.orange))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var topControls: some View {
        VStack {
            HStack(spacing: 16) {
                Button {
                    router.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.current.text)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(theme.current.card)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                }
                
                Text(vm.bus.number)
                    .font(.title3.weight(.black))
                    .foregroundStyle(theme.current.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(theme.current.card).shadow(radius: 4))
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Refresh Button
                    Button {
                        vm.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(theme.current.accent)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(theme.current.card))
                            .shadow(radius: 4)
                    }
                    
                    // Admin Calendar
                    if SessionManager.shared.userRole == "admin" {
                        Button {
                            showingCalendar.toggle()
                        } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(theme.current.accent)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(theme.current.card))
                                .shadow(radius: 4)
                        }
                    }
                }
            }
            .padding(.top, 60)
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }

    @ViewBuilder
    private var floatingMapTools: some View {
        VStack {
            Spacer()
            HStack {
                HStack(spacing: 20) {
                    Button { 
                        withAnimation { 
                            position = .region(MKCoordinateRegion(center: vm.currentCoordinate.cl, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Bus \(vm.bus.number)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                        }
                    }
                    
                    Button { 
                        // Mock location
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    
                    Button { 
                        // Mock layers
                    } label: {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .padding(.horizontal, 24)
                .frame(height: 54)
                .background(
                    Capsule()
                        .fill(theme.current.card)
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                )
                .foregroundStyle(theme.current.accent)
            }
            .padding(.bottom, 260)
        }
    }
    
    @ViewBuilder
    private var deviationAlertOverlay: some View {
        if vm.bus.isDeviated && !vm.isHistorical {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bus Deviated").font(.headline)
                        Text("bus deviated in \(vm.bus.route.stops[max(0, vm.bus.currentStopIndex - 1)].name) kindly wait for other bus").font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.red)
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding(.top, 60)
                .padding(.horizontal)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var deviationTimelineMark: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 2)
                .frame(height: 30)
                .padding(.leading, 2)
            
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text("Bus Deviated")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private func filterButton(title: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(isOn ? .white : color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isOn ? color : Color.clear)
                .cornerRadius(4)
        }
    }

    private func regionForStops(_ stops: [Stop]) -> MKCoordinateRegion {
        // Filter out any stops with 0,0 coordinates
        let validStops = stops.filter { $0.coordinate.lat != 0 && $0.coordinate.lon != 0 }
        
        // Start with stops bounds
        var minLat = 90.0, maxLat = -90.0
        var minLon = 180.0, maxLon = -180.0
        var foundAny = false

        for stop in validStops {
            minLat = min(minLat, stop.coordinate.lat)
            maxLat = max(maxLat, stop.coordinate.lat)
            minLon = min(minLon, stop.coordinate.lon)
            maxLon = max(maxLon, stop.coordinate.lon)
            foundAny = true
        }

        // Also include full high-res path if available
        if !vm.fullRoutePath.isEmpty {
            for coord in vm.fullRoutePath {
                minLat = min(minLat, coord.lat)
                maxLat = max(maxLat, coord.lat)
                minLon = min(minLon, coord.lon)
                maxLon = max(maxLon, coord.lon)
                foundAny = true
            }
        }
        
        if !foundAny {
            // Sensible fallback (Saveetha University area) if no valid data
            let fallbackCenter = (vm.sourceCoord?.lat != 0 && vm.sourceCoord?.lat != nil) ? vm.sourceCoord!.cl : 
                                 (vm.currentCoordinate.lat != 0 ? vm.currentCoordinate.cl : 
                                  CLLocationCoordinate2D(latitude: 13.0292, longitude: 80.0165))
            return MKCoordinateRegion(center: fallbackCenter,
                                      span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(maxLat - minLat + 0.05, 0.05), longitudeDelta: max(maxLon - minLon + 0.05, 0.05))
        
        return MKCoordinateRegion(center: center, span: span)
    }

    private var zoomControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Button(action: { adjustZoom(by: 0.5) }) {
                        Image(systemName: "plus")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(theme.current.card))
                            .foregroundStyle(theme.current.text)
                            .shadow(radius: 4)
                    }
                    Button(action: { adjustZoom(by: 2.0) }) {
                        Image(systemName: "minus")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(theme.current.card))
                            .foregroundStyle(theme.current.text)
                            .shadow(radius: 4)
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 80) // Positioned lower on screen
            }
        }
    }

    private func adjustZoom(by factor: Double) {
        if let region = position.region {
            let newSpan = MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * factor,
                longitudeDelta: region.span.longitudeDelta * factor
            )
            withAnimation {
                position = .region(MKCoordinateRegion(center: region.center, span: newSpan))
            }
        }
    }
}

struct BusMapMarker: View {
    let bus: Bus
    let theme: ThemeManager
    let isMain: Bool
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            VStack(alignment: .center, spacing: 2) {
                Text(bus.number)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                if let eta = bus.displayETA {
                    Text("\(eta)m").font(.system(size: 8, weight: .heavy))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(markerColor)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(isSelected ? 1.15 : 1.0)
            
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: isMain ? 32 : 24, height: isMain ? 32 : 24)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 3 : 0))
                
                Image(systemName: bus.isDeviated ? "exclamationmark.triangle.fill" : "bus.fill")
                    .font(.system(size: isMain ? 16 : 12))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isSelected ? 1.2 : 1.0)
        }
    }
    
    private var markerColor: Color {
        if bus.isDeviated { return .orange }
        if bus.liveTelemetry.isHalted { return .gray }
        return theme.current.accent
    }
}

struct MarkerLabel: View {
    let text: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: 8, weight: .black))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.8))
                .foregroundStyle(.white)
                .cornerRadius(4)
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(color)
                .font(.title3)
        }
    }
}

struct StopLocationMarker: View {
    let icon: String
    let color: Color
    let isTerminal: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if isTerminal {
                Text(icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                    .shadow(radius: 2, y: 1)
            } else {
                Text(icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
        }
    }
}

extension LiveTrackingMapView {
    private var emptyHistoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge")
                .font(.system(size: 64))
                .foregroundStyle(.gray.opacity(0.5))
            
            Text("Scheduled Every Day")
                .font(.title2.bold())
                .foregroundStyle(theme.current.accent)
                
            Text("Live tracking data / history is currently unavailable for this route on this date.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if SessionManager.shared.userRole == "admin" {
                Button {
                    print("Add Schedule Pressed")
                } label: {
                    Text("Add Schedule / Bus Data")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(theme.current.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 12)
            }
            
            VStack(spacing: 12) {
                if vm.isHistoryScheduled {
                    Button {
                        vm.showScheduledStopsOnly = true
                    } label: {
                        Text("View Scheduled Stops")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(theme.current.accent)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                }
                
                Button {
                    vm.selectedDate = Date()
                    vm.isHistorical = false
                } label: {
                    Text("Return to Live Tracking")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(vm.isHistoryScheduled ? Color.gray.opacity(0.1) : theme.current.accent)
                        .foregroundStyle(vm.isHistoryScheduled ? theme.current.accent : .white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vm.isHistoryScheduled ? theme.current.accent : Color.clear, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
struct FloatingTrackingCard: View {
    @ObservedObject var vm: LiveTrackingViewModel
    @EnvironmentObject var theme: ThemeManager
    @State private var pulseOpacity = 0.6
    
    var body: some View {
        let displayBus = vm.selectedBusForDetail ?? vm.bus
        let isRunning = (displayBus.liveTelemetry.speedKmph ?? 0) > 1
        
        VStack(spacing: 16) {
            // Header: ID + Live Status
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bus.fill")
                        .foregroundStyle(theme.current.accent)
                    Text(displayBus.number)
                        .font(.title3.bold())
                        .foregroundStyle(theme.current.accent)
                }
                
                Spacer()
                
                // Pulsing LIVE indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.isWaitingForGPS ? .gray : (isRunning ? .green : .orange))
                        .frame(width: 8, height: 8)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                pulseOpacity = 1.0
                            }
                        }
                    
                    Text(vm.isWaitingForGPS ? "CONNECTING..." : (isRunning ? "LIVE" : "HALTED"))
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(vm.isWaitingForGPS ? .gray : (isRunning ? .green : .orange))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isRunning ? Color.green : Color.orange).opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Route Segment
            HStack {
                Text(vm.sourceName.isEmpty ? "Source" : vm.sourceName)
                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.secondaryText)
                Text(vm.destName.isEmpty ? "Destination" : vm.destName)
            }
            .font(.subheadline.bold())
            .foregroundStyle(theme.current.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Middle: Next Stop + Highlighted ETA
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT STOP")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.current.secondaryText)
                    Text(vm.nextStop?.name ?? "End Component")
                        .font(.headline.bold())
                        .foregroundStyle(theme.current.text)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ARRIVAL")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.current.secondaryText)
                    
                    Text(vm.arrivalAtNextStop ?? "--:--")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(theme.current.accent)
                                .shadow(color: theme.current.accent.opacity(0.3), radius: 4, y: 2)
                        )
                }
            }
            

        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.current.card)
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
        )
    }
}
