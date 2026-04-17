import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, MapPin, Bus, Navigation2, X, ChevronRight, History } from 'lucide-react';

const FloatingSearchBar = ({ 
    isOpen, 
    onToggle, 
    onSearch, 
    onFindNearby,
    onTrackByNumber,
    searchMode = 'omni', // 'omni' or 'transit'
    onModeChange 
}) => {
    const [query, setQuery] = useState('');
    const [suggestions, setSuggestions] = useState([]);
    const [fromStop, setFromStop] = useState('');
    const [toStop, setToStop] = useState('');

    const handleOmniChange = async (val) => {
        setQuery(val);
        if (val.length > 2) {
            try {
                const res = await onSearch(val, true); // true for suggestions
                if (res?.suggestions) setSuggestions(res.suggestions);
            } catch (err) { console.error(err); }
        } else {
            setSuggestions([]);
        }
    };

    const handleSelect = (s) => {
        onSearch(s); // Selected result
        setQuery(s.name);
        setSuggestions([]);
    };

    const containerVariants = {
        closed: { width: '56px', height: '56px', borderRadius: '28px' },
        open: { width: '400px', height: 'auto', borderRadius: '32px' }
    };

    return (
        <div className="fixed top-8 left-8 z-[2100] pointer-events-none">
            {/* SEARCH ICON / MINIMIZED STATE */}
            <AnimatePresence mode="wait">
                {!isOpen ? (
                    <motion.button 
                        key="search-icon"
                        layoutId="search-container"
                        initial={{ scale: 0.8, opacity: 0 }}
                        animate={{ scale: 1, opacity: 1 }}
                        exit={{ scale: 0.8, opacity: 0 }}
                        onClick={onToggle}
                        className="w-14 h-14 bg-white text-black rounded-full flex items-center justify-center shadow-2xl shadow-black/50 pointer-events-auto hover:bg-[var(--accent)] hover:text-white transition-colors"
                    >
                        <Search size={24} />
                    </motion.button>
                ) : (
                    <motion.div 
                        key="search-bar"
                        layoutId="search-container"
                        variants={containerVariants}
                        initial="closed"
                        animate="open"
                        exit="closed"
                        className="bg-[#0a0a0a]/90 backdrop-blur-3xl border border-white/10 shadow-2xl pointer-events-auto flex flex-col overflow-hidden"
                    >
                        {/* HEADER / MODE SWITCHER */}
                        <div className="p-6 flex items-center justify-between border-b border-white/5">
                            <div className="flex items-center gap-3">
                                <button 
                                    onClick={() => onModeChange('omni')}
                                    className={`px-3 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest transition-all ${searchMode === 'omni' ? 'bg-white text-black' : 'text-white/40 hover:text-white'}`}
                                >
                                    Location
                                </button>
                                <button 
                                    onClick={() => onModeChange('transit')}
                                    className={`px-3 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest transition-all ${searchMode === 'transit' ? 'bg-white text-black' : 'text-white/40 hover:text-white'}`}
                                >
                                    Transit
                                </button>
                            </div>
                            <button onClick={onToggle} className="text-white/20 hover:text-white transition-colors">
                                <X size={20} />
                            </button>
                        </div>

                        {/* OMNI SEARCH (Place/Stop) */}
                        {searchMode === 'omni' && (
                            <div className="p-6 flex flex-col gap-4">
                                <div className="relative group">
                                    <div className="absolute inset-y-0 left-5 flex items-center text-white/20 group-focus-within:text-[var(--accent)] transition-colors">
                                        <MapPin size={18} />
                                    </div>
                                    <input 
                                        autoFocus
                                        value={query}
                                        onChange={(e) => handleOmniChange(e.target.value)}
                                        placeholder="Search for a stop or place..."
                                        className="w-full bg-white/5 border border-white/5 rounded-2xl py-3 pl-14 pr-6 text-white font-bold placeholder:text-white/10 outline-none focus:border-[var(--accent)] transition-all"
                                    />
                                    <AnimatePresence>
                                        {suggestions.length > 0 && (
                                            <motion.div 
                                                initial={{ opacity: 0, y: -10 }}
                                                animate={{ opacity: 1, y: 0 }}
                                                exit={{ opacity: 0, y: -10 }}
                                                className="absolute top-full left-0 right-0 mt-2 bg-black/90 backdrop-blur-3xl border border-white/10 rounded-[20px] overflow-hidden shadow-2xl z-[10]"
                                            >
                                                {suggestions.map((s, i) => (
                                                    <button 
                                                        key={i}
                                                        onClick={() => handleSelect(s)}
                                                        className="w-full flex items-center gap-3 px-6 py-4 hover:bg-white/10 text-left transition-all group"
                                                    >
                                                        <MapPin size={16} className="text-white/20 group-hover:text-[var(--accent)]" />
                                                        <span className="text-sm font-bold text-white/80 group-hover:text-white truncate">{s.name}</span>
                                                    </button>
                                                ))}
                                            </motion.div>
                                        )}
                                    </AnimatePresence>
                                </div>
                                <div className="flex gap-2">
                                    <button 
                                        onClick={onFindNearby}
                                        className="flex-1 py-3 bg-white/5 rounded-xl text-[10px] font-black uppercase tracking-widest text-white/40 hover:text-white transition-all flex items-center justify-center gap-2"
                                    >
                                        <Navigation2 size={14} /> Nearby
                                    </button>
                                    <button 
                                        onClick={onTrackByNumber}
                                        className="flex-1 py-3 bg-white/5 rounded-xl text-[10px] font-black uppercase tracking-widest text-white/40 hover:text-white transition-all flex items-center justify-center gap-2"
                                    >
                                        <Bus size={14} /> Track Bus
                                    </button>
                                </div>
                            </div>
                        )}

                        {/* TRANSIT SEARCH (From -> To) */}
                        {searchMode === 'transit' && (
                            <div className="p-6 flex flex-col gap-3">
                                <div className="flex flex-col gap-2 relative">
                                    <div className="absolute left-6 h-12 w-[1px] bg-white/10 top-1/2 -translate-y-1/2" />
                                    <div className="relative group">
                                        <MapPin size={16} className="absolute left-6 top-1/2 -translate-y-1/2 text-white/20 group-focus-within:text-[var(--accent)]" />
                                        <input 
                                            value={fromStop}
                                            onChange={(e) => setFromStop(e.target.value)}
                                            placeholder="From stop..."
                                            className="w-full bg-white/5 border border-white/5 rounded-xl py-2.5 pl-12 pr-4 text-sm font-bold text-white placeholder:text-white/10 outline-none focus:border-[var(--accent)] transition-all"
                                        />
                                    </div>
                                    <div className="relative group">
                                        <Search size={16} className="absolute left-6 top-1/2 -translate-y-1/2 text-white/20 group-focus-within:text-[var(--accent)]" />
                                        <input 
                                            value={toStop}
                                            onChange={(e) => setToStop(e.target.value)}
                                            placeholder="To destination..."
                                            className="w-full bg-white/5 border border-white/5 rounded-xl py-2.5 pl-12 pr-4 text-sm font-bold text-white placeholder:text-white/10 outline-none focus:border-[var(--accent)] transition-all"
                                        />
                                    </div>
                                </div>
                                <button 
                                    onClick={() => onSearch(fromStop, toStop)}
                                    className="w-full py-3.5 mt-3 bg-white text-black rounded-xl text-[11px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-2 hover:bg-[var(--accent)] hover:text-white transition-all shadow-xl hover:shadow-[var(--accent-glow)] active:scale-95"
                                >
                                    Search Fleet <ChevronRight size={14} />
                                </button>
                            </div>
                        )}

                        {/* RECENT SEARCHES */}
                        <div className="px-6 pb-6 pt-2">
                             <div className="flex items-center gap-3 text-white/10 mb-4 px-1">
                                <History size={14} />
                                <span className="text-[9px] font-bold uppercase tracking-widest">Recent Searches</span>
                             </div>
                             <div className="flex flex-col gap-1">
                                <button className="w-full p-3 rounded-xl hover:bg-white/5 flex items-center justify-between group transition-all">
                                    <span className="text-[11px] font-bold text-white/40 group-hover:text-white">Arumbakkam Metro</span>
                                    <ChevronRight size={12} className="text-white/0 group-hover:text-white/40" />
                                </button>
                                <button className="w-full p-3 rounded-xl hover:bg-white/5 flex items-center justify-between group transition-all">
                                    <span className="text-[11px] font-bold text-white/40 group-hover:text-white">T-Nagar Depot</span>
                                    <ChevronRight size={12} className="text-white/0 group-hover:text-white/40" />
                                </button>
                             </div>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default FloatingSearchBar;
