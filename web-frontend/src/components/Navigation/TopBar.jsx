import React from 'react';
import { motion } from 'framer-motion';
import { Menu, Apple, Smartphone, Compass } from 'lucide-react';

const TopBar = ({ onMenuClick }) => {
  return (
    <div className="h-14 w-full bg-[#0a0a0a] border-b border-white/10 flex items-center justify-between px-4 z-[2000] relative shadow-2xl">
      {/* Left: Menu & Logo */}
      <div className="flex items-center gap-6">
        <button 
          onClick={onMenuClick}
          className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center text-white/60 hover:text-white hover:bg-white/10 transition-all border border-white/5"
        >
          <Menu size={20} />
        </button>
        
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-[var(--accent)] flex items-center justify-center shadow-[0_0_15px_rgba(74,222,128,0.4)]">
            <Compass size={18} className="text-white animate-pulse" />
          </div>
          <div className="flex items-center gap-2 select-none">
            <h1 className="text-sm font-black text-white tracking-[0.2em] uppercase leading-none">WhereIsMyBus</h1>
          </div>
        </div>

        {/* Small Status Pill */}
        <div className="hidden md:flex items-center gap-2 px-3 py-1.5 bg-[#4ade80]/5 rounded-full border border-[#4ade80]/10 ml-4">
            <span className="text-[9px] font-black text-[#4ade80] uppercase tracking-widest leading-none">Healthy</span>
        </div>
      </div>

      {/* Right: Apps & Primary Action */}
      <div className="flex items-center gap-4">
        <div className="hidden sm:flex items-center gap-2 mr-4">
            <button className="w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center text-white/40 hover:text-white transition-all border border-white/5">
                <Apple size={16} />
            </button>
            <button className="w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center text-white/40 hover:text-white transition-all border border-white/5">
                <Smartphone size={16} />
            </button>
        </div>

        <motion.button 
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="px-6 h-10 bg-white text-black rounded-xl text-[10px] font-black uppercase tracking-[0.2em] flex items-center gap-2 shadow-lg shadow-white/5 hover:bg-[var(--accent)] hover:text-white transition-all"
        >
          <Compass size={14} />
          Get Me Somewhere
        </motion.button>
      </div>
    </div>
  );
};

export default TopBar;
