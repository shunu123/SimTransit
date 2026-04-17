import { useRef, useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Navigation2, Loader2, Compass, Map as MapIcon, Globe, Mountain, X, Menu, Layers, LogOut, Home, Calendar, MapPin, ChevronRight, User, ArrowLeft, Search, Bus, Zap, Activity } from 'lucide-react';
import { Link, useNavigate } from 'react-router-dom';
import MapContainer from '../components/MapContainer';
import DashboardCards from '../components/DashboardCards';
import TripList from '../components/Navigation/TripList';
import LiveTimeline from '../components/Sidebar/LiveTimeline';
import { useAuth } from '../context/AuthContext';
import { searchTrips, getRouteStops, getLatestGPS, getNearbyStops, getStops, getSearchSuggestions, trackBusByNumber, getTripTimeline, getLiveFleet } from '../services/api';
import UserProfile from '../components/UserProfile';
import HackerLoader from '../components/HackerLoader';

const Dashboard = () => {
    const { user, logout } = useAuth();
    const navigate = useNavigate();
    
    // UI State
    const [viewState, setViewState] = useState('main'); // 'main', 'searching', 'tracking', 'nearby'
    const [theme, setTheme] = useState('dark');
    const [loading, setLoading] = useState(false);
    const [isLayerMenuOpen, setIsLayerMenuOpen] = useState(false);
    
    // Map State
    const [userLocation, setUserLocation] = useState(null);
    const [mapType, setMapType] = useState(() => localStorage.getItem('last_map_type') || 'city');
    const [viewport, setViewport] = useState(() => {
        const saved = localStorage.getItem('last_viewport');
        return saved ? JSON.parse(saved) : null;
    });

    // Data State
    const [allStops, setAllStops] = useState([]);
    const [searchResults, setSearchResults] = useState([]);
    const [nearbyStops, setNearbyStops] = useState([]);
    const [routeStops, setRouteStops] = useState([]);
    const [busLocation, setBusLocation] = useState(null);
    const [activeTrip, setActiveTrip] = useState(null);
    const [roadPath, setRoadPath] = useState([]);
    const [tripStats, setTripStats] = useState({ distance: 0, duration: 0 });
    
    // Form State
    const [sourceQuery, setSourceQuery] = useState('');
    const [destQuery, setDestQuery] = useState('');
    const [busNumber, setBusNumber] = useState('');
    const [activeSuggestionsField, setActiveSuggestionsField] = useState(null);
    const [suggestions, setSuggestions] = useState([]);
    const [fleetData, setFleetData] = useState([]);
    const [selectedFleetBus, setSelectedFleetBus] = useState(null);
    const [selectedBusDetails, setSelectedBusDetails] = useState(null);
    
    const mapRef = useRef(null);
    const hasCenteredRef = useRef(false);

    // Initialization
    useEffect(() => {
        const fetchInitialData = async () => {
            try {
                const stopsData = await getStops();
                setAllStops(stopsData.data || []);
            } catch (err) {
                console.error("Failed to fetch stops:", err);
            }
        };
        fetchInitialData();
    }, []);

    // Suggestions logic
    useEffect(() => {
        const query = activeSuggestionsField === 'source' ? sourceQuery : destQuery;
        if (!query || query.length < 2) {
            setSuggestions([]);
            return;
        }

        const timer = setTimeout(async () => {
            try {
                const data = await getSearchSuggestions(query);
                if (data.ok) {
                    setSuggestions(data.suggestions || []);
                }
            } catch (err) {
                console.error("Suggestions fetch failed:", err);
                setSuggestions([]);
            }
        }, 300);

        return () => clearTimeout(timer);
    }, [sourceQuery, destQuery, activeSuggestionsField]);

    // Geolocation
    useEffect(() => {
        if (!navigator.geolocation) return;
        const watchId = navigator.geolocation.watchPosition(
            (pos) => {
                const newLoc = { lat: pos.coords.latitude, lng: pos.coords.longitude };
                setUserLocation(newLoc);
                // ONLY center if in main view and we haven't centered yet
                if (!hasCenteredRef.current && mapRef.current && viewState === 'main') {
                    mapRef.current.flyTo({ center: [newLoc.lng, newLoc.lat], zoom: 14 });
                    hasCenteredRef.current = true;
                }
            },
            (err) => console.error("Geolocation error:", err),
            { enableHighAccuracy: true }
        );
        return () => navigator.geolocation.clearWatch(watchId);
    }, [viewState]); // depend on viewState instead of viewport to prevent re-triggering when viewport is nulled

    const handleLogout = async () => {
        await logout();
        navigate('/login');
    };

    const handleBusSearch = async () => {
        if (!sourceQuery || !destQuery) return;
        setLoading(true);
        try {
            // If the user typed something like "KO" but didn't pick "Koyambedu",
            // we should try to resolve it from suggestions first to get the proper name.
            let finalSource = sourceQuery;
            let finalDest = destQuery;

            if (suggestions.length > 0) {
                const bestMatch = suggestions[0].name || suggestions[0].stop_name || suggestions[0];
                if (activeSuggestionsField === 'source') finalSource = bestMatch;
                if (activeSuggestionsField === 'dest') finalDest = bestMatch;
            }

            const results = await searchTrips(finalSource, finalDest);
            setSearchResults(results.data || []);
            
            // If we have results, set the roadPath to the first trip's polyline and populate stats
            if (results.data && results.data.length > 0) {
                const firstTrip = results.data[0];
                
                // Set the stats for map overlay - STRICTLY use firstTrip data
                setTripStats({
                    distance: firstTrip.distance_km || 0,
                    duration: firstTrip.duration_minutes || 0
                });

                if (firstTrip.polyline_coords && Array.isArray(firstTrip.polyline_coords)) {
                    const path = firstTrip.polyline_coords.map(c => [c.lon, c.lat]);
                    setRoadPath(path);
                    
                    // Center the map on the route
                    if (mapRef.current && path.length > 0) {
                        const midPoint = path[Math.floor(path.length / 2)];
                        mapRef.current.flyTo({ center: midPoint, zoom: 12 });
                    }
                }
            } else {
                setTripStats({ distance: 0, duration: 0 });
                setRoadPath([]);
            }
            
            setViewState('searching');
        } catch (err) {
            console.error("Search failed:", err);
        } finally {
            setLoading(false);
        }
    };

    const handleNearbyStops = async () => {
        setLoading(true);
        try {
            // Use current position if available, else default
            const lat = userLocation?.lat || 12.8231;
            const lon = userLocation?.lng || 80.2372;
            const results = await getNearbyStops(lat, lon);
            setNearbyStops(results.data || []);
            setViewState('nearby');
            if (mapRef.current) {
                mapRef.current.flyTo({ center: [lon, lat], zoom: 14 });
            }
        } catch (err) {
            console.error("Failed to fetch nearby stops:", err);
        } finally {
            setLoading(false);
        }
    };
    
    const handleFleetView = async () => {
        setLoading(true);
        try {
            const data = await getLiveFleet();
            setFleetData(data.data || []);
            setViewState('fleet');
            if (mapRef.current && data.data?.[0]) {
                const first = data.data[0];
                mapRef.current.flyTo({ center: [parseFloat(first.lon), parseFloat(first.lat)], zoom: 12 });
            }
        } catch (err) {
            console.error("Failed to fetch fleet:", err);
        } finally {
            setLoading(false);
        }
    };

    const handleTrackByNumber = async () => {
        if (!busNumber) return;
        setLoading(true);
        try {
            const data = await trackBusByNumber(busNumber);
            if (data.ok && data.trip) {
                await handleTripSelect(data.trip);
            } else {
                alert(`No active trip found for bus #${busNumber}`);
            }
        } catch (err) {
            alert(err);
        } finally {
            setLoading(false);
        }
    };

    const handleTripSelect = async (trip) => {
        setLoading(true);
        setActiveTrip(trip);
        try {
            // 1. Initial Data Fetch
            const [routeData, timelineData] = await Promise.all([
                getRouteStops(trip.route_id, trip.direction || 'Inbound'),
                getTripTimeline(trip.trip_id, trip.from_stop_id, trip.to_stop_id)
            ]);

            // Filter timeline stops perfectly natively to the searched segment
            const validTimeline = timelineData.timeline ? timelineData.timeline.filter(t => t.is_in_segment) : [];
            setRouteStops(validTimeline.length > 0 ? validTimeline : (routeData.data || []));
            setBusLocation(null);
            
            // 2. Setup High-Precision Stats & Polyline
            if (timelineData.ok) {
                setTripStats({
                    distance: trip.distance_km || timelineData.segment_distance || 0,
                    duration: trip.duration_minutes || timelineData.segment_duration || 0
                });
                
                if (timelineData.live_location) {
                    setBusLocation({ 
                        lat: parseFloat(timelineData.live_location.lat), 
                        lng: parseFloat(timelineData.live_location.lng),
                        heading: parseFloat(timelineData.live_location.heading || 0)
                    });
                }
            }

            // Normalize road path from tracking or search results
            if (timelineData.polyline_coords && Array.isArray(timelineData.polyline_coords) && timelineData.polyline_coords.length > 0) {
                const path = timelineData.polyline_coords.map(c => [c.lon, c.lat]);
                setRoadPath(path);
            } else if (trip.polyline_coords && Array.isArray(trip.polyline_coords)) {
                const path = trip.polyline_coords.map(c => [c.lon, c.lat]);
                setRoadPath(path);
            } else {
                setRoadPath([]);
            }
            
            // 3. initial Map Focus
            const focusLoc = timelineData.live_location || (routeData.data?.[0]);
            if (focusLoc && mapRef.current) {
                mapRef.current.flyTo({ 
                    center: [parseFloat(focusLoc.lng || focusLoc.lon), parseFloat(focusLoc.lat)], 
                    zoom: 15 
                });
            }

            setViewState('tracking');
        } catch (err) {
            console.error("Trip selection failed:", err);
            alert("Failed to fetch tracking details.");
        } finally {
            setLoading(false);
        }
    };

    // Tracking Loop (Only active when viewState is tracking)
    useEffect(() => {
        if (viewState !== 'tracking' || !activeTrip) return;

        const updateTracking = async () => {
            try {
                const [gps, timeline] = await Promise.all([
                    getLatestGPS(activeTrip.trip_id),
                    getTripTimeline(activeTrip.trip_id, activeTrip.from_stop_id, activeTrip.to_stop_id)
                ]);

                if (gps && gps.lat) {
                    setBusLocation({ 
                        lat: parseFloat(gps.lat), 
                        lng: parseFloat(gps.lon),
                        heading: parseFloat(gps.hdg || gps.heading || 0)
                    });
                }

                if (timeline.ok) {
                    setTripStats({
                        distance: activeTrip?.distance_km || timeline.segment_distance || 0,
                        duration: activeTrip?.duration_minutes || timeline.segment_duration || 0
                    });
                    if (timeline.polyline_coords && Array.isArray(timeline.polyline_coords) && timeline.polyline_coords.length > 0) {
                        const path = timeline.polyline_coords.map(c => [c.lon, c.lat]);
                        setRoadPath(path);
                    }
                    // Refresh stops status if update occurred
                    if (timeline.timeline) {
                        const validSegment = timeline.timeline.filter(t => t.is_in_segment);
                        setRouteStops(validSegment.length > 0 ? validSegment : timeline.timeline);
                    }
                }
            } catch (err) {
                console.error("Tracking update failed:", err);
            }
        };

        const interval = setInterval(updateTracking, 10000); // 10s refresh
        return () => clearInterval(interval);
    }, [viewState, activeTrip]);

    // Fleet Polling Loop
    useEffect(() => {
        if (viewState !== 'fleet') return;
        
        const updateFleet = async () => {
            try {
                const data = await getLiveFleet();
                setFleetData(data.data || []);
            } catch (err) {
                console.error("Fleet update failed:", err);
            }
        };

        const interval = setInterval(updateFleet, 8000);
        return () => clearInterval(interval);
    }, [viewState]);

    const centerOnUser = useCallback(() => {
        if (userLocation && mapRef.current) {
            mapRef.current.flyTo({ center: [userLocation.lng, userLocation.lat], zoom: 16, pitch: 0, bearing: 0 });
        }
    }, [userLocation]);

    try {
        return (
        <div className="h-screen w-screen bg-[#050505] relative overflow-hidden font-sans selection:bg-[#3B5BDB] selection:text-white flex flex-col items-center box-border">
            {/* ATMOSPHERIC BACKGROUND ORBS */}
            <div className="absolute inset-0 pointer-events-none overflow-hidden">
                <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-[#3B5BDB]/10 blur-[120px] rounded-full" />
                <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-[#F76707]/10 blur-[120px] rounded-full" />
                <div className="absolute top-[40%] left-[30%] w-[30%] h-[30%] bg-[#12B886]/5 blur-[100px] rounded-full" />
            </div>

            {/* DYNAMIC NAVBAR (Transparent Glass) */}
            <div className="absolute top-0 left-0 right-0 z-[4000] px-12 py-8 flex items-center justify-between pointer-events-none">
                <div className="pointer-events-auto">
                    <button 
                        onClick={() => setViewState('main')}
                        className="flex items-center gap-3 active:scale-95 transition-transform group"
                    >
                        <div className="w-12 h-12 rounded-2xl bg-white/[0.03] border border-white/10 flex items-center justify-center text-white shadow-2xl group-hover:bg-white/10 transition-all">
                            <Home size={22} className="group-hover:scale-110 transition-transform" />
                        </div>
                        <div className="hidden md:block">
                            <h2 className="text-xl font-black text-white tracking-tighter">Sim<span className="text-[#f59e0b]">Transit</span></h2>
                            <p className="text-[8px] font-black text-white/30 uppercase tracking-[0.4em]">Operations Hub</p>
                        </div>
                    </button>
                </div>

                <div className="pointer-events-auto flex items-center gap-4">
                    <UserProfile />
                </div>
            </div>

            <main className={`h-full w-full flex relative ${viewState === 'main' ? 'flex-col items-center justify-center' : ''}`}>
                {/* LEFT PANEL / MAIN CONTENT */}
                <div className={`relative z-10 transition-all duration-700 ease-in-out flex flex-col ${viewState === 'main' ? 'max-w-full w-full px-12' : 'w-[450px] bg-[#050505] border-r border-white/5'}`}>
                    <div>
                        {viewState === 'main' && (
                            <div className="flex flex-col h-screen w-full relative">
                                {/* TOP HEADER SECTION */}
                                <div className="text-center pt-[22vh] pb-[2vh] relative z-10 w-full box-border">
                                    <h1 className="text-[72px] font-black text-white leading-none tracking-tighter">
                                        Sim<span className="text-[#f59e0b]">Transit</span>
                                    </h1>
                                    <p className="text-white/20 text-[13px] font-black uppercase tracking-[0.6em] mt-[16px]">
                                        Modern Urban Mobility
                                    </p>
                                </div>
                                
                                {/* CENTERED CARDS SECTION */}
                                <div className="flex-1 flex items-center justify-center pb-[10vh]">
                                    <DashboardCards 
                                        sourceQuery={sourceQuery}
                                        setSourceQuery={setSourceQuery}
                                        destQuery={destQuery}
                                        setDestQuery={setDestQuery}
                                        busNumber={busNumber}
                                        setBusNumber={setBusNumber}
                                        onFindBus={handleBusSearch}
                                        onNearbyStops={handleNearbyStops}
                                        onTrackBus={handleTrackByNumber}
                                        loading={loading}
                                        activeSuggestionsField={activeSuggestionsField}
                                        setActiveSuggestionsField={setActiveSuggestionsField}
                                        suggestions={suggestions}
                                        user={user}
                                        onFleetView={handleFleetView}
                                        onSuggestionClick={(field, s) => {
                                            const name = s.name || s.stop_name || s;
                                            if (field === 'source') setSourceQuery(name);
                                            else setDestQuery(name);
                                            setSuggestions([]);
                                            setActiveSuggestionsField(null);
                                        }}
                                    />
                                </div>
                            </div>
                        )}

                        {viewState === 'searching' && (
                            <div className="flex-1 flex flex-col h-full overflow-hidden pt-64" style={{ paddingTop: '256px' }}>
                                <TripList 
                                    trips={searchResults} 
                                    from={sourceQuery} 
                                    to={destQuery} 
                                    onTrack={handleTripSelect}
                                    onBack={() => setViewState('main')}
                                />
                            </div>
                        )}

                        {viewState === 'tracking' && activeTrip && (
                            <div className="flex-1 flex flex-col h-full bg-[#0a0a0a]">
                                <div className="p-10 pt-64 shrink-0 bg-[#050505]" style={{ paddingTop: '256px' }}>
                                    <button onClick={() => setViewState('searching')} className="flex items-center gap-2 text-[#d4a843] font-black uppercase tracking-widest text-xs mb-10">
                                        <ArrowLeft size={16} /> Back to Search
                                    </button>
                                    <div className="flex items-center justify-between mb-2">
                                        <h2 className="text-4xl font-black text-white tracking-tighter">Live Tracking</h2>
                                        <div className="bg-[#d4a843] text-black px-4 py-2 rounded-xl text-xs font-black uppercase tracking-tighter flex items-center gap-2">
                                            <Zap size={14} fill="currentColor" /> Bus #{activeTrip.bus_no || activeTrip.bus_number}
                                        </div>
                                    </div>
                                    <p className="text-white/20 text-[10px] font-bold uppercase tracking-[0.3em] mb-8">Trip Identifier: {activeTrip.trip_id}</p>
                                    
                                    <div className="grid grid-cols-2 gap-4">
                                        <div className="bg-white/5 p-5 rounded-2xl border border-white/5">
                                            <div className="text-[9px] font-black text-white/30 uppercase tracking-widest mb-1">Estimated Arrival</div>
                                            <div className="text-2xl font-black text-white tracking-tight">
                                                {activeTrip.live_to_arrival || activeTrip.to_arrival ? 
                                                    new Date(activeTrip.live_to_arrival || activeTrip.to_arrival).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 
                                                    '--:--'
                                                }
                                            </div>
                                        </div>
                                        <div className="bg-white/5 p-5 rounded-2xl border border-white/5">
                                            <div className="text-[9px] font-black text-white/30 uppercase tracking-widest mb-1">Time to destination</div>
                                            <div className="text-2xl font-black text-blue-400 tracking-tight">{tripStats.duration || activeTrip.duration_minutes || '25'} MIN</div>
                                        </div>
                                    </div>
                                </div>
                                <div className="flex-1 overflow-y-auto px-10 py-10 no-scrollbar">
                                    <LiveTimeline 
                                        routeStops={routeStops} 
                                        selectedBus={activeTrip} 
                                        busLocation={busLocation}
                                        tripStats={tripStats}
                                    />
                                </div>
                            </div>
                        )}

                        {viewState === 'fleet' && (
                            <div className="flex-1 flex flex-col h-full">
                                <div className="p-10 pt-64 shrink-0" style={{ paddingTop: '256px' }}>
                                    <button onClick={() => setViewState('main')} className="flex items-center gap-2 text-[#d4a843] font-black uppercase tracking-widest text-xs mb-10">
                                        <ArrowLeft size={16} /> Exit Fleet View
                                    </button>
                                    <div className="flex items-center justify-between mb-2">
                                        <h2 className="text-4xl font-black text-white tracking-tighter">Fleet Overview</h2>
                                        <div className="bg-emerald-500/20 text-emerald-400 px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-widest flex items-center gap-2">
                                            <div className="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse" />
                                            {fleetData.length} Active
                                        </div>
                                    </div>
                                    <p className="text-white/40 font-bold uppercase tracking-[0.2em] text-[10px]">Real-time vehicle diagnostics</p>
                                </div>
                                <div className="flex-1 overflow-y-auto px-10 pb-10 space-y-3 no-scrollbar">
                                    {fleetData.length > 0 ? fleetData.map((bus, idx) => (
                                        <div 
                                            key={bus.vid || idx}
                                            className={`bg-white/5 border rounded-2xl p-5 flex items-center justify-between group cursor-pointer transition-all ${
                                                (selectedFleetBus?.vid === bus.vid) ? 'border-[#d4a843] bg-[#d4a843]/10' : 'border-white/10 hover:border-white/20'
                                            }`}
                                            onClick={async () => {
                                                setSelectedFleetBus(bus);
                                                try {
                                                    const details = await getTripTimeline(bus.vid || bus.tatripid);
                                                    setSelectedBusDetails(details);
                                                    mapRef.current?.flyTo({ center: [parseFloat(bus.lon), parseFloat(bus.lat)], zoom: 15 });
                                                } catch (err) {
                                                    console.error("Fleet bus selection failed:", err);
                                                }
                                            }}
                                        >
                                            <div className="flex items-center gap-4">
                                                <div className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${
                                                    (selectedFleetBus?.vid === bus.vid) ? 'bg-[#d4a843] text-black' : 'bg-white/5 text-white/40'
                                                }`}>
                                                    <Bus size={20} />
                                                </div>
                                                <div>
                                                    <div className="text-sm font-black text-white leading-tight mb-0.5">Bus #{bus.vid || bus.bus_no}</div>
                                                    <div className="text-[10px] font-bold text-white/30 uppercase tracking-widest">{bus.rt || 'Route Admin'} • {bus.dir || 'Inbound'}</div>
                                                </div>
                                            </div>
                                            <ChevronRight className={`transition-colors ${(selectedFleetBus?.vid === bus.vid) ? 'text-[#d4a843]' : 'text-white/10 group-hover:text-white'}`} size={16} />
                                        </div>
                                    )) : (
                                        <div className="text-center py-20 opacity-20 flex flex-col items-center gap-4">
                                            <Activity size={48} strokeWidth={1} />
                                            <span className="text-xs font-black uppercase tracking-widest">No active vehicles found</span>
                                        </div>
                                    )}
                                </div>
                            </div>
                        )}

                        {viewState === 'nearby' && (
                            <div className="flex-1 flex flex-col h-full">
                                <div className="p-10 pt-64 shrink-0" style={{ paddingTop: '256px' }}>
                                    <button onClick={() => setViewState('main')} className="flex items-center gap-2 text-[#d4a843] font-black uppercase tracking-widest text-xs mb-10">
                                        <ArrowLeft size={16} /> Back to Dashboard
                                    </button>
                                    <h2 className="text-4xl font-black text-white tracking-tighter mb-2">Nearby Stops</h2>
                                    <p className="text-white/40 font-bold uppercase tracking-[0.2em] text-[10px]">Within 5km of your location</p>
                                </div>
                                <div className="flex-1 overflow-y-auto px-10 pb-10 space-y-4 no-scrollbar">
                                    {nearbyStops.length > 0 ? nearbyStops.map((stop, idx) => (
                                        <div 
                                            key={idx}
                                            className="bg-white/5 border border-white/10 rounded-2xl p-6 flex items-center justify-between group cursor-pointer hover:border-emerald-500/50 transition-all hover:bg-white/[0.08]"
                                            onClick={() => mapRef.current?.flyTo({ center: [stop.lng, stop.lat], zoom: 16 })}
                                        >
                                            <div className="flex items-center gap-5">
                                                <div className="w-12 h-12 rounded-xl bg-emerald-600/20 flex items-center justify-center text-emerald-400 group-hover:bg-emerald-600 group-hover:text-white transition-all">
                                                    <MapPin size={22} />
                                                </div>
                                                <div>
                                                    <div className="text-lg font-black text-white leading-tight mb-0.5">{stop.name}</div>
                                                    <div className="text-[10px] font-bold text-white/30 uppercase tracking-widest">{stop.distance || (0.5 + idx * 0.3).toFixed(1)} km away</div>
                                                </div>
                                            </div>
                                            <ChevronRight className="text-white/10 group-hover:text-white transition-colors" />
                                        </div>
                                    )) : (
                                        <div className="text-center py-20 opacity-20 flex flex-col items-center gap-4">
                                            <MapPin size={48} strokeWidth={1} />
                                            <span className="text-xs font-black uppercase tracking-widest">No nearby stops found</span>
                                        </div>
                                    )}
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* RIGHT PANEL / MAP */}
                <div className={`flex-1 relative ${viewState === 'main' ? 'hidden' : ''}`}>
                    {/* FETCHING GPS OVERLAY */}
                    {viewState === 'tracking' && !busLocation && (
                        <div className="absolute top-10 left-1/2 -translate-x-1/2 z-50 bg-black/80 backdrop-blur-md px-6 py-3 rounded-full border border-white/10 shadow-2xl flex items-center gap-3">
                            <div className="w-2 h-2 bg-[#d4a843] rounded-full" />
                            <span className="text-xs font-black text-white uppercase tracking-widest">Fetching Live GPS...</span>
                        </div>
                    )}
                {viewState !== 'main' && (
                    <div className="flex-1 relative">
                        <MapContainer 
                            ref={mapRef}
                            theme={theme}
                            userLocation={userLocation}
                            nearbyStops={nearbyStops}
                            activeRoute={routeStops.filter(s => s.lng !== undefined && s.lat !== undefined).map(s => [s.lng, s.lat])}
                            roadPath={roadPath}
                            busLocation={busLocation}
                            selectedStops={routeStops}
                            mapType={mapType}
                            viewport={viewState === 'tracking' ? null : viewport}
                            tripStats={tripStats}
                            viewState={viewState}
                            fleetData={fleetData}
                            selectedBusId={selectedFleetBus?.vid || selectedFleetBus?.ext_vehicle_id}
                            onBusClick={async (bus) => {
                                setSelectedFleetBus(bus);
                                try {
                                    const details = await getTripTimeline(bus.vid || bus.tatripid);
                                    setSelectedBusDetails(details);
                                } catch (err) {
                                    console.error("Fleet bus details fetch failed:", err);
                                }
                            }}
                            onViewportChange={(v) => {
                                setViewport(v);
                                localStorage.setItem('last_viewport', JSON.stringify(v));
                            }}
                        />

                        {/* MAP CONTROLS */}
                        <div className="absolute top-10 right-10 flex flex-col gap-4 z-[2000]">
                            <button 
                                onClick={centerOnUser}
                                className="w-14 h-14 bg-white/10 backdrop-blur-3xl rounded-2xl flex items-center justify-center text-white border border-white/20 shadow-2xl hover:bg-white/20 transition-all font-black"
                            >
                                <Navigation2 size={24} />
                            </button>
                            <button 
                                onClick={() => setIsLayerMenuOpen(!isLayerMenuOpen)}
                                className={`w-14 h-14 rounded-2xl flex items-center justify-center border border-white/20 transition-all shadow-2xl backdrop-blur-3xl ${isLayerMenuOpen ? 'bg-[#d4a843] text-black' : 'bg-white/10 text-white font-black'}`}
                            >
                                <Layers size={24} />
                            </button>
                        </div>
                    </div>
                )}

                        {isLayerMenuOpen && (
                            <div className="absolute top-10 right-[100px] bg-[#1a1a1a]/95 backdrop-blur-3xl p-3 rounded-[24px] border border-white/20 shadow-2xl flex gap-3 z-[2000]">
                                {[
                                    { id: 'city', icon: MapIcon, color: 'text-blue-400' },
                                    { id: 'satellite', icon: Globe, color: 'text-emerald-400' },
                                    { id: 'terrain', icon: Mountain, color: 'text-amber-400' }
                                ].map(t => (
                                    <button 
                                        key={t.id} 
                                        onClick={() => { setMapType(t.id); setIsLayerMenuOpen(false); }}
                                        className={`w-16 h-16 rounded-2xl flex items-center justify-center transition-all ${mapType === t.id ? 'bg-white/10 ring-2 ring-white/50' : 'hover:bg-white/5'}`}
                                    >
                                        <t.icon size={24} className={t.color} />
                                    </button>
                                ))}
                            </div>
                        )}
                </div>
            </main>

            {/* LOADER */}
            <HackerLoader isVisible={loading} />

            {/* FLEET BUS DETAILS OVERLAY (ADMIN) */}
            {viewState === 'fleet' && selectedFleetBus && (
                <div className="absolute top-10 left-1/2 -translate-x-1/2 z-[3000] w-[400px] bg-black/80 backdrop-blur-2xl border-2 border-white/10 rounded-[32px] p-8 shadow-[0_40px_80px_-20px_rgba(0,0,0,0.8)] flex flex-col gap-6 animate-in slide-in-from-top-10 duration-500">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-4">
                            <div className="w-12 h-12 rounded-2xl bg-[#d4a843] flex items-center justify-center text-black">
                                <Bus size={24} />
                            </div>
                            <div>
                                <h4 className="text-xl font-black text-white tracking-tighter">Bus #{selectedFleetBus.vid || selectedFleetBus.bus_no}</h4>
                                <p className="text-[#d4a843] text-[9px] font-black uppercase tracking-[0.2em]">{selectedFleetBus.rt || 'Route Admin'}</p>
                            </div>
                        </div>
                        <button onClick={() => setSelectedFleetBus(null)} className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/40 hover:bg-white/10 hover:text-white transition-all">
                            <X size={18} />
                        </button>
                    </div>

                    <div className="h-[1px] bg-white/5 w-full" />

                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <div className="text-[10px] font-black text-white/30 uppercase tracking-widest">Route Segment</div>
                            <div className="text-xs font-bold text-white uppercase tracking-tighter">
                                {selectedBusDetails?.from_stop_name || 'Terminal A'} → {selectedBusDetails?.to_stop_name || 'Terminal B'}
                            </div>
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <div className="bg-white/[0.03] p-4 rounded-2xl border border-white/5">
                                <span className="text-[8px] font-black text-white/20 uppercase tracking-widest block mb-1">Next Stop</span>
                                <span className="text-sm font-black text-emerald-400 tracking-tight block">
                                    {selectedBusDetails?.next_stop_name || 'Pulsing...'}
                                </span>
                            </div>
                            <div className="bg-white/[0.03] p-4 rounded-2xl border border-white/5">
                                <span className="text-[8px] font-black text-white/20 uppercase tracking-widest block mb-1">ETA</span>
                                <span className="text-sm font-black text-white tracking-tight block">
                                    {selectedBusDetails?.next_stop_eta || '5 MIN'}
                                </span>
                            </div>
                        </div>

                        <div className="flex items-center justify-between bg-[#3B5BDB]/10 p-5 rounded-2xl border border-[#3B5BDB]/20">
                            <div>
                                <span className="text-[8px] font-black text-[#3B5BDB] uppercase tracking-widest block mb-0.5">Final Destination</span>
                                <span className="text-sm font-black text-white tracking-tight">{selectedBusDetails?.destination_name || 'Main Hub'}</span>
                            </div>
                            <div className="text-right">
                                <span className="text-[8px] font-black text-[#3B5BDB] uppercase tracking-widest block mb-0.5">Remaining</span>
                                <span className="text-sm font-black text-white tracking-tight">{selectedBusDetails?.segment_duration || '12'} MIN</span>
                            </div>
                        </div>
                    </div>
                </div>
            )}
            </div>
        );
    } catch (error) {
        console.error('[Dashboard] Render Crash:', error);
        return (
            <div className="h-screen w-screen bg-[#050505] flex flex-col items-center justify-center p-20 text-center">
                <div className="text-red-500 mb-8 border border-red-500/50 p-6 rounded-3xl bg-red-500/10">
                    <Activity size={48} />
                </div>
                <h1 className="text-4xl font-black text-white tracking-tighter mb-4">Dashboard System Crash</h1>
                <p className="text-white/40 font-bold uppercase tracking-[0.2em] text-[10px] mb-12 max-w-sm">
                    A critical rendering exception was encountered. 
                </p>
                <div className="bg-white/5 border border-white/10 rounded-2xl p-6 text-left w-full max-w-3xl overflow-auto max-h-[400px]">
                    <p className="text-red-400 font-mono text-xs mb-4">Error: {error.message}</p>
                    <pre className="text-white/20 font-mono text-[9px] leading-relaxed">
                        {error.stack}
                    </pre>
                </div>
            </div>
        );
    }
};

export default Dashboard;
