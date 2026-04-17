import React from 'react';
import { Settings, Bell, Search, Map as MapIcon, Layers } from 'lucide-react';
import { motion } from 'framer-motion';

const TopToolbar = ({ activeTrip }) => {
    return (
        <motion.div 
            initial={{ y: -10, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            className="absolute top-6 left-6 right-6 z-[1001] flex items-center justify-between pointer-events-none gap-4"
        >
            {/* LEFT HUD: Status & Quick Utils */}
            <div className="flex items-center gap-4 glass-dark backdrop-blur-3xl rounded-[24px] px-5 py-3 shadow-2xl pointer-events-auto border border-white/10 shrink-0">
                <div className="flex items-center gap-3 md:border-r border-white/10 md:pr-4">
                    <div className="w-9 h-9 bg-gradient-to-br from-[var(--accent)] to-[var(--accent-2)] rounded-[14px] flex items-center justify-center text-white shadow-lg shadow-[var(--accent-glow)]">
                        <MapIcon size={18} strokeWidth={2.5} />
                    </div>
                    <div className="flex flex-col min-w-0">
                        <span className="text-[8px] font-black text-white/20 uppercase tracking-[0.4em] leading-none mb-1">Network Status</span>
                        <div className="flex items-center gap-1.5">
                            <div className="w-1.5 h-1.5 rounded-full bg-[#4ade80] animate-pulse shadow-[0_0_8px_rgba(74,222,128,0.5)]" />
                            <span className="text-[10px] font-black text-white uppercase tracking-widest whitespace-nowrap truncate max-w-[120px] md:max-w-none">
                                {activeTrip ? `Tracking: #${activeTrip.bus_no}` : "Real-time Monitoring"}
                            </span>
                        </div>
                    </div>
                </div>

                <div className="hidden md:flex items-center gap-1">
                    <button className="p-2 text-white/30 hover:text-white transition-all duration-300">
                        <Layers size={16} />
                    </button>
                    <button className="p-2 text-white/30 hover:text-white transition-all duration-300 relative">
                        <Bell size={16} />
                        <span className="absolute top-2 right-2 w-1.5 h-1.5 bg-red-500 rounded-full border border-black shadow-sm" />
                    </button>
                </div>
            </div>

            {/* RIGHT HUD: System Utils (Hidden on small viewports) */}
            <div className="hidden sm:flex items-center gap-3 glass-dark backdrop-blur-3xl rounded-[24px] px-3 py-2 pointer-events-auto border border-white/10 shadow-2xl">
                <button className="p-2 text-white/30 hover:text-white transition-all duration-300">
                    <Search size={18} />
                </button>
                <div className="w-px h-4 bg-white/10" />
                <button className="p-2 text-white/30 hover:text-white transition-all duration-300">
                    <Settings size={18} />
                </button>
            </div>
        </motion.div>
    );
};

export default TopToolbar;
