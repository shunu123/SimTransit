import React, { useState, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, MapPin, Navigation2, Bus, ChevronRight, History } from 'lucide-react';
import { getSearchSuggestions } from '../../services/api';

const HomeHero = ({ onSearch, onTrackByNumber, onFindNearby }) => {
    const [fromStop, setFromStop] = useState('');
    const [toStop, setToStop] = useState('');
    const [suggestions, setSuggestions] = useState([]);
    const [activeField, setActiveField] = useState(null); // 'from' or 'to'
    const [loading, setLoading] = useState(false);

    const fetchSuggestions = useCallback(async (query) => {
        if (!query || query.length < 2) {
            setSuggestions([]);
            return;
        }
        setLoading(true);
        try {
            const res = await getSearchSuggestions(query);
            if (res.ok) setSuggestions(res.data || []);
        } catch (err) {
            console.error("Suggestions error:", err);
            setSuggestions([]);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        const timeout = setTimeout(() => {
            if (activeField === 'from') fetchSuggestions(fromStop);
            if (activeField === 'to') fetchSuggestions(toStop);
        }, 300);
        return () => clearTimeout(timeout);
    }, [fromStop, toStop, activeField, fetchSuggestions]);

    const handleSelect = (stopName) => {
        if (activeField === 'from') setFromStop(stopName);
        else setToStop(stopName);
        setSuggestions([]);
        setActiveField(null);
    };

    const containerVariants = {
        hidden: { opacity: 0, y: 10 },
        visible: { 
            opacity: 1, 
            y: 0, 
            transition: { staggerChildren: 0.1, duration: 0.4 } 
        }
    };

    const itemVariants = {
        hidden: { opacity: 0, y: 10 },
        visible: { opacity: 1, y: 0 }
    };

    return (
        <motion.div 
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            className="flex flex-col gap-8 p-0 pt-4"
        >
            {/* SEARCH TOOL */}
            <div className="relative flex flex-col gap-4">
                {/* FROM */}
                <div className="relative group/input">
                    <div className={`absolute inset-0 bg-white/[0.03] rounded-[var(--radius-lg)] border transition-all duration-500 ${activeField === 'from' ? 'border-[var(--accent)] bg-white/[0.06] shadow-[0_0_30px_rgba(99,102,241,0.05)]' : 'border-white/[0.05] group-hover/input:border-white/10'}`} />
                    <div className="relative px-6 py-5 flex items-center gap-5">
                        <MapPin size={18} className={activeField === 'from' ? 'text-[var(--accent)]' : 'text-white/20'} />
                        <div className="flex flex-col flex-1">
                            <span className="text-[9px] font-black text-white/20 uppercase tracking-[0.2em] leading-none mb-2">Origin Point</span>
                            <input 
                                value={fromStop}
                                onFocus={() => setActiveField('from')}
                                onChange={(e) => setFromStop(e.target.value)}
                                placeholder="Where are you..."
                                className="bg-transparent border-none outline-none text-white font-bold text-base placeholder:text-white/5 w-full"
                            />
                        </div>
                    </div>
                </div>

                {/* TO */}
                <div className="relative group/input">
                    <div className={`absolute inset-0 bg-white/[0.03] rounded-[var(--radius-lg)] border transition-all duration-500 ${activeField === 'to' ? 'border-[var(--accent)] bg-white/[0.06] shadow-[0_0_30px_rgba(99,102,241,0.05)]' : 'border-white/[0.05] group-hover/input:border-white/10'}`} />
                    <div className="relative px-6 py-5 flex items-center gap-5">
                        <Search size={18} className={activeField === 'to' ? 'text-[var(--accent)]' : 'text-white/20'} />
                        <div className="flex flex-col flex-1">
                            <span className="text-[9px] font-black text-white/20 uppercase tracking-[0.2em] leading-none mb-2">Your Destination</span>
                            <input 
                                value={toStop}
                                onFocus={() => setActiveField('to')}
                                onChange={(e) => setToStop(e.target.value)}
                                placeholder="Heading to..."
                                className="bg-transparent border-none outline-none text-white font-bold text-base placeholder:text-white/5 w-full"
                            />
                        </div>
                    </div>
                </div>

                {/* SUGGESTIONS TOOLTIP */}
                <AnimatePresence>
                    {suggestions.length > 0 && activeField && (
                        <motion.div 
                            initial={{ opacity: 0, y: 10, scale: 0.98 }}
                            animate={{ opacity: 1, y: 0, scale: 1 }}
                            exit={{ opacity: 0, y: 10, scale: 0.98 }}
                            className="absolute top-[calc(100%+8px)] left-0 right-0 z-[100] bg-[#0a0a0a]/95 backdrop-blur-3xl border border-white/10 rounded-[var(--radius-lg)] overflow-hidden shadow-[0_30px_60px_rgba(0,0,0,0.6)] p-2"
                        >
                            {suggestions.map((s, i) => (
                                <button 
                                    key={i}
                                    onClick={() => handleSelect(s.name)}
                                    className="w-full flex items-center gap-4 px-4 py-3.5 hover:bg-white/[0.04] rounded-xl text-left transition-all group"
                                >
                                    <div className="w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center text-white/20 group-hover:bg-[var(--accent)] group-hover:text-white transition-colors">
                                        <MapPin size={16} />
                                    </div>
                                    <div className="flex flex-col flex-1 truncate">
                                        <span className="text-sm font-bold text-white/70 group-hover:text-white truncate">{s.name}</span>
                                        <span className="text-[9px] font-black text-white/10 uppercase tracking-widest mt-0.5 group-hover:text-white/30 transition-colors">Public Transit Stop</span>
                                    </div>
                                </button>
                            ))}
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* SEARCH BUTTON */}
                <motion.button 
                    whileTap={{ scale: 0.98 }}
                    onClick={() => onSearch(fromStop, toStop)}
                    disabled={!fromStop || !toStop}
                    className="w-full h-16 bg-white text-black rounded-[var(--radius-lg)] font-black text-[11px] uppercase tracking-[0.4em] flex items-center justify-center gap-3 hover:bg-[var(--accent)] hover:text-white transition-all shadow-[0_20px_40px_rgba(0,0,0,0.3)] disabled:opacity-5 disabled:grayscale mt-2 group"
                >
                    Initiate Live Tracking <ChevronRight size={18} className="group-hover:translate-x-1 transition-transform" />
                </motion.button>
            </div>

            {/* QUICK ACTIONS */}
            <div className="flex flex-col gap-6">
                <div className="flex items-center gap-3 px-1">
                    <span className="text-[9px] font-black text-white/15 uppercase tracking-[0.4em]">Operations Hub</span>
                    <div className="h-px flex-1 bg-white/[0.03]" />
                </div>
                
                <div className="grid grid-cols-2 gap-4">
                    <motion.button 
                        variants={itemVariants}
                        whileTap={{ scale: 0.96 }}
                        onClick={onTrackByNumber}
                        className="p-6 bg-white/[0.02] border border-white/[0.05] rounded-[var(--radius-lg)] hover:bg-white/[0.04] hover:border-white/10 transition-all text-left flex flex-col items-start gap-4 group"
                    >
                        <div className="w-11 h-11 rounded-xl bg-white/[0.03] flex items-center justify-center text-white/20 group-hover:text-[var(--accent)] group-hover:scale-110 border border-white/[0.05] transition-all">
                            <Bus size={20} />
                        </div>
                        <div className="flex flex-col">
                            <h4 className="text-[10px] font-black text-white tracking-widest uppercase">Fleet ID</h4>
                            <p className="text-[8px] font-bold text-white/10 uppercase tracking-[0.2em] mt-1.5">Direct Lookup</p>
                        </div>
                    </motion.button>

                    <motion.button 
                        variants={itemVariants}
                        whileTap={{ scale: 0.96 }}
                        onClick={onFindNearby}
                        className="p-6 bg-white/[0.02] border border-white/[0.05] rounded-[var(--radius-lg)] hover:bg-white/[0.04] hover:border-white/10 transition-all text-left flex flex-col items-start gap-4 group"
                    >
                        <div className="w-11 h-11 rounded-xl bg-white/[0.03] flex items-center justify-center text-white/20 group-hover:text-[var(--emerald)] group-hover:scale-110 border border-white/[0.05] transition-all">
                            <Navigation2 size={20} />
                        </div>
                        <div className="flex flex-col">
                            <h4 className="text-[10px] font-black text-white tracking-widest uppercase">Depot Scan</h4>
                            <p className="text-[8px] font-bold text-white/10 uppercase tracking-[0.2em] mt-1.5">Nearby Nodes</p>
                        </div>
                    </motion.button>
                </div>

                <motion.div 
                    variants={itemVariants}
                    className="p-5 bg-white/[0.01] border border-white/[0.04] rounded-[var(--radius-lg)] flex items-center gap-5 group cursor-pointer hover:bg-white/[0.03] hover:border-white/10 transition-all"
                >
                    <div className="w-11 h-11 rounded-xl bg-white/[0.03] flex items-center justify-center text-white/10 group-hover:text-white transition-all">
                        <History size={18} />
                    </div>
                    <div className="flex flex-col flex-1">
                        <h4 className="text-[9px] font-black text-white/30 tracking-widest uppercase leading-none mb-2">Transit Logs</h4>
                        <p className="text-[8px] font-bold text-white/5 uppercase tracking-[0.3em] leading-none">Global Network Active</p>
                    </div>
                    <ChevronRight size={16} className="text-white/5 group-hover:text-white transition-all group-hover:translate-x-1" />
                </motion.div>
            </div>
        </motion.div>
    );
};

export default HomeHero;
