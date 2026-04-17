import React, { forwardRef, useEffect, useState, useRef } from 'react';
import { Map, MapMarker, MapRoute, MarkerContent } from '@/components/ui/map';
import { Bus, MapPin, Zap, Navigation2 } from 'lucide-react';

const MapContainer = forwardRef(({ 
    theme = 'dark', 
    activeRoute = [], 
    busLocation = null, 
    userLocation = null,
    selectedStops = [],
    nearbyStops = [],
    searchPin = null, // { lat, lng, name }
    navigationRoute = null, // { coordinates: [[lng, lat], ...] }
    fleetLocations = {}, // { busId: { lat, lng, heading } }
    walkingRoute = null,  // { coordinates: [[lng, lat], ...] }
    mapType = null, // NEW: terrain, city, satellite
    viewport = null, // Controlled viewport
    onViewportChange = null, // Callback for movement
    roadPath = [], // High-precision roadway polyline
    tripStats = null, 
    viewState = 'main',
    fleetData = [],
    onBusClick = null,
    selectedBusId = null
}, ref) => {
    const [mapObj, setMapObj] = useState(null);
    const [interpolatedBus, setInterpolatedBus] = useState(busLocation);
    const [isRouteHovered, setIsRouteHovered] = useState(false);

    // Filter for valid coordinates only
    const validRoute = activeRoute.filter(coord => 
        coord && typeof coord[0] === 'number' && !isNaN(coord[0]) &&
        typeof coord[1] === 'number' && !isNaN(coord[1])
    );

    const validStops = selectedStops.filter(s => 
        s && typeof s.lat === 'number' && !isNaN(s.lat) &&
        typeof s.lng === 'number' && !isNaN(s.lng)
    );

    const isValidBus = busLocation && 
        typeof busLocation.lat === 'number' && !isNaN(busLocation.lat) &&
        typeof busLocation.lng === 'number' && !isNaN(busLocation.lng);

    // Auto-fit bounds logic removed to prevent unintended zooming
    useEffect(() => {
        // fitBounds removed as per request to stop auto zooming
    }, [mapObj, validRoute, searchPin, userLocation, viewState]);

    // Minimalist Map Layout (No 3D extras)

    const defaultViewport = {
        center: [80.2372, 12.8231], // Default to Chennai/College
        zoom: 12,
        pitch: 0,
        bearing: 0
    };

    // Force map resize when it loads or viewState changes
    useEffect(() => {
        if (mapObj) {
            const timer = setTimeout(() => {
                mapObj.resize();
            }, 100);
            return () => clearTimeout(timer);
        }
    }, [mapObj, viewState]);

    return (
        <div className="gm-map-container w-full h-full relative" style={{ minHeight: '400px' }}>
            <Map
                ref={(instance) => {
                    if (instance) {
                        setMapObj(instance);
                        if (typeof ref === 'function') ref(instance);
                        else if (ref) ref.current = instance;
                    }
                }}
                viewport={viewport && viewport.center ? viewport : defaultViewport}
                onViewportChange={onViewportChange}
                theme={theme}
                mapType={mapType}
                className="w-full h-full"
            >
                {/* WALKING DIRECTIONS (Student) */}
                {walkingRoute?.coordinates && (
                    <MapRoute 
                        id="walking-path"
                        coordinates={walkingRoute.coordinates}
                        color="#4ade80"
                        width={4}
                        opacity={0.6}
                        dashArray={[2, 2]}
                    />
                )}

                {/* NAVIGATION ROUTE (User -> Search Pin) */}
                {navigationRoute?.coordinates && (
                    <MapRoute 
                        id="nav-path"
                        coordinates={navigationRoute.coordinates}
                        color="#3b82f6"
                        width={6}
                        opacity={0.8}
                    />
                )}

                {/* ACTIVE ROAD PATH (High Precision) */}
                {roadPath && roadPath.length > 1 ? (
                    <>
                        <MapRoute 
                            id="road-glow"
                            coordinates={roadPath}
                            color="#ef4444"
                            width={12}
                            opacity={0.15}
                        />
                        <MapRoute 
                            id="road-core"
                            coordinates={roadPath}
                            color="#ef4444"
                            width={5}
                            opacity={1}
                            onMouseEnter={() => setIsRouteHovered(true)}
                            onMouseLeave={() => setIsRouteHovered(false)}
                        />
                    </>
                ) : (
                    /* FALLBACK: STRAIGHT LINE BETWEEN STOPS */
                    validRoute.length > 1 && (
                        <>
                            <MapRoute 
                                id="route-glow"
                                coordinates={validRoute}
                                color="#ef4444"
                                width={12}
                                opacity={0.1}
                            />
                            <MapRoute 
                                coordinates={validRoute}
                                color="#ef4444"
                                width={5}
                                opacity={0.4} // Lower opacity for fallback
                                onMouseEnter={() => setIsRouteHovered(true)}
                                onMouseLeave={() => setIsRouteHovered(false)}
                            />
                        </>
                    )
                )}

                {/* NEARBY STOP MARKERS (Emerald) */}
                {nearbyStops.map((stop, idx) => (
                    <MapMarker 
                        key={`nearby-${stop.id || idx}`}
                        longitude={stop.lng}
                        latitude={stop.lat}
                    >
                        <MarkerContent>
                            <div className="group relative">
                                <div className="w-6 h-6 bg-white rounded-full border-[3px] border-emerald-500 shadow-2xl transform transition-all group-hover:scale-125 flex items-center justify-center">
                                    <div className="w-2 h-2 bg-emerald-500 rounded-full" />
                                </div>
                                <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 px-3 py-1.5 bg-black/90 backdrop-blur-md rounded-xl text-[10px] font-black text-white opacity-0 group-hover:opacity-100 transition-all scale-90 group-hover:scale-100 whitespace-nowrap border border-white/10 shadow-2xl">
                                    {stop.name}
                                </div>
                            </div>
                        </MarkerContent>
                    </MapMarker>
                ))}

                {/* SEARCH PIN MARKER */}
                {searchPin && (
                    <MapMarker 
                        longitude={searchPin.lng}
                        latitude={searchPin.lat}
                    >
                        <MarkerContent>
                            <div className="relative group">
                                <div className="absolute inset-0 bg-red-500 blur-xl opacity-40" />
                                <div className="w-10 h-10 bg-white rounded-2xl border-4 border-red-500 shadow-2xl flex items-center justify-center text-red-500 transform -rotate-12">
                                    <MapPin size={20} fill="currentColor" />
                                </div>
                            </div>
                        </MarkerContent>
                    </MapMarker>
                )}

                {/* STOP MARKERS (Active/Route) */}
                {validStops.map((stop, idx) => {
                    const isStart = idx === 0;
                    const isEnd = idx === validStops.length - 1;
                    
                    return (
                        <MapMarker 
                            key={`${stop.id || idx}`}
                            longitude={stop.lng}
                            latitude={stop.lat}
                        >
                            <MarkerContent>
                                <div className="group relative">
                                    {/* Outer Glow */}
                                    <div className={`absolute inset-0 blur-md opacity-20 group-hover:opacity-40 transition-opacity ${
                                        isStart ? 'bg-emerald-500' : isEnd ? 'bg-red-500' : 'bg-[#d4a843]'
                                    }`} />
                                    
                                    {/* Marker Body */}
                                    <div className={`w-6 h-6 rounded-full border-[3px] shadow-2xl transform transition-all group-hover:scale-125 z-10 flex items-center justify-center ${
                                        isStart ? 'bg-emerald-500 border-white text-white' : 
                                        isEnd ? 'bg-red-500 border-white text-white' : 
                                        'bg-white border-[#d4a843] text-[#d4a843]'
                                    }`}>
                                        {isStart ? <Zap size={10} fill="currentColor" /> : 
                                         isEnd ? <MapPin size={10} fill="currentColor" /> : 
                                         <div className="w-1.5 h-1.5 bg-[#d4a843] rounded-full" />}
                                    </div>
                                    
                                    {/* Label */}
                                    <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 px-3 py-2 bg-black/90 backdrop-blur-md rounded-xl border border-white/10 shadow-2xl opacity-0 group-hover:opacity-100 transition-all scale-90 group-hover:scale-100 whitespace-nowrap z-50">
                                        <div className="flex flex-col items-center gap-0.5">
                                            <span className={`text-[8px] font-black uppercase tracking-[0.2em] ${
                                                isStart ? 'text-emerald-400' : isEnd ? 'text-red-400' : 'text-[#d4a843]'
                                            }`}>
                                                {isStart ? 'Journey Start' : isEnd ? 'Destination' : 'Bus Stop'}
                                            </span>
                                            <span className="text-xs font-bold text-white leading-tight">{stop.name}</span>
                                        </div>
                                    </div>
                                </div>
                            </MarkerContent>
                        </MapMarker>
                    );
                })}

                {/* USER LOCATION PULSE */}
                {(viewState === 'main' || viewState === 'nearby') && userLocation && typeof userLocation.lng === 'number' && typeof userLocation.lat === 'number' && (userLocation.lng !== 0 || userLocation.lat !== 0) && (
                    <MapMarker 
                        longitude={userLocation.lng}
                        latitude={userLocation.lat}
                    >
                        <MarkerContent>
                            <div className="relative flex items-center justify-center">
                                {/* Dynamic Pulse Rings */}
                                <div className="absolute w-16 h-16 bg-blue-500/20 rounded-full" />
                                <div className="absolute w-10 h-10 bg-blue-500/30 rounded-full" />
                                {/* Core Marker */}
                                <div className="w-8 h-8 bg-white rounded-full flex items-center justify-center text-blue-500 shadow-[0_0_30px_rgba(59,130,246,0.6)] border-[3px] border-white z-10">
                                    <div className="w-3 h-3 bg-blue-500 rounded-full shadow-inner" />
                                </div>
                            </div>
                        </MarkerContent>
                    </MapMarker>
                )}

                {/* TRIP STATS MIDPOINT LABEL (Hover) */}
                {isRouteHovered && roadPath && roadPath.length > 0 && tripStats && (tripStats.distance > 0 || tripStats.duration > 0) && (
                    <MapMarker 
                        longitude={roadPath[Math.floor(roadPath.length / 2)][0]}
                        latitude={roadPath[Math.floor(roadPath.length / 2)][1]}
                    >
                        <MarkerContent>
                            <div className="bg-black/90 backdrop-blur-md rounded-2xl border border-white/10 shadow-[0_10px_40px_rgba(0,0,0,0.5)] px-4 py-2 transform -translate-y-4">
                                <div className="flex gap-4">
                                    <div className="flex flex-col items-center">
                                        <span className="text-[9px] font-black text-white/50 uppercase tracking-[0.2em] mb-0.5">Distance</span>
                                        <span className="text-white font-[1000] text-sm leading-none">{Number(tripStats.distance).toFixed(1)} km</span>
                                    </div>
                                    <div className="w-[1px] bg-white/10" />
                                    <div className="flex flex-col items-center">
                                        <span className="text-[9px] font-black text-white/50 uppercase tracking-[0.2em] mb-0.5">Duration</span>
                                        <span className="text-[#d4a843] font-[1000] text-sm leading-none">{tripStats.duration} min</span>
                                    </div>
                                </div>
                            </div>
                        </MarkerContent>
                    </MapMarker>
                )}

                {/* LIVE TRACKED BUS MARKER */}
                {viewState === 'tracking' && isValidBus && busLocation && (
                    <MapMarker 
                        longitude={busLocation.lng}
                        latitude={busLocation.lat}
                        rotation={busLocation.heading || 0}
                    >
                        <MarkerContent>
                            <div className="relative group">
                                <div className="absolute inset-0 bg-[#d4a843] blur-2xl opacity-40" />
                                <div className="w-14 h-14 bg-white rounded-[24px] flex items-center justify-center text-[#d4a843] shadow-[0_20px_60px_rgba(0,0,0,0.5)] border-[4px] border-[#d4a843] transform transition-transform group-hover:scale-110">
                                    <Bus size={30} className="drop-shadow-lg" />
                                </div>
                                <div className="absolute -top-10 left-1/2 -translate-x-1/2 px-3 py-1 bg-[#d4a843] text-black text-[10px] font-black uppercase tracking-widest rounded-lg shadow-xl whitespace-nowrap">
                                    LIVE BUS
                                </div>
                            </div>
                        </MarkerContent>
                    </MapMarker>
                )}

                {/* FLEET VIEW MARKERS (Multiple Buses) */}
                {viewState === 'fleet' && fleetData.map((bus, idx) => {
                    const lat = parseFloat(bus.lat);
                    const lon = parseFloat(bus.lon);
                    if (isNaN(lat) || isNaN(lon)) return null;
                    const isSelected = selectedBusId === (bus.vid || bus.ext_vehicle_id);

                    return (
                        <MapMarker 
                            key={`fleet-${bus.vid || idx}`}
                            longitude={lon}
                            latitude={lat}
                            rotation={parseFloat(bus.hdg || bus.heading || 0)}
                            onClick={() => onBusClick && onBusClick(bus)}
                        >
                            <MarkerContent>
                                <div className="relative group cursor-pointer">
                                    {isSelected && (
                                        <div className="absolute inset-0 bg-blue-500 blur-2xl opacity-60 animate-pulse" />
                                    )}
                                    <div className={`w-12 h-12 rounded-2xl flex items-center justify-center shadow-2xl border-[3px] transform transition-all group-hover:scale-110 ${
                                        isSelected ? 'bg-blue-600 border-white text-white' : 'bg-white border-[#d4a843] text-[#d4a843]'
                                    }`}>
                                        <Bus size={24} className="drop-shadow-md" />
                                    </div>
                                    {!isSelected && (
                                        <div className="absolute -top-10 left-1/2 -translate-x-1/2 px-2 py-0.5 bg-black/80 backdrop-blur-md text-white text-[9px] font-black uppercase tracking-widest rounded shadow-xl whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity">
                                            #{bus.vid || bus.ext_vehicle_id}
                                        </div>
                                    )}
                                </div>
                            </MarkerContent>
                        </MapMarker>
                    );
                })}
            </Map>
        </div>
    );
});

export default MapContainer;
