import React, { useEffect } from 'react';
import { ArrowLeft, Clock, Info, Navigation2, Activity, ShieldAlert } from 'lucide-react';
import LiveTimeline from './LiveTimeline';
import { motion } from 'framer-motion';

const LiveTrackingView = ({ selectedBus, routeStops, onBack, tripStats, wsData }) => {
  const liveStats = wsData[selectedBus?.bus_no] || {};
  
  return (
    <motion.div 
      initial={{ x: 20, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: 20, opacity: 0 }}
      className="flex flex-col h-full overflow-hidden"
    >
      <div className="glass rounded-[24px] p-6 mb-6 relative overflow-hidden">
        {/* Abstract Background Decoration */}
        <div className="absolute top-[-20%] right-[-10%] w-32 h-32 bg-[var(--accent)] opacity-[0.1] blur-3xl rounded-full animate-pulse"></div>
        
        <div className="flex items-center gap-4 relative z-10 mb-8 px-1">
          <button 
            onClick={onBack}
            className="w-12 h-12 bg-white/5 hover:bg-white/10 rounded-2xl transition-all duration-300 text-white border border-white/10 flex items-center justify-center active:scale-90"
          >
            <ArrowLeft size={20} />
          </button>
          <div className="flex flex-col gap-1.5 justify-center">
            <div className="flex items-center gap-2.5">
              <div className="w-2 h-2 rounded-full bg-[#4ade80] shadow-[0_0_12px_rgba(74,222,128,0.5)] animate-pulse" />
              <h2 className="text-2xl font-black text-white tracking-tighter leading-none">#{selectedBus?.bus_no}</h2>
            </div>
            <p className="text-[9px] font-black text-white/30 uppercase tracking-[0.4em] leading-none px-0.5">
              Live Monitoring
            </p>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4 relative z-10 px-0.5">
          <div className="bg-white/5 border border-white/5 rounded-2xl p-5 hover:bg-white/[0.08] transition-all group shadow-xl">
            <div className="flex items-center gap-2 mb-3">
              <Activity size={12} className="text-[var(--accent)]" />
              <p className="text-[9px] font-black text-white/20 uppercase tracking-[0.2em] leading-none">Velocity</p>
            </div>
            <div className="flex items-baseline gap-1.5">
              <span className="text-3xl font-black text-white tracking-tighter leading-none">{liveStats.speed || selectedBus?.speed || 0}</span>
              <span className="text-[10px] font-black text-white/20 tracking-widest uppercase">KM/H</span>
            </div>
          </div>
          <div className="bg-white/5 border border-white/5 rounded-2xl p-5 hover:bg-white/[0.08] transition-all group shadow-xl">
            <div className="flex items-center gap-2 mb-3">
              <Clock size={12} className="text-[#4ade80]" />
              <p className="text-[9px] font-black text-white/20 uppercase tracking-[0.2em] leading-none">Estimated</p>
            </div>
            <div className="flex items-baseline gap-1.5">
              <span className="text-3xl font-black text-white tracking-tighter leading-none">{tripStats.duration}</span>
              <span className="text-[10px] font-black text-white/20 tracking-widest uppercase">MIN</span>
            </div>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-1 py-2 scrollbar-hide">
        <div className="flex flex-col gap-2 mb-8 px-1">
          <div className="flex items-center justify-between text-[10px] font-black uppercase tracking-[0.4em] text-white/20">
            <span>Route Progress</span>
            <span className="text-[var(--accent-bright)]">65%</span>
          </div>
          <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden border border-white/5">
            <motion.div 
               initial={{ width: 0 }}
               animate={{ width: '65%' }}
               transition={{ duration: 1, ease: [0.4, 0, 0.2, 1] }}
               className="h-full bg-gradient-to-r from-[var(--accent)] to-[var(--accent-bright)] shadow-[0_0_10px_rgba(99,102,241,0.5)]"
            />
          </div>
        </div>
        
        <LiveTimeline 
            routeStops={routeStops} 
            selectedBus={selectedBus}
            tripDuration={tripStats.duration}
        />
      </div>

      <div className="mt-8 flex flex-col gap-4">
        <button className="w-full h-[56px] bg-gradient-to-r from-red-500 to-orange-500 hover:from-red-600 hover:to-orange-600 text-white text-[11px] font-black rounded-2xl transition-all duration-300 flex items-center justify-center gap-3 tracking-[0.3em] uppercase shadow-2xl shadow-red-500/20 active:scale-95 group">
          <ShieldAlert size={18} className="group-hover:rotate-12 transition-transform" />
          <span>Report Emergency</span>
        </button>
        <button 
           onClick={onBack}
           className="w-full h-[56px] bg-white/5 hover:bg-red-500/10 text-white/40 hover:text-red-500 text-[10px] font-black rounded-2xl transition-all duration-300 border border-white/5 hover:border-red-500/20 tracking-[0.4em] uppercase"
        >
          Cancel Tracking
        </button>
      </div>
    </motion.div>
  );
};

export default LiveTrackingView;
