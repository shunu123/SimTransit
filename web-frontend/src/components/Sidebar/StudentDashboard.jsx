import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { MapPin, Star, Clock, Bus, Navigation2, ChevronRight, Activity, Zap, ArrowLeft, Search } from 'lucide-react';
import { getNearbyStops } from '../../services/api';

const StudentDashboard = ({ onSearch, onTrack, user }) => {
    const [step, setStep] = useState('hub'); // hub, nearby, favorites
    const [nearbyStops, setNearbyStops] = useState([]);
    const [loadingNearby, setLoadingNearby] = useState(false);
    const [favorites, setFavorites] = useState(() => {
        const saved = localStorage.getItem('bus_favorites');
        return saved ? JSON.parse(saved) : [];
    });

    useEffect(() => {
        if (navigator.geolocation) {
            setLoadingNearby(true);
            navigator.geolocation.getCurrentPosition(async (pos) => {
                try {
                    const res = await getNearbyStops(pos.coords.latitude, pos.coords.longitude);
                    if (res.ok) setNearbyStops(res.data);
                } catch (err) {
                    console.error("Nearby stops error:", err);
                } finally {
                    setLoadingNearby(false);
                }
            }, (err) => {
                console.error("Geolocation error:", err);
                setLoadingNearby(false);
            });
        }
    }, []);

    const containerVariants = {
        hidden: { opacity: 0, x: 20 },
        visible: { 
            opacity: 1, 
            x: 0, 
            transition: { 
                staggerChildren: 0.1,
                duration: 0.4,
                ease: [0.4, 0, 0.2, 1]
            } 
        },
        exit: { opacity: 0, x: -20, transition: { duration: 0.3 } }
    };

    const itemVariants = {
        hidden: { opacity: 0, y: 10 },
        visible: { opacity: 1, y: 0 }
    };

    const renderHub = () => (
        <motion.div 
            key="hub"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            exit="exit"
            className="flex flex-col gap-8"
        >
            {/* WELCOME SECTION */}
            <div className="px-2">
                <span className="text-[10px] font-black text-[var(--accent)] uppercase tracking-[0.4em] mb-2 block">Student Experience</span>
                <h1 className="text-4xl font-black text-white tracking-tighter leading-none mb-1">
                    Hi, {user?.first_name || 'Student'}!
                </h1>
                <p className="text-[12px] font-bold text-white/30 uppercase tracking-[0.2em] leading-relaxed">Choose your daily mission</p>
            </div>

            {/* QUICK ACTIONS GRID */}
            <div className="grid grid-cols-1 gap-4">
                {/* EXPLORE NEARBY */}
                <motion.button 
                    variants={itemVariants}
                    whileTap={{ scale: 0.98 }}
                    onClick={() => setStep('nearby')}
                    className="group relative p-6 bg-white/5 border border-white/5 rounded-[32px] overflow-hidden hover:bg-white/10 transition-all text-left"
                >
                    <div className="flex items-center justify-between mb-4">
                        <div className="w-12 h-12 rounded-2xl bg-[var(--accent)]/10 flex items-center justify-center text-[var(--accent)] group-hover:bg-[var(--accent)] group-hover:text-white transition-all">
                            <MapPin size={24} />
                        </div>
                        <ChevronRight size={20} className="text-white/20 group-hover:text-white transition-all" />
                    </div>
                    <h3 className="text-xl font-black text-white mb-1">Explore Nearby</h3>
                    <p className="text-[10px] font-bold text-white/40 uppercase tracking-widest">Discover stops around you</p>
                </motion.button>

                {/* FREQUENT TRIPS */}
                <motion.button 
                    variants={itemVariants}
                    whileTap={{ scale: 0.98 }}
                    onClick={() => setStep('favorites')}
                    className="group relative p-6 bg-yellow-500/5 border border-yellow-500/10 rounded-[32px] overflow-hidden hover:bg-yellow-500/10 transition-all text-left"
                >
                    <div className="flex items-center justify-between mb-4">
                        <div className="w-12 h-12 rounded-2xl bg-yellow-500/10 flex items-center justify-center text-yellow-500 group-hover:bg-yellow-500 group-hover:text-black transition-all">
                            <Star size={24} />
                        </div>
                        <ChevronRight size={20} className="text-white/20 group-hover:text-white transition-all" />
                    </div>
                    <h3 className="text-xl font-black text-white mb-1">Frequent Trips</h3>
                    <p className="text-[10px] font-bold text-white/40 uppercase tracking-widest">Jump into your daily routine</p>
                </motion.button>

                {/* MANUAL SEARCH */}
                <motion.button 
                    variants={itemVariants}
                    whileTap={{ scale: 0.98 }}
                    onClick={onOpenSearch}
                    className="group relative p-6 bg-white/5 border border-white/5 rounded-[32px] overflow-hidden hover:bg-[var(--accent)] transition-all text-left"
                >
                    <div className="flex items-center justify-between mb-4">
                        <div className="w-12 h-12 rounded-2xl bg-white/5 flex items-center justify-center text-white/40 group-hover:bg-white group-hover:text-black transition-all">
                            <Search size={24} />
                        </div>
                    </div>
                    <h3 className="text-xl font-black text-white group-hover:text-white mb-1">Route Planner</h3>
                    <p className="text-[10px] font-bold text-white/40 group-hover:text-white/60 uppercase tracking-widest">Plan your custom journey</p>
                </motion.button>
            </div>

            {/* LIVE TRIP STATUS (MINI-WIDGET) */}
            <motion.div 
                variants={itemVariants}
                className="p-6 bg-gradient-to-br from-[var(--accent)]/10 to-black border border-white/10 rounded-[32px] relative overflow-hidden"
            >
                <div className="flex items-center gap-3 mb-4">
                    <Activity size={14} className="text-[#4ade80]" />
                    <span className="text-[9px] font-black text-[#4ade80] uppercase tracking-[0.2em]">Next Bus Insight</span>
                </div>
                <h4 className="text-sm font-black text-white mb-1">Bus #{user?.reg_no?.slice(-3) || '101'}</h4>
                <p className="text-[10px] font-bold text-white/40 uppercase mb-4">Approaching {user?.bus_stop || 'Main Gate'}</p>
                <button 
                    onClick={() => onTrack({ bus_no: user?.reg_no?.slice(-3) || '101' })}
                    className="w-full py-3 bg-white/5 hover:bg-white text-white hover:text-black rounded-2xl text-[9px] font-black uppercase tracking-widest transition-all"
                >
                    Quick Track
                </button>
            </motion.div>
        </motion.div>
    );

    const renderNearby = () => (
        <motion.div 
            key="nearby"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            exit="exit"
            className="flex flex-col gap-6"
        >
            <div className="flex items-center gap-4 px-2 mb-2">
                <button onClick={() => setStep('hub')} className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/40 hover:text-white transition-all">
                    <ArrowLeft size={18} />
                </button>
                <div className="flex flex-col">
                    <h2 className="text-2xl font-black text-white tracking-tight leading-none">Nearby Stops</h2>
                    <span className="text-[10px] font-bold text-white/30 uppercase tracking-[0.2em]">Focusing on your area</span>
                </div>
            </div>

            <div className="space-y-3">
                {loadingNearby ? (
                    <div className="p-12 text-center">
                        <Activity size={24} className="text-[var(--accent)] animate-pulse mx-auto mb-4" />
                        <span className="text-[10px] font-black text-white/20 uppercase tracking-widest">Scanning Horizons...</span>
                    </div>
                ) : nearbyStops.length > 0 ? (
                    nearbyStops.map(stop => (
                        <motion.button
                            key={stop.id}
                            whileHover={{ x: 4 }}
                            onClick={() => onSearch(stop.name, user?.bus_stop || 'Main Campus')}
                            className="w-full flex items-center justify-between p-5 bg-white/5 border border-white/5 rounded-[28px] hover:bg-white/10 transition-all group"
                        >
                            <div className="flex items-center gap-4">
                                <div className="w-10 h-10 rounded-2xl bg-white/5 flex items-center justify-center text-[var(--accent)]">
                                    <MapPin size={18} />
                                </div>
                                <div className="text-left">
                                    <h5 className="text-sm font-black text-white/90">{stop.name}</h5>
                                    <span className="text-[9px] font-bold text-white/30 uppercase tracking-widest">{stop.distance_km?.toFixed(2)} km away</span>
                                </div>
                            </div>
                            <ChevronRight size={16} className="text-white/20" />
                        </motion.button>
                    ))
                ) : (
                    <div className="p-10 border border-dashed border-white/10 rounded-[32px] text-center text-white/20">
                        <p className="text-[10px] font-black uppercase tracking-widest leading-relaxed">No stops detected around your coordinate</p>
                    </div>
                )}
            </div>
        </motion.div>
    );

    const renderFavorites = () => (
        <motion.div 
            key="favorites"
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            exit="exit"
            className="flex flex-col gap-6"
        >
            <div className="flex items-center gap-4 px-2 mb-2">
                <button onClick={() => setStep('hub')} className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/40 hover:text-white transition-all">
                    <ArrowLeft size={18} />
                </button>
                <div className="flex flex-col">
                    <h2 className="text-2xl font-black text-white tracking-tight leading-none">Frequent Trips</h2>
                    <span className="text-[10px] font-bold text-white/30 uppercase tracking-[0.2em]">Your daily habits</span>
                </div>
            </div>

            <div className="space-y-3">
                {favorites.length > 0 ? (
                    favorites.map((fav, idx) => (
                        <motion.button
                            key={idx}
                            whileHover={{ x: 4 }}
                            onClick={() => onSearch(fav.from, fav.to)}
                            className="w-full flex items-center justify-between p-5 bg-[#0a0a0a] border border-white/5 rounded-[28px] hover:border-yellow-500/40 transition-all group"
                        >
                            <div className="flex items-center gap-4">
                                <div className="w-10 h-10 rounded-2xl bg-yellow-500/10 flex items-center justify-center text-yellow-500">
                                    <Star size={18} />
                                </div>
                                <div className="text-left">
                                    <h5 className="text-sm font-black text-white/90 truncate max-w-[150px]">{fav.from} → {fav.to}</h5>
                                    <span className="text-[9px] font-bold text-white/30 uppercase tracking-widest">Morning Routine</span>
                                </div>
                            </div>
                            <Activity size={12} className="text-[#4ade80] opacity-40" />
                        </motion.button>
                    ))
                ) : (
                    <div className="p-12 text-center text-white/10 bg-white/5 rounded-[32px] border border-white/5">
                        <Star size={32} className="mx-auto mb-4 opacity-20" />
                        <p className="text-[10px] font-black uppercase tracking-widest max-w-[180px] mx-auto">Build your routine by starring trips in the planner</p>
                    </div>
                )}
            </div>
        </motion.div>
    );

    return (
        <div className="flex-1 overflow-y-auto scrollbar-hide p-8 pt-4 pb-20">
            <AnimatePresence mode="wait">
                {step === 'hub' && renderHub()}
                {step === 'nearby' && renderNearby()}
                {step === 'favorites' && renderFavorites()}
            </AnimatePresence>
        </div>
    );
};
export default StudentDashboard;
