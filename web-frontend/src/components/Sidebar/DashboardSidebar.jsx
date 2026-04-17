import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { MapPin, Search, ArrowLeftRight, Clock, ChevronRight, User, ShieldCheck, Navigation2, Bus } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';

const DashboardSidebar = ({ onSearch, onFindNearby, onTrackByNumber }) => {
  const { user } = useAuth();
  const [fromStop, setFromStop] = useState('');
  const [toStop, setToStop] = useState('');

  const handleSwap = () => {
    const temp = fromStop;
    setFromStop(toStop);
    setToStop(temp);
  };

  return (
<aside className="w-[400px] h-full bg-[var(--bg)] border-r border-[var(--border)] flex flex-col overflow-hidden relative z-[1500] shadow-[20px_0_80px_rgba(0,0,0,0.4)] px-6 py-10 gap-8">
      
      {/* 1. PROFILE / LOCATION CARD */}
      <div className="w-full">
        <div className="p-7 bg-white/[0.02] rounded-[var(--radius-lg)] border border-white/[0.05] shadow-2xl relative overflow-hidden group hover:border-white/10 transition-colors">
          <div className="absolute top-[-20%] right-[-10%] w-[50%] h-[100%] bg-[var(--accent)] opacity-[0.03] blur-[60px] rounded-full pointer-events-none group-hover:opacity-[0.06] transition-opacity duration-700" />
          
          <div className="flex items-center gap-6">
            <div className="w-14 h-14 rounded-2xl bg-white/[0.03] border border-white/[0.08] flex items-center justify-center relative overflow-hidden shrink-0 group-hover:scale-105 transition-transform duration-500">
                <User size={24} className="text-white/30" />
                <div className="absolute bottom-1 right-1 w-2.5 h-2.5 bg-[var(--emerald)] rounded-full border-2 border-[#1a1a1a]" />
            </div>
            
            <div className="flex flex-col">
              <h2 className="text-2xl font-black text-white tracking-tight leading-none mb-3">Kattankulathur</h2>
              <button className="flex items-center gap-2.5 text-[10px] font-black text-white/30 uppercase tracking-[0.3em] hover:text-white transition-all group/btn">
                Network Region <ChevronRight size={12} className="text-[var(--accent)] group-hover/btn:translate-x-1 transition-transform" />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* 2. SEARCH CARD */}
      <div className="w-full">
        <div className="p-8 bg-white/[0.01] rounded-[var(--radius-lg)] border border-dashed border-white/[0.08] flex flex-col gap-8 relative group hover:border-white/20 transition-all duration-700">
          
          {/* INPUT STACK */}
          <div className="flex flex-col gap-px bg-white/[0.08] rounded-2xl overflow-hidden relative border border-white/[0.05] shadow-2xl">
            <div className="relative group/field">
              <div className="absolute inset-y-0 left-6 flex items-center text-white/20 pointer-events-none group-focus-within/field:text-[var(--accent)] transition-colors">
                <span className="text-[9px] font-black uppercase tracking-widest">From</span>
              </div>
              <input 
                value={fromStop}
                onChange={(e) => setFromStop(e.target.value)}
                placeholder=" "
                className="w-full bg-[#050505] py-3.5 pl-20 pr-6 text-white text-sm font-bold placeholder:text-white/10 outline-none focus:bg-white/[0.01] transition-all"
              />
            </div>

            <div className="h-px w-[calc(100%-24px)] mx-auto bg-white/[0.03]" />

            <div className="relative group/field">
              <div className="absolute inset-y-0 left-6 flex items-center text-white/20 pointer-events-none group-focus-within/field:text-[var(--accent)] transition-colors">
                <span className="text-[9px] font-black uppercase tracking-widest">To</span>
              </div>
              <input 
                value={toStop}
                onChange={(e) => setToStop(e.target.value)}
                placeholder=" "
                className="w-full bg-[#050505] py-3.5 pl-20 pr-6 text-white text-sm font-bold placeholder:text-white/10 outline-none focus:bg-white/[0.01] transition-all"
              />
            </div>

            {/* SWAP BUTTON */}
            <div className="absolute right-4 top-1/2 -translate-y-1/2 z-10">
              <button 
                onClick={handleSwap}
                className="w-9 h-9 rounded-full bg-white text-black flex items-center justify-center hover:bg-[var(--accent)] hover:text-white transition-all shadow-xl active:scale-90"
              >
                <ArrowLeftRight size={14} className="rotate-90" />
              </button>
            </div>
          </div>

          {/* NOW BUTTON */}
          <button className="flex items-center gap-2.5 text-[10px] font-black text-white/40 uppercase tracking-[0.4em] hover:text-white transition-all w-fit px-1 group/now">
            Departing Now <ChevronRight size={14} className="text-[var(--accent)] group-hover/now:translate-x-1 transition-transform" />
          </button>
        </div>
      </div>

      {/* 3. INSTRUCTIONAL AREA */}
      <div className="flex-1 flex flex-col items-center justify-center py-6 px-10 text-center">
          <div className="p-10 bg-white/[0.01] rounded-full border border-dashed border-white/[0.05] mb-8 group hover:border-white/10 transition-all">
            <Navigation2 size={42} className="text-white/5 group-hover:text-[var(--accent)] transition-all duration-700 animate-pulse" />
          </div>
          <h3 className="text-[11px] font-black text-white uppercase tracking-[0.5em] mb-4 opacity-70">Focus the Map</h3>
          <p className="text-[9px] font-bold text-white/20 uppercase tracking-[0.3em] max-w-[240px] leading-relaxed">Select points on the map to automatically calculate routes</p>
      </div>

      {/* FOOTER QUICK TOOLS */}
      <div className="grid grid-cols-2 gap-4 mt-auto">
          <button 
              onClick={onFindNearby}
              className="flex flex-col gap-4 p-7 bg-white/[0.03] rounded-[var(--radius-lg)] border border-white/[0.08] hover:bg-white/[0.08] hover:border-[var(--accent)] transition-all text-left group shadow-2xl"
          >
              <div className="w-10 h-10 rounded-xl bg-[var(--emerald)]/10 flex items-center justify-center text-[var(--emerald)] group-hover:scale-110 transition-transform">
                  <Navigation2 size={18} />
              </div>
              <span className="text-[9px] font-black text-white/40 uppercase tracking-widest leading-none">Nearby Depot</span>
          </button>
          <button 
              onClick={onTrackByNumber}
              className="flex flex-col gap-4 p-7 bg-white/[0.03] rounded-[var(--radius-lg)] border border-white/[0.08] hover:bg-white/[0.08] hover:border-[var(--accent)] transition-all text-left group shadow-2xl"
          >
              <div className="w-10 h-10 rounded-xl bg-[var(--accent)]/10 flex items-center justify-center text-[var(--accent)] group-hover:scale-110 transition-transform">
                  <Bus size={18} />
              </div>
              <span className="text-[9px] font-black text-white/40 uppercase tracking-widest leading-none">Fleet Lookup</span>
          </button>
      </div>

      {/* SECURED BADGE */}
      <div className="pt-8 border-t border-white/[0.05] flex items-center gap-5">
        <div className="w-11 h-11 rounded-xl bg-white/[0.03] border border-white/[0.05] flex items-center justify-center text-[var(--accent)]">
            <ShieldCheck size={22} />
        </div>
        <div className="flex flex-col">
            <span className="text-[10px] font-black text-white uppercase tracking-widest leading-none">Security Protocol</span>
            <span className="text-[8px] font-bold text-white/10 uppercase tracking-[0.2em] mt-2 leading-none">institutional grade encryption</span>
        </div>
      </div>

    </aside>
  );
};

export default DashboardSidebar;
