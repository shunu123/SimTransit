import SwiftUI
import MapKit

struct StudentDashboardView: View {
    @StateObject private var vm = StudentDashboardViewModel()
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Map Layer
            Map(position: $position) {
                UserAnnotation()
                
                // 5km Radius Circle
                if let userLoc = vm.currentUserLocation {
                    MapCircle(center: userLoc.coordinate, radius: 5000)
                        .foregroundStyle(theme.current.accent.opacity(0.1))
                        .stroke(theme.current.accent.opacity(0.3), lineWidth: 2)
                }

                // Walking Polyline to Nearest
                if let selected = vm.selectedStop, let route = vm.routes[selected.id] {
                    MapPolyline(route)
                        .stroke(theme.current.accent, lineWidth: 6)
                }
                
                // Nearby Bus Stops
                ForEach(vm.nearbyStops) { stop in
                    Annotation(coordinate: stop.coordinate, anchor: .bottom) {
                        VStack(spacing: 4) {
                            Image(systemName: "bus.fill")
                                .font(.system(size: 12))
                                .padding(8)
                                .background(stop.id == vm.selectedStop?.id ? theme.current.accent : theme.current.secondaryText)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                            
                            Text(stop.name)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.9))
                                .cornerRadius(4)
                        }
                        .onTapGesture {
                            withAnimation { vm.selectStop(stop) }
                        }
                    } label: {
                        Text(stop.name)
                    }
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .ignoresSafeArea()
            
            // MARK: - Navigation Header (Transparency)
            VStack {
                HStack {
                    Button { router.back() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .padding(12)
                            .background(Circle().fill(.white).shadow(radius: 5))
                            .foregroundStyle(.black)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)
                    Spacer()
                }
                Spacer()
            }
            
            // MARK: - Premium Action Card
            if let selected = vm.selectedStop {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selected.id == vm.nearbyStops.first?.id ? "NEAREST STATION" : "NEARBY STATION")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(theme.current.accent)
                            
                            Text(selected.name)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(theme.current.text)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.title2)
                                .foregroundStyle(theme.current.accent)
                            
                            if let km = vm.distances[selected.id] {
                                Text(String(format: "%.1f km", km))
                                    .font(.headline)
                                    .foregroundStyle(theme.current.secondaryText)
                            }
                        }
                    }
                    
                    if let time = vm.walkingTimes[selected.id] {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text("\(Int(time / 60)) minute walk from your location")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(theme.current.secondaryText.opacity(0.8))
                    }
                    
                    Button {
                        vm.openInMaps()
                    } label: {
                        HStack {
                            Image(systemName: "location.north.fill")
                            Text("Open in Maps for Directions")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.current.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .shadow(color: theme.current.accent.opacity(0.3), radius: 10, y: 5)
                    }
                }
                .padding(24)
                .background(
                    theme.current.card
                        .cornerRadius(32)
                        .shadow(color: .black.opacity(0.15), radius: 25, y: -10)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            vm.refreshDashboard()
        }
    }
}
