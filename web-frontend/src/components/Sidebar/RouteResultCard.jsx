import React from 'react';
import { motion } from 'framer-motion';
import { Bus, Clock, ChevronRight, Zap } from 'lucide-react';

const RouteResultCard = ({ 
    busNo, 
    routeName, 
    arrivals = [4, 15, 24], 
    frequency = "Every 12 mins",
    isLive = true,
    onClick 
}) => {
    return (
        <motion.div 
            whileHover={{ x: 4 }}
            onClick={onClick}
            className="group relative bg-white/[0.03] hover:bg-white/[0.08] border border-white/5 hover:border-[var(--accent)] rounded-[32px] p-6 mb-4 cursor-pointer transition-all duration-300 flex items-center gap-6"
        >
            {/* BUS TAG (Citymapper Style) */}
            <div className="flex-shrink-0 w-20 h-16 bg-white rounded-2xl flex items-center justify-center shadow-xl group-hover:bg-[var(--accent)] transition-colors">
                <span className="text-xl font-black text-black group-hover:text-white tracking-tighter">{busNo}</span>
            </div>

            {/* ROUTE INFO */}
            <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                    <h3 className="text-lg font-black text-white truncate">{routeName}</h3>
                    {isLive && (
                        <div className="flex items-center gap-1.5 px-2 py-0.5 bg-[#4ade80]/10 rounded-full">
                            <div className="w-1.5 h-1.5 rounded-full bg-[#4ade80] animate-pulse" />
                            <span className="text-[8px] font-black text-[#4ade80] uppercase tracking-widest">Live</span>
                        </div>
                    )}
                </div>
                <div className="flex items-center gap-4 text-white/30 truncate">
                    <div className="flex items-center gap-1">
                        <Clock size={12} />
                        <span className="text-[10px] font-bold uppercase tracking-wider">{frequency}</span>
                    </div>
                </div>
            </div>

            {/* ETAs (The "in 4, 15, 23 min" section) */}
            <div className="flex flex-col items-end gap-1 px-4">
                <div className="flex items-baseline gap-1 text-[var(--accent)]">
                    <span className="text-2xl font-black tracking-tighter">{arrivals[0]}</span>
                    <span className="text-[10px] font-black uppercase">min</span>
                </div>
                <div className="flex gap-2 opacity-40">
                    {arrivals.slice(1).map((min, i) => (
                        <span key={i} className="text-[10px] font-black tracking-tight">{min}m</span>
                    ))}
                </div>
            </div>

            {/* ACTION */}
            <div className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/20 group-hover:bg-[var(--accent)] group-hover:text-white group-hover:rotate-45 transition-all">
                <ChevronRight size={20} />
            </div>
        </motion.div>
    );
};

export default RouteResultCard;
