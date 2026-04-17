import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const Sidebar = ({ children, isOpen, onToggle }) => {
  return (
    <>
      {/* Mobile Toggle Button */}
      <button 
        onClick={onToggle}
        className="lg:hidden fixed bottom-8 left-1/2 -translate-x-1/2 z-[3000] px-8 py-4 glass-dark rounded-full flex items-center gap-3 shadow-2xl active:scale-95 transition-all text-white border border-white/20 backdrop-blur-3xl animate-fade-in"
      >
        <div className={`w-2 h-2 rounded-full ${isOpen ? 'bg-red-500' : 'bg-[#4ade80]'} shadow-[0_0_8px_rgba(74,222,128,0.5)] animate-pulse`} />
        <span className="text-[10px] font-black uppercase tracking-[0.4em]">
          {isOpen ? 'Close Explorer' : 'Quick Search'}
        </span>
      </button>

      <aside className={`
        fixed inset-y-0 left-0 z-[2000] w-[440px] shrink-0 bg-[#050505] border-r border-white/10 flex flex-col overflow-hidden transition-all duration-500 ease-[cubic-bezier(0.4,0,0.2,1)] shadow-2xl
        lg:relative lg:translate-x-0 lg:h-screen lg:max-h-screen
        ${isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
      `}>
        {/* Sidebar Header: Premium Homepage Style */}
        <div className="px-8 pt-10 pb-4">
            <div className="flex flex-col gap-2">
                <h1 className="text-3xl font-black tracking-tighter leading-none py-1 flex items-baseline gap-0.5">
                    <span className="bg-clip-text text-transparent bg-gradient-to-br from-[#ededed] via-[#ededed]/90 to-white/20">WhereIs</span>
                    <span className="text-[#ededed]">MyBus</span>
                </h1>
                <div className="flex items-center gap-2 px-1">
                    <div className="w-1.5 h-1.5 rounded-full bg-[#4ade80] shadow-[0_0_12px_rgba(74,222,128,0.6)] animate-pulse" />
                    <p className="text-[9px] font-black text-white/80 uppercase tracking-[0.4em] font-sans">Institutional Portal</p>
                </div>
            </div>
        </div>
        
        <div className="flex-1 overflow-y-auto px-8 py-4 scrollbar-hide">
            {children}
        </div>

        {/* Sidebar Footer */}
        <div className="px-8 py-8 border-t border-white/5 bg-white/[0.01]">
            <p className="text-[8px] font-black text-white/40 uppercase tracking-[0.4em] italic leading-none">Powered by SNS</p>
        </div>
      </aside>

      {/* Mobile Backdrop */}
      {isOpen && (
        <div 
          onClick={onToggle}
          className="lg:hidden fixed inset-0 bg-black/60 backdrop-blur-sm z-[1900] transition-opacity duration-500"
        />
      )}
    </>
  );
};

export default Sidebar;
