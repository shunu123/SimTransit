import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, MapPin, Bus, Navigation2, X, ChevronRight, History, Clock, Calendar } from 'lucide-react';

const TransitDrawer = ({ 
    isOpen, 
    onClose, 
    onSearch, 
    onFindNearby,
    onTrackByNumber,
    searchMode = 'transit',
    onModeChange 
}) => {
    const [fromStop, setFromStop] = useState('');
    const [toStop, setToStop] = useState('');

    const drawerVariants = {
        closed: { x: '-100%', transition: { type: 'spring', damping: 25, stiffness: 200 } },
        open: { x: 0, transition: { type: 'spring', damping: 25, stiffness: 200 } }
    };

    return (
        <AnimatePresence>
            {isOpen && (
                <>
                    {/* BACKDROP DIMMER */}
                    <motion.div 
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        onClick={onClose}
                        className="fixed inset-0 bg-black/40 backdrop-blur-[2px] z-[2000]"
                    />

                    {/* SLIDING PANEL */}
                    <motion.div 
                        variants={drawerVariants}
                        initial="closed"
                        animate="open"
                        exit="closed"
                        className="fixed top-0 left-0 bottom-0 w-full max-w-[420px] bg-[#0a0a0a]/95 backdrop-blur-2xl border-r border-white/10 z-[2100] shadow-[20px_0_50px_rgba(0,0,0,0.5)] flex flex-col"
                    >
                        {/* PANEL HEADER */}
                        <div className="p-8 pb-4 flex items-center justify-between">
                            <div className="flex flex-col">
                                <h2 className="text-2xl font-black text-white tracking-tight">Plan Your Journey</h2>
                                <p className="text-[10px] font-black text-white/20 uppercase tracking-[0.3em] mt-1">Real-time Transit Network</p>
                            </div>
                            <button 
                                onClick={onClose}
                                className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/40 hover:bg-white/10 hover:text-white transition-all"
                            >
                                <X size={20} />
                            </button>
                        </div>

                        {/* MODE TOGGLE */}
                        <div className="px-8 py-4">
                            <div className="flex p-1.5 bg-white/5 rounded-2xl border border-white/5">
                                <button 
                                    onClick={() => onModeChange('transit')}
                                    className={`flex-1 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${searchMode === 'transit' ? 'bg-white text-black shadow-lg' : 'text-white/40 hover:text-white'}`}
                                >
                                    Routing
                                </button>
                                <button 
                                    onClick={() => onModeChange('omni')}
                                    className={`flex-1 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${searchMode === 'omni' ? 'bg-white text-black shadow-lg' : 'text-white/40 hover:text-white'}`}
                                >
                                    Stop Lookup
                                </button>
                            </div>
                        </div>

                        {/* SEARCH INPUTS */}
                        <div className="flex-1 overflow-y-auto px-8 py-6 scrollbar-hide">
                            <div className="flex flex-col gap-4">
                                {/* FROM */}
                                <div className="space-y-4">
                                    <label className="text-[10px] font-black text-white/40 uppercase tracking-[0.2em] ml-1">Departure Point</label>
                                    <div className="relative group">
                                        <div className="absolute inset-y-0 left-5 flex items-center text-white/20 group-focus-within:text-[var(--accent)] transition-colors">
                                            <MapPin size={18} />
                                        </div>
                                        <input 
                                            value={fromStop}
                                            onChange={(e) => setFromStop(e.target.value)}
                                            placeholder="Choose origin station..."
                                            className="w-full bg-white/5 border border-white/5 rounded-2xl py-3.5 pl-14 pr-6 text-white font-bold placeholder:text-white/10 outline-none focus:border-[var(--accent)] focus:bg-white/[0.08] transition-all"
                                        />
                                    </div>
                                </div>

                                {/* TO */}
                                <div className="space-y-4">
                                    <label className="text-[10px] font-black text-white/40 uppercase tracking-[0.2em] ml-1">Destination</label>
                                    <div className="relative group">
                                        <div className="absolute inset-y-0 left-5 flex items-center text-white/20 group-focus-within:text-[var(--accent)] transition-colors">
                                            <Search size={18} />
                                        </div>
                                        <input 
                                            value={toStop}
                                            onChange={(e) => setToStop(e.target.value)}
                                            placeholder="Choose destination..."
                                            className="w-full bg-white/5 border border-white/5 rounded-2xl py-3.5 pl-14 pr-6 text-white font-bold placeholder:text-white/10 outline-none focus:border-[var(--accent)] focus:bg-white/[0.08] transition-all"
                                        />
                                    </div>
                                </div>

                                {/* OPTIONS */}
                                <div className="grid grid-cols-2 gap-4 mt-2">
                                    <div className="p-4 bg-white/5 rounded-2xl border border-white/5 flex items-center gap-3">
                                        <Clock size={16} className="text-white/20" />
                                        <span className="text-xs font-bold text-white/40">Now</span>
                                    </div>
                                    <div className="p-4 bg-white/5 rounded-2xl border border-white/5 flex items-center gap-3">
                                        <Calendar size={16} className="text-white/20" />
                                        <span className="text-xs font-bold text-white/40">Today</span>
                                    </div>
                                </div>

                                {/* FIND BUSES BUTTON */}
                                <button 
                                    onClick={() => onSearch(fromStop, toStop)}
                                    className="w-full py-4 mt-6 bg-white text-black rounded-2xl text-[11px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-2 hover:bg-[var(--accent)] hover:text-white transition-all shadow-2xl shadow-white/5 hover:shadow-[var(--accent-glow)] active:scale-95"
                                >
                                    Find Buses <ChevronRight size={18} />
                                </button>
                            </div>

                            {/* QUICK ACTIONS */}
                            <div className="mt-12 space-y-6">
                                <h3 className="text-[10px] font-black text-white/20 uppercase tracking-[0.4em] px-1">Quick Discovery</h3>
                                <div className="grid grid-cols-2 gap-4">
                                    <button 
                                        onClick={onFindNearby}
                                        className="p-6 bg-white/5 border border-white/5 rounded-3xl hover:bg-white/10 transition-all text-left group"
                                    >
                                        <div className="w-12 h-12 rounded-2xl bg-white/5 flex items-center justify-center text-white/20 group-hover:text-[#4ade80] transition-colors mb-4">
                                            <Navigation2 size={24} />
                                        </div>
                                        <span className="text-xs font-black text-white uppercase tracking-widest">Nearby</span>
                                    </button>
                                    <button 
                                        onClick={onTrackByNumber}
                                        className="p-6 bg-white/5 border border-white/5 rounded-3xl hover:bg-white/10 transition-all text-left group"
                                    >
                                        <div className="w-12 h-12 rounded-2xl bg-white/5 flex items-center justify-center text-white/20 group-hover:text-[var(--accent)] transition-colors mb-4">
                                            <Bus size={24} />
                                        </div>
                                        <span className="text-xs font-black text-white uppercase tracking-widest">Fleet</span>
                                    </button>
                                </div>
                            </div>
                        </div>

                        {/* FOOTER */}
                        <div className="p-8 border-t border-white/5 bg-white/[0.02]">
                            <div className="flex items-center gap-4 text-white/10">
                                <History size={16} />
                                <span className="text-[10px] font-black uppercase tracking-widest">Recent Search Logs</span>
                            </div>
                        </div>
                    </motion.div>
                </>
            )}
        </AnimatePresence>
    );
};

export default TransitDrawer;
